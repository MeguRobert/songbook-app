# App icon & splash source art

> **Status: NEEDS FINAL ART.** This folder has no on-brand source artwork yet, so the launcher icon
> and splash screen have **not** been regenerated. The generator configs
> (`../../flutter_launcher_icons.yaml`, `../../flutter_native_splash.yaml`) are wired and ready;
> they point at the placeholder paths below. Do not ship the default Flutter icon.

## 1. Add the source files here

| File | Purpose | Recommended |
|------|---------|-------------|
| `app_icon.png` | Master launcher icon | 1024×1024 PNG, **no transparency** (iOS rejects alpha) |
| `app_icon_foreground.png` | Android adaptive-icon foreground | 1024×1024 PNG, transparent, art within centre safe zone |
| `splash_logo.png` | Centered splash logo | ~1152×1152 transparent PNG |

Confirm the brand colors referenced in the two config files
(`adaptive_icon_background`, splash `color` / `color_dark`).

## 2. Install the generator dev-dependencies

These are **not** in `pubspec.yaml` — the overnight environment had no network and the packages were
not cached, so adding them would have broken `flutter pub get`. Add them when online:

```bash
cd songbook_app
flutter pub add dev:flutter_launcher_icons
flutter pub add dev:flutter_native_splash
```

## 3. Regenerate

```bash
dart run flutter_launcher_icons          # reads flutter_launcher_icons.yaml
dart run flutter_native_splash:create    # reads flutter_native_splash.yaml
```

This overwrites the platform icon assets under `android/app/src/main/res/mipmap-*`,
`ios/Runner/Assets.xcassets/AppIcon.appiconset`, and the splash resources. Commit the regenerated
assets. See `.planning/phases/06-store-prep/RELEASE-CHECKLIST.md` for where this fits in the release flow.
