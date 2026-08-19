<div align="center">

<img src="daily_log/Assets.xcassets/AppIcon.appiconset/icon_256x256.png" width="128" alt="daily_log">

# daily_log

**A macOS menu-bar agent that nags you to jot down what you're doing —
and hands you a readable per-project rollup when Friday's timesheet is due.**

[![Platform](https://img.shields.io/badge/platform-macOS%2026.5%2B-black?logo=apple&logoColor=white)](#build)
[![Swift](https://img.shields.io/badge/Swift-AppKit%20%2B%20SwiftUI-F05138?logo=swift&logoColor=white)](#build)
[![Dependencies](https://img.shields.io/badge/dependencies-none-brightgreen)](#build)
[![License](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

```sh
brew tap albinaxtelius/tap
brew install --cask --no-quarantine daily-log
```

</div>

---

> [!IMPORTANT]
> **It is a memory aid, not a time-accounting engine.** Nothing it computes is
> authoritative; every number is a hint you use while typing your own figures into the
> real timesheet. Totals are rendered with a `~` prefix for that reason.

## Capture

Hit `⌃⌥Space`. Type. Hit `↩`. That's the whole ritual.

```
#acme design sync
1115 #acme  backfill an earlier slot with a time prefix
       ...  no #tag? inherits the previous entry's project
```

A centred, Spotlight-style input summoned by a global hotkey or the menu-bar icon.
`#` autocompletes from known projects.

## Features

| | |
|---|---|
| **Nudges** | A silence-based reminder after 60m with no entry during work hours, plus an end-of-day summary at 16:30. Log something and the timer resets — a well-logged day is silent. No day-close ritual. |
| **Week view** | Read-only day × project grid. The surface you actually report from. |
| **Day view** | Project rollup that unfolds into timestamped entries, editable in place. |
| **Projects** | Rename (rewrites history) and archive. |
| **Settings** | Hotkey, work hours, nudge intervals, duration cap, day start, data path. |

## How duration works

Entries store **only a timestamp** — no end time, no duration. Duration is derived:

```
duration = min(next.at − this.at, cap)     // cap defaults to 90m
```

The last entry of a day gets the cap. Gaps are never invented, so a genuine 40h week may
read as ~32h — the accepted trade for never making up time. Values round to 0.25h.

A day runs **04:00 → 04:00** (configurable), so a 00:40 entry lands on the day that just
ended. Project inheritance crosses day boundaries too.

## Storage

Plain JSON in `~/Library/Application Support/daily/` (overridable in settings):

| File | Contents |
|---|---|
| `entries.json` | All history |
| `projects.json` | Key, display name, archived |
| `settings.json` | Hotkey, hours, cap, nudge config, day start, data path |

## Build

Native AppKit + SwiftUI, no dependencies. Requires **macOS 26.5** and **Xcode 26**.
Open `daily_log.xcodeproj` and run — set your own team under Signing & Capabilities
first, since the checked-in project deliberately has none.

```
daily_log/
├── App/       shell — AppDelegate, main
├── Capture/   capture panel, input parsing
├── Main/      week / day / projects / settings
├── Model/     Entry, Project, Settings, Store
└── Support/   hotkey, notifications, formatting, theme
daily_logTests/
Tools/         make-icon.swift, release.sh
```

<details>
<summary><strong>The logo is drawn in code</strong></summary>

A day dial — an open ring with a wedge for the part of the day that's logged — rather
than checked-in art. Running `swift Tools/make-icon.swift` from the repo root rewrites
the AppIcon PNGs and the monochrome menu-bar template.

</details>

<details>
<summary><strong>Why it's unsandboxed, and what that costs</strong></summary>

`LSUIElement` — menu-bar item only, no dock icon. The app is unsandboxed
(`ENABLE_APP_SANDBOX = NO`), which the Carbon hotkey needs and which rules out Mac App
Store distribution. Notification actions are unreliable from unsigned debug runs, so test
those against a built `.app`.

</details>

## Distribution

**Shipping a version is one act: bump `MARKETING_VERSION` in Xcode and merge.**

CI runs the suite on every push and PR, then cuts a release *only* when
`MARKETING_VERSION` names a version that has no matching release — so ordinary commits
are silent, and no push can accidentally re-release a version. The zip and the rendered
cask both land as release assets; copy `daily-log.rb` into
`AlbinAxtelius/homebrew-tap` as `Casks/daily-log.rb`.

```
push to main
├── always ......................... run tests
├── MARKETING_VERSION unreleased ... build → zip → publish v1.1
└── already released ............... stop, note it in the job summary
```

`main` is protected: changes go through a PR, `test` must pass, and force-push and
deletion are blocked.

<details>
<summary><strong>Running a release by hand</strong></summary>

`Tools/release.sh` is what CI invokes, and works standalone. It builds a Release,
universal, ad-hoc-signed `.app`, zips it, and renders `build/release/daily-log.rb` from
`Tools/daily-log.rb.tmpl`. Add `--publish` to cut the GitHub release and upload both
assets. `SKIP_TESTS=1` skips the gating test run; `ALLOW_DIRTY=1` builds from a dirty
tree.

</details>

No Apple Developer account is involved. Ad-hoc signing is enough to *execute* the app; the
Gatekeeper prompt comes from the quarantine xattr on the download, which `--no-quarantine`
never attaches — set `HOMEBREW_CASK_OPTS="--no-quarantine"` in your shell profile so
`brew upgrade` does not re-quarantine.

> [!NOTE]
> The cost of skipping notarization: the code signature changes every build, so macOS may
> treat an upgrade as a different app and re-ask for notification permission.

## Tests

```sh
xcodebuild test -project daily_log.xcodeproj -scheme daily_log -destination 'platform=macOS'
```

Swift Testing, in a host-less bundle that compiles the pure sources directly — nothing
launches, and nothing touches your real data directory. Coverage is the logic worth
pinning down: input parsing, project slugging, quarter-hour rounding, formatting, the
work-time window, and JSON decoding defaults.

---

<div align="center">

MIT — see [LICENSE](LICENSE) · Full design rationale in [PLAN.md](PLAN.md)

</div>
