# daily_log

A macOS menu-bar agent that nags you to jot down what you're doing, and gives you a
readable per-project rollup when you fill in the timesheet on Friday.

**It is a memory aid, not a time-accounting engine.** Nothing it computes is
authoritative; every number is a hint you use while typing your own figures into the
real timesheet. Totals are rendered with a `~` prefix for that reason.

## What it does

- **Capture bar** — a centred, Spotlight-style input summoned by a global hotkey
  (`⌃⌥Space` by default) or the menu-bar icon. Type `#project note`, hit `↩`, done.
  `#` autocompletes from known projects; a time prefix (`1115 #acme design sync`)
  backfills an earlier slot.
- **Nudges** — a silence-based reminder after 60m with no entry during work hours, plus
  an end-of-day summary at 16:30. Log something and the timer resets, so a well-logged
  day is silent. No day-close ritual.
- **Week view** — read-only day × project grid, the surface you actually report from.
- **Day view** — project rollup that unfolds into timestamped entries, editable in place.
- **Projects & settings** — rename (rewrites history), archive; hotkey, work hours,
  nudge intervals, duration cap, day start, data path.

## How duration works

Entries store only a timestamp — no end time, no duration. Duration is derived as
`min(next.at − this.at, cap)`, with a default cap of 90m; the last entry of a day gets
the cap. Gaps are never invented, so a genuine 40h week may read as ~32h. That's the
accepted trade for never making up time. Values round to 0.25h.

A day runs 04:00 → 04:00 (configurable), so a 00:40 entry lands on the day that just
ended. An entry typed with no `#tag` inherits the previous entry's project, including
across day boundaries.

## Storage

Plain JSON in `~/Library/Application Support/daily/` (overridable in settings):

```
entries.json    all history
projects.json   key, display name, archived
settings.json   hotkey, hours, cap, nudge config, day start, data path
```

## Build

Native AppKit + SwiftUI, no dependencies. Requires **macOS 26.5** and Xcode 26.
Open `daily_log.xcodeproj` and run — set your own team under Signing & Capabilities
first, since the checked-in project deliberately has none.

```
daily_log/
  App/       shell — AppDelegate, main
  Capture/   capture panel, input parsing
  Main/      week / day / projects / settings
  Model/     Entry, Project, Settings, Store
  Support/   hotkey, notifications, formatting, theme
daily_logTests/
Tools/       make-icon.swift
```

The logo is a day dial — an open ring with a wedge for the part of the day that's
logged — drawn in code rather than checked in as art. `swift Tools/make-icon.swift`
from the repo root rewrites the AppIcon PNGs and the monochrome menu-bar template.

`LSUIElement` — menu-bar item only, no dock icon. The app is unsandboxed
(`ENABLE_APP_SANDBOX = NO`), which the Carbon hotkey needs and which rules out Mac App
Store distribution. Notification actions are unreliable from unsigned debug runs, so
test those against a built `.app`.

## Distribution

`Tools/release.sh` builds a Release, universal, ad-hoc-signed `.app`, zips it, and
renders `build/release/daily-log.rb` from `Tools/daily-log.rb.tmpl`. Add `--publish` to
cut the GitHub release and upload the zip; copy the rendered cask into
`AlbinAxtelius/homebrew-tap` as `Casks/daily-log.rb`. Then:

```
brew tap albinaxtelius/tap
brew install --cask --no-quarantine daily-log
```

No Apple Developer account is involved. Ad-hoc signing is enough to *execute* the app;
the Gatekeeper prompt comes from the quarantine xattr on the download, which
`--no-quarantine` never attaches — set `HOMEBREW_CASK_OPTS="--no-quarantine"` in your
shell profile so `brew upgrade` does not re-quarantine. The cost of skipping
notarization is that the code signature changes every build, so macOS may treat an
upgrade as a different app and re-ask for notification permission.

## Tests

```
xcodebuild test -project daily_log.xcodeproj -scheme daily_log -destination 'platform=macOS'
```

Swift Testing, in a host-less bundle that compiles the pure sources directly — nothing
launches, and nothing touches your real data directory. Coverage is the logic worth
pinning down: input parsing, project slugging, quarter-hour rounding, formatting,
the work-time window, and JSON decoding defaults.

## License

MIT — see [LICENSE](LICENSE).

See [PLAN.md](PLAN.md) for the full design rationale.
