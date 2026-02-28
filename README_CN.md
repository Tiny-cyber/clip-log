<div align="center">

# clip-log

**轻量级 macOS 剪贴板历史记录工具**

单文件 · 零依赖 · 57KB

[![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)](https://swift.org)
[![macOS](https://img.shields.io/badge/macOS-13%2B-blue.svg)](https://www.apple.com/macos)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

[English](README.md) · **中文**

</div>

---

在后台默默记录你每次复制的文本 —— **复制了什么**、**什么时候**、**在哪个 App 里复制的** —— 全部存入本地 SQLite 数据库。

你的剪贴板记录了你一天的轨迹：搜了什么、问了什么、关注了什么。clip-log 把这些轨迹沉淀下来，作为**个人活动回顾和生活记录**的数据基础。

## 功能特性

| 特性 | 说明 |
|------|------|
| **极致轻量** | 单个 Swift 文件，编译后仅 ~57KB，几乎不占 CPU 和内存 |
| **自动去重** | 连续复制相同内容只记录一次 |
| **长度过滤** | 超过 1000 字符自动跳过（过滤搬运长文本，保留个人输入） |
| **来源追踪** | 记录复制时所在的应用名称 |
| **开机自启** | 作为 macOS LaunchAgent 运行，登录即启动，崩溃自动重启 |
| **本地隐私** | 所有数据存在 `~/.clip-log/history.db`，不联网，不上传 |

## 快速开始

**环境要求：** macOS 13+（Apple Silicon 或 Intel）· Xcode 命令行工具 · SQLite3（macOS 系统自带，无需安装）

```bash
# 安装 Xcode 命令行工具（如果没有）
xcode-select --install

# 克隆并安装
git clone https://github.com/Tiny-cyber/clip-log.git
cd clip-log
chmod +x install.sh
./install.sh
```

安装完成，clip-log 已在后台运行。

> 卸载：`./uninstall.sh`（数据会保留，不会删除）

## 工作原理

```
┌─────────────────────────────────────────────────┐
│              macOS 系统剪贴板                     │
│            （每 0.5 秒检查一次）                   │
└────────────────────┬────────────────────────────┘
                     │ changeCount 变化？
                     ▼
              ┌──────────────┐
              │   读取文本    │
              └──────┬───────┘
                     │
          ┌──────────┼──────────┐
          ▼          ▼          ▼
      超过1000字？  跟上条重复？  空内容？
       跳过 ✗      跳过 ✗      跳过 ✗
                     │
                     ▼ 通过 ✓
         ┌───────────────────────┐
         │   写入 SQLite 数据库   │
         │   + 时间戳             │
         │   + 来源应用名称       │
         └───────────────────────┘
```

## 查看记录

```bash
# 最近 10 条记录
sqlite3 -header -column ~/.clip-log/history.db \
  "SELECT id, datetime(timestamp,'unixepoch','localtime') as 时间,
   app_name as 来源, substr(content,1,60) as 内容
   FROM clipboard ORDER BY id DESC LIMIT 10;"
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

# 查看某一天的记录
sqlite3 -header -column ~/.clip-log/history.db \
  "SELECT * FROM clipboard
   WHERE date(timestamp,'unixepoch','localtime') = '2026-02-28';"

# 导出为 CSV（可用 Excel / Numbers 打开）
sqlite3 -header -csv ~/.clip-log/history.db \
  "SELECT * FROM clipboard;" > history.csv
```

</details>

## 数据库结构

```sql
CREATE TABLE clipboard (
    id        INTEGER PRIMARY KEY AUTOINCREMENT,
    content   TEXT    NOT NULL,
    timestamp INTEGER NOT NULL,  -- Unix 时间戳（秒）
    app_name  TEXT               -- 来源应用名称
);
CREATE INDEX idx_timestamp ON clipboard(timestamp);
```

## 文件说明

```
~/.clip-log/
├── history.db        # SQLite 数据库（你的数据）
├── clip-log.log      # 运行日志
└── clip-log.err.log  # 错误日志
```

## 实时监控

安装后可以用一行命令实时查看剪贴板记录：

```bash
tail -f ~/.clip-log/clip-log.log
```

## 开源协议

[MIT](LICENSE)
