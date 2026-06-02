#!/usr/bin/env bash
# scan-plugins.sh — 扫描 Claude Code Plugins
# 用法: bash scan-plugins.sh [--check-remote]
# 输出: JSON { "plugins": [...], "marketplaces": [...], "remoteInfo": {} }

set -euo pipefail

home="${HOME:-$(eval echo ~)}"
plugins_path="$home/.claude/plugins/installed_plugins.json"
mk_path="$home/.claude/plugins/known_marketplaces.json"

# Read installed plugins via stdin
if [ -f "$plugins_path" ]; then
  plugins=$(node -e "
    const raw = JSON.parse(require('fs').readFileSync(0, 'utf8'));
    const pluginsObj = raw.plugins || {};
    const arr = [];
    for (const [key, installs] of Object.entries(pluginsObj)) {
      if (!Array.isArray(installs) || installs.length === 0) continue;
      const inst = installs[0];
      const parts = key.split('@');
      arr.push({
        name: parts[0],
        marketplace: parts.slice(1).join('@') || null,
        version: inst.version || null,
        gitCommitSha: inst.gitCommitSha || null
      });
    }
    process.stdout.write(JSON.stringify(arr));
  " < "$plugins_path" 2>/dev/null || echo '[]')
else
  plugins='[]'
fi

# Read known marketplaces via stdin
if [ -f "$mk_path" ]; then
  marketplaces=$(node -e "
    const data = JSON.parse(require('fs').readFileSync(0, 'utf8'));
    process.stdout.write(JSON.stringify(
      Object.entries(data).map(([name, info]) => ({
        name,
        path: info.path || null,
        gitUrl: info.gitUrl || info.url || null
      }))
    ));
  " < "$mk_path" 2>/dev/null || echo '[]')
else
  marketplaces='[]'
fi

# Check remote updates (optional)
remote_info='{}'
if [ "${1:-}" = "--check-remote" ] && [ "$marketplaces" != '[]' ]; then
  remote_info=$(echo "$marketplaces" | node -e "
    const mks = JSON.parse(require('fs').readFileSync(0, 'utf8'));
    const result = {};
    for (const mk of mks) {
      if (mk.path) {
        const p = mk.path.replace(/^~/, process.env.HOME || '');
        result[mk.name] = { path: p, latestSha: null, error: null };
      }
    }
    process.stdout.write(JSON.stringify(result));
  " 2>/dev/null || echo '{}')
fi

echo "{\"plugins\":$plugins,\"marketplaces\":$marketplaces,\"remoteInfo\":$remote_info}"
