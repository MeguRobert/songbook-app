-- Where a crash on somebody else's phone goes.
--
-- WHY THIS EXISTS. Until now the app had no error reporting of any kind: no
-- FlutterError.onError, no runZonedGuarded, nothing. A red screen on a phone the
-- owner does not have was simply never known about. The congregation is about to
-- start using this, so "it broke and nobody told me" is the gap being closed.
--
-- WHY NOT SENTRY. It would be a new account, a new SDK, a new origin in the CSP
-- and a new thing to pay for. Supabase is already here, already allowed by the
-- CSP, already the place RLS is understood in this project. A table costs
-- nothing and is read with the same SQL editor the owner already uses.
--
-- THE UNCOMFORTABLE PART. This is the first table in the schema that `anon` may
-- WRITE to. Everything else anon can do is read-only. That is unavoidable --
-- signed-out visitors crash too, and theirs are the reports that matter most,
-- since a signed-out visitor is who a first-time congregation member is -- but
-- it means an insert endpoint reachable by anyone with the publishable key, and
-- that key ships in the bundle. The guards below exist because of that, and
-- their sizing is spelled out rather than guessed at.

-- ---------------------------------------------------------------------------
-- The table
-- ---------------------------------------------------------------------------
-- Every text column is length-capped IN THE SCHEMA, not merely in the Dart that
-- writes it. The client caps are a courtesy to whoever reads the rows; these are
-- the actual bound on what one insert can cost, and they hold no matter what is
-- posted straight at the REST endpoint with curl.
--
-- Worst case per row is about 5 kB. Combined with the 60-per-hour ceiling and
-- the 30-day retention below, the table cannot exceed roughly
--   60 * 24 * 30 * 5 kB  ~=  216 MB
-- and realistic rows are nearer 1 kB, so ~43 MB. That fits the free tier's
-- 500 MB with room to spare, which is the number this had to be sized against.

create table public.error_reports (
  id           uuid primary key default gen_random_uuid(),
  created_at   timestamptz not null default now(),

  -- The one-line summary: the exception's toString(), truncated. `not null`
  -- because a report with nothing to read is not a report; the trigger below
  -- substitutes a placeholder rather than letting a blank one be rejected.
  message      text not null check (length(message) between 1 and 500),

  -- The stack, already truncated client-side to the top frames. 4000 characters
  -- is roughly 40 frames, which is far past the point where a Flutter stack
  -- stops being about the app and starts being about the framework.
  stack        text check (stack is null or length(stack) <= 4000),

  -- A grouping key computed by the client from the message and the top frames.
  -- The client also throttles on it, so `occurrences` says how many times the
  -- same fault fired since the last row was written -- a build loop reports
  -- "and 214 more" instead of writing 214 rows.
  fingerprint  text    check (fingerprint is null or length(fingerprint) <= 64),
  occurrences  integer not null default 1 check (occurrences between 1 and 100000),

  -- Which build. Without this a report is nearly useless: "it crashes" against
  -- an unknown deploy cannot be reproduced or confirmed fixed. build_number is
  -- the commit count CI stamps in, so it identifies the deploy exactly.
  app_version  text check (app_version  is null or length(app_version)  <= 40),
  build_number text check (build_number is null or length(build_number) <= 20),

  -- Where in the app, as a router location ('/song/123', '/admin/queue').
  route        text check (route is null or length(route) <= 200),

  -- Which interface language was on screen. Layout faults are routinely
  -- language-specific -- Hungarian and Romanian strings are longer than English.
  locale       text check (locale is null or length(locale) <= 20),

  -- Coarse platform: 'web/android 412x915 dpr2.6'. Deliberately NOT the raw
  -- user-agent. The bucket ("it only breaks on iPhones", "it only breaks
  -- narrow") is the whole diagnostic value, and a full UA string is a
  -- fingerprinting surface for no extra benefit.
  platform     text check (platform is null or length(platform) <= 200),

  -- Nullable, and the null case is the important one. A signed-out visitor is
  -- the app's default state -- Songbook works fully without an account -- so
  -- most reports will carry no user at all.
  --
  -- `on delete set null`, matching admin_audit.actor_id: someone deleting their
  -- account must not erase the evidence of a bug they hit.
  --
  -- NEVER supplied by the client. The trigger overwrites it with auth.uid(),
  -- the same "stamped server-side, not supplied by the client" rule that
  -- songs.reviewed_by follows, so nobody can attribute their crash to somebody
  -- else's account.
  user_id      uuid references auth.users (id) on delete set null
);

-- Newest first is the only way this is ever read, and the same index serves the
-- rate counter and the pruner below, both of which are range scans on created_at.
create index error_reports_created_at_idx on public.error_reports (created_at desc);

-- ---------------------------------------------------------------------------
-- The abuse guard
-- ---------------------------------------------------------------------------
-- WHAT WAS REJECTED, and why:
--
--   Per-IP limiting. The address is only reachable as
--   current_setting('request.headers')::json->>'x-forwarded-for', which is
--   absent for anything that is not a PostgREST request, spoofable by the
--   caller, and shared by everyone behind one church wifi router. It would have
--   rate-limited the congregation and not the attacker.
--
--   Per-user limiting. The reports that matter most have no user.
--
--   A captcha or a signed nonce. Both need a server the project does not run,
--   and both would fail closed exactly when the app is broken, which is the one
--   moment this table has to work.
--
--   pg_cron for retention. It is an extension the owner would have to enable in
--   the dashboard before applying this migration, and a migration that silently
--   does nothing when a prerequisite is missing is worse than no migration.
--
-- WHAT IS DONE INSTEAD: one GLOBAL ceiling on the rate of inserts. It does not
-- care who is calling, which is the point -- there is no identity here worth
-- trusting. 60 rows an hour is far above anything this app can legitimately
-- produce (a congregation of a few hundred, each crashing twice an hour, still
-- fits) and far below anything worth calling an attack. Past it, inserts are
-- DROPPED SILENTLY rather than refused: a refusal is an error raised inside the
-- error reporter, and the client would have to swallow it anyway, so the honest
-- answer is to accept the request and store nothing.
--
-- `security definer` is required, not stylistic: the trigger counts rows in a
-- table that anon has no SELECT privilege on and no SELECT policy for. As the
-- invoker the count would be a permission error, and if it were not, RLS would
-- make it zero and the ceiling would never trigger.

create or replace function public.guard_error_report_insert()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  recent integer;
begin
  -- Identity is the server's to state. See the column comment.
  new.user_id := auth.uid();

  -- Truncate rather than reject. The check constraints above are the real cap
  -- and stay as the backstop for any other write path, but a stack that is 4001
  -- characters long is a report worth keeping, not an insert worth failing --
  -- and a failed insert here is a crash the owner never hears about.
  new.message      := left(coalesce(nullif(btrim(new.message), ''), 'unspecified error'), 500);
  new.stack        := left(new.stack, 4000);
  new.fingerprint  := left(new.fingerprint, 64);
  new.app_version  := left(new.app_version, 40);
  new.build_number := left(new.build_number, 20);
  new.route        := left(new.route, 200);
  new.locale       := left(new.locale, 20);
  new.platform     := left(new.platform, 200);

  -- created_at is the pruner's and the counter's clock, so it is not the
  -- client's to set either.
  new.created_at := now();

  select count(*) into recent
    from public.error_reports
   where created_at > now() - interval '1 hour';

  if recent >= 60 then
    -- RETURN NULL in a BEFORE INSERT row trigger skips the row without raising.
    return null;
  end if;

  -- Retention, without a scheduler. Roughly one insert in twenty pays for an
  -- index range scan and deletes anything older than 30 days. At the ceiling
  -- above that is at most three sweeps an hour, and at the realistic rate it is
  -- a handful a week -- which is all the table needs, because nothing here is
  -- worth reading a month after it happened. If pg_cron is ever enabled, this
  -- becomes a scheduled call to public.prune_error_reports() and the random()
  -- branch can go.
  if random() < 0.05 then
    delete from public.error_reports where created_at < now() - interval '30 days';
  end if;

  return new;
end;
$$;

create trigger error_reports_guard_insert
  before insert on public.error_reports
  for each row execute function public.guard_error_report_insert();

-- One report per statement, which is what closes the bulk hole.
--
-- PostgREST accepts a JSON ARRAY on POST and turns it into a single multi-row
-- INSERT, so `curl -d '[{...} x 10000]'` is one statement. Whether the row
-- trigger's `select count(*)` above sees rows inserted earlier by that same
-- statement is a snapshot-visibility subtlety, and a rate limit that depends on
-- reading it correctly is a rate limit nobody should trust. This does not
-- depend on it: the transition table holds exactly the rows the statement
-- inserted, counted after the fact, and more than one is refused outright.
--
-- No legitimate caller is affected. The Dart reporter writes one row per crash,
-- and 20260728120100's design note applies here too -- the client is a message,
-- this is the gate.
create or replace function public.guard_error_report_batch()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  n integer;
begin
  select count(*) into n from inserted;
  if n > 1 then
    raise exception 'error_reports accepts one report per statement (got %)', n;
  end if;
  return null;
end;
$$;

create trigger error_reports_guard_batch
  after insert on public.error_reports
  referencing new table as inserted
  for each statement execute function public.guard_error_report_batch();

-- The same sweep, callable by hand from the SQL editor when the owner wants the
-- table emptied on purpose. Granted to nobody: `security definer` plus no grant
-- means only the owner's own session (or a future service-role job) can run it.
create or replace function public.prune_error_reports(older_than interval default interval '30 days')
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  removed integer;
begin
  delete from public.error_reports where created_at < now() - older_than;
  get diagnostics removed = row_count;
  return removed;
end;
$$;

revoke all on function public.prune_error_reports(interval) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- GRANTs and RLS -- both, because they are independent layers
-- ---------------------------------------------------------------------------
-- Same reasoning as 20260728120100 and 20260728120200 spell out at length:
--   GRANT without RLS -> the role reads every row. That is the leak.
--   RLS without GRANT -> "permission denied for table error_reports".
-- Revoke first so a stray default privilege in the cloud cannot survive; grant
-- back precisely.
--
-- Note what anon gets: INSERT and NOTHING ELSE. Not SELECT -- a signed-out
-- visitor may report a crash and may not read anybody's crash, including their
-- own, because reading one back is the only way to confirm the endpoint stores
-- anything, and a write-only endpoint is a much less interesting target.

alter table public.error_reports enable row level security;

revoke all    on public.error_reports from anon, authenticated;
grant  insert on public.error_reports to   anon, authenticated;
grant  select on public.error_reports to   authenticated;

-- Anyone may file one. There is no condition to check that would mean anything:
-- the caller is usually anonymous, and the columns worth trusting (user_id,
-- created_at) are overwritten by the trigger regardless of what was sent.
create policy error_reports_insert_anyone on public.error_reports
  for insert to anon, authenticated
  with check (true);

-- Reading is for the people who can act on it. public.is_admin() has, since
-- 20260822120000, been an alias for can_moderate() -- so this is moderators and
-- administrators, not administrators alone. That is the right set here: a
-- moderator is who else would notice that a screen has been broken since
-- Tuesday. Nothing in a row is personal beyond an opaque user id.
create policy error_reports_read_admin on public.error_reports
  for select to authenticated
  using (public.is_admin());

-- Deliberately absent: any UPDATE or DELETE policy, and any UPDATE or DELETE
-- grant. A crash log that its own subject can edit is not a log -- the same
-- rule admin_audit follows. Removal happens through prune_error_reports(),
-- which no client role may call.
