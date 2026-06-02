#!/usr/bin/env bash
# scan-npm.sh — 扫描 npm 全局包，输出当前版本和可用更新
# 用法: bash scripts/scan-npm.sh [--with-outdated]
# 输出: JSON 对象 { "installed": {...}, "outdated": {...} }

set -euo pipefail

result='{"installed":{},"outdated":{}}'

# npm list
if command -v npm &>/dev/null; then
  npm_output=$(npm list -g --depth=0 --json 2>/dev/null || true)
  if [ -n "$npm_output" ]; then
    installed=$(echo "$npm_output" | node -e "
      const data = JSON.parse(require('fs').readFileSync(0, 'utf8'));
      const deps = data.dependencies || {};
      const out = {};
      for (const [name, info] of Object.entries(deps)) {
        out[name] = { version: info.version || null, path: info.path || null };
      }
      process.stdout.write(JSON.stringify(out));
    " 2>/dev/null || echo '{}')
  else
    installed='{}'
  fi
else
  installed='{}'
fi

# npm outdated (optional, needs network)
outdated='{}'
if [ "${1:-}" = "--with-outdated" ]; then
  outdated_output=$(npm outdated -g --json 2>/dev/null || true)
  if [ -n "$outdated_output" ]; then
    outdated=$(echo "$outdated_output" | node -e "
      const raw = require('fs').readFileSync(0, 'utf8');
      // Extract JSON object from potentially mixed output
      const start = raw.indexOf('{');
      const end = raw.lastIndexOf('}');
      if (start === -1 || end === -1) { process.stdout.write('{}'); return; }
      try {
        const data = JSON.parse(raw.substring(start, end + 1));
        const out = {};
        for (const [name, info] of Object.entries(data)) {
          out[name] = {
            current: info.current || null,
            wanted: info.wanted || null,
            latest: info.latest || null
          };
        }
        process.stdout.write(JSON.stringify(out));
      } catch { process.stdout.write('{}'); }
    " 2>/dev/null || echo '{}')
  fi
fi

printf '{"installed":%s,"outdated":%s}' "$installed" "$outdated" | node -e "
  const raw = require('fs').readFileSync(0, 'utf8');
  const { installed, outdated } = JSON.parse(raw);
  for (const [name, info] of Object.entries(installed)) {
    if (outdated[name]) {
      info.latest = outdated[name].latest;
      info.updateAvailable = true;
    }
  }
  process.stdout.write(JSON.stringify({ installed, outdated }));
"
