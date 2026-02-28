<div align="center">

# clip-log

**Lightweight macOS personal activity tracker**

Clipboard history + App usage tracking · Zero dependencies

[![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)](https://swift.org)
[![macOS](https://img.shields.io/badge/macOS-13%2B-blue.svg)](https://www.apple.com/macos)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

**English** · [中文](README_CN.md)

</div>

---

Two lightweight daemons that passively track your daily activity on macOS:

- **clip-log** — records every text you copy (what, when, from which app)
- **app-tracker** — records which apps you use and for how long (with window titles)

All data stays local in a single SQLite database. Designed as the data layer for **personal activity review and life logging**.

## Features

### clip-log (clipboard history)

| Feature | Description |
|---------|-------------|
| **Lightweight** | Single Swift file, compiles to ~57KB, near-zero CPU & memory |
| **Auto-dedup** | Skips consecutive identical copies |
| **Length filter** | Ignores entries over 1000 chars (filters bulk copy-paste) |
| **Source tracking** | Records which app the copy came from |
| **Auto-start** | macOS LaunchAgent, starts on login, auto-restarts on crash |
| **Local & private** | All data stays in `~/.clip-log/history.db`, nothing leaves your machine |

### app-tracker (app usage tracking)

| Feature | Description |
|---------|-------------|
| **App usage time** | Tracks which app is in the foreground and for how long |
| **Window titles** | Records what you're doing in each app (e.g. which webpage, which file) |
| **Noise filtering** | Strips spinner animations and other noise from window titles |
| **Short switch filter** | Ignores app switches under 2 seconds (just passing through) |
| **Shared database** | Uses the same `history.db` as clip-log |

## Quick Start

**Requirements:** macOS 13+ (Apple Silicon or Intel) · Xcode Command Line Tools · SQLite3 (pre-installed on macOS)

```bash
git clone https://github.com/Tiny-cyber/clip-log.git
cd clip-log
chmod +x install.sh
./install.sh
```

That's it. clip-log is now running in the background.

> To uninstall: `./uninstall.sh` (your data is preserved)

## How It Works

```
┌─────────────────────────────────────────────────┐
│                  macOS Pasteboard                │
│              (polled every 0.5s)                 │
└────────────────────┬────────────────────────────┘
                     │ changeCount changed?
                     ▼
              ┌──────────────┐
              │  Read text   │
              └──────┬───────┘
                     │
          ┌──────────┼──────────┐
          ▼          ▼          ▼
      Length > 1000? Duplicate? Empty?
       skip ✗      skip ✗    skip ✗
                     │
                     ▼ pass ✓
         ┌───────────────────────┐
         │  INSERT into SQLite   │
         │  + timestamp          │
         │  + source app name    │
         └───────────────────────┘
```

## Query Your History

```bash
# Recent 10 entries
sqlite3 -header -column ~/.clip-log/history.db \
  "SELECT id, datetime(timestamp,'unixepoch','localtime') as time,
   app_name, substr(content,1,60) as preview
   FROM clipboard ORDER BY id DESC LIMIT 10;"
```

<details>
<summary><b>More query examples</b></summary>

```bash
# Search by keyword
sqlite3 -header -column ~/.clip-log/history.db \
  "SELECT * FROM clipboard WHERE content LIKE '%keyword%';"

# Stats by app
sqlite3 -header -column ~/.clip-log/history.db \
  "SELECT app_name, COUNT(*) as count FROM clipboard
   GROUP BY app_name ORDER BY count DESC;"

# Entries from a specific date
sqlite3 -header -column ~/.clip-log/history.db \
  "SELECT * FROM clipboard
   WHERE date(timestamp,'unixepoch','localtime') = '2026-02-28';"

# Export to CSV
sqlite3 -header -csv ~/.clip-log/history.db \
  "SELECT * FROM clipboard;" > history.csv
```

</details>

## Database Schema

```sql
-- clip-log
CREATE TABLE clipboard (
    id        INTEGER PRIMARY KEY AUTOINCREMENT,
    content   TEXT    NOT NULL,
    timestamp INTEGER NOT NULL,  -- Unix epoch seconds
    app_name  TEXT               -- Source application
);
CREATE INDEX idx_timestamp ON clipboard(timestamp);

-- app-tracker
CREATE TABLE app_usage (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    app_name     TEXT    NOT NULL,
    window_title TEXT,
    start_time   INTEGER NOT NULL,  -- Unix epoch seconds
    duration     INTEGER NOT NULL   -- seconds
);
CREATE INDEX idx_app_start ON app_usage(start_time);
```

## File Structure

```
~/.clip-log/
├── history.db            # SQLite database (shared by both daemons)
├── clip-log.log          # clip-log stdout log
├── clip-log.err.log      # clip-log stderr log
├── app-tracker.log       # app-tracker stdout log
└── app-tracker.err.log   # app-tracker stderr log
```

## License

[MIT](LICENSE)
