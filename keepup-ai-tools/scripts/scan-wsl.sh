#!/usr/bin/env bash
# scan-wsl.sh — 探测 WSL 中安装的工具
# 输出: JSON { "wsl_available": bool, "tools": [...] }

set -euo pipefail

if ! command -v wsl.exe &>/dev/null; then
  echo '{"wsl_available":false,"tools":[]}'
  exit 0
fi

if ! wsl.exe -e sh -lc "echo ok" 2>/dev/null | grep -q "ok"; then
  echo '{"wsl_available":false,"tools":[]}'
  exit 0
fi

# Collect raw output, strip null bytes
hermes_raw=$(wsl.exe -e sh -lc "command -v hermes && hermes --version" 2>&1 | tr -d '\0' || true)

tools='[]'

if [ -n "$hermes_raw" ]; then
  # Parse via stdin to avoid quoting issues
  hermes_json=$(echo "$hermes_raw" | node -e "
    const lines = require('fs').readFileSync(0, 'utf8').split('\n');
    const info = { name: 'Hermes', version: null, project: null, updateAvailable: null };
    for (const raw of lines) {
      const line = raw.trim();
      if (!line || line.toLowerCase().startsWith('active code page:')) continue;
      if (!info.version && /v?\d+\.\d+/.test(line)) { const m = line.match(/(v?\d+\.\d+\S*)/); if (m) info.version = m[1]; continue; }
      if (line.startsWith('Project:')) { info.project = line.split(':', 2)[1].trim(); continue; }
      if (line.startsWith('Update available:')) {
        const val = line.split(':', 2)[1].trim();
        if (val && !/^no$/i.test(val) && !/^none$/i.test(val) && !/^false$/i.test(val) && !/^0$/.test(val)) {
          info.updateAvailable = val;
        }
      }
    }
    process.stdout.write(JSON.stringify(info));
  " 2>/dev/null || echo '{}')

  tools=$(echo "$hermes_json" | node -e "
    const arr = [];
    try { arr.push(JSON.parse(require('fs').readFileSync(0, 'utf8'))); } catch {}
    process.stdout.write(JSON.stringify(arr));
  ")
fi

# Detect WSL npm packages
wsl_npm_raw=$(wsl.exe -e sh -lc "command -v npm >/dev/null 2>&1 && npm list -g --depth=0 --json || true" 2>/dev/null | tr -d '\0' || true)

if [ -n "$wsl_npm_raw" ]; then
  wsl_pkgs=$(echo "$wsl_npm_raw" | node -e "
    const raw = require('fs').readFileSync(0, 'utf8');
    const start = raw.indexOf('{');
    const end = raw.lastIndexOf('}');
    if (start === -1 || end === -1) { process.stdout.write('[]'); return; }
    try {
      const data = JSON.parse(raw.substring(start, end + 1));
      const deps = data.dependencies || {};
      process.stdout.write(JSON.stringify(
        Object.entries(deps).map(([name, info]) => ({ name: name + ' (WSL)', version: info.version || null, source: 'wsl-npm' }))
      ));
    } catch { process.stdout.write('[]'); }
  " 2>/dev/null || echo '[]')

  tools=$(printf '%s\n%s' "$tools" "$wsl_pkgs" | node -e "
    let tools = [];
    let pkgs = [];
    const lines = require('fs').readFileSync(0, 'utf8').trim().split('\n');
    if (lines.length >= 1) try { tools = JSON.parse(lines[0]); } catch {}
    if (lines.length >= 2) try { pkgs = JSON.parse(lines[1]); } catch {}
    process.stdout.write(JSON.stringify(tools.concat(pkgs)));
  ")
fi

echo "{\"wsl_available\":true,\"tools\":$tools}"
