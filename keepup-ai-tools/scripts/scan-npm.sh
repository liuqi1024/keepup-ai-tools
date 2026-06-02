#!/usr/bin/env bash
# scan-npm.sh — 扫描 npm 全局包，输出当前版本和可用更新
# 用法: bash scripts/scan-npm.sh [--with-outdated]
# 输出: JSON 对象 { "installed": {...}, "outdated": {...} }

set -euo pipefail

# Delegate everything to node — avoids shell variable interpolation issues on Windows
node -e '
const { execSync } = require("child_process");
const result = { installed: {}, outdated: {} };

// npm list
try {
  const raw = execSync("npm list -g --depth=0 --json", { encoding: "utf8", stdio: ["pipe","pipe","pipe"] });
  const data = JSON.parse(raw);
  const deps = data.dependencies || {};
  for (const [name, info] of Object.entries(deps)) {
    result.installed[name] = { version: info.version || null, path: info.path || null };
  }
} catch {}

// npm outdated (optional, needs network)
if (process.argv.includes("--with-outdated")) {
  try {
    const raw = execSync("npm outdated -g --json", { encoding: "utf8", stdio: ["pipe","pipe","pipe"] });
    const start = raw.indexOf("{");
    const end = raw.lastIndexOf("}");
    if (start !== -1 && end !== -1) {
      const data = JSON.parse(raw.substring(start, end + 1));
      for (const [name, info] of Object.entries(data)) {
        result.outdated[name] = {
          current: info.current || null,
          wanted: info.wanted || null,
          latest: info.latest || null
        };
      }
    }
  } catch {}
}

// Merge outdated info into installed
for (const [name, info] of Object.entries(result.installed)) {
  if (result.outdated[name]) {
    info.latest = result.outdated[name].latest;
    info.updateAvailable = true;
  }
}

process.stdout.write(JSON.stringify(result));
' -- "$@"
