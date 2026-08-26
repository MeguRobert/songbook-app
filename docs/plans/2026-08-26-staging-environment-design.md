# A staging environment

**Date:** 2026-08-26
**Branch:** `feat/staging-environment`
**Status:** repo side implemented and verified; four manual steps outstanding
(see "What is not done").

## The problem

There is one Supabase project and it is production. Every migration's first
contact with a cloud database is the congregation's cloud database, and
`master` deploys to GitHub Pages on push, so merging is publishing. The class of
bug this leaves open is recorded in
`2026-08-22-admin-panel-outcome.md`: `service_role` had no table privileges
locally and permissive ones in the cloud, so the Edge Function answered **403 to
a genuine administrator** — a bug that "would have failed on every developer
machine and worked in production, which is the worst version of this bug."

A local `supabase db reset` structurally cannot catch that. Only a *cloud*
database that is not production can.

## Decisions

Six, each with what was rejected.

### 1. A second Supabase project, not branching and not a shared schema

A free-tier project (the second slot) reproduces cloud default privileges, which
is the specific thing that bit. It costs nothing.

- *Supabase branching* was rejected on price and fit: Pro (~$25/mo) plus
  per-branch compute, and its ephemeral-branch-per-PR model pays off in a PR flow
  this project does not have.
- *One project, a second schema* was rejected because it shares `auth.users`, so
  it cannot rehearse `on_auth_user_created`, the role ladder, or account-delete
  orphaning — which is most of what the recent migrations do. It would also mean
  templatising a schema name that fifteen migrations hardcode.

### 2. A separate origin, not a subpath and not a second repo under one account

**`shared_preferences` on web is `localStorage`, which is scoped per origin and
not per path.** Every GitHub Pages project site under one account is
`<account>.github.io/<repo>/` — one origin. So a `staging/` subpath, *and* a
second repo under the same account, would share settings, setlists and the cached
catalogue with production. A staging bug that wrote nonsense into those keys
would write it into a real congregation member's browser, which is the blast
radius a pre-production environment exists to contain.

Hence a second repository under a **separate organisation**, giving
`<org>.github.io/songbook-app/`: a distinct hostname is a distinct origin, with
its own `localStorage` and its own service-worker scope.

Named `songbook-app` like this repo on purpose. The build carries
`--base-href /songbook-app/`, so identical repo names mean the staging site's
paths match production's exactly and `tools/browser-smoke/` needs no
per-environment case.

*Cloudflare Pages* would also have given a distinct origin for free; rejected in
favour of staying on one host with configuration already understood.

### 3. `staging` → `master`, and production keeps deploying on push

Feature work lands on `staging`, the staging site deploys, you look at it, then
`master` is fast-forwarded and production deploys as it does today.

A manual approval gate on the `github-pages` environment was considered and
rejected: it is one settings change and no workflow edits, but it adds a click to
every release for a project with one developer. **The consequence is accepted
explicitly: merging is still publishing, so "migrations first, then the app"
stays a rule you keep rather than one the pipeline enforces.** What staging buys
is that the migration has already run somewhere real before it runs here.

*A release-tag trigger* was rejected because the pipeline already derives build
numbers from commit count and writes `build-N` tags *after* a successful deploy;
a tag-driven trigger would tangle with a scheme that works.

### 4. Migrations only, plus a synthetic fixture

`supabase db push` against a virgin project already produces the whole catalogue:
`20260728120400` seeds the eight hymnal songs idempotently (ids are
`md5('hymnal:<number>')`) and `20260822120500` seeds the guidelines. Nothing needs
copying.

Test accounts come from **signing up on the staging site**, which is the point —
that exercises `on_auth_user_created`, the trigger most likely to break. Keeping
test accounts out of production is structural rather than disciplinary: a
different project with a different `auth.users` cannot reach it.

What migrations do not give you is a single user submission, so the moderation
queue, the daily cap, the rejection path and frozen attribution are all
invisible. `supabase/seed_staging.sql` fills that in.

*Copying production data* was rejected: production has zero user submissions, so
it would copy nothing that isn't already there, and a `db dump` carries
`auth.users` password hashes — the reason `backups/` is gitignored.

### 5. The compile-time defaults now point at staging

This was not in the original brief and is the largest single risk this work
removes.

`supabase_config.dart` baked production's URL and key as `defaultValue`, and
`deploy-pages.yml` passed no Supabase defines at all — it *relied* on that
default. So any build that omitted the flag silently talked to the live project:
a local `flutter run`, a fork, or a staging workflow with a mistyped filename.
Nothing failed. It just quietly read and wrote the congregation's catalogue.

The defaults are staging. Production is now the case that must be stated out
loud, and it is stated in exactly one reviewed place. An unconfigured build lands
somewhere harmless.

Both deploys then **assert what they built**, on the compiled output rather than
on the flags we believe we passed:

- production fails if `main.dart.js` does not contain the production project;
- staging fails if it contains the production project at all.

Between them, neither environment can quietly become the other. Verified that
this is a real check and not a hopeful one: all three defines appear as literal
strings in the deployed `main.dart.js`.

### 6. A second Cloud Run service, with the CSP rewritten per build

`deploy/omr/server.py` verifies bearer tokens against a single project's JWKS, so
staging tokens get 401 from the production reader. `songbook-omr-staging` runs the
**same image digest** with `SUPABASE_URL` pointed at staging: no second build, no
extra registry storage, scale-to-zero, and inside the Cloud Run free tier at
~$0.001 per page conversion (the binding limit is ~9,000/month, shared with
production).

`web/index.html` is static and shared by both builds, and its CSP names the
production Cloud Run host *literally* — unlike Supabase, which is a
`*.supabase.co` wildcard and needs nothing. The staging workflow rewrites the
**built** copy rather than the source, so production's CSP stays byte-identical
instead of being widened to permit a host only staging calls. The host is read
out of `staging.json`, so the CSP and the address the app actually calls cannot
drift apart.

## The shape

| | staging | production |
|---|---|---|
branch | `staging` | `master` |
site | `<org>.github.io/songbook-app/` | `megurobert.github.io/songbook-app/` |
Supabase | second free project | `sjsgrxvebzsuubebbfwx` |
OMR | `songbook-omr-staging` | `songbook-omr` |
config | `environment/staging.json` | `environment/prod.json` |
gates | analyze, test, python, build, browser walk | the same five |
tags and Releases | none | `build-N`, plus `vX.Y.Z` on a semver move |

## What changed here

- **`songbook_app/environment/`** — `prod.json`, `staging.json`, `template.json`,
  and a README explaining why these are committed. They are not secrets: the
  `sb_publishable_` key is designed to ship in the client and is already in every
  deployed bundle. Committing them buys one place per value.
- **`supabase_config.dart`** — defaults flipped to staging, with a comment saying
  not to flip them back.
- **`deploy-pages.yml`** — `--dart-define-from-file=environment/prod.json`, plus
  the "points at production" assertion.
- **`deploy-staging.yml`** — new. Same gates and same build flags as production,
  a placeholder check that refuses to deploy an unfilled config, the staging
  assertion, the CSP and `<title>` rewrite, the browser walk, and a
  deploy-key push to the staging repository's `gh-pages`.
- **`ci.yml`** — now ignores `staging` as well as `master`, since both have their
  own deploy workflow running the same three checks.
- **`supabase-keepalive.yml`** — a matrix over both projects, reading
  `environment/<flavor>.json` instead of Actions secrets. Not tidiness: the
  production key lived in two places, so a rotation could go half-done and leave
  the keepalive authenticating with a stale key against a project the app reached
  fine. It skips an environment whose config is still a placeholder rather than
  going red every morning for a known reason.
- **`supabase/seed_staging.sql`** — new, and deliberately *not* in `migrations/`,
  because everything there runs against production on the next `db push`.

### The seed's guards

It cannot ask "am I staging?" — a Postgres session does not know which Supabase
project it belongs to. So it guards on facts that are true of staging and false
of production:

1. It does nothing unless the named test accounts exist. In production they do
   not, so running it there is a no-op that says so.
2. It **refuses** if it finds user submissions owned by anyone else, because that
   means real contributors' data is in this database.

Guard 2 will eventually start refusing on staging too, once songs have been
submitted there by hand from an account not in the list. That is correct: at that
point staging holds state you probably did not mean to seed over.

## Verified

| | |
|---|---|
Flutter | 1352 tests pass, `flutter test` |
Analyzer | `flutter analyze --no-fatal-infos` — no issues |
Workflow YAML | all four parse; jobs enumerate as expected |
Environment JSON | all three parse |
Assertion technique | the deployed `main.dart.js` really does contain the URL, key and OMR host as literals, so the guards can see them |
Seed, happy path | 5 rows, one per state, against the local schema — the submission gate admitted the `pending` rows through `assert_may_submit` rather than around it |
Seed, realism | `submitted_by_name`, `submitted_at`, `reviewed_at`/`reviewed_by` and `rejection_reason` all land on the right rows |
Seed, idempotency | a second run inserts 0 and leaves 5 |
Seed, guard 1 | with no test accounts it no-ops with a notice, writing nothing |
Seed, guard 2 | with one foreign submission present it raises and refuses |
Production drift | read-only check: prod already carries `20260826120000`, so `master` and the live database are in step |

Every seed test ran inside a transaction that was rolled back; the local database
is untouched (0 user songs before and after).

Not verified, and cannot be from here: the staging workflow has never run,
because the org, the repo, the Supabase project and the deploy key do not exist
yet.

## What is not done

Four steps need an account this session cannot reach.

1. **Create the free organisation** and tell me the name; it becomes the staging
   URL. Free-org creation is UI-only, not in the REST API.
2. **Create the second Supabase project.** Via the dashboard rather than the CLI,
   so the database password never passes through a transcript. Send back the
   project ref and the `sb_publishable_` key — both safe to paste.
3. **Set `STAGING_PAGES_DEPLOY_KEY`.** I generate the keypair and register the
   public half; you paste the private half. (`gh` here is authenticated as the
   *work* account, which 403s on this repo's secrets.)
4. **First `supabase db push --project-ref <staging>`**, then sign up on the
   staging site, then run `seed_staging.sql` and the promotion statement at the
   foot of it. This first push is the whole point of the exercise: fifteen
   migrations against a virgin cloud project.

Then: delete the now-unreferenced `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY`
repository secrets.

## Deferred on purpose

- **CI does not run `db push`.** Automatic would rehearse ordering for free;
  manual keeps every database write deliberate and puts no database password in
  CI. Matches how production works. Revisit if the manual step gets skipped.
- **`tools/delete-test-admin.py` hardcodes the production ref.** It is a
  production tool and works; a `--project` flag would let it serve staging too.
  Not needed yet.
- **No staging banner in the app.** The hostname and the `(staging)` tab title
  are enough, and a banner would mean shipping UI that only ever appears in one
  environment.
- **No approval gate on production.** Decision 3. One settings change if it is
  ever wanted.
