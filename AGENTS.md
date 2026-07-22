# AGENTS.md

See `CLAUDE.md` and `README.md` for the project overview, architecture, build commands, and desktop-login flow. Standard build/run/localization commands are documented there and are not duplicated here.

## Cursor Cloud specific instructions

Qui is a single-process Flutter **Linux desktop** app (no backend, no DB server; persistence is embedded SQLite via `sqflite_common_ffi`). There are no services to orchestrate — you build and launch one GUI binary.

### Environment (already provisioned in the snapshot)
- Flutter SDK **3.44.6** (pinned by `.fvmrc`) is installed at `~/flutter` and on `PATH` via `~/.bashrc`. Verify with `flutter --version`.
- System libs required to build the Linux desktop target are installed: GTK3 toolchain, `ninja-build`, `pkg-config`, `liblzma-dev`, `libstdc++-14-dev` (needed so `clang++` can link `-lstdc++`), and `libmpv-dev` + `mpv` (needed by the `media_kit_video` plugin — without it CMake fails with `PkgConfig::mpv ... not found`).
- The update script runs `flutter pub get` plus codegen (`intl_utils:generate`, `flutter_iconpicker:generate_packs`, `dart_pubspec_licenses:generate`). These regenerate `lib/generated/` and `lib/oss_licenses.dart`, which are **gitignored** and must exist before building.

### Running the GUI
- A headless X server is available on `DISPLAY=:1`. Run with `DISPLAY=:1 flutter run -d linux`.
- Rendering uses software GL under Xvfb; `libEGL warning: DRI3 ...` messages are harmless.
- If a Linux build ever fails on the first attempt with a linker/CMake error after changing dependencies, delete `build/linux` and rebuild — stale build dirs can cause spurious failures.

### Login / expected errors without credentials
- The app needs a real X account: paste browser cookies (`auth_token` + `ct0`) via Settings → Accounts → Login (see `README.md`). No credentials are provisioned here.
- Without login you will see a "You are not logged in" dialog, an "update available" dialog, and a "Something went wrong" / `Provider<GroupModel>` error banner in feed areas. These are expected in an unauthenticated session and are **not** environment problems.
- Local-first features work without login and are the safest things to exercise in this environment: creating **Groups**, and changing **Settings/themes** (both persist to local SQLite).
