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

-- `updated_at` is deliberately NOT touched. It means "when an administrator last
-- changed these settings", and it is shown as such; a spelling fix arriving in a
-- migration is not that, and moving it would tell the next administrator that
-- somebody edited the settings when nobody did.
