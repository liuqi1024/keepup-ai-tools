#!/usr/bin/env bash
# scan-skills.sh — 扫描 Agent Skills 锁文件和目录
# 输出: JSON { "lock": {...}, "directories": {...} }

set -euo pipefail

home="${HOME:-$(eval echo ~)}"
lock_path="$home/.agents/.skill-lock.json"

# Scan lock file via stdin to avoid path escaping issues
if [ -f "$lock_path" ]; then
  lock_json=$(node -e "
    const fs = require('fs');
    const data = JSON.parse(fs.readFileSync(0, 'utf8'));
    const skills = data.skills || {};
    const groups = {};
    for (const [name, info] of Object.entries(skills)) {
      if (typeof info !== 'object') continue;
      const source = info.source || info.sourceUrl || 'unknown';
      const sourceType = info.sourceType || 'unknown';
      if (!groups[source]) {
        groups[source] = { source, sourceType, skills: [], updatedAt: null };
      }
      groups[source].skills.push(name);
      const ua = info.updatedAt;
      if (ua && (!groups[source].updatedAt || ua > groups[source].updatedAt)) {
        groups[source].updatedAt = ua;
      }
    }
    process.stdout.write(JSON.stringify(groups));
  " < "$lock_path" 2>/dev/null || echo '{}')
else
  lock_json='{}'
fi

# Scan skill directories
dirs_json='{}'
for dir in \
  "$home/.agents/skills" \
  "$home/.claude/skills" \
  "$home/.codex/skills" \
  "$home/.hermes/skills"; do
  if [ -d "$dir" ]; then
    count=$(find "$dir" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
    # Use ~ shorthand
    key=$(echo "$dir" | sed "s|^$home|~|")
    dirs_json=$(echo "$dirs_json" | node -e "
      let obj;
      try { obj = JSON.parse(require('fs').readFileSync(0, 'utf8')); } catch { obj = {}; }
      obj[process.argv[1]] = parseInt(process.argv[2]);
      process.stdout.write(JSON.stringify(obj));
    " "$key" "$count")
  fi
done

echo "{\"lock\":$lock_json,\"directories\":$dirs_json}"
