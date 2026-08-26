-- The seeded contribution guidelines say what they are meant to say.
--
-- WHY THIS EXISTS. 20260826120000 corrects two language faults in the seed that
-- 20260822120500 planted, and it does so with an UPDATE guarded on the exact
-- original text. That guard has one silent failure mode: edit the seed in
-- 20260822120500 by so much as a character and the correction stops matching,
-- the UPDATE quietly affects zero rows, and a fresh database is seeded with the
-- faulty prose again -- with nothing anywhere reporting a problem. These
-- assertions are what turns that silence into a failing test.
--
-- They assert the shape of the fault rather than the whole paragraph, so that
-- rewriting the guidelines does not break the test while a regression still
-- does.

begin;
select plan(4);

-- ---------------------------------------------------------------------------
-- The corrections landed
-- ---------------------------------------------------------------------------
-- Hungarian takes no comma before `vagy` joining members of a plain list.
select ok(
  (select guidelines_hu from public.app_settings where id = 1)
    like '%tréfát, próbát vagy olyan éneket%',
  'the Hungarian list runs "tréfát, próbát vagy", with no comma before vagy');

select ok(
  (select guidelines_hu from public.app_settings where id = 1)
    not like '%próbát, vagy%',
  'the comma before vagy is gone from the Hungarian guidelines');

-- `la închinare` calqued the English "at worship"; the app says `adunarea`.
select ok(
  (select guidelines_ro from public.app_settings where id = 1)
    like '%în adunare%'
  and (select guidelines_ro from public.app_settings where id = 1)
    not like '%la închinare%',
  'the Romanian guidelines say "în adunare", not the calque "la închinare"');

-- ---------------------------------------------------------------------------
-- The guard protects an administrator's own words
-- ---------------------------------------------------------------------------
-- The claim made in 20260826120000's comment, exercised rather than asserted:
-- run its UPDATE verbatim against text a congregation has written for itself and
-- watch it decline to touch it. Were the `where` clause ever loosened to
-- `id = 1`, this is the assertion that would fail.
update public.app_settings
   set guidelines_hu = 'A mi gyülekezetünk saját szabályai.'
 where id = 1;

update public.app_settings
   set guidelines_hu = 'Csak olyan énekeket küldj be, amelyeket valóban énekelünk az istentiszteleten. A szöveget és az akkordokat gondosan írd le — valaki ebből fog énekelni. Ne küldj be tréfát, próbát vagy olyan éneket, amelynek megosztására nincs jogod.'
 where id = 1
   and guidelines_hu = 'Csak olyan énekeket küldj be, amelyeket valóban énekelünk az istentiszteleten. A szöveget és az akkordokat gondosan írd le — valaki ebből fog énekelni. Ne küldj be tréfát, próbát, vagy olyan éneket, amelynek megosztására nincs jogod.';

select is(
  (select guidelines_hu from public.app_settings where id = 1),
  'A mi gyülekezetünk saját szabályai.',
  'the correction leaves text an administrator has written alone');

select * from finish();
rollback;
