# Build-time configuration

One JSON file per environment, passed to the build with
`--dart-define-from-file`. Every key here is read by `String.fromEnvironment`
somewhere in `lib/`.

```bash
# Staging — the default for local work, so a forgotten flag is harmless.
flutter build web --release --no-web-resources-cdn \
  --base-href /songbook-app/ \
  --dart-define-from-file=environment/staging.json

# Production. The only place this file is named is deploy-pages.yml.
flutter build web --release --no-web-resources-cdn \
  --base-href /songbook-app/ \
  --dart-define-from-file=environment/prod.json
```

## These files are committed, and that is deliberate

The reference project this pattern comes from gitignores its environment files,
because they hold a Google Maps API key — a real secret. **Nothing here is.**

- `SUPABASE_PUBLISHABLE_KEY` is the `sb_publishable_…` key, which Supabase
  designs to ship inside clients. The security boundary is row-level security,
  not the secrecy of this string; see the comment block in
  `lib/data/datasources/remote/supabase_config.dart`, and the 20 assertions in
  `supabase/tests/songs_rls_test.sql` that were written before the client was.
- `SUPABASE_URL` is in every network request the app makes.
- `PHOTO_IMPORT_ENDPOINT` is a publicly reachable Cloud Run service, by
  design — a browser calls it directly, so Google IAM cannot gate it. It is
  gated by a signed-in user's Supabase token instead.

Committing them buys something worth having: **there is exactly one place each
value lives.** The alternative — secrets in Actions — had the production key in
two places (the workflow secret and the source default), which is a rotation
waiting to go half-done. `supabase-keepalive.yml` now reads these same files
rather than its own copy, so the thing that pings a project cannot disagree with
the app that talks to it.

What must NEVER appear in these files is the `service_role` key, which bypasses
RLS entirely, or a database password. Those live in server-side contexts and in
your password manager respectively.

## Keys

| key | what it is |
|---|---|
`SUPABASE_URL` | `https://<project-ref>.supabase.co` |
`SUPABASE_PUBLISHABLE_KEY` | the `sb_publishable_…` key from Settings → API Keys |
`PHOTO_IMPORT_ENDPOINT` | the Cloud Run `/extract` address, or `""` for a build with no sheet-music reader |

`PHOTO_IMPORT_ENDPOINT` empty is a supported state, not a broken one: the import
screen explains that this build has no reader instead of offering a dead button
(`SettingsRepository.getPhotoImportEndpoint`). The words-and-chords half of photo
import runs in the browser and needs no address at all.

## Adding an environment

Copy `template.json`, fill it in, and name the file in whichever workflow builds
it. Do not add a key here without a `String.fromEnvironment` that reads it — an
unread define is dead weight that reads like configuration.
