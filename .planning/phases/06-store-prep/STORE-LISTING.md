# Store Listing Metadata — DRAFT for Robert

> Draft copy for Google Play and Apple App Store. Every value in «guillemets» needs Robert's
> confirmation before submission. Lengths are annotated against each store's hard limits.

## Shared

- **App name:** Songbook
- **Developer / publisher:** «your name / org»
- **Support email:** «support@example.com»
- **Marketing / privacy URL:** «https://… (a one-page site or GitHub Pages is fine)»
- **Bundle id (iOS) / application id (Android):** `com.songbook.songbook_app`
  («Apple bundle id is set in Xcode → PRODUCT_BUNDLE_IDENTIFIER; confirm it matches»)
- **Version:** 1.0.0 (build 1)
- **Languages:** English (UI); song content is Hungarian. «Add Hungarian (hu) localized listing?»

## Google Play

- **Title** (≤30 chars): `Songbook` — 8 chars.
- **Short description** (≤80 chars):
  `Hymns & worship songs with chords, sheet music, transpose & projection mode.` — 76 chars.
- **Full description** (≤4000 chars):

  ```
  Songbook is a clean, offline songbook for musicians and worship leaders. View any hymn or
  worship song with accurate chords and engraved sheet music, transpose it to any key in a tap,
  and project lyrics on a screen during a service.

  FEATURES
  • Chords above lyrics, positioned accurately over each word
  • Real sheet-music notation (custom-engraved, not scanned images)
  • One-tap transposition to any key, with the current key always shown
  • Configurable view: notation, chords, and lyrics — show exactly what you need
  • Presentation mode: full-screen lyrics for projection or large-text personal reading,
    with a dark "projection" theme and verse-by-verse navigation
  • Pinch-to-zoom and adjustable text size
  • Organize songs by book / hymnal and browse or filter by book
  • Favorites and fast search by number, title, or reference
  • Light and dark themes
  • Fully offline — no account, no network, no ads, no tracking

  Built for Hungarian Reformed hymnals (Zsoltárok & Dicséretek) and growing.
  ```
  «Trim/adjust feature list to match what actually ships in 1.0.»

- **Category:** Music & Audio (primary). «Secondary: Books & Reference?»
- **Tags / keywords (Play uses category + description, no keyword field):** ensure the description
  naturally includes: hymnal, worship, chords, sheet music, transpose, lyrics, projection, songbook.
- **Content rating (IARC questionnaire):** no objectionable content → expected **Everyone**.
- **Data safety:** **No data collected, no data shared.** App has no network access and stores only
  local preferences (theme, view, favorites, selected book) on-device. Declare accordingly.
- **Ads:** None.

## Apple App Store

- **Name** (≤30 chars): `Songbook`.
- **Subtitle** (≤30 chars): `Hymns, chords & sheet music` — 27 chars.
- **Promotional text** (≤170 chars, editable anytime):
  `Chords, real sheet music, instant transpose, and full-screen projection — a clean offline
  songbook for worship.` — «confirm ≤170».
- **Keywords** (≤100 chars, comma-separated, no spaces needed):
  `hymnal,worship,chords,sheet music,transpose,lyrics,projection,songbook,church,hymns` — «trim to ≤100».
- **Description:** reuse the Play full description (no length issue).
- **Primary category:** Music. **Secondary:** Reference. «confirm»
- **Age rating:** 4+ (no objectionable content).
- **Privacy (App Privacy "nutrition label"):** **Data Not Collected.** No tracking, no network.
- **Privacy policy URL:** required by Apple even when no data is collected — «provide a short one».

## Screenshot shot-list (capture on device/emulator — pending, no device overnight)

Capture both **phone** (6.5"/6.7" required by Apple) and **tablet/iPad**; Play wants ≥2, Apple ≥3:

1. Song list (a book selected, showing book name in the app bar)
2. Song view — sheet music + chords (notation on screen)
3. Song view — chords + lyrics
4. Controls bottom sheet open (view presets + transpose + text size)
5. Transposed song (key badge visible)
6. Presentation mode — full-screen lyrics, projection (dark) theme
7. Book browser
8. Settings (theme + default view)

«Optionally add a feature-graphic 1024×500 for Play and an App Store preview video.»

## Pre-submission content check (criterion #5: "no placeholder content")

- App display name is "Songbook" (not "songbook_app"). ✅ (06-02)
- Launcher icon / splash are **still placeholders** — must be replaced with final art before submit. ⛔
- Bundled songs are real hymnal entries (no lorem-ipsum). ✅
- No debug-only UI in release: the sheet-music renderer shows a "Canvas/SVG" badge **only in
  kDebugMode**, so release builds are clean. ✅ (verify during the on-device release build)
