import Cocoa
import SQLite3

// ─── Config ─────────────────────────────────────────────────────

let homeDir = NSHomeDirectory()
let dataDir = homeDir + "/.clip-log"
let dbPath  = dataDir + "/history.db"
let maxLength = 1000  // skip entries longer than this (utility copy-paste)

// Apps that handle sensitive data — clipboard from these is never recorded
let blockedApps: Set<String> = [
    "1Password", "Keychain Access", "钥匙串访问",
    "Bitwarden", "LastPass", "KeePassXC", "Dashlane",
    "Enpass", "RoboForm", "Keeper",
]

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
var lastRecordedText: String? = nil  // in-memory dedup (catches rapid double-fires)

func checkClipboard() {
    let currentCount = pasteboard.changeCount
    guard currentCount != lastChangeCount else { return }
    lastChangeCount = currentCount

    guard let text = pasteboard.string(forType: .string),
          !text.isEmpty else { return }

    // Skip long texts (likely utility copy-paste, not personal input)
    if text.count > maxLength { return }

    // Skip sensitive content (API keys, tokens, secrets)
    let lower = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    let looksLikeKey = lower.hasPrefix("sk-ant-")       // Anthropic
        || lower.hasPrefix("sk-")                       // OpenAI / Stripe
        || lower.hasPrefix("sk_")                       // Stripe etc.
        || lower.hasPrefix("ghp_")                      // GitHub PAT
        || lower.hasPrefix("gho_")                      // GitHub OAuth
        || lower.hasPrefix("ghs_")                      // GitHub App
        || lower.hasPrefix("github_pat_")               // GitHub fine-grained
        || lower.hasPrefix("aig_")                      // AI keys
        || lower.hasPrefix("aizasy")                    // Google API key
        || lower.hasPrefix("xai-")                      // xAI / Grok
        || lower.hasPrefix("hf_")                       // HuggingFace
        || lower.hasPrefix("r8_")                       // Replicate
        || lower.hasPrefix("tvly-")                     // Tavily
        || lower.hasPrefix("sess-")                     // Session tokens
        || lower.hasPrefix("eyj")                       // JWT tokens (base64 of {"...)
        || lower.contains("api_key")
        || lower.contains("apikey")
        || lower.contains("secret_key")
        || lower.contains("access_token")
        || lower.contains("bearer ")
        || (text.count >= 32 && text.range(of: "^[A-Za-z0-9+/=_\\-]{32,}$", options: .regularExpression) != nil)
    if looksLikeKey { return }

    // In-memory dedup: catch rapid double changeCount fires
    if text == lastRecordedText { return }

    // DB dedup: survives restarts
    if text == getLastContent() { return }

    let appName = NSWorkspace.shared.frontmostApplication?.localizedName

    // Skip sensitive apps (password managers etc.)
    if let app = appName, blockedApps.contains(app) { return }

    insertEntry(content: text, appName: appName)
    lastRecordedText = text

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
