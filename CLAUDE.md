# CLAUDE.md

## Project Overview

**Qui** is a privacy-focused Flutter desktop client for X (formerly Twitter). It is the PC port of [Aimdi/QuaX-fix](https://github.com/Aimdi/QuaX-fix) (itself based on Teskann/QuaX / Quacker / Fritter). Primary target is **Linux**; Windows and macOS are supported via the same Flutter codebase.

## Build

```bash
flutter pub get
dart run intl_utils:generate
dart run flutter_iconpicker:generate_packs --packs material
flutter run -d linux
flutter build linux --release
```

## Architecture

Same as QuaX-fix: feature folders under `lib/`, **flutter_triple** stores, SQLite via `sqflite` + `sqflite_common_ffi` on desktop, reverse-engineered X API under `lib/client/`.

### Desktop differences

- Login uses cookie paste (`lib/client/desktop_login.dart`) instead of mobile WebView.
- File open/save uses `file_picker` on desktop (`lib/utils/desktop_files.dart`).
- `secure_content` screenshot blocking is Android/iOS only.
- Window chrome via `window_manager`.

## Localization

Edit `lib/l10n/*.arb`, then `dart run intl_utils:generate`. Do not hand-edit `lib/generated/`.
