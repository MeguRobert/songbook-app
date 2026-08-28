import 'dart:typed_data';

/// What the leading bytes of an upload say it is.
///
/// **Why the app has to sniff this itself.** A photo that will not read is
/// diagnosed almost entirely by what was handed over, and the one measurement
/// nothing else can supply is the container: the first real failure from the
/// live app was a scrolled screenshot on a Xiaomi that threw inside
/// `createImageBitmap` after 107ms, before a single pixel was read. Two causes
/// fit that evidence and they need opposite advice — the phone saved it as
/// HEIC, which Chrome cannot decode at all, or the image was simply too large
/// for a phone to decode. Nothing downstream can tell them apart, because
/// nothing downstream ever ran.
///
/// So this is measured **before** the decode is attempted, from the bytes the
/// import service already holds, and it goes into the diagnostic row whether the
/// decode throws or not.
///
/// The file name is deliberately not consulted and deliberately not recorded.
/// `.jpg` on a HEIC file is exactly the situation this exists to catch, and a
/// name is content — `error_reports` is written by an anonymous client and read
/// by moderators, and the rule there is measurements only.
enum ImageFormat {
  jpeg,
  png,
  gif,
  webp,

  /// ISO base-media still image, `ftyp` brand `heic`/`heix`/`hevc`/`hevx`.
  /// Xiaomi, Samsung and Apple all write this when "high efficiency" storage is
  /// on, and no version of Chrome decodes it.
  heic,

  /// The same container under the generic image brands `mif1`/`msf1`/`heif`.
  /// What Android's own camera pipeline most often stamps.
  heif,

  /// AV1 in the same container, brand `avif`/`avis`. Chrome does decode this.
  avif,

  /// An ISO base-media file whose brand is none of the still-image ones —
  /// `isom`, `mp42`, `qt  `. Almost always a video, which is worth telling
  /// apart from bytes that match nothing at all: a motion photo or a screen
  /// recording picked by mistake lands here, and that is a different
  /// conversation from a corrupt file.
  isoBmff,

  pdf,

  /// None of the above, including a file too short to have a signature.
  unknown,
}

/// [bytes] identified by its signature, never by its name.
///
/// Reads at most the first twelve bytes and cannot throw: a truncated,
/// zero-length or entirely unrecognised upload answers [ImageFormat.unknown],
/// which is itself a useful thing for a diagnostic row to say.
ImageFormat sniffImageFormat(Uint8List bytes) {
  bool at(int offset, List<int> signature) {
    if (bytes.length < offset + signature.length) return false;
    for (var i = 0; i < signature.length; i++) {
      if (bytes[offset + i] != signature[i]) return false;
    }
    return true;
  }

  // 0xFFD8FF, not the two-byte SOI alone: a bare 0xFFD8 is one marker and the
  // third byte is what makes it a stream rather than a coincidence.
  if (at(0, const [0xFF, 0xD8, 0xFF])) return ImageFormat.jpeg;
  if (at(0, const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
    return ImageFormat.png;
  }
  // `GIF8`, which covers both 87a and 89a and needs no third case.
  if (at(0, const [0x47, 0x49, 0x46, 0x38])) return ImageFormat.gif;
  // RIFF is a family, so the form type twelve bytes in is the part that says
  // WebP rather than WAVE or AVI.
  if (at(0, const [0x52, 0x49, 0x46, 0x46]) &&
      at(8, const [0x57, 0x45, 0x42, 0x50])) {
    return ImageFormat.webp;
  }
  if (at(0, const [0x25, 0x50, 0x44, 0x46])) return ImageFormat.pdf;

  // ISO base media: a big-endian box length, then `ftyp`, then the major brand.
  // The length is not checked — a HEIC whose first box is malformed is still a
  // HEIC, and this is a diagnosis rather than a parser.
  if (at(4, const [0x66, 0x74, 0x79, 0x70])) {
    if (bytes.length < 12) return ImageFormat.isoBmff;
    final brand = String.fromCharCodes(bytes.sublist(8, 12));
    return switch (brand) {
      'heic' || 'heix' || 'hevc' || 'hevx' => ImageFormat.heic,
      'heif' || 'heim' || 'heis' || 'mif1' || 'msf1' => ImageFormat.heif,
      'avif' || 'avis' => ImageFormat.avif,
      _ => ImageFormat.isoBmff,
    };
  }

  return ImageFormat.unknown;
}
