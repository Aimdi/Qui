# XTA reader improvements for Qui

The initial reader-recovery port compared Qui
`89217ec9bdfdcf757f1e3d02a80f9754b456c840` with XTA
`41208aed8f463cbc25b204504baba8dcc6c74110`. The completed branch was checked
again against XTA `1d1ca2100979e888153858c3c0f42d9138ba2cbf` on 2026-09-25.

## Adapted capabilities

- Request scopes, deadlines and generation checks prevent old responses from
  replacing a newer read. Refresh keeps visible posts, coalesces concurrent
  refreshes and retries the operation that failed.
- Profile routes accept an ID or screen name, release their Store on exit,
  retain cached profiles during failures and show cached/refresh status.
- Optional cache reads have short deadlines; cache writes cannot delay a
  successful conversation or profile timeline. Group reads stop issuing follow-up
  work after cancellation.
- Empty, loading and failed feed/profile states use real scrollable widgets in
  nested tab views. Query changes can start a new first page after an empty result.
- Loaded X posts can be searched locally, including author names, handles,
  expanded links and quoted/retweeted content. Search captures a snapshot and
  does not issue network reads. Home/group toolbar access and focused-feed
  Ctrl/Cmd+F are available.
- Desktop search has labelled tabs, immediate Enter submission, working initial
  focus and clear controls. People lookup runs only when its tab is selected;
  stale results cannot overwrite a later query. Explicitly submitted searches
  are kept locally (at most 20), removable and clearable. X Search and Discover
  use the same recent-search controls and clearing behavior.
- Saved-post search supports multiple terms across the post, author and links.
  Invalid bookmark payloads are isolated, with an action to reopen the original.
  The Saved library also supports newest/oldest sorting, bulk selection and
  moving several posts to a folder at once.
- Enabled readers can be opened from the plugin store with their home tab hidden;
  reader settings and Back navigation remain available.
- Home uses a compact desktop source menu and XTA-style Posts / Media controls
  without replacing Qui's rail, deck or reading-pane layout.
- Profiles retain their nested scroll position and Saved-tab state across tab
  switches.
- Desktop navigation keeps the selected tab and its controllers by stable ID.
  Deck columns preserve mounted state while off screen and gain pointer/focus
  selection so keyboard scrolling follows the chosen column. The reading pane
  keeps back/forward history, available from its controls and Alt+Left/Right.
- Arch and other Linux desktops can install the release bundle for the current
  user through `scripts/install_linux_user.sh`, including a desktop entry.

## Desktop boundaries

Qui retains its desktop shell, cookie login, media_kit player, file picker,
SQLite integration and existing plugins. No new networks are introduced. The
manifest, lockfile and database are unchanged. The only client-layer change is
the typed transaction-signing failure used by the shared reader error UI; no X
endpoint, account-selection or transport behavior is changed.
The profile cache and recent-search history are optional local sidecar files
under the application support directory; they are separate from backup exports.

This is a reader upgrade, not complete XTA parity. XTA's Android integrations,
multi-network archive/notes, additional plugins and mobile navigation are not
copied into Qui. XTA's newest in-app rich-card reader, unified media viewer for
networks Qui does not ship, and expanded stale-cache diagnostics remain follow-up
work. Native Windows/macOS and authenticated live-service behavior need testing
on those hosts/accounts.

## Validation

See the pull request for the exact commands and results from this branch.
Regression coverage includes cancellation, stale-result isolation, retry cursor
selection, profile cache failures, people search, local search/history, malformed
bookmarks, standalone plugin navigation and rail/deck behavior.
