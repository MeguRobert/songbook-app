import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/song.dart';
import 'supabase_config.dart';

/// Reads the shared catalogue from Supabase.
///
/// Only *approved* songs are visible here, and that is enforced server-side by
/// row-level security rather than by this query — see
/// `supabase/migrations/20260728120100_songs_rls.sql`. The old Songbook app's
/// defect was filtering unapproved content in the client while the backend
/// streamed everything; adding `.eq('status', 'approved')` below would recreate
/// exactly that pattern of trust, so it is deliberately absent. What the server
/// sends is already all this client is allowed to see.
class RemoteSongDataSource {
  final SupabaseClient _client;

  RemoteSongDataSource(this._client);

  /// Fetches the catalogue, or throws if the server cannot be reached in time.
  ///
  /// Callers are expected to treat a throw as "use the bundled asset" rather
  /// than as an error worth surfacing — being offline is a normal state for this
  /// app, not a failure.
  Future<List<Song>> fetchSongs() async {
    final rows = await _client
        .from('songs')
        .select('id, source, number, payload')
        .order('number')
        .timeout(SupabaseConfig.fetchTimeout);

    final songs = <Song>[];
    for (final row in rows) {
      final song = _tryParse(row);
      if (song != null) songs.add(song);
    }
    return songs;
  }

  /// Turns one row into a [Song], or null if it cannot be understood.
  ///
  /// Deliberately forgiving: a single malformed row must not blank the whole
  /// catalogue and push every user onto the bundled fallback. Skipping the bad
  /// row degrades one song instead of all of them.
  Song? _tryParse(Map<String, dynamic> row) {
    try {
      final payload = row['payload'];
      if (payload is! Map) return null;
      final json = Map<String, dynamic>.from(payload);

      // Identity comes from the row, not the payload, so the server stays
      // authoritative about what a song *is*.
      //
      // `source = 'hymnal'` songs derive their SongId from the hymnal number
      // exactly as the bundled asset does (see song_id.dart), so they carry no
      // explicit id and will collide-and-replace their bundled twin on merge —
      // which is the intent. Anything else is a server-side user submission and
      // needs an explicit id so it cannot be confused with a local song.
      if (row['source'] != 'hymnal') {
        json['id'] = 'user:${row['id']}';
      } else {
        json.remove('id');
      }

      return Song.fromJson(json);
    } catch (_) {
      return null;
    }
  }
}
