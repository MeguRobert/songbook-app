-- What an administrator did to somebody's account, and when.
--
-- Written only by the admin-users Edge Function, using the service-role key. No
-- client role gets INSERT, UPDATE or DELETE -- not even an administrator's,
-- because a log its own subject can edit is not a log. The grant below is SELECT
-- and nothing else, and the policy narrows even that to administrators.

create table public.admin_audit (
  id             bigint generated always as identity primary key,

  -- `on delete set null`: an administrator who later leaves must not erase the
  -- record of what they did. actor_name is the frozen copy that survives it,
  -- same reasoning as songs.submitted_by_name.
  actor_id       uuid references auth.users (id) on delete set null,
  actor_name     text,

  action         text not null check (action in
                   ('role_changed', 'user_deleted', 'user_invited', 'settings_changed')),

  -- DELIBERATELY NOT A FOREIGN KEY. The commonest entry here records a deleted
  -- account; an FK would either cascade the evidence away or block the very
  -- delete it is supposed to be recording. target_email is likewise a frozen
  -- copy, because after the delete there is nothing left to join to.
  target_user_id uuid,
  target_email   text,

  details        jsonb not null default '{}'::jsonb,
  at             timestamptz not null default now()
);

-- The panel reads this newest-first and nothing else ever queries it.
create index admin_audit_at_idx on public.admin_audit (at desc);

alter table public.admin_audit enable row level security;

revoke all on public.admin_audit from anon, authenticated;
grant select on public.admin_audit to authenticated;

create policy admin_audit_read_admin on public.admin_audit
  for select to authenticated using (public.is_administrator());
