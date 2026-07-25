---
phase: 06-store-prep
plan: 02
subsystem: platform-config
status: complete
tags: [flutter, android, ios, store-release, branding, metadata]
dependencies:
  requires: [06-01]
  provides:
    - App display name "Songbook" (Android + iOS)
    - Documented minimal-permission posture
    - Launcher-icon + native-splash generator config (placeholder)
    - Drafted store-listing metadata
    - Release checklist (human/online steps)
  affects: []
tech-stack:
  added: []
  patterns:
    - Standalone generator config files (flutter_launcher_icons.yaml / flutter_native_splash.yaml) instead of pubspec keys
    - Placeholder-flagged branding (NEEDS FINAL ART) — no fabricated artwork
key-files:
  created:
    - songbook_app/flutter_launcher_icons.yaml
    - songbook_app/flutter_native_splash.yaml
    - songbook_app/assets/icons/README.md
    - .planning/phases/06-store-prep/STORE-LISTING.md
    - .planning/phases/06-store-prep/RELEASE-CHECKLIST.md
  modified:
    - songbook_app/android/app/src/main/AndroidManifest.xml
    - songbook_app/ios/Runner/Info.plist
    - songbook_app/android/app/build.gradle.kts
key-decisions:
  - decision: Generator deps NOT added to pubspec.yaml; documented `flutter pub add` instead
    rationale: Offline sandbox + packages not cached — adding them would break `flutter pub get` and the gates. Standalone config files + a documented install keep gates green and the setup ready.
    date: 2026-06-13
  - decision: App display name "Songbook" (not "songbook_app")
    rationale: Store-quality user-facing name; the package/internal ids stay com.songbook.songbook_app
    date: 2026-06-13
  - decision: Keep zero Android permissions (not even INTERNET) and document it in the manifest
    rationale: App is fully offline/local-first; minimal surface eases store review and user trust
    date: 2026-06-13
metrics:
  completed: 2026-06-13
  tasks: 5
  files: 8
---

# Phase 06 Plan 02: Platform Config, Branding Scaffold & Store Metadata — Summary

**One-liner:** The app now presents as "Songbook" with a documented zero-permission posture, icon/splash
generation is wired and one-art-drop away, and the store listing + release path are drafted for Robert.

## What Was Built

**App display name.** Android `android:label` and iOS `CFBundleDisplayName` now read **Songbook**
(were `songbook_app` / "Songbook App"). Bundle/application id stays `com.songbook.songbook_app`;
version stays 1.0.0+1.

**Minimal-permission posture, documented.** Android declares **no** `<uses-permission>` (not even
INTERNET) — a comment in the manifest records this as intentional (offline/local-first) so it isn't
silently changed. iOS Info.plist carries a comment noting no `NS*UsageDescription` keys are needed.
The stale "Specify your own unique Application ID" TODO in `build.gradle.kts` is removed; the
debug-key signing placeholder now points at the release checklist.

**Icon & splash generators (placeholder-flagged).** `flutter_launcher_icons.yaml` and
`flutter_native_splash.yaml` are wired (all relevant platforms, adaptive icon, android12 splash,
light/dark) pointing at placeholder source paths, each with a **NEEDS FINAL ART** banner.
`assets/icons/README.md` lists the required source files/sizes, the (offline-deferred)
`flutter pub add` lines, and the regen commands. **No artwork was fabricated; nothing was regenerated.**

**Store-listing metadata** (`STORE-LISTING.md`) — Play + App Store copy with length-checked fields
(title, short/full description, subtitle, promo text, keywords), categories, content rating, the
"no data collected" privacy posture, and a phone+tablet screenshot shot-list. Confirm-me values are
marked with «guillemets».

**Release checklist** (`RELEASE-CHECKLIST.md`) — ordered human/online steps: final art → dep install
→ regen → Android/iOS signing → release builds → on-device crash/perf + screen-reader UAT →
screenshots → store consoles → submit.

## Quality Gates

- `flutter analyze`: **8 issues, all pre-existing** info-level RadioListTile deprecations (unchanged).
- `flutter test`: **23/23 pass** (no app-code behavior change; manifest/plist/gradle/yaml/doc only).

## Deviations from Plan

- Generator dev-dependencies were **not** added to `pubspec.yaml` (planned as a possibility): the
  sandbox has no network and the packages weren't cached, so `flutter pub get` would have failed and
  broken the gates. Standalone config files + a documented `flutter pub add` achieve the same setup
  while keeping the build green. Recorded as a human/online blocker.

## Human-only / online blockers (carried to verification)

- Final on-brand artwork + icon/splash regeneration. ⛔
- Installing the two generator dev-deps (needs network). ⛔
- Release signing (Android keystore, Apple provisioning). ⛔
- On-device release-build crash/perf testing (criterion #3) + screen-reader UAT. ⛔
- Screenshots + store-console submission. ⛔
