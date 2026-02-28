<div align="center">

# daily-trace

**轻量级 macOS 个人活动追踪工具**

剪贴板历史 + 应用使用追踪 + 每日报告 · 零依赖

[![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)](https://swift.org)
[![macOS](https://img.shields.io/badge/macOS-13%2B-blue.svg)](https://www.apple.com/macos)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

[English](README.md) · **中文**

</div>

---

三个轻量工具，被动拼出你每天在 macOS 上的完整轨迹：

- **clip-log** — 记录你每次复制的文本：复制了什么、什么时候、在哪个 App 里
- **app-tracker** — 记录你使用了哪些 App、每个用了多久、在里面干什么（通过窗口标题）
- **daily-stats** — 从数据库自动生成每日摘要报告

你的剪贴板记录了你一天的轨迹：搜了什么、问了什么、关注了什么。你的 App 使用记录了你的时间花在了哪里、在做什么。daily-trace 把这些轨迹默默沉淀到一个本地 SQLite 数据库里——作为**个人活动回顾和生活记录**的数据基础。

## 功能特性

### clip-log（剪贴板历史）

| 特性 | 说明 |
|------|------|
| **极致轻量** | 单个 Swift 文件，编译后仅 ~57KB，几乎不占 CPU 和内存 |
| **自动去重** | 连续复制相同内容只记录一次（内存 + 数据库双重去重） |
| **长度过滤** | 超过 1000 字符自动跳过（过滤搬运长文本，保留个人输入） |
| **敏感内容过滤** | 自动识别并跳过 API key、token、密钥（覆盖 Anthropic、OpenAI、GitHub、Google 等） |
| **密码管理器黑名单** | 来自 1Password、Bitwarden、KeePassXC 等的剪贴板永不记录 |
| **来源追踪** | 记录复制时所在的应用名称 |
| **开机自启** | 作为 macOS LaunchAgent 运行，登录即启动，崩溃自动重启 |
| **本地隐私** | 所有数据存在 `~/.clip-log/history.db`，不联网，不上传 |

### app-tracker（应用追踪）

| 特性 | 说明 |
|------|------|
| **使用时长** | 追踪前台 App 及使用时长 |
| **窗口标题** | 记录你在每个 App 里干什么（看哪个网页、编辑哪个文件、跟谁聊天） |
| **噪音过滤** | 自动过滤终端 spinner 动画等干扰字符 |
| **短切过滤** | 不到 2 秒的 App 切换自动忽略 |
| **共享数据库** | 与 clip-log 共用同一个 `history.db` |

### daily-stats（每日报告）

| 特性 | 说明 |
|------|------|
| **自动生成** | Shell 脚本查询数据库，生成可读的每日摘要 |
| **App 时长统计** | 今天每个 App 用了多久 |
| **剪贴板统计** | 复制次数及来源 App 分布 |
| **Markdown 输出** | 保存到 `~/.clip-log/daily/YYYY-MM-DD.md`，方便查看 |

## 快速开始

**环境要求：** macOS 13+（Apple Silicon 或 Intel）· Xcode 命令行工具 · SQLite3（macOS 系统自带，无需安装）

```bash
# 安装 Xcode 命令行工具（如果没有）
xcode-select --install

# 克隆并安装
git clone https://github.com/Tiny-cyber/daily-trace.git
cd daily-trace
chmod +x install.sh
./install.sh
```

安装完成，clip-log 和 app-tracker 都已在后台运行。

> 卸载：`./uninstall.sh`（数据会保留，不会删除）

## 工作原理

```
┌──────────────────────────────────────────────────────────────┐
│                         macOS                                │
│                                                              │
│  ┌─────────────────────┐       ┌──────────────────────────┐  │
│  │     系统剪贴板       │       │      前台应用程序         │  │
│  │  （每 0.5 秒检查）   │       │   （每 3 秒检查）        │  │
│  └─────────┬───────────┘       └────────────┬─────────────┘  │
│            │                                │                │
│            ▼                                ▼                │
│       ┌─────────┐                     ┌───────────┐          │
│       │clip-log │                     │app-tracker│          │
│       └────┬────┘                     └─────┬─────┘          │
│            │    ┌──────────────────┐        │                │
│            └───►│  history.db      │◄───────┘                │
│                 │  （共享 SQLite）   │                         │
│                 └────────┬─────────┘                          │
│                          │                                   │
│                          ▼                                   │
│                   ┌─────────────┐                            │
│                   │ daily-stats │                             │
│                   │ （定时/手动） │                            │
│                   └──────┬──────┘                             │
│                          │                                   │
│                          ▼                                   │
│                 ~/.clip-log/daily/                            │
│                 2026-02-28.md                                 │
└──────────────────────────────────────────────────────────────┘
```

## 查看记录

```bash
# 最近 10 条剪贴板记录
sqlite3 -header -column ~/.clip-log/history.db \
  "SELECT id, datetime(timestamp,'unixepoch','localtime') as 时间,
   app_name as 来源, substr(content,1,60) as 内容
   FROM clipboard ORDER BY id DESC LIMIT 10;"

# 今日 App 使用统计
sqlite3 -header -column ~/.clip-log/history.db \
  "SELECT app_name as 应用,
   SUM(duration)/60 as 分钟,
   COUNT(*) as 切换次数
   FROM app_usage
   WHERE date(start_time,'unixepoch','localtime') = date('now')
   GROUP BY app_name ORDER BY 分钟 DESC;"

# 生成今日报告
./daily-stats.sh
```

<details>
<summary><b>更多查询示例</b></summary>

```bash
# 关键词搜索
sqlite3 -header -column ~/.clip-log/history.db \
  "SELECT * FROM clipboard WHERE content LIKE '%关键词%';"

# 按应用统计复制次数
sqlite3 -header -column ~/.clip-log/history.db \
  "SELECT app_name as 应用, COUNT(*) as 次数 FROM clipboard
   GROUP BY app_name ORDER BY 次数 DESC;"

# 查看某一天的 App 使用记录
sqlite3 -header -column ~/.clip-log/history.db \
  "SELECT app_name as 应用, window_title as 窗口标题,
   datetime(start_time,'unixepoch','localtime') as 开始时间,
   duration || '秒' as 时长
   FROM app_usage
   WHERE date(start_time,'unixepoch','localtime') = '2026-02-28'
   ORDER BY start_time;"

# 导出为 CSV（可用 Excel / Numbers 打开）
sqlite3 -header -csv ~/.clip-log/history.db \
  "SELECT * FROM clipboard;" > clipboard.csv
sqlite3 -header -csv ~/.clip-log/history.db \
  "SELECT * FROM app_usage;" > app_usage.csv
```

</details>

## 数据库结构

```sql
-- clip-log
CREATE TABLE clipboard (
    id        INTEGER PRIMARY KEY AUTOINCREMENT,
    content   TEXT    NOT NULL,
    timestamp INTEGER NOT NULL,  -- Unix 时间戳（秒）
    app_name  TEXT               -- 来源应用名称
);
CREATE INDEX idx_timestamp ON clipboard(timestamp);

-- app-tracker
CREATE TABLE app_usage (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    app_name     TEXT    NOT NULL,
    window_title TEXT,
    start_time   INTEGER NOT NULL,  -- Unix 时间戳（秒）
    duration     INTEGER NOT NULL   -- 秒
);
CREATE INDEX idx_app_start ON app_usage(start_time);
```

## 文件说明

```
~/.clip-log/
├── history.db            # SQLite 数据库（所有组件共用）
├── daily/                # 每日摘要报告
│   └── 2026-02-28.md
├── clip-log.log          # clip-log 运行日志
├── clip-log.err.log      # clip-log 错误日志
├── app-tracker.log       # app-tracker 运行日志
└── app-tracker.err.log   # app-tracker 错误日志
```

## 实时监控

```bash
# 实时查看剪贴板记录
tail -f ~/.clip-log/clip-log.log

# 实时查看 App 切换记录
tail -f ~/.clip-log/app-tracker.log
```

## 开源协议

[MIT](LICENSE)
