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
/// Overridable at build time so a fork or a staging project needs no code edit:
///   flutter build web --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
class SupabaseConfig {
  const SupabaseConfig._();

  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://sjsgrxvebzsuubebbfwx.supabase.co',
  );

  /// Supabase renamed this concept: `anonKey` is deprecated in favour of
  /// `publishableKey`. Same value, clearer name — "anon key" invited the reading
  /// that it was a secret for anonymous users, when it is simply the key that is
  /// meant to be published.
  static const String publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNqc2dyeHZlYnpzdXViZWJiZnd4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU1ODkxNDAsImV4cCI6MjEwMTE2NTE0MH0.bQ-O6dIF2jqrBb5cQ6I4Gc63e7ArZ9X4vjXmmF9VvX4',
  );

  /// A short budget for the catalogue fetch.
  ///
  /// The app must stay usable with no network and with a paused project (the
  /// free tier sleeps after ~a week idle and answers HTTP 540). Startup
  /// therefore never waits long on the server: on timeout the bundled asset is
  /// used and the app opens as it always did.
  static const Duration fetchTimeout = Duration(seconds: 4);
}
