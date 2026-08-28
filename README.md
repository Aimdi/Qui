<div align="center">
<img src="assets/icon.png" height="100">

# Qui

[![Based on](https://img.shields.io/badge/based%20on-Aimdi%2FXTA-1565C0?style=for-the-badge&logo=github)](https://github.com/Aimdi/XTA)
[![License: MIT](https://img.shields.io/github/license/Aimdi/Qui?style=for-the-badge&logo=opensourceinitiative&logoColor=FFFFFF&color=750014)](/LICENSE)
[![Build Status](https://img.shields.io/github/actions/workflow/status/Aimdi/Qui/ci.yml?style=for-the-badge&logo=github)](https://github.com/Aimdi/Qui/actions)
![Platforms](https://img.shields.io/badge/Linux%20%7C%20Windows%20%7C%20macOS-desktop-54C5F8?style=for-the-badge&logo=flutter&logoColor=white)
![Flutter version](https://img.shields.io/badge/Flutter-3.44+-54C5F8?style=for-the-badge&logo=flutter&logoColor=white)

**Qui** is [XTA](https://github.com/Aimdi/XTA) for the PC. Same app, same local-first X client, same plugins — built for Linux, Windows, and macOS with Flutter.

</div>

## ⚠️ This is a vibe-coded fork

Qui is forked from [Aimdi/XTA](https://github.com/Aimdi/XTA) (itself a fork of [Teskann/QuaX](https://github.com/Teskann/QuaX)). Virtually every change on top of upstream was written by an AI coding agent, directed and tested by a human. It exists so XTA’s features work on a desktop, with chrome that belongs on a PC rather than a stretched phone layout.

- Use [XTA](https://github.com/Aimdi/XTA) on Android and **Qui** on desktop. They stay in feature parity.
- Issues welcome; fixes will also be vibe coded.

> [!IMPORTANT]
> An X account is required. On desktop, sign in by pasting your browser cookies (`auth_token` + `ct0`) after logging into x.com. Subscriptions, saved posts, and settings stay local to the app.

## Features (same as XTA)

- Local subscriptions and custom **groups** / feeds, including nested groups
- Media grids, feed order (Recent / Popular), content filters, **Zen mode**
- Advanced search, quotes, Community Notes, cashtag tickers, polls
- Saved posts / folders, local likes, broken-subscription cleanup
- Optional plugins: **Reddit**, **Substack**, Karakeep, Deepmarks
- X Look theming (Light / Dim / Lights Out + accent)

## Desktop shell

XTA’s phone chrome is replaced with a layout closer to [Flare](https://github.com/DimensionDev/Flare) and TweetDeck, without dropping XTA features:

- Left **icon rail** (Home, Subscriptions, Trending, Saved, plugin tabs + Search / Settings)
- **Centered timeline** column (~640px) and a **reading pane** for opened threads
- **Trends side panel** on wide windows
- **Deck mode** — side-by-side columns for each home tab
- Keyboard: `j`/`k` next/previous post, `/` search, `Esc` close pane, `1`–`9` switch tabs
- Right-click matches XTA’s long-press actions (save folder, translate thread, Reddit post menu)
- Plugin settings (Reddit sign-in, Substack publications, …) stay reachable from Settings → Plugin store when the plugin tab is hidden

Qui is X-first, not a multi-network client. Mastodon/Bluesky/RSS live in Flare; Reddit and Substack here are the same optional XTA plugins.

## Platforms

| | Linux | Windows | macOS | Android |
|---|:---:|:---:|:---:|:---:|
| **Qui** | ✅ primary | ✅ | ✅ | (use [XTA](https://github.com/Aimdi/XTA)) |

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
- [Aimdi/XTA](https://github.com/Aimdi/XTA) for the fork Qui is based on

## License

MIT — see [LICENSE](./LICENSE).
