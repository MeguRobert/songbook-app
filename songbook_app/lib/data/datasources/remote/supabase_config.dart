/// Connection details for the Songbook Supabase project.
///
/// **The anon key belongs in the bundle and that is not a leak.** It is the
/// *publishable* key: Supabase designs it to ship inside clients, and it grants
/// nothing beyond what row-level security allows the `anon` role to do. The
/// security boundary is RLS, not the secrecy of this string — which is why the
/// policies were written and tested (`supabase/tests/songs_rls_test.sql`, 20
/// assertions) before any of this client code existed.
///
/// What must NEVER appear here is the `service_role` key, which bypasses RLS
/// entirely. That one lives only in server-side contexts.
///
/// Supplied at build time from `environment/<flavor>.json`, one file per
/// environment (see `environment/README.md`):
///
///   flutter build web --dart-define-from-file=environment/prod.json
///
/// **The defaults below are STAGING, and that is the whole point.** They used to
/// be production, which meant any build that did not pass the flag — a local
/// `flutter run`, a fork, a workflow with a mistyped filename — silently talked
/// to the live project. Nothing failed; it quietly read and wrote the
/// congregation's catalogue. Production is now the case that must be stated out
/// loud, and it is stated in exactly one reviewed place,
/// `.github/workflows/deploy-pages.yml`. An unconfigured build lands somewhere
/// harmless instead.
///
/// So do not "fix" these back to the production values. A wrong default here
/// fails in the one direction that has no undo.
class SupabaseConfig {
  const SupabaseConfig._();

  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://STAGING_PROJECT_REF.supabase.co',
  );

  /// Supabase renamed this concept: `anonKey` is deprecated in favour of
  /// `publishableKey`. Same value, clearer name — "anon key" invited the reading
  /// that it was a secret for anonymous users, when it is simply the key that is
  /// meant to be published.
  ///
  /// **No longer a legacy HS256 JWT, and that was the point.** The value here
  /// used to decode as `{"alg":"HS256"}` with `{"role":"anon"}`, and because the
  /// client authenticated with a key of that kind, the project had to keep HS256
  /// verification switched on — so rotating the project's JWT keys to ECC never
  /// retired the legacy symmetric secret. While that secret was live, anyone who
  /// obtained it could mint a `service_role` token and bypass every row-level
  /// security policy in the database.
  ///
  /// This is the non-JWT `sb_publishable_…` format instead, which does not
  /// depend on that secret. Verified against the live project before it was
  /// committed: this key answers 200, a same-shaped counterfeit answers 401, and
  /// no key at all answers 401 — so the format is genuinely accepted rather than
  /// merely tolerated. `Supabase.initialize` treats it as an opaque string, sent
  /// as the `apikey` header and never parsed, so nothing but the value changed.
  ///
  /// One step remains and it is not in this codebase: the legacy JWT secret is
  /// still enabled in the dashboard (Settings → JWT Keys) and nothing depends on
  /// it any more. Disabling it is what actually closes the exposure.
  ///
  /// Staging by default, for the reason given on the class. The production key
  /// now lives only in `environment/prod.json`.
  static const String publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_STAGING_KEY_PENDING',
  );

  /// A short budget for the catalogue fetch.
  ///
  /// The app must stay usable with no network and with a paused project (the
  /// free tier sleeps after ~a week idle and answers HTTP 540). Startup
  /// therefore never waits long on the server: on timeout the bundled asset is
  /// used and the app opens as it always did.
  static const Duration fetchTimeout = Duration(seconds: 4);
}
