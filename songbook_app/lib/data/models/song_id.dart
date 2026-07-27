import 'dart:math';

/// Where a song came from, and therefore who guarantees its identity.
enum SongSource {
  /// A song from a bundled hymnal (`assets/data/songs.json`). Its reference is
  /// the hymnal number, which is authoritative and shared between users.
  hymnal('hymnal'),

  /// A song the user imported or wrote locally. Its reference is an opaque
  /// generated id with no meaning outside this device.
  user('user');

  const SongSource(this.wireName);

  /// The token used in the canonical string form and in persisted payloads.
  /// Deliberately explicit rather than [Enum.name] so renaming the enum
  /// constant cannot silently invalidate everything already stored.
  final String wireName;

  static SongSource? fromWireName(String value) {
    for (final source in SongSource.values) {
      if (source.wireName == value) return source;
    }
    return null;
  }
}

/// Identifies one song across the whole app.
///
/// Song identity used to be a bare `int` — the hymnal number — and it was the
/// only key in the system: favourites, recents, setlists, tag overrides and the
/// router all stored one. That works exactly as long as every song comes from a
/// numbered hymnal.
///
/// Imported songs have no hymnal number. Handing them sequential integers does
/// not solve it either: it just moves the collision to the boundary between
/// bundled and user content, where a favourite pointing at `300` becomes
/// ambiguous the moment a hymnal gains a song 300.
///
/// So identity is a *source* plus a *reference*, rendered `hymnal:151` or
/// `user:l9f3a2c4b1`. The source is what makes two references from different
/// origins incomparable rather than accidentally equal.
class SongId implements Comparable<SongId> {
  final SongSource source;

  /// Opaque within a [source]. For [SongSource.hymnal] it is the decimal
  /// hymnal number; for [SongSource.user] a generated token.
  final String ref;

  const SongId({required this.source, required this.ref});

  /// A song from the bundled catalogue, keyed by its hymnal number.
  const SongId.hymnal(int number)
      : source = SongSource.hymnal,
        ref = '$number';

  /// An existing user song whose [ref] has already been generated.
  const SongId.user(this.ref) : source = SongSource.user;

  /// Mints an id for a newly created user song.
  ///
  /// Time-ordered prefix plus randomness: the timestamp keeps ids roughly
  /// sortable by creation and makes collisions between two songs created in the
  /// same millisecond the only case randomness has to cover. There is no server
  /// to allocate from, and a max+1 counter would collide as soon as songs are
  /// ever merged between devices.
  factory SongId.newUserSong({DateTime? now, Random? random}) {
    final stamp = (now ?? DateTime.now()).millisecondsSinceEpoch;
    final rng = random ?? Random();
    final suffix = rng.nextInt(1 << 32).toRadixString(36).padLeft(7, '0');
    return SongId.user('${stamp.toRadixString(36)}$suffix');
  }

  /// The canonical string form, `source:ref`. This is what gets persisted and
  /// what appears in routes.
  String get value => '${source.wireName}:$ref';

  /// The hymnal number, or null for a user song.
  ///
  /// Callers that need a number to *display* should prefer the song's own
  /// `displayNumber`; this exists for the places that still index the bundled
  /// catalogue by int.
  int? get hymnalNumber =>
      source == SongSource.hymnal ? int.tryParse(ref) : null;

  bool get isHymnal => source == SongSource.hymnal;
  bool get isUserSong => source == SongSource.user;

  /// Parses the canonical form, or returns null if [value] is not an id.
  ///
  /// A bare integer is accepted and read as a hymnal number. Every payload
  /// written before song ids existed stores bare ints, so this is the upgrade
  /// path for favourites, recents, setlists and tag overrides — not a
  /// convenience.
  static SongId? tryParse(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;

    final separator = trimmed.indexOf(':');
    if (separator < 0) {
      final legacyNumber = int.tryParse(trimmed);
      return legacyNumber == null ? null : SongId.hymnal(legacyNumber);
    }

    final source = SongSource.fromWireName(trimmed.substring(0, separator));
    final ref = trimmed.substring(separator + 1);
    if (source == null || ref.isEmpty) return null;
    return SongId(source: source, ref: ref);
  }

  /// Like [tryParse] but throws on malformed input. Use where a bad id means a
  /// programming error rather than stale data.
  static SongId parse(String value) {
    final parsed = tryParse(value);
    if (parsed == null) {
      throw FormatException('Not a song id: "$value"');
    }
    return parsed;
  }

  /// Accepts the canonical string, or a bare `int` from a pre-[SongId] payload.
  static SongId? fromJson(Object? json) => switch (json) {
        final int number => SongId.hymnal(number),
        final String text => tryParse(text),
        _ => null,
      };

  String toJson() => value;

  /// Hymnal songs sort by number, user songs by ref, and all hymnal songs sort
  /// before user songs so the bundled catalogue keeps its familiar order with
  /// imports appended rather than interleaved by coincidence of id.
  @override
  int compareTo(SongId other) {
    if (source != other.source) {
      return source.index.compareTo(other.source.index);
    }
    final a = hymnalNumber;
    final b = other.hymnalNumber;
    if (a != null && b != null) return a.compareTo(b);
    return ref.compareTo(other.ref);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SongId &&
          runtimeType == other.runtimeType &&
          source == other.source &&
          ref == other.ref;

  @override
  int get hashCode => Object.hash(source, ref);

  @override
  String toString() => value;
}
