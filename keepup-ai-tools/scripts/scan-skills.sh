#!/usr/bin/env bash
# scan-skills.sh — 扫描 Agent Skills 锁文件和目录
# 输出: JSON { "lock": {...}, "directories": {...} }

set -euo pipefail

home="${HOME:-$(eval echo ~)}"
lock_path="$home/.agents/.skill-lock.json"

# Delegate all logic to node — avoids shell variable interpolation issues
node -e '
const fs = require("fs");
const path = require("path");
const home = process.argv[1];
const lockPath = process.argv[2];

const result = { lock: {}, directories: {} };

// Parse lock file
if (fs.existsSync(lockPath)) {
  try {
    const data = JSON.parse(fs.readFileSync(lockPath, "utf8"));
    const skills = data.skills || {};
    const groups = {};
    for (const [name, info] of Object.entries(skills)) {
      if (typeof info !== "object") continue;
      const source = info.source || info.sourceUrl || "unknown";
      const sourceType = info.sourceType || "unknown";
      if (!groups[source]) {
        groups[source] = { source, sourceType, skills: [], updatedAt: null };
      }
      groups[source].skills.push(name);
      const ua = info.updatedAt;
      if (ua && (!groups[source].updatedAt || ua > groups[source].updatedAt)) {
        groups[source].updatedAt = ua;
      }
    }
    result.lock = groups;
  } catch {}
}

// Scan skill directories
const dirs = [
  path.join(home, ".agents/skills"),
  path.join(home, ".claude/skills"),
  path.join(home, ".codex/skills"),
  path.join(home, ".hermes/skills")
];
for (const dir of dirs) {
  try {
    const entries = fs.readdirSync(dir, { withFileTypes: true });
    const count = entries.filter(e => e.isDirectory()).length;
    if (count > 0) {
      const key = dir.replace(home, "~");
      result.directories[key] = count;
    }
  } catch {}
}

process.stdout.write(JSON.stringify(result));
' "$home" "$lock_path"
