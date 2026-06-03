---
name: keepup-ai-tools
version: 1.0.2
description: >-
  Cross-agent skill: one-command check & update for all AI CLI tools, Skills and Plugins.
  Works with Claude Code, Codex, Hermes, and any agent that supports SKILL.md.
  Auto-discovers npm/pipx/brew/winget/cargo/go tools, Agent Skills (npx skills),
  Claude Code Plugins. Detects available updates and applies them.
  First run auto-detects OS, proxy, and WSL environment.
  Triggers: check updates, update tools, update CLI, update skills, update all,
  check versions, tool versions, keepup, skill update, ai tools update,
  检查更新, 工具更新, 版本检查, 更新全部, 技能更新.
---

# KeepUp AI Tools — Cross-Agent AI Toolchain Update

**Works with Claude Code, Codex, Hermes, and any agent that supports the SKILL.md format.**

Install once via `npx skills add`, automatically available in all your agents.

自动发现并检查用户本地安装的所有 AI Agent CLI 工具、Skills 和 Plugins 的更新状态。

## 核心理念：自动发现，不硬编码

本 Skill 不预设"应该安装了哪些工具"，而是通过探测策略自动发现用户环境中的所有工具。支持 Windows、macOS、Linux（含 WSL）。

---

## 首次使用：环境检测与配置

**首次运行任何工作流时，先检查配置文件是否存在。**

配置文件路径：`~/.handy-tools-update.json`

如果配置文件不存在，**必须先执行环境检测并引导用户完成配置**，然后再进入正常工作流。

### 环境检测步骤

#### 步骤 1：自动检测运行环境

```bash
# 检测 OS
uname_output=$(uname -a 2>/dev/null || ver 2>/dev/null || echo "unknown")

# 检测 WSL 可用性（仅 Windows）
wsl_available=false
if command -v wsl.exe &>/dev/null; then
  if wsl.exe -e sh -lc "echo ok" 2>/dev/null | grep -q "ok"; then
    wsl_available=true
  fi
fi
```

从 `uname_output` 判断平台：
- 包含 `MINGW` 或 `MSYS` 或 `Windows` → `windows`
- 包含 `Darwin` → `macos`
- 包含 `Linux` → `linux`

#### 步骤 2：交互式收集用户配置

使用 AskUserQuestion 工具，依次询问以下信息：

**问题 1：网络代理**
> "你是否需要通过代理访问外网（如 GitHub、npm registry）？如果需要，请提供代理地址（如 http://127.0.0.1:7890）。"

- 选项：不需要代理 / 需要代理
- 如果选择"需要代理"，追问代理地址（默认 `http://127.0.0.1:7890`）

**问题 2：WSL 使用（仅 Windows 且检测到 WSL 可用时）**
> "检测到你使用 WSL。WSL 中的工具（如 Hermes）更新时需要代理访问 GitHub，是否需要为 WSL 配置代理？"

- 选项：需要 / 不需要 / WSL 中没有需要代理的工具

#### 步骤 3：自动检测 WSL 代理地址

如果用户需要 WSL 代理，**自动检测 Windows 宿主机 IP**：

```bash
# 方法 1：通过 ip route 获取默认网关
wsl_gateway=$(wsl.exe -e sh -lc "ip route | grep default | awk '{print \$3}'" 2>/dev/null | tr -d '\r\0')

# 方法 2（备选）：通过 hostname.local
if [ -z "$wsl_gateway" ]; then
  win_hostname=$(hostname)
  wsl_gateway="$win_hostname.local"
fi
```

用检测到的网关 IP 替换代理地址中的 `127.0.0.1`，例如：
- 用户代理：`http://127.0.0.1:7890`
- WSL 代理：`http://172.x.x.x:7897`（网关 IP）

#### 步骤 4：保存配置

将配置写入 `~/.handy-tools-update.json`：

```json
{
  "platform": "windows",
  "proxy": {
    "enabled": true,
    "address": "http://127.0.0.1:7890"
  },
  "wsl": {
    "available": true,
    "proxyEnabled": true,
    "proxyAddress": "http://172.x.x.x:7897"
  }
}
```

macOS/Linux 示例：

```json
{
  "platform": "macos",
  "proxy": {
    "enabled": false,
    "address": null
  },
  "wsl": {
    "available": false
  }
}
```

保存后告知用户："配置已保存到 ~/.handy-tools-update.json，后续使用将自动读取。如需修改，删除该文件后重新运行即可。"

### 配置文件读取规则

所有工作流开始时：
1. 读取 `~/.handy-tools-update.json`
2. 如果文件不存在或 JSON 无效 → 进入首次使用配置流程
3. 从配置中提取 `proxy.address`、`wsl.proxyAddress` 等参数
4. 用配置值替换下面所有工作流中的代理占位符 `{proxy}`

---

## 辅助脚本

本 Skill 包含 5 个辅助脚本，位于 `scripts/` 目录下，用于精确采集数据。Claude 应调用这些脚本而非直接运行底层命令。

| 脚本 | 用途 | 输出 |
|------|------|------|
| `scripts/scan-npm.sh [--with-outdated]` | 扫描 npm 全局包及可用更新 | `{ installed: {name: {version, path, latest?}}, outdated: {...} }` |
| `scripts/scan-wsl.sh` | 探测 WSL 工具（Hermes + WSL npm） | `{ wsl_available, tools: [{name, version, project?, updateAvailable?}] }` |
| `scripts/scan-skills.sh` | 扫描 Skills 锁文件和目录 | `{ lock: {source: {sourceType, skills[], updatedAt}}, directories: {path: count} }` |
| `scripts/scan-plugins.sh [--check-remote]` | 扫描 Claude Code Plugins | `{ plugins: [{name, version, gitCommitSha, marketplace}], marketplaces: [...] }` |
| `scripts/scan-system.sh` | 系统级检测：包管理器 + AI CLI 探测 | `{ cliTools: [...], packageManagers: {...} }` |

调用方式：`bash {SKILL_DIR}/scripts/scan-xxx.sh`。`{SKILL_DIR}` 是本 SKILL.md 所在目录的绝对路径。

## 数据源定义

### 探测目标

| 探测项 | 检测方式 | 适用平台 |
|--------|---------|---------|
| npm 全局 CLI | `scripts/scan-npm.sh --with-outdated` | 全平台 |
| WSL 工具 | `scripts/scan-wsl.sh` | 仅 Windows |
| Agent Skills | `scripts/scan-skills.sh` | 全平台 |
| Claude Code Plugins | `scripts/scan-plugins.sh --check-remote` | 全平台 |
| pipx 工具 | `pipx list --json`（如果 pipx 可用） | 全平台 |
| 系统 AI CLI + 包管理器 | `scripts/scan-system.sh` | 全平台 |

### 已知 CLI 工具的版本检测命令

以下列表用于识别常见的 AI Agent CLI，但不是硬性要求——即使某个工具不在列表中，只要它出现在扫描结果中就会被报告。

| CLI 命令 | 常见安装方式 | 更新方式 |
|----------|-------------|---------|
| `claude` / `claude-code` | npm: `@anthropic-ai/claude-code` | npm update |
| `codex` | npm: `@openai/codex` 或 MSIX (Windows) | npm update / winget upgrade |
| `lark-cli` / `lark` | npm: `@larksuite/cli` | `lark-cli update` |
| `mocli` / `mo` | npm: `@mowenxd/cli` | npm update |
| `hermes` | WSL/git 安装 | git pull --ff-only |
| `aider` | pipx: `aider-chat` | pipx upgrade |
| `ollama` | brew / direct download | `brew upgrade` / 手动下载 |
| `q` (Amazon Q) | direct download | `q update` |
| `gemini` | npm / direct | npm update |
| `cursor` | winget / direct (自动更新) | winget upgrade / 自动 |
| `fabric` | go install / pipx | `go install` / pipx upgrade |
| `llm` (simonw) | pipx / brew | pipx upgrade / brew upgrade |
| `sg` (Sourcegraph Cody) | npm / direct | npm update |
| `jan` | brew / AppImage | brew upgrade / 手动 |
| `lms` (LM Studio) | direct download | 手动 |

### winget/scoop 输出中识别 AI 相关工具

winget 和 scoop 的输出包含所有已安装软件（可能数百项）。Claude 应只报告以下类别中的工具：

**AI/开发相关关键词**（用于过滤）：
- AI Agent CLI：claude、codex、ollama、gemini、q、cursor、aider、copilot、cody、jan、lm-studio、trae、千问、豆包、飞书
- 开发工具：docker、git、node.js、python、anaconda、java、typora、notepad++
- 通讯/办公：feishu、wechat、lark、dingtalk、腾讯会议

在报告中将匹配的工具标记来源为 `winget` 或 `scoop`，并标注可更新的版本。

---

## 工作流 1：全量检查（check）

**触发**：用户说"检查更新"、"check updates"、"版本检查"等

### 前置步骤：读取配置

读取 `~/.handy-tools-update.json`。如不存在，先执行"首次使用配置"流程。

从配置中提取：
- `{proxy}` = `proxy.address`（如 `http://127.0.0.1:7890`），如果 `proxy.enabled` 为 false 则为空
- `{wsl_proxy}` = `wsl.proxyAddress`，如果 `wsl.proxyEnabled` 为 false 则为空

### 步骤 1：自动发现已安装的 CLI 工具

**并行执行以下探测**（失败的跳过，不阻塞）：

```bash
# npm 全局包 + 可用更新（需要网络）
{ if [ -n "{proxy}" ]; then export http_proxy="{proxy}" && export https_proxy="{proxy}"; fi; }
bash {SKILL_DIR}/scripts/scan-npm.sh --with-outdated

# pipx 工具列表（如果 pipx 可用）
pipx list --json 2>/dev/null

# 系统 AI CLI 探测 + 包管理器扫描（winget/brew/scoop/cargo/go）
bash {SKILL_DIR}/scripts/scan-system.sh
```

从脚本的 JSON 输出中解析每个包的 `version`、`latest`（如有）、`updateAvailable`。对有特殊更新命令的工具（如 `lark-cli update`），优先使用特殊命令。

**scan-system.sh 结果处理**：
- `cliTools` 数组：通过 `command -v` 探测到的 AI CLI 工具（ollama、gemini 等）
- `packageManagers`：可用的包管理器及其安装的包列表
  - `brew.packages`：结构化数组 `{name, version}`
  - `winget.raw`：winget 原始文本输出，需要按"winget/scoop 输出中识别 AI 相关工具"规则过滤
  - `scoop.raw`：scoop 原始文本输出
  - `cargo.packages`：结构化数组 `{name, version}`
  - `go.packages`：Go bin 名称列表
- **去重规则**：如果工具同时出现在 npm 和 scan-system 结果中，优先使用 npm 来源的数据（npm 版本和更新信息更准确）

### 步骤 2：WSL 工具探测（仅 Windows 且 wsl.available）

```bash
bash {SKILL_DIR}/scripts/scan-wsl.sh
```

脚本自动检测 WSL 可用性、Hermes 版本和更新状态、WSL npm 全局包。输出 JSON：
- `wsl_available`: WSL 是否可用
- `tools`: 数组，每个元素含 `name`、`version`、`project`（Hermes 项目路径）、`updateAvailable`

如果 `wsl_available` 为 false，跳过整个 WSL 部分。

### 步骤 3：Skills 状态检查

```bash
bash {SKILL_DIR}/scripts/scan-skills.sh
```

脚本读取 `~/.agents/.skill-lock.json`，按来源分组统计 skills 数量和最后更新时间，并扫描各 skills 目录。输出 JSON：
- `lock`: 按来源分组，每组含 `sourceType`、`skills[]`、`updatedAt`
- `directories`: 各 skills 目录路径及其 skill 数量

如需检查 GitHub 来源的远程变化，对每个来源额外运行：
```bash
{ if [ -n "{proxy}" ]; then export http_proxy="{proxy}" && export https_proxy="{proxy}"; fi; }
git ls-remote https://github.com/{source}.git HEAD
```

### 步骤 4：Claude Code Plugin 更新检查

```bash
bash {SKILL_DIR}/scripts/scan-plugins.sh --check-remote
```

脚本读取 `installed_plugins.json` 和 `known_marketplaces.json`。如传 `--check-remote`，还会对每个 marketplace 执行 `git fetch` 并获取远程最新 SHA。

比较每个插件的 `gitCommitSha` 与 marketplace 远程最新 SHA：
- 完全匹配 → ✅最新
- 不匹配 → 🔺可更新

如需手动检查 marketplace 远程 SHA：
```bash
{ if [ -n "{proxy}" ]; then export http_proxy="{proxy}" && export https_proxy="{proxy}"; fi; }
cd ~/.claude/plugins/marketplaces/{name}
git fetch origin
git remote show origin | grep 'HEAD branch' | awk '{print $NF}'
git rev-parse origin/{branch}
```

### 步骤 5：输出汇总报告

以 Markdown 表格格式输出（只输出实际发现的项，未安装的工具不显示）：

```
## 🔍 工具链更新检查报告

### CLI 工具

| 工具 | 当前版本 | 最新版本 | 状态 | 更新命令 |
|------|---------|---------|------|---------|
| Claude Code | 2.1.133 | 2.1.140 | 🔺可更新 | `npm update -g @anthropic-ai/claude-code` |
| Codex CLI | 0.134.0 | — | ✅最新 | — |

### WSL 工具

| 工具 | 当前版本 | 状态 | 更新命令 |
|------|---------|------|---------|
| Hermes | x.y.z | 🔺可更新 | `wsl.exe -e sh -lc "export http_proxy={wsl_proxy} && cd {path} && git pull --ff-only"` |

### Agent Skills（按来源分组）

| 来源 | 类型 | Skills 数量 | 远程状态 | 更新命令 |
|------|------|------------|---------|---------|
| user/example-skill | GitHub | 1 | 🔺有变化 | `npx skills add user/example-skill -g -y` |
| skills.example.com | Well-known | 26 | ⚠️无法检测 | `npx skills add https://skills.example.com -g -y` |

### Claude Code Plugins

| Plugin | Marketplace | 当前 SHA | 远程 SHA | 状态 |
|--------|-------------|---------|---------|------|
| superpowers | example-marketplace | abc1234 | abc1234 | ✅最新 |

### Skills 目录概览

| 目录 | Skills 数量 |
|------|-----------|
| ~/.agents/skills/ | 41 |
| ~/.claude/skills/ | 38 |
| ~/.codex/skills/ | 5 |

---
> 📊 总计：X 项可更新 | Y 项最新 | Z 项检查失败
> 💡 回复"更新全部"或"只更新 X"来执行更新
```

---

## 工作流 2：执行更新（update）

**触发**：用户确认要更新（说"更新全部"、"update all"、"只更新 Claude Code"等）

### 关键规则

**始终先列出将要更新的内容，获得用户确认后再执行。绝不静默自动更新。**

### 步骤

1. 先运行工作流 1 获取最新状态（如果还没有运行过）
2. 筛选出所有"可更新"的项，列出清单请用户确认
3. 根据用户选择（全部 / 指定项），按以下规则执行：

#### npm 全局包更新

```bash
{ if [ -n "{proxy}" ]; then export http_proxy="{proxy}" && export https_proxy="{proxy}"; fi; }
# Windows
npm.cmd update -g {package_name}
# macOS/Linux
npm update -g {package_name}
```

根据配置中的 `platform` 选择使用 `npm.cmd`（Windows）还是 `npm`（macOS/Linux）。

对有特殊更新命令的工具（如 `lark-cli update`），优先使用特殊命令。

#### WSL 工具更新

```bash
wsl.exe -e sh -lc "export http_proxy='{wsl_proxy}' && export https_proxy='{wsl_proxy}' && cd '{project_path}' && git pull --ff-only"
```

**重要**：WSL 中的 `127.0.0.1` 指向 WSL 自身，不是 Windows 宿主机。必须使用配置中自动检测的 `{wsl_proxy}`（网关 IP 或 `hostname.local`）。

从 `hermes --version` 输出中解析 `Project:` 行获取项目路径。

#### Agent Skills 更新

优先使用 `npx skills update` 官方命令。如果更新失败，回退到 `npx skills add` 逐个来源重装。

**方式 1（优先）：使用官方 update 命令**

```bash
{ if [ -n "{proxy}" ]; then export http_proxy="{proxy}" && export https_proxy="{proxy}"; fi; }
# Windows
npx.cmd skills update -g -y
# macOS/Linux
npx skills update -g -y
```

**方式 2（回退）：按来源逐个重新安装**

当 `npx skills update` 失败时，对每个来源单独执行：

```bash
{ if [ -n "{proxy}" ]; then export http_proxy="{proxy}" && export https_proxy="{proxy}"; fi; }
# GitHub 来源
# Windows
npx.cmd skills add {source} -g -y
# macOS/Linux
npx skills add {source} -g -y

# Well-known 来源（如飞书）
# Windows
npx.cmd skills add {sourceUrl} -g -y
# macOS/Linux
npx skills add {sourceUrl} -g -y
```

#### Claude Code Plugins 更新

```bash
{ if [ -n "{proxy}" ]; then export http_proxy="{proxy}" && export https_proxy="{proxy}"; fi; }
cd ~/.claude/plugins/marketplaces/{name}
git pull origin {branch}
```

更新后提示用户**重启 Claude Code** 以加载新版本。

#### pipx 工具更新

```bash
pipx upgrade {package_name}
```

#### 系统包管理器工具更新

根据工具来源选择对应的更新命令：

```bash
# Homebrew (macOS/Linux)
brew upgrade {package_name}

# winget (Windows)
winget.exe upgrade --id {package_id} --accept-source-agreements

# scoop (Windows)
scoop update {package_name}

# cargo (Rust)
cargo install {package_name} --quiet

# go
go install {package_path}@latest
```

对于检测到但无法确定更新方式的工具，标注"请手动检查更新"。

### 输出结果摘要

```
## ✅ 更新结果

| 类别 | 工具/来源 | 操作 | 结果 |
|------|----------|------|------|
| CLI | Claude Code | npm update -g ... | ✅成功 |
| CLI | Lark CLI | lark-cli update | ✅成功 |
| Skills | example-skill | npx skills add ... | ✅成功 |
| Plugin | frontend-design | git pull origin main | ✅成功 |

---
> 📊 更新完成：成功 N 个，失败 M 个
> 💡 如有 Plugin 更新，建议重启 Claude Code
```

---

## 工作流 3：快速状态（status）

**触发**：用户说"工具状态"、"tool status"等

纯本地操作，不访问网络，速度最快。

### 步骤

1. 自动发现已安装 CLI 工具：
   - 并行运行 `npm list -g --depth=0 --json` 和各个可用的 `--version` 命令
   - 检测 pipx（`pipx --version`）
   - 检测 WSL（`wsl.exe` 可用性）

2. 读取 Skills 锁文件（`~/.agents/.skill-lock.json`）：
   - 统计总数、按来源分组计数、最后更新时间

3. 读取 Plugin 信息（`~/.claude/plugins/installed_plugins.json`）：
   - 统计已安装数量

4. 扫描各 skills 目录统计数量

### 输出格式

```
## 📋 工具链状态快照

### CLI 工具
| 工具 | 版本 | 来源 |
|------|------|------|
| Claude Code | 2.1.133 | npm 全局 |
| Codex CLI | 0.134.0 | npm 全局 |

### Skills 概览
- 总计：X 个 skills（来自 ~/.agents/.skill-lock.json）
- 来源分布：GitHub Y 个 / Well-known Z 个
- 最后更新：{最近的 updatedAt}
- 目录分布：~/.agents/skills/ (41) | ~/.claude/skills/ (38) | ...

### Plugins 概览
- 已安装：N 个 plugins
- Marketplace：{名称列表}

> 💡 这是离线快照，不检查远程更新。回复"检查更新"获取最新可用版本。
```

---

## WSL 代理地址说明

WSL 中的网络代理地址与宿主机不同。`127.0.0.1` 在 WSL 中指向 WSL 自身，而非 Windows 宿主机。获取正确地址有两种方式：

**方式 1：通过默认网关（推荐）**
```bash
wsl.exe -e sh -lc "ip route | grep default | awk '{print \$3}'"
# 输出类似：172.x.x.1
```
然后代理地址为 `http://172.x.x.1:{port}`

**方式 2：通过 hostname.local**
```bash
# 在 Windows 中获取 hostname
hostname
# 假设输出 MY-PC
# WSL 中使用 MY-PC.local 作为主机地址
# 代理地址为 http://MY-PC.local:{port}
```

首次配置时自动检测并保存到配置文件。

---

## 通用规则

1. **自动发现优先**：不硬编码"应该安装了什么"，而是通过扫描命令和目录自动发现
2. **中文输出**：所有面向用户的文本使用中文
3. **配置驱动**：所有环境相关参数（代理、平台、WSL）从 `~/.handy-tools-update.json` 读取，不硬编码
4. **首次使用引导**：配置文件不存在时自动引导用户完成环境配置
5. **平台自适应**：
   - 根据配置中的 `platform` 选择命令：
     - Windows：`npm.cmd`、`npx.cmd`、`wsl.exe`
     - macOS/Linux：`npm`、`npx`
   - 自动检测平台（`uname -a` 或 `ver`）
6. **代理设置**：仅在 `proxy.enabled` 为 true 时设置代理环境变量。代理不通时标注"网络检查失败"，不阻塞其他检查
7. **WSL 代理**：WSL 内操作使用 `{wsl_proxy}`（自动检测的网关 IP），不使用宿主机的 `127.0.0.1`
8. **WSL 检测**：`wsl.exe` 不存在或失败时跳过，不报错
9. **容错**：任何命令失败时不中断流程，继续检查其他项，在报告中标注失败原因
10. **并行执行**：多个无依赖的检查命令应并行执行以提高速度
11. **npm outdated 解析**：输出为 JSON，key 是包名，value 含 `current`、`wanted`、`latest`
12. **版本输出清理**：忽略 `Active code page: 65001` 等无关行
13. **配置重置**：用户说"重置配置"、"重新配置"时，删除 `~/.handy-tools-update.json` 并重新引导配置流程
