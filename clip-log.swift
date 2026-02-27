import Cocoa
import SQLite3

// ─── Config ─────────────────────────────────────────────────────

let homeDir = NSHomeDirectory()
let dataDir = homeDir + "/.clip-log"
let dbPath  = dataDir + "/history.db"
let maxLength = 1000  // skip entries longer than this (utility copy-paste)

// ─── SQLite helpers ─────────────────────────────────────────────

var db: OpaquePointer?

func openDB() {
    try? FileManager.default.createDirectory(
        atPath: dataDir, withIntermediateDirectories: true
    )

    if sqlite3_open(dbPath, &db) != SQLITE_OK {
        let err = String(cString: sqlite3_errmsg(db))
        fputs("DB open failed: \(err)\n", stderr)
        exit(1)
    }

    let sql = """
    CREATE TABLE IF NOT EXISTS clipboard (
        id        INTEGER PRIMARY KEY AUTOINCREMENT,
        content   TEXT    NOT NULL,
        timestamp INTEGER NOT NULL,
        app_name  TEXT
    );
    CREATE INDEX IF NOT EXISTS idx_timestamp ON clipboard(timestamp);
    """

    if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
        let err = String(cString: sqlite3_errmsg(db))
        fputs("DB init failed: \(err)\n", stderr)
        exit(1)
    }
}

func getLastContent() -> String? {
    let sql = "SELECT content FROM clipboard ORDER BY id DESC LIMIT 1"
    var stmt: OpaquePointer?
    guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
    defer { sqlite3_finalize(stmt) }
    if sqlite3_step(stmt) == SQLITE_ROW, let ptr = sqlite3_column_text(stmt, 0) {
        return String(cString: ptr)
    }
    return nil
}

func insertEntry(content: String, appName: String?) {
    let sql = "INSERT INTO clipboard (content, timestamp, app_name) VALUES (?, ?, ?)"
    var stmt: OpaquePointer?

    guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
        fputs("Prepare failed: \(String(cString: sqlite3_errmsg(db)))\n", stderr)
        return
    }
    defer { sqlite3_finalize(stmt) }

    let ts = Int(Date().timeIntervalSince1970)
    sqlite3_bind_text(stmt, 1, (content as NSString).utf8String, -1, nil)
    sqlite3_bind_int64(stmt, 2, Int64(ts))
    if let app = appName {
        sqlite3_bind_text(stmt, 3, (app as NSString).utf8String, -1, nil)
    } else {
        sqlite3_bind_null(stmt, 3)
    }

    if sqlite3_step(stmt) != SQLITE_DONE {
        fputs("Insert failed: \(String(cString: sqlite3_errmsg(db)))\n", stderr)
    }
}

// ─── Clipboard monitor ─────────────────────────────────────────

let pasteboard = NSPasteboard.general
var lastChangeCount = pasteboard.changeCount

func checkClipboard() {
    let currentCount = pasteboard.changeCount
    guard currentCount != lastChangeCount else { return }
    lastChangeCount = currentCount

    guard let text = pasteboard.string(forType: .string),
          !text.isEmpty else { return }

    // Skip long texts (likely utility copy-paste, not personal input)
    if text.count > maxLength { return }

    // Dedup: check against last entry in DB (survives restarts)
    if text == getLastContent() { return }

    let appName = NSWorkspace.shared.frontmostApplication?.localizedName

    insertEntry(content: text, appName: appName)

    let preview = text.prefix(60).replacingOccurrences(of: "\n", with: "\\n")
    let timestamp = ISO8601DateFormatter().string(from: Date())
    print("[\(timestamp)] [\(appName ?? "?")] \(preview)")
    fflush(stdout)
}

// ─── Main ───────────────────────────────────────────────────────

openDB()
print("clip-log started. DB: \(dbPath)")
fflush(stdout)

let timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
    checkClipboard()
}

RunLoop.current.add(timer, forMode: .default)
RunLoop.current.run()
