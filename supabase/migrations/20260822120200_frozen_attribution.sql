-- Who submitted this, recorded so it cannot be edited by the person it names.
--
-- WHY A COPY AND NOT A JOIN. A join to profiles.display_name would have been
-- less to write and worth nothing: display_name is under the contributor's own
-- control, so an audit trail read live from profiles is one the audited party
-- can rewrite after the fact. The account can also be deleted outright, and this
-- column is what keeps an orphaned song attributable afterwards -- the next
-- migration depends on it, including in a check constraint.
--
-- Only songs that have actually been submitted carry a name. A private draft has
-- nothing to attribute yet, and stamping one would imply it had been offered.

alter table public.songs add column submitted_by_name text;

-- Backfill from what is currently known, for songs already submitted.
update public.songs s
   set submitted_by_name = p.display_name
  from public.profiles p
 where p.id = s.owner_id
   and s.submitted_at is not null
   and s.submitted_by_name is null;

create or replace function public.stamp_submitted_by()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  -- Stamp on the transition INTO pending, reached either by an insert that is
  -- already pending or by an owner submitting a draft.
  if new.status = 'pending'
     and (tg_op = 'INSERT' or old.status is distinct from 'pending') then
    new.submitted_by_name :=
      (select display_name from public.profiles where id = new.owner_id);

  elsif tg_op = 'UPDATE' then
    -- Frozen. A client that sends its own value has it discarded rather than
    -- rejected, because the value was never the client's to supply -- there is
    -- nothing for it to be told off about, and an error here would only make
    -- ordinary edits fail for sending a column back unchanged.
    new.submitted_by_name := old.submitted_by_name;
  end if;

  return new;
end;
$$;

-- Runs AFTER the existing status triggers, by name.
--
-- Postgres fires same-timing triggers in alphabetical order, and
-- `songs_enforce_status_transition` < `songs_stamp_submitted_by`. That ordering
-- is load-bearing: the status this reads has already been validated by the
-- transition trigger, so an illegal draft -> approved attempt is refused before
-- a name is ever stamped for it.
create trigger songs_stamp_submitted_by
  before insert or update on public.songs
  for each row execute function public.stamp_submitted_by();
