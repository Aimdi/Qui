<div align="center">
<img src="assets/icon.png" height="100">

# Qui

[![Based on](https://img.shields.io/badge/based%20on-Aimdi%2FQuaX--fix-1565C0?style=for-the-badge&logo=github)](https://github.com/Aimdi/QuaX-fix)
[![License: MIT](https://img.shields.io/github/license/Aimdi/Qui?style=for-the-badge&logo=opensourceinitiative&logoColor=FFFFFF&color=750014)](/LICENSE)
[![Build Status](https://img.shields.io/github/actions/workflow/status/Aimdi/Qui/ci.yml?style=for-the-badge&logo=github)](https://github.com/Aimdi/Qui/actions)
![Platforms](https://img.shields.io/badge/Linux%20%7C%20Windows%20%7C%20macOS-desktop-54C5F8?style=for-the-badge&logo=flutter&logoColor=white)
![Flutter version](https://img.shields.io/badge/Flutter-3.44+-54C5F8?style=for-the-badge&logo=flutter&logoColor=white)

**Qui** is the **desktop** (PC) counterpart of [QuaX-fix](https://github.com/Aimdi/QuaX-fix) — a free, open-source, privacy-focused client for X (formerly Twitter). Same local-first design, same feeds and groups, built for Linux, Windows, and macOS with Flutter.

</div>

## ⚠️ This is a vibe-coded desktop port

Qui is forked from [Aimdi/QuaX-fix](https://github.com/Aimdi/QuaX-fix) (itself a fork of [Teskann/QuaX](https://github.com/Teskann/QuaX)). Desktop support was added so the phone app’s features work on a PC — not every mobile UX detail was redesigned.

- Prefer [QuaX-fix](https://github.com/Aimdi/QuaX-fix) on Android and **Qui** on desktop.
- Issues welcome; fixes will also be vibe coded.

> [!IMPORTANT]
> An X account is required. On desktop, sign in by pasting your browser cookies (`auth_token` + `ct0`) after logging into x.com. Subscriptions, saved posts, and settings stay local to the app.

## Features (from QuaX-fix)

- Local subscriptions and custom **groups** / feeds
- Media grids, feed order (Recent / Popular), content filters
- **Zen mode** anti-doomscrolling options
- Advanced search, quotes, Community Notes in timelines
- Saved posts / folders, broken-subscription cleanup
- Themes: seed-color, True Black, Fairy Forest, Pitch Black


## Desktop shell (Flare-inspired)

Qui keeps the **QuaX-fix / X-only core** (local subscriptions, groups, reverse-engineered API)
but presents it with a desktop chrome closer to [Flare](https://github.com/DimensionDev/Flare):

- Left **icon rail** (Home, Subscriptions, Trending, Saved + Search / Settings)
- **Centered timeline** column (~640px)
- **Trends side panel** on wide windows
- Flat post cards with hairline dividers (compact still uses mobile cards)

Qui is **not** a multi-network client — Mastodon/Bluesky/RSS live in Flare; Qui stays an X client.

## Platforms

| | Linux | Windows | macOS | Android |
|---|:---:|:---:|:---:|:---:|
| **Qui** | ✅ primary | ✅ | ✅ | (use [QuaX-fix](https://github.com/Aimdi/QuaX-fix)) |

## Download

Grab desktop builds from [GitHub releases](https://github.com/Aimdi/Qui/releases) when published. CI builds Linux artifacts on every push.

## Build locally

Prerequisites:

- Flutter **3.44+** (or [FVM](https://fvm.app/) with the pin in [`.fvmrc`](./.fvmrc))
- Linux: `cmake`, `ninja`, GTK3, clang
- Python (for icon generation)

```bash
# Optional: pin SDK with FVM
fvm install && fvm use

# Icons
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python generate_icons.py
deactivate

flutter pub get
dart run flutter_launcher_icons
dart run dart_pubspec_licenses:generate
dart run intl_utils:generate
dart run flutter_iconpicker:generate_packs --packs material

# Linux
flutter build linux --release

# Windows / macOS (on those hosts)
flutter build windows --release
flutter build macos --release
```

Run in debug:

```bash
flutter run -d linux
```

## Desktop login

1. Open [x.com](https://x.com/i/flow/login) in a normal browser and sign in.
2. DevTools → Application → Cookies → `x.com` — copy **auth_token** and **ct0**.
3. In Qui: Settings → Accounts → Login (or the first-run dialog) → paste cookies + your screen name.

## Credits

- [Teskann/QuaX](https://github.com/Teskann/QuaX) and upstream Quacker / Fritter authors
- [Aimdi/QuaX-fix](https://github.com/Aimdi/QuaX-fix) for the fork Qui is based on

## License

MIT — see [LICENSE](./LICENSE).
