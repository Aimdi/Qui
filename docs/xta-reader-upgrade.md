# XTA reader improvements for Qui

Compared Qui `89217ec9bdfdcf757f1e3d02a80f9754b456c840` with XTA
`41208aed8f463cbc25b204504baba8dcc6c74110` (the `claude/main` head inspected
for this change).

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
  are kept locally (at most 20), removable and clearable.
- Saved-post search supports multiple terms across the post, author and links.
  Invalid bookmark payloads are isolated, with an action to reopen the original.
- Enabled readers can be opened from the plugin store with their home tab hidden;
  reader settings and Back navigation remain available.
- Desktop navigation keeps the selected tab and its controllers by stable ID.
  Deck columns preserve mounted state while off screen and gain pointer/focus
  selection so keyboard scrolling follows the chosen column.

## Desktop boundaries

Qui retains its desktop shell, cookie login, media_kit player, file picker,
SQLite integration and existing plugins. No new networks are introduced.
Neither the manifest/lockfile nor `lib/client/` or `lib/database/` is changed.
The profile cache and recent-search history are optional local sidecar files
under the application support directory; they are separate from backup exports.

This is a reader upgrade, not complete XTA parity. XTA’s Android integrations,
multi-network archive/notes, additional plugins and mobile navigation are not
copied into Qui. Native Windows/macOS and authenticated live-service behavior
need testing on those hosts/accounts.

## Validation

See the pull request for the exact commands and results from this branch.
Regression coverage includes cancellation, stale-result isolation, retry cursor
selection, profile cache failures, people search, local search/history, malformed
bookmarks, standalone plugin navigation and rail/deck behavior.
