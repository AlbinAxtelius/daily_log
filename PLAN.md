# Daily — design plan

A macOS menu-bar agent that nags you to jot down what you're doing, and gives you a
readable per-project rollup when you fill in the timesheet on Friday.

**It is a memory aid, not a time-accounting engine.** Nothing it computes is
authoritative; every number is a hint you use while typing your own figures into the
real timesheet.

---

## Data model

Entry:

```jsonc
{
  "id": "e_01J…",
  "at": "2026-08-07T09:30:12+02:00",
  "project": "acme",
  "note": "auth refactor"
}
```

- No end time, no duration stored. No todo/done concept — the current task model goes away.
- Duration is **derived**: `min(next.at − this.at, cap)`, cap default **90m**.
  The last entry of a day also gets the cap.
- Totals are always rendered with a `~` prefix. Rounded to 0.25h.
- **Gaps are not invented and not reported.** A day simply won't sum to 8h, and that's fine.
- A day runs **04:00 → 04:00** (configurable), so a 00:40 entry lands on the day that
  just ended.
- If an entry is typed with no `#tag`, it inherits the previous entry's project —
  including across day boundaries.

### Storage

Single readable JSON per concern, in `~/Library/Application Support/daily/`
(path overridable in settings):

```
entries.json    all history
projects.json   key, display name, archived
settings.json   hotkey, hours, cap, nudge config, day start, data path
```

Readability is a nice-to-have, not a design constraint. At ~10 entries/day this stays
tiny for a decade.

---

## Capture

A centred, Spotlight-style bar. **The anchored menu-bar popover is removed** — the
menu-bar icon and the global hotkey both summon the same bar.

```
┌──────────────────────────────┐
│ #acme auth refactor█         │
├─ today · ~7.0h · acme ───────┤
│ 09:30  auth refactor         │
│ 11:45  PR review             │
│ 13:40  standup               │
└─ ↩ log · ⌘↩ window · esc ────┘
```

- Opens as a bare input; grows the today-list beneath on `↓` or as you type.
- `#` autocompletes from known projects. An unrecognised tag still works but asks
  *create project "acmeportal"?* first — that's where typo drift gets caught.
- **Time-prefix backfill**: `1115 #acme design sync` inserts at 11:15 instead of now,
  and the list re-sorts.
- `↩` logs and dismisses · `⌘↩` opens the main window · `Esc` dismisses.

---

## Nudges

### During the day — silence-based

- Fires after **60m with no entry**, within **Mon–Fri 08:00–17:00**. All configurable.
- Logging anything resets the timer, so a well-logged day is completely silent.
- Two actions only — macOS collapses anything beyond two into an Options menu:

```
🔔 Still on acme?
[Same as before] [Open]
```

- `Same as before` copies the previous entry's **project and note** — a true
  continuation, so it leaves no description hole.
- Pending nudges are cancelled on sleep/lock; the timer restarts on wake. You never
  unlock to a stack of stale banners. macOS Focus is left to do its own thing.

### End of day — 16:30, weekdays

The notification body *is* the summary. Most days you read it and dismiss.

```
🔔 Daily — Friday
   acme ~5.5h · internal ~1h
   "auth refactor, PR review, standup"
   [ Open ]
```

**There is no close ritual.** No day-close step, no auto-close, no "unreviewed" state,
no prompt to reconcile. Clicking opens the main window on today if something's missing.

---

## Review — the main window

### Week view (primary surface)

You report weekly, looking back, so this is the surface that matters.

```
Week 32          acme  int  pre
Mon 08-03         6.0  2.0    —
Tue 08-04         7.5  0.5    —
Wed 08-05         4.0  1.0   3.0
Thu 08-06         8.0    —     —
Fri 08-07         5.5  1.5   1.0
                 ───────────────
                 31.0  5.0   4.0
```

Read-only; drill into a day to edit.

### Day view

Project rollup by default. Click a project row to unfold its timestamped entries,
editable in place.

```
Fri 08-07
▾ acme ~5.5h
   09:30 auth refactor   [✎]
   11:45 PR review       [✎]
   14:10 design sync     [✎]
▸ internal ~1h
   standup
```

Full edit and delete on any entry, any day: time, project, note.

### Also in the window

- Projects: rename (rewrites history), archive.
- Settings: hotkey, work hours and days, silence interval, end-of-day time, cap,
  day start, data path.

---

## Shell

- `LSUIElement = true` — menu-bar item only, no dock icon, no app-switcher entry.
- Login item registered on first run, with consent. Notification permission requested
  at the same time.
- `AppDelegate` owns the store *and* all notification scheduling and response handling;
  the capture panel and main window are both driven from it via an `AppCoordinator`.
- Closing the main window does not quit.

---

## Defaults chosen without further discussion

| | |
|---|---|
| Hotkey | `⌃⌥Space` |
| Duration cap | 90m |
| Rounding | 0.25h |
| Week view | read-only, drill into a day to edit |
| Sticky project | carries across days |
| Search | not in v1 |
| Export / clipboard | not in v1 |

---

## Three things that will bite

1. **Notification actions need a real bundle.** `UNUserNotificationCenter` is unreliable
   from unsigned debug runs. Categories and their actions must be registered
   *before* the first schedule, and testing has to happen against a built `.app`.
   Budget real time here — this is the feature that was actually asked for.
2. **Hotkey registration**: use Carbon `RegisterEventHotKey` in Swift, not a global
   `NSEvent` monitor. The latter demands Accessibility permission for no benefit.
3. **Week totals will read low.** Cap plus no gap-filling means a genuine 40h week may
   show as ~32h. That's the accepted trade for never inventing time — but don't be
   surprised by it.
