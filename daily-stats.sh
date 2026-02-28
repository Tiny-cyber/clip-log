#!/bin/bash
# 每日统计脚本 — 从 history.db 生成当天的 App 使用和剪贴板统计

DB="$HOME/.clip-log/history.db"
TODAY=$(date +%Y-%m-%d)
DAILY_DIR="$HOME/.clip-log/daily"
DAILY_FILE="$DAILY_DIR/$TODAY.md"
REPORT_FILE="$DAILY_DIR/$TODAY-report.txt"

mkdir -p "$DAILY_DIR"

# 今天的起止时间戳
START_TS=$(date -j -f "%Y-%m-%d %H:%M:%S" "$TODAY 00:00:00" +%s)
END_TS=$(date -j -f "%Y-%m-%d %H:%M:%S" "$TODAY 23:59:59" +%s)

# ─── App 使用统计 ───
APP_STATS=$(sqlite3 "$DB" <<SQL
.mode list
.separator ' | '
SELECT app_name,
       SUM(duration) as total_sec,
       COUNT(*) as switches
FROM app_usage
WHERE start_time >= $START_TS AND start_time <= $END_TS
GROUP BY app_name
ORDER BY total_sec DESC;
SQL
)

# ─── 剪贴板统计 ───
CLIP_TOTAL=$(sqlite3 "$DB" "SELECT COUNT(*) FROM clipboard WHERE timestamp >= $START_TS AND timestamp <= $END_TS;")

CLIP_BY_APP=$(sqlite3 "$DB" <<SQL
.mode list
.separator ' | '
SELECT COALESCE(app_name, '未知') as app, COUNT(*) as cnt
FROM clipboard
WHERE timestamp >= $START_TS AND timestamp <= $END_TS
GROUP BY app_name
ORDER BY cnt DESC
LIMIT 5;
SQL
)

# ─── 格式化输出 ───
format_duration() {
    local sec=$1
    local h=$((sec / 3600))
    local m=$(( (sec % 3600) / 60 ))
    if [ $h -gt 0 ]; then
        echo "${h}h ${m}m"
    elif [ $m -gt 0 ]; then
        echo "${m}m"
    else
        echo "${sec}s"
    fi
}

# 生成报告
{
    echo "## 今日统计（自动生成 $(date +%H:%M)）"
    echo ""
    echo "### App 使用时长"

    if [ -z "$APP_STATS" ]; then
        echo "- 暂无数据"
    else
        while IFS='|' read -r app sec switches; do
            app=$(echo "$app" | xargs)
            sec=$(echo "$sec" | xargs)
            echo "- $app: $(format_duration $sec)"
        done <<< "$APP_STATS"
    fi

    echo ""
    echo "### 剪贴板统计"
    echo "- 共复制 ${CLIP_TOTAL} 次"

    if [ -n "$CLIP_BY_APP" ]; then
        echo "- 来源："
        while IFS='|' read -r app cnt; do
            app=$(echo "$app" | xargs)
            cnt=$(echo "$cnt" | xargs)
            echo "  - $app: ${cnt}次"
        done <<< "$CLIP_BY_APP"
    fi
} > "$REPORT_FILE"

# 同时追加到 daily markdown 文件
if [ -f "$DAILY_FILE" ]; then
    echo "" >> "$DAILY_FILE"
    cat "$REPORT_FILE" >> "$DAILY_FILE"
else
    echo "# $TODAY 每日摘要" > "$DAILY_FILE"
    echo "" >> "$DAILY_FILE"
    cat "$REPORT_FILE" >> "$DAILY_FILE"
fi

echo "Report saved to $REPORT_FILE"
cat "$REPORT_FILE"
