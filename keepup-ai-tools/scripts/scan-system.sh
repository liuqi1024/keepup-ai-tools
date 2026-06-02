#!/usr/bin/env bash
# scan-system.sh — System-level AI CLI tool and package manager detection
# Output: JSON { "cliTools": [...], "packageManagers": {...} }

set -euo pipefail

# Collect all data as tab-delimited lines, parse in node
{
  # --- Probe known AI CLI tools (not typically installed via npm/pipx) ---
  for cmd in ollama q gemini sg fabric llm jan lms tabby aider; do
    path=$(command -v "$cmd" 2>/dev/null || true)
    [ -z "$path" ] && continue
    ver=$("$cmd" --version 2>&1 | tr -d '\0' | tr '\n' ' ' | head -c 300 || true)
    printf 'PROBE\t%s\t%s\t%s\n' "$cmd" "$path" "$ver"
  done

  # --- Homebrew (macOS / Linux) ---
  if command -v brew &>/dev/null; then
    printf 'PM\tbrew\tyes\n'
    brew list --formula --versions 2>/dev/null | while IFS= read -r line; do
      [ -n "$line" ] && printf 'BREW\t%s\n' "$line"
    done
  else
    printf 'PM\tbrew\tno\n'
  fi

  # --- winget (Windows) ---
  if command -v winget.exe &>/dev/null; then
    printf 'PM\twinget\tyes\n'
    winget.exe list --accept-source-agreements --disable-interactivity 2>/dev/null | tr -d '\0' | grep -v '^[[:space:]]*$' | grep -E '^[A-Za-z一-鿿]|^[-─]+' | while IFS= read -r line; do
      printf 'WINGET\t%s\n' "$line"
    done
  else
    printf 'PM\twinget\tno\n'
  fi

  # --- scoop (Windows) ---
  if command -v scoop &>/dev/null; then
    printf 'PM\tscoop\tyes\n'
    scoop list 2>/dev/null | tr -d '\0' | while IFS= read -r line; do
      [ -n "$line" ] && printf 'SCOOP\t%s\n' "$line"
    done
  else
    printf 'PM\tscoop\tno\n'
  fi

  # --- cargo (Rust, cross-platform) ---
  if command -v cargo &>/dev/null; then
    printf 'PM\tcargo\tyes\n'
    cargo install --list 2>/dev/null | tr -d '\0' | while IFS= read -r line; do
      [ -n "$line" ] && printf 'CARGO\t%s\n' "$line"
    done
  else
    printf 'PM\tcargo\tno\n'
  fi

  # --- go (cross-platform) ---
  if command -v go &>/dev/null; then
    printf 'PM\tgo\tyes\n'
    gopath=$(go env GOPATH 2>/dev/null || true)
    if [ -n "$gopath" ] && [ -d "$gopath/bin" ]; then
      ls -1 "$gopath/bin" 2>/dev/null | while IFS= read -r line; do
        [ -n "$line" ] && printf 'GOBIN\t%s\n' "$line"
      done
    fi
  else
    printf 'PM\tgo\tno\n'
  fi

} | node -e "
const raw = require('fs').readFileSync(0, 'utf8');
const lines = raw.split('\n');
const cliTools = [];
const pm = {};
const sections = { brew: [], winget: [], scoop: [], cargo: [], go: [] };

for (const line of lines) {
  if (!line.trim()) continue;
  const parts = line.split('\t');
  const type = parts[0];

  // CLI tool probe result
  if (type === 'PROBE') {
    const cmd = parts[1];
    const path = parts[2];
    const verRaw = parts.slice(3).join('\t');
    let version = null;
    const clean = verRaw.replace(/active code page:\s*\d+/gi, '').trim();
    const m = clean.match(/v?(\d+\.\d+[\d.]*)/);
    if (m) version = m[1];
    cliTools.push({ name: cmd, command: cmd, version, path });
  }

  // Package manager availability
  if (type === 'PM') {
    pm[parts[1]] = { available: parts[2] === 'yes' };
  }

  // Brew packages: 'name version1 version2 ...'
  if (type === 'BREW') {
    const p = parts[1]?.trim();
    if (p) {
      const sp = p.split(/\s+/);
      sections.brew.push({ name: sp[0], version: sp.slice(1).join(' ') });
    }
  }

  // Winget raw output — filter progress bars and ANSI noise
  if (type === 'WINGET') {
    const raw = parts.slice(1).join('\t').replace(/[\r\0█▒]/g, '').trim();
    // Keep only lines that look like actual data (name/id/version or separator)
    if (raw && /^[A-Za-z一-鿿─\-]/.test(raw) && !raw.includes('KB /') && !raw.includes('│')) {
      sections.winget.push(raw);
    }
  }

  // Scoop raw output
  if (type === 'SCOOP') {
    sections.scoop.push(parts.slice(1).join('\t'));
  }

  // Cargo packages: 'name v1.2.3'
  if (type === 'CARGO') {
    const p = parts[1]?.trim();
    if (p) {
      const m = p.match(/^(\S+)\s+v([\d.]+)/);
      if (m) sections.cargo.push({ name: m[1], version: m[2] });
    }
  }

  // Go binaries (just names)
  if (type === 'GOBIN') {
    const name = parts[1]?.trim();
    if (name) sections.go.push(name);
  }
}

// Attach parsed data to package managers
if (pm.brew?.available && sections.brew.length > 0) pm.brew.packages = sections.brew;
if (pm.winget?.available && sections.winget.length > 0) pm.winget.raw = sections.winget.join('\n');
if (pm.scoop?.available && sections.scoop.length > 0) pm.scoop.raw = sections.scoop.join('\n');
if (pm.cargo?.available && sections.cargo.length > 0) pm.cargo.packages = sections.cargo;
if (pm.go?.available && sections.go.length > 0) pm.go.packages = sections.go;

process.stdout.write(JSON.stringify({ cliTools, packageManagers: pm }));
"
