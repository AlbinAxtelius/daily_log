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

Native AppKit + SwiftUI, no dependencies. Open `daily_log.xcodeproj` in Xcode and run.

```
daily_log/
  App/       shell — AppDelegate, main
  Capture/   capture panel, input parsing
  Main/      week / day / projects / settings
  Model/     Entry, Project, Settings, Store
  Support/   hotkey, notifications, formatting, theme
```

`LSUIElement` — menu-bar item only, no dock icon. Notification actions need a real
bundle, so test against a built `.app`, not a debug run. The hotkey uses Carbon
`RegisterEventHotKey`, which needs no Accessibility permission.

See [PLAN.md](PLAN.md) for the full design rationale.
