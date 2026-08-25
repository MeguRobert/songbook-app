import '../../domain/services/import_notice.dart';
import '../../l10n/app_localizations.dart';

/// Says an [ImportNotice] in the language the app is being read in.
///
/// This is the *only* place the importer's and parser's prose exists. Those two
/// services are pure domain code with no `BuildContext`, so they used to build
/// their own English sentences — which is why they were the last untranslated
/// strings a user could see, long after every screen had been done. They now
/// name an [ImportNoticeCode] and carry the facts; the words are here.
///
/// An extension on [AppLocalizations] rather than a free function or a class,
/// because at a call site it then reads exactly like every other translated
/// string — `l10n.importNoticeText(notice)` next to `l10n.importWarningsTitle(n)`
/// — and needs no extra thing to construct or inject.
extension ImportNoticeText on AppLocalizations {
  /// [notice] as a finished sentence.
  ///
  /// An exhaustive `switch` with no default: adding a code becomes a compile
  /// error here instead of a silently unrendered warning. The arguments are
  /// forced non-null at the point of use, which is safe precisely because the
  /// code determines which of them it carries — see [ImportNoticeCode], where
  /// each one documents its own.
  String importNoticeText(ImportNotice notice) => switch (notice.code) {
        ImportNoticeCode.unknownDirective =>
          importNoticeUnknownDirective(notice.line ?? 0, notice.text ?? ''),
        ImportNoticeCode.ambiguousBareRoot =>
          importNoticeAmbiguousBareRoot(notice.line ?? 0, notice.text ?? ''),
        ImportNoticeCode.continuationWithoutChord =>
          importNoticeContinuationWithoutChord(
              notice.line ?? 0, notice.text ?? ''),
        // Quoted, not translated — see ImportNoticeCode.fromReader.
        ImportNoticeCode.fromReader => notice.text ?? '',
        ImportNoticeCode.bracketNotAChord =>
          importNoticeBracketNotAChord(notice.line ?? 0, notice.text ?? ''),
        ImportNoticeCode.photoLowResolution => importNoticePhotoLowResolution(
            notice.text ?? '', notice.count ?? 0),
        ImportNoticeCode.photoShowThroughRemoved =>
          importNoticePhotoShowThroughRemoved,
        ImportNoticeCode.photoTwoSongs =>
          importNoticePhotoTwoSongs(notice.count ?? 0),
        ImportNoticeCode.photoNoChords => importNoticePhotoNoChords,
        ImportNoticeCode.photoNothingLegible =>
          importNoticePhotoNothingLegible,
        ImportNoticeCode.photoGermanNoteNames =>
          importNoticePhotoGermanNoteNames(notice.text ?? ''),
        ImportNoticeCode.photoLowercaseCRaised =>
          importNoticePhotoLowercaseCRaised(notice.count ?? 0),
        ImportNoticeCode.timewiseScore => importNoticeTimewiseScore,
        ImportNoticeCode.noNotes => importNoticeNoNotes,
        ImportNoticeCode.extraVoicesKept =>
          importNoticeExtraVoicesKept(notice.count ?? 0),
        ImportNoticeCode.graceNotesSkipped =>
          importNoticeGraceNotesSkipped(notice.count ?? 0),
        ImportNoticeCode.chordsReducedToTopNote =>
          importNoticeChordsReduced(notice.count ?? 0),
        ImportNoticeCode.doubleAccidentalsApproximated =>
          importNoticeDoubleAccidentals(notice.count ?? 0),
        ImportNoticeCode.doubleDotsReduced =>
          importNoticeDoubleDots(notice.count ?? 0),
        ImportNoticeCode.unsupportedNoteValues =>
          importNoticeUnsupportedNoteValues(notice.count ?? 0, notice.text ?? ''),
        ImportNoticeCode.emptyXmlInput => importNoticeEmptyXmlInput,
        ImportNoticeCode.invalidXml => importNoticeInvalidXml(notice.text ?? ''),
        ImportNoticeCode.containerManifestNotScore =>
          importNoticeContainerManifest,
        ImportNoticeCode.emptyMxlInput => importNoticeEmptyMxlInput,
        ImportNoticeCode.unreadableArchive =>
          importNoticeUnreadableArchive(notice.text ?? ''),
        ImportNoticeCode.noScoreInArchive => importNoticeNoScoreInArchive,
      };
}
