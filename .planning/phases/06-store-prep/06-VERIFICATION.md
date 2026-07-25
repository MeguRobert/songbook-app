# Phase 06 Verification: Store Release Prep

**Date:** 2026-06-13 (overnight, unattended)
**Branch:** `claude/phase-6-store-prep` (off `claude/phase-5-song-books`)
**Verifier:** Claude (Opus 4.8) — goal-backward analysis against ROADMAP success criteria.

> Phase 6 is intrinsically part code, part human/online. The codeable slice is implemented and tested;
> every human-only criterion is mapped to an explicit blocker, not faked. No device/network overnight,
> so all on-device and store-submission steps are PENDING (see RELEASE-CHECKLIST.md).

## Quality Gates

| Gate | Result |
|------|--------|
| `flutter analyze` | 8 issues — all pre-existing `info` RadioListTile deprecations in `settings_screen.dart`. **No new issues.** |
| `flutter test` | **23/23 pass** (5 new accessibility tests + 18 prior). |

## Success Criteria → Evidence / Blocker

### Criterion 1 — App icon and splash screen are professional and on-brand ⛔ (scaffolded; needs art)
- Generator config wired and ready: `songbook_app/flutter_launcher_icons.yaml`,
  `songbook_app/flutter_native_splash.yaml` (adaptive icon, android12 splash, light/dark).
- `songbook_app/assets/icons/README.md` documents required source files + regen commands.
- **BLOCKER:** no on-brand source art exists (`assets/icons/` was empty); deps not installable
  offline. Not fabricated. → RELEASE-CHECKLIST.md §A.

### Criterion 2 — Store listing metadata is complete ⛔ (drafted; needs literals + screenshots)
- `STORE-LISTING.md` drafts Play + App Store copy (length-checked), categories, content rating,
  privacy ("no data collected"), and a screenshot shot-list.
- **BLOCKER:** developer name / URLs / support email («…») need Robert; screenshots need a device. →
  RELEASE-CHECKLIST.md §E.

### Criterion 3 — App runs smoothly on Android and iOS without crashes ⛔ (needs device)
- No regressions at code level (analyze clean, 23/23 tests). Release builds expose no debug badge
  (`kDebugMode`-gated).
- **BLOCKER:** real on-device release-build crash/perf testing requires hardware. →
  RELEASE-CHECKLIST.md §D.11/13.

### Criterion 4 — Basic accessibility (text scaling, screen reader labels) works ✅ (code) / ⛔ (device UAT)
- Implemented in 06-01: labeled icon/letter-only controls (settings font-size buttons; controls-sheet
  A−/A+), header semantics, "Song N" tile labels, sheet-music canvas image label, presentation title
  header.
- Automated tests: `test/accessibility/accessibility_test.dart` — `androidTapTargetGuideline`,
  `iOSTapTargetGuideline`, `labeledTapTargetGuideline`, semantic-label checks, 2.5× text-scaling smoke.
- **Pending:** real TalkBack/VoiceOver + system font-slider UAT (no device). → RELEASE-CHECKLIST.md §D.12.

### Criterion 5 — Passes store review (no placeholder content, proper permissions) ✅ (posture) / ⛔ (final art)
- App name is user-facing "Songbook" (Android `android:label`, iOS `CFBundleDisplayName`) — not
  `songbook_app`. (06-02)
- Permissions: Android declares **none** (documented in manifest); iOS declares **no** privacy usage
  strings (documented in Info.plist). Minimal, review-friendly surface.
- Bundled content is real hymnal data; debug-only UI is `kDebugMode`-gated.
- **BLOCKER for full pass:** placeholder launcher icon/splash must be replaced with final art before
  submission (criterion #1).

## Summary

| Criterion | Code-level | Human/online remaining |
|-----------|-----------|------------------------|
| 1 Icon/splash | Config wired | Final art + dep install + regen |
| 2 Listing | Copy drafted | Literals + screenshots + console |
| 3 Stability | No regressions | On-device release testing |
| 4 Accessibility | **Done + tested** | Screen-reader / font-slider UAT |
| 5 Review-ready | Name + permissions done | Final art (see #1) |

The codeable slice of Phase 6 is complete and green. Shipping requires the human/online steps in
`RELEASE-CHECKLIST.md`. See OVERNIGHT-REPORT-2026-06-13.md "Decisions for the morning".
