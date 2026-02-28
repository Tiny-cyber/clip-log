import Cocoa
import SQLite3

// ─── Config ─────────────────────────────────────────────────────

let homeDir = NSHomeDirectory()
let dataDir = homeDir + "/.clip-log"
let dbPath  = dataDir + "/history.db"  // share DB with clip-log

// ─── SQLite ─────────────────────────────────────────────────────

var db: OpaquePointer?

func openDB() {
    try? FileManager.default.createDirectory(
        atPath: dataDir, withIntermediateDirectories: true
    )

    if sqlite3_open(dbPath, &db) != SQLITE_OK {
        fputs("DB open failed: \(String(cString: sqlite3_errmsg(db)))\n", stderr)
        exit(1)
    }

    let sql = """
    CREATE TABLE IF NOT EXISTS app_usage (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        app_name   TEXT    NOT NULL,
        window_title TEXT,
        start_time INTEGER NOT NULL,
        duration   INTEGER NOT NULL
    );
    CREATE INDEX IF NOT EXISTS idx_app_start ON app_usage(start_time);
    """

    if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
        fputs("DB init failed: \(String(cString: sqlite3_errmsg(db)))\n", stderr)
        exit(1)
    }
}

func insertUsage(app: String, title: String?, start: Int, duration: Int) {
    // Skip very short usage (< 2 seconds, likely just switching through)
    if duration < 2 { return }

    let sql = "INSERT INTO app_usage (app_name, window_title, start_time, duration) VALUES (?, ?, ?, ?)"
    var stmt: OpaquePointer?

    guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
    defer { sqlite3_finalize(stmt) }

    sqlite3_bind_text(stmt, 1, (app as NSString).utf8String, -1, nil)
    if let t = title {
        sqlite3_bind_text(stmt, 2, (t as NSString).utf8String, -1, nil)
    } else {
        sqlite3_bind_null(stmt, 2)
    }
    sqlite3_bind_int64(stmt, 3, Int64(start))
    sqlite3_bind_int64(stmt, 4, Int64(duration))

    sqlite3_step(stmt)
}

// ─── Window title via CGWindowList ──────────────────────────────

func getWindowTitle(for pid: pid_t) -> String? {
    guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
        return nil
    }
    for info in list {
        if let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t,
           ownerPID == pid,
           let layer = info[kCGWindowLayer as String] as? Int, layer == 0,
           let name = info[kCGWindowName as String] as? String,
           !name.isEmpty {
            return name
        }
    }
    return nil
}

// ─── App tracker ────────────────────────────────────────────────

var currentApp: String? = nil
var currentTitle: String? = nil
var currentTitleNorm: String? = nil
var switchTime: Int = Int(Date().timeIntervalSince1970)

// Strip spinner chars and other noise from window titles
func normalize(_ title: String?) -> String? {
    guard let t = title else { return nil }
    var result = t
    // Remove Braille pattern chars (U+2800-U+28FF) used as spinners
    result = result.unicodeScalars.filter { !($0.value >= 0x2800 && $0.value <= 0x28FF) }
        .map { String($0) }.joined()
    // Collapse multiple spaces
    result = result.replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
    return result.trimmingCharacters(in: .whitespaces)
}

func checkApp() {
    guard let frontApp = NSWorkspace.shared.frontmostApplication else { return }
    let appName = frontApp.localizedName ?? "Unknown"
    let title = getWindowTitle(for: frontApp.processIdentifier)
    let titleNorm = normalize(title)

    // Same app and same normalized title — no change
    if appName == currentApp && titleNorm == currentTitleNorm { return }

    let now = Int(Date().timeIntervalSince1970)

    // Record the previous app session
    if let prevApp = currentApp {
        let duration = now - switchTime
        insertUsage(app: prevApp, title: currentTitle, start: switchTime, duration: duration)

        let durStr = duration >= 60 ? "\(duration / 60)m\(duration % 60)s" : "\(duration)s"
        let titleStr = currentTitle ?? ""
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("[\(timestamp)] \(prevApp) | \(titleStr) | \(durStr)")
        fflush(stdout)
    }

    // Start tracking new app/window
    currentApp = appName
    currentTitle = title
    currentTitleNorm = titleNorm
    switchTime = now
}

// ─── Main ───────────────────────────────────────────────────────

openDB()
print("app-tracker started. DB: \(dbPath)")
fflush(stdout)

// Check every 3 seconds
let timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in
    checkApp()
}

RunLoop.current.add(timer, forMode: .default)
RunLoop.current.run()
