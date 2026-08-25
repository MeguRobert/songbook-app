-- Settings that govern contribution, and the gate that enforces them.
--
-- The whole point of this feature: nothing reaches the shared songbook without a
-- named, verified account that has read the rules. Every one of those conditions
-- is checked HERE, because a check in the Flutter app is a message rather than a
-- gate -- the same division of labour the rest of this schema already uses.

-- ---------------------------------------------------------------------------
-- app_settings: one row, world-readable, administrator-writable
-- ---------------------------------------------------------------------------
-- One row, enforced by `check (id = 1)`. A key/value table would have been more
-- flexible and would have cost a cast per read plus a lookup miss per setting;
-- these are a small fixed set of knobs with different types, so columns are the
-- honest shape. When that stops being true, this table is easy to leave behind.
create table public.app_settings (
  id                       smallint primary key default 1 check (id = 1),

  submissions_open         boolean  not null default true,
  require_confirmed_email  boolean  not null default true,

  -- 0 is permitted rather than special-cased: it means the same as
  -- submissions_open = false, which says it more clearly, so nothing needs to
  -- forbid the redundant way of saying it.
  daily_submission_cap     smallint not null default 5 check (daily_submission_cap >= 0),

  guidelines_en            text not null default '',
  guidelines_hu            text not null default '',
  guidelines_ro            text not null default '',

  updated_at               timestamptz not null default now(),
  updated_by               uuid references auth.users (id) on delete set null
);

-- Seed text, so the gate has something to show before an administrator ever
-- opens the settings screen. Written to be replaced, but not written to be
-- placeholder: an empty guidelines box would make the acceptance tick meaningless
-- on day one, which is the day it matters most.
insert into public.app_settings (id, guidelines_en, guidelines_hu, guidelines_ro) values (
  1,
  'Submit only songs that are actually sung in worship. Type the words and chords carefully — someone will sing from this. Do not submit jokes, tests, or songs you have no right to share.',
  'Csak olyan énekeket küldj be, amelyeket valóban énekelünk az istentiszteleten. A szöveget és az akkordokat gondosan írd le — valaki ebből fog énekelni. Ne küldj be tréfát, próbát, vagy olyan éneket, amelynek megosztására nincs jogod.',
  'Trimite doar cântări care se cântă cu adevărat la închinare. Scrie versurile și acordurile cu atenție — cineva va cânta din ele. Nu trimite glume, teste sau cântări pe care nu ai dreptul să le distribui.'
);

alter table public.app_settings enable row level security;

-- Readable by everyone including anon. A signed-out visitor has to be able to
-- read the guidelines and see whether the door is open BEFORE signing in --
-- otherwise the gate's first stop is "sign in to find out that you cannot".
revoke all on public.app_settings from anon, authenticated;
grant select on public.app_settings to anon, authenticated;
grant update on public.app_settings to authenticated;

create policy app_settings_read_all on public.app_settings
  for select using (true);

create policy app_settings_write_admin on public.app_settings
  for update to authenticated
  using (public.is_administrator())
  with check (public.is_administrator());

-- Reuses the trigger function from 20260728120000.
create trigger app_settings_touch_updated_at
  before update on public.app_settings
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- Accepting the guidelines
-- ---------------------------------------------------------------------------
-- On profiles, which the owner may already update via profiles_write_own.
-- Acceptance is a self-assertion -- the claim "I have read this" is only ever the
-- user's to make -- so self-service is the correct trust level and needs no new
-- policy.
alter table public.profiles add column guidelines_accepted_at timestamptz;

-- ---------------------------------------------------------------------------
-- The gate, in one place
-- ---------------------------------------------------------------------------
-- Called from both the insert trigger and the status-transition trigger, because
-- a song can become 'pending' either way and a gate with two copies is a gate
-- with one hole.
--
-- Raises bare snake_case tokens rather than sentences. The Dart layer maps them
-- to localised messages, exactly as AuthRepository._classify already does for
-- GoTrue's codes: server prose in three languages is not a thing that works, and
-- matching on English text is not a thing that keeps working.
create or replace function public.assert_may_submit(submitter uuid)
returns void
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  settings       public.app_settings;
  confirmed_at   timestamptz;
  accepted_at    timestamptz;
  submitter_name text;
  today_count    integer;
begin
  -- Moderators and above are exempt. They are the people the gate exists to
  -- serve, a moderator entering a song is already a reviewed act, and a cap that
  -- stops the reviewer working during a busy week would be the first thing
  -- anybody asked to have removed.
  if public.can_moderate() then
    return;
  end if;

  select * into settings from public.app_settings where id = 1;

  if not settings.submissions_open then
    raise exception 'submissions_closed';
  end if;

  if settings.require_confirmed_email then
    select email_confirmed_at into confirmed_at
      from auth.users where id = submitter;
    if confirmed_at is null then
      raise exception 'email_not_confirmed';
    end if;
  end if;

  select guidelines_accepted_at, coalesce(display_name, '')
    into accepted_at, submitter_name
    from public.profiles where id = submitter;

  if accepted_at is null then
    raise exception 'guidelines_not_accepted';
  end if;

  -- A missing display name would force attribution back onto an email address,
  -- publishing it. Refused here as well as prompted for in the UI, because the
  -- prompt is a courtesy and this is the rule.
  if submitter_name = '' then
    raise exception 'display_name_required';
  end if;

  select count(*) into today_count
    from public.songs
   where owner_id = submitter
     and submitted_at >= date_trunc('day', now());

  if today_count >= settings.daily_submission_cap then
    raise exception 'daily_limit_reached';
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Insert side
-- ---------------------------------------------------------------------------
-- Now `security definer`, because assert_may_submit reads auth.users. Otherwise
-- unchanged from 20260728120100.
create or replace function public.enforce_song_insert()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.status = 'pending' and new.source = 'user' then
    perform public.assert_may_submit(new.owner_id);
    new.submitted_at := coalesce(new.submitted_at, now());
  end if;

  if new.status <> 'rejected' then
    new.rejection_reason := null;
  end if;

  return new;
end;
$$;
