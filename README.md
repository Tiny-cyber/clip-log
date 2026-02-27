# clip-log

A lightweight macOS clipboard history daemon. One file, zero dependencies, 57KB binary.

Silently records every text you copy — what you copied, when, and from which app — into a local SQLite database. Designed as the data layer for personal activity review and life logging.

## Features

- **Lightweight** — Single Swift file, compiles to ~57KB, near-zero CPU/memory usage
- **Auto-dedup** — Skips consecutive identical copies
- **Length filter** — Ignores entries over 1000 characters (catches bulk copy-paste, keeps personal input)
- **Source tracking** — Records which app the copy came from
- **Auto-start** — Runs as a macOS LaunchAgent, starts on login, auto-restarts on crash
- **Local & private** — All data stays in `~/.clip-log/history.db`, nothing leaves your machine

## Requirements

- macOS (Apple Silicon or Intel)
- Xcode Command Line Tools (`xcode-select --install`)

## Install

```bash
git clone https://github.com/Tiny-cyber/clip-log.git
cd clip-log
chmod +x install.sh
./install.sh
```

## Uninstall

```bash
chmod +x uninstall.sh
./uninstall.sh
```

Your data at `~/.clip-log/history.db` is preserved after uninstall.

## Query your history

```bash
# Recent 10 entries
sqlite3 -header -column ~/.clip-log/history.db \
  "SELECT id, datetime(timestamp,'unixepoch','localtime') as time, app_name, substr(content,1,60) as preview FROM clipboard ORDER BY id DESC LIMIT 10;"

# Search by keyword
sqlite3 -header -column ~/.clip-log/history.db \
  "SELECT * FROM clipboard WHERE content LIKE '%keyword%';"

# Stats by app
sqlite3 -header -column ~/.clip-log/history.db \
  "SELECT app_name, COUNT(*) as count FROM clipboard GROUP BY app_name ORDER BY count DESC;"

# Entries from a specific date
sqlite3 -header -column ~/.clip-log/history.db \
  "SELECT * FROM clipboard WHERE date(timestamp,'unixepoch','localtime') = '2026-02-28';"
```

## Database schema

```sql
CREATE TABLE clipboard (
    id        INTEGER PRIMARY KEY AUTOINCREMENT,
    content   TEXT    NOT NULL,
    timestamp INTEGER NOT NULL,  -- Unix timestamp
    app_name  TEXT               -- Source application name
);
```

## How it works

Polls `NSPasteboard.general.changeCount` every 0.5 seconds. When it changes, reads the text content, checks against the last database entry for deduplication, and inserts if new. The frontmost application name is captured via `NSWorkspace`.

## License

MIT
