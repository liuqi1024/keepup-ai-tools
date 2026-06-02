#!/usr/bin/env bash
# scan-plugins.sh — 扫描 Claude Code Plugins
# 用法: bash scan-plugins.sh [--check-remote]
# 输出: JSON { "plugins": [...], "marketplaces": [...], "remoteInfo": {} }

set -euo pipefail

home="${HOME:-$(eval echo ~)}"

# Delegate all logic to node
node -e '
const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");
const home = process.argv[1];
const checkRemote = process.argv.includes("--check-remote");

const pluginsPath = path.join(home, ".claude/plugins/installed_plugins.json");
const mkPath = path.join(home, ".claude/plugins/known_marketplaces.json");

// Read installed plugins
let plugins = [];
if (fs.existsSync(pluginsPath)) {
  try {
    const raw = JSON.parse(fs.readFileSync(pluginsPath, "utf8"));
    const pluginsObj = raw.plugins || {};
    for (const [key, installs] of Object.entries(pluginsObj)) {
      if (!Array.isArray(installs) || installs.length === 0) continue;
      const inst = installs[0];
      const parts = key.split("@");
      plugins.push({
        name: parts[0],
        marketplace: parts.slice(1).join("@") || null,
        version: inst.version || null,
        gitCommitSha: inst.gitCommitSha || null
      });
    }
  } catch {}
}

// Read known marketplaces
let marketplaces = [];
if (fs.existsSync(mkPath)) {
  try {
    const data = JSON.parse(fs.readFileSync(mkPath, "utf8"));
    marketplaces = Object.entries(data).map(([name, info]) => ({
      name,
      path: info.installLocation || info.path || null,
      repo: info.source?.repo || info.gitUrl || info.url || null
    }));
  } catch {}
}

// Check remote updates via git fetch
const remoteInfo = {};
if (checkRemote && marketplaces.length > 0) {
  for (const mk of marketplaces) {
    if (!mk.path) continue;
    const expanded = mk.path.replace(/^~/, home);
    if (!fs.existsSync(expanded)) continue;

    try {
      // Get default branch
      const headOutput = execSync(
        "git remote show origin",
        { cwd: expanded, encoding: "utf8", stdio: ["pipe","pipe","pipe"] }
      );
      const branchMatch = headOutput.match(/HEAD branch:\s*(\S+)/);
      const branch = branchMatch ? branchMatch[1] : "main";

      // Fetch latest
      execSync(
        "git fetch origin",
        { cwd: expanded, encoding: "utf8", stdio: ["pipe","pipe","pipe"] }
      );

      // Get remote HEAD SHA
      const sha = execSync(
        `git rev-parse origin/${branch}`,
        { cwd: expanded, encoding: "utf8", stdio: ["pipe","pipe","pipe"] }
      ).trim();

      remoteInfo[mk.name] = { path: expanded, branch, latestSha: sha, error: null };
    } catch (e) {
      remoteInfo[mk.name] = { path: expanded, latestSha: null, error: String(e.message || e).slice(0, 200) };
    }
  }
}

process.stdout.write(JSON.stringify({ plugins, marketplaces, remoteInfo }));
' -- "$home" "$@"
