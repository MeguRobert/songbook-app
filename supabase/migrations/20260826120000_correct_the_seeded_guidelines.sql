-- Two language corrections to the seeded contribution guidelines.
--
-- WHY THIS EXISTS. The guidelines are the one piece of prose every member reads
-- before their first submission, and the seed in 20260822120500 was written by
-- someone who does not speak the two languages it was written in. A review found
-- two things:
--
--   hu  "tréfát, próbát, vagy olyan éneket" carries a comma before `vagy`.
--       Hungarian takes no comma before vagy/és/s/meg in a plain list, so the
--       comma is simply wrong -- AkH. rule on coordinated list members.
--
--   ro  "se cântă cu adevărat la închinare" -- `la închinare` is a calque of the
--       English "at worship". The app has already settled on `adunarea` for the
--       congregation (see publishNameBody), so `în adunare` is both idiomatic
--       and consistent with the register the rest of the Romanian now uses.
--
-- The English is untouched; nothing was wrong with it.
--
-- WHY THE `where` CLAUSE MATTERS. This text is administrator-editable at
-- /admin/settings, and an UPDATE that matched on `id = 1` alone would silently
-- overwrite whatever a congregation had since written -- on this project, and on
-- every fork that had already made the settings its own. Matching the exact
-- original seed means this migration corrects the placeholder or does nothing at
-- all. There is no third outcome, and no case where it destroys someone's work.
--
-- Neither column is a translation of the other, so each is guarded on its own
-- value: correcting the Hungarian must not depend on the Romanian still being
-- untouched.

update public.app_settings
   set guidelines_hu = 'Csak olyan énekeket küldj be, amelyeket valóban énekelünk az istentiszteleten. A szöveget és az akkordokat gondosan írd le — valaki ebből fog énekelni. Ne küldj be tréfát, próbát vagy olyan éneket, amelynek megosztására nincs jogod.'
 where id = 1
   and guidelines_hu = 'Csak olyan énekeket küldj be, amelyeket valóban énekelünk az istentiszteleten. A szöveget és az akkordokat gondosan írd le — valaki ebből fog énekelni. Ne küldj be tréfát, próbát, vagy olyan éneket, amelynek megosztására nincs jogod.';

update public.app_settings
   set guidelines_ro = 'Trimite doar cântări care se cântă cu adevărat în adunare. Scrie versurile și acordurile cu atenție — cineva va cânta din ele. Nu trimite glume, teste sau cântări pe care nu ai dreptul să le distribui.'
 where id = 1
   and guidelines_ro = 'Trimite doar cântări care se cântă cu adevărat la închinare. Scrie versurile și acordurile cu atenție — cineva va cânta din ele. Nu trimite glume, teste sau cântări pe care nu ai dreptul să le distribui.';

-- `updated_at` MOVES, and cannot be stopped from moving. app_settings carries
-- `app_settings_touch_updated_at`, a BEFORE UPDATE trigger reusing
-- `touch_updated_at()` from 20260728120000, so any write to this row stamps
-- now() regardless of what the statement asks for. Holding the old value would
-- mean disabling a trigger in the middle of a migration, which is a heavier
-- tool than a spelling fix has earned.
--
-- An earlier draft of this file claimed the opposite. It was wrong, and the
-- check that was supposed to catch it printed the timestamp without comparing
-- it to the value from before the update -- an assertion that could not fail.
--
-- It costs nothing here: `updated_at` is parsed into AppSettings and rendered by
-- no screen, so no administrator is shown a date implying somebody edited these
-- settings. `updated_by` is genuinely untouched and stays null, and that is the
-- column that would name a person. If `updated_at` is ever put on screen, this
-- is the write that makes it lie.
