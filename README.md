<div align="center">

# daily-trace

**Lightweight macOS personal activity tracker**

Clipboard history + App usage tracking + Daily reports · Zero dependencies

[![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)](https://swift.org)
[![macOS](https://img.shields.io/badge/macOS-13%2B-blue.svg)](https://www.apple.com/macos)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

**English** · [中文](README_CN.md)

</div>

---

Three lightweight tools that passively build a complete picture of your day on macOS:

- **clip-log** — records every text you copy: what you copied, when, and from which app
- **app-tracker** — records which apps you use, for how long, and what you're doing in each one (via window titles)
- **daily-stats** — generates a daily summary report from the collected data

Your clipboard tells the story of your day: what you searched, what you asked, what caught your attention. Your app usage shows where you spent your time and what you were working on. daily-trace captures all of this silently and stores it locally in a single SQLite database — the data layer for **personal activity review and life logging**.

## Features

### clip-log (clipboard history)

| Feature | Description |
|---------|-------------|
| **Lightweight** | Single Swift file, compiles to ~57KB, near-zero CPU & memory |
| **Auto-dedup** | Skips consecutive identical copies (in-memory + database double check) |
| **Length filter** | Ignores entries over 1000 chars (filters bulk copy-paste, keeps personal input) |
| **Sensitive content filter** | Auto-detects and skips API keys, tokens, secrets (Anthropic, OpenAI, GitHub, Google, etc.) |
| **Password manager blacklist** | Never records clipboard from 1Password, Bitwarden, KeePassXC, etc. |
| **Source tracking** | Records which app the copy came from |
| **Auto-start** | macOS LaunchAgent, starts on login, auto-restarts on crash |
| **Local & private** | All data stays in `~/.clip-log/history.db`, nothing leaves your machine |

### app-tracker (app usage tracking)

| Feature | Description |
|---------|-------------|
| **App usage time** | Tracks which app is in the foreground and for how long |
| **Window titles** | Records what you're doing in each app (which webpage, which file, which chat) |
| **Noise filtering** | Strips terminal spinner animations and other noise from window titles |
| **Short switch filter** | Ignores app switches under 2 seconds (just passing through) |
| **Shared database** | Uses the same `history.db` as clip-log |

### daily-stats (daily report)

| Feature | Description |
|---------|-------------|
| **Auto-generated** | Shell script queries the database and produces a readable daily summary |
| **App time breakdown** | Shows how long you spent in each app today |
| **Clipboard stats** | Copy count and breakdown by source app |
| **Markdown output** | Saves to `~/.clip-log/daily/YYYY-MM-DD.md` for easy review |

## Quick Start

**Requirements:** macOS 13+ (Apple Silicon or Intel) · Xcode Command Line Tools · SQLite3 (pre-installed on macOS)

```bash
git clone https://github.com/Tiny-cyber/daily-trace.git
cd daily-trace
chmod +x install.sh
./install.sh
```

That's it. clip-log and app-tracker are now running in the background.

> To uninstall: `./uninstall.sh` (your data is preserved)

## How It Works

```
┌──────────────────────────────────────────────────────────────┐
│                         macOS                                │
│                                                              │
│  ┌─────────────────────┐       ┌──────────────────────────┐  │
│  │   System Clipboard  │       │   Frontmost Application  │  │
│  │  (polled every 0.5s)│       │    (polled every 3s)     │  │
│  └─────────┬───────────┘       └────────────┬─────────────┘  │
│            │                                │                │
│            ▼                                ▼                │
│       ┌─────────┐                     ┌───────────┐          │
│       │clip-log │                     │app-tracker│          │
│       └────┬────┘                     └─────┬─────┘          │
│            │    ┌──────────────────┐        │                │
│            └───►│  history.db      │◄───────┘                │
│                 │  (shared SQLite) │                          │
│                 └────────┬─────────┘                          │
│                          │                                   │
│                          ▼                                   │
│                   ┌─────────────┐                            │
│                   │ daily-stats │                             │
│                   │  (cron/manual)                            │
│                   └──────┬──────┘                             │
│                          │                                   │
│                          ▼                                   │
│                 ~/.clip-log/daily/                            │
│                 2026-02-28.md                                 │
└──────────────────────────────────────────────────────────────┘
```

## Query Your History

```bash
# Recent 10 clipboard entries
sqlite3 -header -column ~/.clip-log/history.db \
  "SELECT id, datetime(timestamp,'unixepoch','localtime') as time,
   app_name, substr(content,1,60) as preview
   FROM clipboard ORDER BY id DESC LIMIT 10;"

# Today's app usage
sqlite3 -header -column ~/.clip-log/history.db \
  "SELECT app_name,
   SUM(duration)/60 as minutes,
   COUNT(*) as switches
   FROM app_usage
   WHERE date(start_time,'unixepoch','localtime') = date('now')
   GROUP BY app_name ORDER BY minutes DESC;"

# Generate today's report
./daily-stats.sh
```

<details>
<summary><b>More query examples</b></summary>

```bash
# Search clipboard by keyword
sqlite3 -header -column ~/.clip-log/history.db \
  "SELECT * FROM clipboard WHERE content LIKE '%keyword%';"

# Clipboard stats by app
sqlite3 -header -column ~/.clip-log/history.db \
  "SELECT app_name, COUNT(*) as count FROM clipboard
   GROUP BY app_name ORDER BY count DESC;"

# App usage on a specific date
sqlite3 -header -column ~/.clip-log/history.db \
  "SELECT app_name, window_title,
   datetime(start_time,'unixepoch','localtime') as started,
   duration || 's' as duration
   FROM app_usage
   WHERE date(start_time,'unixepoch','localtime') = '2026-02-28'
   ORDER BY start_time;"

# Export to CSV
sqlite3 -header -csv ~/.clip-log/history.db \
  "SELECT * FROM clipboard;" > clipboard.csv
sqlite3 -header -csv ~/.clip-log/history.db \
  "SELECT * FROM app_usage;" > app_usage.csv
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
├── history.db            # SQLite database (shared by all components)
├── daily/                # Daily summary reports
│   └── 2026-02-28.md
├── clip-log.log          # clip-log stdout log
├── clip-log.err.log      # clip-log stderr log
├── app-tracker.log       # app-tracker stdout log
└── app-tracker.err.log   # app-tracker stderr log
```

## License

[MIT](LICENSE)
