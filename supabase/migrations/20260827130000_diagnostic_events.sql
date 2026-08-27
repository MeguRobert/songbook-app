-- error_reports stops being only about crashes.
--
-- WHY THIS EXISTS. 20260827120000 built a table for uncaught errors, and uncaught
-- errors turn out to be the minority of what goes wrong here. Everything else is
-- a HANDLED failure, a DEGRADED result or a SILENT FALLBACK: the photo that came
-- back with three of four chord rows, the catalogue that quietly fell back to the
-- bundled asset, the row on the server that no client could parse. None of them
-- raise, so none of them reach FlutterError.onError, so none of them were
-- recorded anywhere at all.
--
-- WHY NOT A SECOND TABLE. It would have needed its own RLS, its own rate guard,
-- its own retention sweep and its own Dart sink -- four things to get right a
-- second time to arrive in the same place. And the cost is not the code: when
-- somebody says "it did not work", whoever reads has to look in ONE place. Two
-- tables means one of them is the one you forget, and it is always the one with
-- the answer in it. A discriminator column costs a `where event = ...`.
--
-- WHAT THIS IS NOT. It is not the audit trail. admin_audit
-- (20260822120400) answers "who did this, and when": it is permanent,
-- append-only, service-role-only, and losing a row is unacceptable. This table
-- answers "why did this fail": it is rate-limited, pruned after 30 days,
-- writable by anon, and losing a row is merely annoying. Those two sets of
-- properties cannot live in one table, which is the whole reason there are two.

-- ---------------------------------------------------------------------------
-- The discriminator
-- ---------------------------------------------------------------------------
-- `default 'crash'` so every row already in the table keeps its meaning, and so
-- a client built before this migration -- a phone with a cached bundle, which on
-- a PWA is the normal case for days after a deploy -- still writes a valid row.
--
-- THE CONSTRAINT LISTS ONLY WHAT SOMETHING ACTUALLY WRITES, and this is a lesson
-- rather than a preference. admin_audit's own constraint has carried
-- 'settings_changed' since the day it was written with NOTHING emitting it, so
-- the schema advertised an accountability guarantee the system did not provide;
-- an administrator could change the submission gate and leave no trace, and the
-- constraint made it look covered. So: two values, because there are two writers.
-- The next event arrives in the same commit as the code that writes it.
--
--   crash        -- an uncaught error. ThrottledCrashReporter.record.
--   photo_import -- one photo-import attempt. BrowserPhotoImportService, via
--                   DiagnosticPhotoImportRecorder.
--
-- These strings are DiagnosticEvent in lib/domain/services/crash_reporter.dart.

alter table public.error_reports
  add column event text not null default 'crash'
    check (event in ('crash', 'photo_import'));

-- ---------------------------------------------------------------------------
-- The measurements
-- ---------------------------------------------------------------------------
-- jsonb rather than columns, and this is the one place in this schema where that
-- is the right answer. app_settings deliberately used columns because it holds a
-- small fixed set of knobs with different types; this holds a DIFFERENT set of
-- numbers per event -- an image's bytes-per-pixel means nothing to a fallback
-- event -- and a column per measurement per event would be a table of mostly
-- nulls that needs a migration every time the reader learns to measure one more
-- thing.
--
-- WHAT MAY GO IN HERE: counts, milliseconds, fractions, sizes, enum names,
-- booleans. Numbers and short tokens.
--
-- WHAT MAY NOT, ever: content. No image and no bytes of one, no words read off a
-- page, no lyrics, no ChordPro, no file names, no email addresses, no free text a
-- user typed. This table is readable by every moderator, an anonymous client
-- writes it, and there is no mechanism here that could review what was sent --
-- so the rule has to be absolute rather than judged case by case.
-- deploy/omr/server.py has followed exactly this rule since it was written: it
-- logs the note count and the elapsed time and never the score.
--
-- 2000 characters is the cap and it is small on purpose. Anything that does not
-- fit in two kilobytes of JSON is not a measurement. length(details::text) rather
-- than pg_column_size() because jsonb_out is immutable and a CHECK constraint may
-- only call immutable functions.
alter table public.error_reports
  add column details jsonb not null default '{}'::jsonb
    check (length(details::text) <= 2000);

-- ---------------------------------------------------------------------------
-- The guard learns about both
-- ---------------------------------------------------------------------------
-- Replaced whole rather than patched, because this function IS the contract: it
-- is the only thing standing between an anonymous insert endpoint and the table,
-- and reading it should not mean reading a base version plus a diff. Everything
-- 20260827120000 established is unchanged and its reasoning is not repeated here.
--
-- Two clauses are new:
--
--   * `event` is coalesced to 'crash' rather than left to fail the check. A row
--     posted with an unknown event is a client this schema has not met -- a
--     future build, or somebody with curl -- and dropping it silently is the same
--     choice the rate ceiling already makes. A refusal here is an error raised
--     inside the error reporter, which the client can only swallow.
--
--   * `details` is emptied if it is too large or is not an object. Emptied, not
--     truncated: half a JSON document is not a smaller JSON document, and there
--     is no partial form of it worth keeping. The event, the outcome in the
--     message and the build number all survive, which is most of the value.

create or replace function public.guard_error_report_insert()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  recent integer;
begin
  -- Identity is the server's to state. See the column comment in 20260827120000.
  new.user_id := auth.uid();

  -- Truncate rather than reject. A stack 4001 characters long is a report worth
  -- keeping, not an insert worth failing.
  new.message      := left(coalesce(nullif(btrim(new.message), ''), 'unspecified error'), 500);
  new.stack        := left(new.stack, 4000);
  new.fingerprint  := left(new.fingerprint, 64);
  new.app_version  := left(new.app_version, 40);
  new.build_number := left(new.build_number, 20);
  new.route        := left(new.route, 200);
  new.locale       := left(new.locale, 20);
  new.platform     := left(new.platform, 200);

  -- An event this schema does not know is recorded as what it certainly is: a
  -- report of something going wrong.
  if new.event is null or new.event not in ('crash', 'photo_import') then
    new.event := 'crash';
  end if;

  -- Anything that is not a small object of measurements becomes no measurements.
  if new.details is null
     or jsonb_typeof(new.details) <> 'object'
     or length(new.details::text) > 2000 then
    new.details := '{}'::jsonb;
  end if;

  -- created_at is the pruner's and the counter's clock, so it is not the
  -- client's to set either.
  new.created_at := now();

  -- ONE ceiling for the whole table, deliberately not one per event. The thing
  -- being bounded is what this table can cost, and that does not care which
  -- event is filling it. A per-event ceiling would also mean a crash storm could
  -- not be crowded out by imports and vice versa, which sounds fairer and is
  -- worse: 60 an hour is already far above anything this app produces
  -- legitimately, so hitting it at all means something is wrong that the app's
  -- own client-side throttles failed to bound.
  select count(*) into recent
    from public.error_reports
   where created_at > now() - interval '1 hour';

  if recent >= 60 then
    -- RETURN NULL in a BEFORE INSERT row trigger skips the row without raising.
    return null;
  end if;

  -- Retention, without a scheduler. Roughly one insert in twenty pays for an
  -- index range scan and deletes anything older than 30 days.
  if random() < 0.05 then
    delete from public.error_reports where created_at < now() - interval '30 days';
  end if;

  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Reading them apart
-- ---------------------------------------------------------------------------
-- Every real query against this table is "the newest N of one kind", because the
-- two kinds are read for different reasons on different days. The existing
-- created_at index cannot serve that without scanning past the other event's
-- rows, and photo_import rows are expected to outnumber crashes heavily -- an
-- import happens on purpose, a crash does not.
create index error_reports_event_created_at_idx
  on public.error_reports (event, created_at desc);

-- No new GRANT and no new POLICY, and that is worth stating rather than leaving
-- to inference: the columns above are part of a table whose privileges are
-- already correct. anon may INSERT and may not SELECT; moderators and
-- administrators may SELECT via is_admin(); nobody at all may UPDATE or DELETE.
-- A diagnostic event is no more sensitive than a crash and no less, so it needs
-- no different answer.
