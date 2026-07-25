# Release Checklist — Songbook v1.0.0

Ordered path from this branch to submitted store builds. Items marked **[human/online]** cannot be
done by a headless agent (no device, no network, no Apple/Google accounts, no real artwork).

## A. Branding (criterion #1)
1. **[human]** Create final source art and drop it in `songbook_app/assets/icons/`
   (`app_icon.png`, `app_icon_foreground.png`, `splash_logo.png` — see that folder's README).
2. **[online]** `cd songbook_app && flutter pub add dev:flutter_launcher_icons dev:flutter_native_splash`.
3. Run `dart run flutter_launcher_icons` and `dart run flutter_native_splash:create`.
4. Confirm brand colors in `flutter_launcher_icons.yaml` / `flutter_native_splash.yaml`.
5. Commit the regenerated platform icon/splash assets. Remove the default Flutter icon.

## B. Android signing (criterion #5)
6. **[human]** Create an upload keystore: `keytool -genkey -v -keystore upload-keystore.jks ...`.
7. Add `key.properties` (gitignored) + a real `signingConfig` in `android/app/build.gradle.kts`
   (replace the debug-key placeholder — see the comment there).
8. `flutter build appbundle --release` → produces the `.aab` for Play.

## C. iOS signing (criterion #5)
9. **[human]** Apple Developer account; create App ID + provisioning in Xcode; set the team and
   `PRODUCT_BUNDLE_IDENTIFIER` to match `com.songbook.songbook_app`.
10. `flutter build ipa --release` → upload via Xcode/Transporter.

## C2. Web/desktop (only if shipping those targets)
- The web/Windows/macOS launcher-icon generation is disabled in `flutter_launcher_icons.yaml`; enable
  per target if those builds go to a store/PWA.

## D. Verification (criterion #3 + #4 — needs a device)
11. **[human/device]** Smoke-test a **release** build on a physical Android phone and iPhone:
    open songs, transpose, presentation mode, switch books, favorites, search — watch for crashes,
    jank, and that the debug "Canvas/SVG" badge is absent.
12. **[human/device]** Accessibility UAT: TalkBack (Android) + VoiceOver (iOS) read controls and
    headings sensibly; the system font-size slider scales text (06-01 added the labels + scaling).
13. Test on a small phone, a large phone, and a tablet for layout.

## E. Store listings (criterion #2)
14. Fill the «...» literals in `STORE-LISTING.md` (developer name, URLs, support email).
15. **[human/device]** Capture the screenshot shot-list (phone + tablet) from `STORE-LISTING.md`.
16. **[online]** Publish a privacy policy URL (Apple requires one even with no data collected).
17. **[online]** Google Play Console: create app, complete Data safety = "no data collected",
    content rating questionnaire, upload `.aab`, paste listing copy + screenshots.
18. **[online]** App Store Connect: create app record, App Privacy = "Data Not Collected", upload
    build, paste subtitle/keywords/description + screenshots.
19. Submit for review on both stores.

## Already done in code (this branch, Phases 1–6)
- Accessibility labels + text scaling + automated guideline tests (06-01).
- App display name "Songbook" on Android + iOS (06-02).
- Minimal permission surface documented: Android declares no permissions; iOS has no usage strings (06-02).
- Bundle id `com.songbook.songbook_app` and version 1.0.0+1 confirmed (06-02).
- Generator configs for icons/splash wired and ready (06-02).
