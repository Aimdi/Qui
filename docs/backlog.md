# Qui — Engineering Backlog (audit)

Audit-only document. **No code was changed to produce it.** It partitions work into four
non-overlapping lanes so items in different lanes can run in parallel without ever editing the
same file.

## Lane rules

- **LANE A — desktop shell**: icon rail, centred timeline column, trends side panel, deck mode,
  post cards, themes.
- **LANE B — X API / networking / data layer**: subscriptions, groups, feed ordering, search,
  cookie auth, saved posts, profiles, trends data.
- **LANE C — tests**: `test/**` only.
- **LANE D — build & packaging**: `.github/**`, `packaging/**`, `linux/**`, `windows/**`,
  `macos/**`, CI.

Every item names the **exact files** it may touch. No file appears in two lanes (see the ownership
map). If a change would need files from two lanes it is listed under **Cross-lane / serialised**
and must be split or run alone.

## File ownership map (disjoint)

| Lane | Owns these paths |
|---|---|
| **A** | `lib/ui/**`, `lib/tweet/**`, `lib/status.dart`, `lib/home/_feed.dart`, `lib/home/home_screen.dart`, `lib/home/_missing.dart`, `lib/home/home_model.dart`, `lib/profile/media_grid/**`, `lib/trends/_list.dart`, `lib/settings/_theme.dart`, `lib/settings/_media.dart`, `lib/settings/_home.dart`, `lib/settings/_about.dart`, `lib/settings/_general.dart`, `lib/settings/_accessibility.dart`, `lib/settings/settings.dart` |
| **B** | `lib/client/**`, `lib/group/**`, `lib/subscriptions/**`, `lib/search/**`, `lib/database/**`, `lib/saved/**`, `lib/utils/**`, `lib/home/_saved.dart`, `lib/home/_for_you.dart`, `lib/profile/**` (except `lib/profile/media_grid/**`), `lib/trends/trends_screen.dart`, `lib/trends/trends_model.dart`, `lib/trends/_tabs.dart`, `lib/trends/_settings.dart`, `lib/settings/_account.dart`, `lib/settings/_data.dart`, `lib/settings/_posts.dart`, `lib/settings/settings_export_screen.dart` |
| **C** | `test/**` |
| **D** | `.github/**`, `packaging/**`, `linux/**`, `windows/**`, `macos/**`, `android/**` |

### Serialised hotspots (never parallelise — see last section)

These files are shared by many features or are explicitly off-limits; any item that must edit one is
**serialised**, not assigned to a lane: `pubspec.yaml`, `pubspec.lock`, `lib/l10n/*.arb`,
`lib/main.dart`, `lib/constants.dart`, and any repo-wide `dart format` pass.

---

## Ranked backlog (highest user-visible-improvement ÷ risk first)

Improvement/Risk are H/M/L. `[HUMAN]` = verification is a manual check, so it must **not** be handed
to an autonomous agent. `[SERIALISED]` = touches a serialised hotspot.

| # | ID | Lane | Description | Files | Verify | Impr/Risk |
|---|----|------|-------------|-------|--------|-----------|
| 1 | D1 | D | Run `flutter analyze`, `flutter test` and `dart format --set-exit-if-changed` in CI (today CI only builds). | `.github/workflows/ci.yml` | CI job `ci / linux` shows the three steps; analyzer rule: `flutter analyze` exits 0 | H / L |
| 2 | A1 | A | Add the media-only grid toggle (already on group feeds) to the Home "Following" tab. | `lib/home/_feed.dart` | [HUMAN] toolbar toggle switches the Following feed to a media grid | H / L |
| 3 | C1 | C | Add unit tests for the advanced-search query builder. | `test/advanced_search_query_test.dart` (new) | `flutter test test/advanced_search_query_test.dart` passes | M / L |
| 4 | C2 | C | Add a widget test for `DeckBody` multi-row layout (N rows → N strips). | `test/deck_body_test.dart` (new) | `flutter test test/deck_body_test.dart` passes | M / L |
| 5 | A2 | A | Keyboard-first navigation on desktop: `j`/`k` move between posts, `o`/Enter open, `Esc` closes the reading pane. | `lib/ui/desktop_shell.dart`, `lib/ui/detail_pane.dart`, `lib/ui/keyboard_shortcuts.dart` (new) | [HUMAN] keys navigate/open/close as described | H / M |
| 6 | B1 | B | Apply per-user "hide reposts" to For You, profile and search feeds (today only subscription-group feeds). | `lib/home/_for_you.dart`, `lib/profile/_tweets.dart`, `lib/search/search.dart` | [HUMAN] a hidden-repost author's reposts disappear from those feeds | M / M |
| 7 | D2 | D | Fix `new_version.yml` pushing to a non-existent `master` (default branch is `main`). | `.github/workflows/new_version.yml` | Dispatch run pushes to `main` and tags without error | M / M |
| 8 | D3 | D | Add Windows and macOS build workflows (README advertises both; only Linux is built). | `.github/workflows/build-windows.yml` (new), `.github/workflows/build-macos.yml` (new) | CI uploads `.exe`/`.app` (or zip) artifacts | M / M |
| 9 | A3 | A | Replace deprecated `Share`/`shareXFiles` with `SharePlus.instance` in post cards. | `lib/tweet/tweet.dart`, `lib/tweet/_media.dart` | analyzer rule `deprecated_member_use` = 0 in those files | L / L |
| 10 | B2 | B | Clear the analyzer `use_build_context_synchronously` infos in the data layer. | `lib/settings/settings_export_screen.dart`, `lib/subscriptions/_groups.dart`, `lib/subscriptions/_import.dart`, `lib/trends/_settings.dart`, `lib/utils/downloads.dart` | analyzer rule `use_build_context_synchronously` = 0 in those files | L / L |
| 11 | A4 | A | Clear post-card analyzer infos: `avoid_unnecessary_containers`, `sort_child_properties_last`, `no_logic_in_create_state`, `strict_top_level_inference`. | `lib/tweet/tweet.dart`, `lib/ui/desktop_shell.dart`, `lib/ui/dates.dart` | analyzer: those rules = 0 in those files | L / L |
| 12 | B3 | B | Fix the 1.6px vertical overflow on subscription group cards. | `lib/subscriptions/_groups.dart` | [HUMAN] no yellow/black overflow stripe on the Groups grid | L / L |
| 13 | A5 | A | Sync the deck rail highlight to manual horizontal scroll in multi-row mode (only single-row updates focus today). | `lib/ui/deck.dart` | [HUMAN] scrolling a deck row updates the highlighted rail icon | L / L |
| 14 | A6 | A | Provide `TranslationBroadcast` in timeline feed scope so "translate whole thread" works outside opened threads. | `lib/tweet/tweet_context_scope.dart` | [HUMAN] long-press/right-click translate affects the whole visible conversation in a feed | L / M |
| 15 | A7 | A | Rename `lib/tweet/_ExpandableTweetText.dart` to snake_case and update its importer. | `lib/tweet/_expandable_tweet_text.dart` (rename), `lib/tweet/tweet.dart` | analyzer rule `file_names` = 0 | L / M |

---

## Lane C (tests) — additional candidates

All live under `test/**` only, so they never collide with A/B/D. Each imports the lane it exercises
but edits only its own test file.

- **C3** — Tests for `cleanUrl`/list-URL parsing already exist (`test/clean_url_test.dart`,
  `test/list_url_test.dart`); extend them for edge cases. Files: `test/clean_url_test.dart`,
  `test/list_url_test.dart`. Verify: `flutter test` passes. Impr/Risk: L/L.
- **C4** — Golden/layout test that the reading pane opens beside the timeline on expanded width.
  Files: `test/detail_pane_layout_test.dart` (new). Verify: `flutter test` passes. Impr/Risk: M/M.

> Note: the repo currently has only 5 test files and CI runs none of them (see D1). Landing D1
> first makes every C item self-enforcing.

---

## Cross-lane / serialised items (never parallelise)

These either touch a serialised hotspot or span multiple lanes. Run them **one at a time**, alone.

| ID | What | Files | Verify | Flags |
|----|------|-------|--------|-------|
| S1 | Make the repo `dart format`-clean (118 of 177 files reformat today). Touches every lane incl. `test/**`. | `lib/**`, `test/**` | `dart format --set-exit-if-changed lib test` exits 0 | [SERIALISED] whole-repo |
| S2 | Align the in-app version with the release scheme (`pubspec.yaml` is `4.12.0+…` while releases are `v0.2.x`). | `pubspec.yaml` | [HUMAN] Settings → About shows the intended version | [SERIALISED] pubspec, [HUMAN] |
| S3 | Register a route/provider for any new top-level screen a feature adds (e.g. a keyboard-shortcuts help page). | `lib/main.dart`, `lib/constants.dart` | [HUMAN] the new route resolves from navigation | [SERIALISED] main.dart + constants.dart, [HUMAN] |
| S4 | Any new user-facing string (e.g. new settings labels) must be added to all locale ARBs. | `lib/l10n/*.arb` | `python l10n.py` reports no missing keys | [SERIALISED] ARB |

### Dependency notes

- **D1 depends on S1 + A3/A4/B2/A7**: `flutter analyze` and `dart format --set-exit-if-changed`
  fail today (458 analyzer infos, 118 unformatted files). Either land the cleanup items first, or
  introduce the CI gates non-fatally (baseline) and tighten once green.
- **A1 (media-only on Home)** reuses the existing `only_show_posts_with_media` string, so it does
  **not** require S4.
- **A2 (keyboard nav)**, if it adds a visible "shortcuts" affordance/label, pulls in **S4** (ARB)
  and possibly **S3** (route); keep the shortcut logic itself free of both to stay parallelisable.

---

## Items explicitly requiring pubspec / ARB edits (serialise these)

Per the request, called out separately — these are **not** parallelisable:

- **`pubspec.yaml`**: S2 (version alignment). Any future item adding a package also lands here.
- **`pubspec.lock`**: only as a side effect of a `pubspec.yaml` dependency change — never edited by
  hand.
- **`lib/l10n/*.arb`**: S4 and any A/B item that introduces a new visible string.
