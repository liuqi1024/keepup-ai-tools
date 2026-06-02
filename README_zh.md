# keepup-ai-tools

[English](README.md) | **中文**

> 一键检查并更新所有 AI Agent CLI 工具、Skills 和 Plugins。

跨 Agent [Skill](https://code.claude.com/docs/en/skills)，支持 **Claude Code、Codex、Hermes** 及任何支持 SKILL.md 格式的 Agent。通过 `npx skills add` 一次安装，所有 Agent 通用。

自动发现本机所有工具——npm/pipx/Homebrew/winget 安装的 CLI、Agent Skills（npx skills）、Claude Code Plugins——检查更新，一键完成。

**自动发现，零配置。** 不硬编码工具列表，装了什么就发现什么。

## 检测范围

| 数据源 | 检测方式 | 适用平台 |
|--------|---------|---------|
| npm 全局包 | `npm list -g` + `npm outdated` | 全平台 |
| pipx 工具 | `pipx list` | 全平台 |
| Homebrew formulae | `brew list` | macOS / Linux |
| winget 包 | `winget list` | Windows |
| scoop 包 | `scoop list` | Windows |
| cargo / go 二进制 | `cargo install --list` / `go env GOPATH` | 全平台 |
| AI CLI 工具（ollama、gemini 等） | PATH 探测（`command -v`） | 全平台 |
| WSL 工具（Hermes 等） | `wsl.exe` | Windows |
| Agent Skills | `~/.agents/.skill-lock.json` | 全平台 |
| Claude Code Skills | `npx skills check` | 全平台 |
| Claude Code Plugins | `~/.claude/plugins/`（git SHA 对比） | 全平台 |
| Codex / Hermes skills | 目录扫描 | 全平台 |

## 快速开始

```bash
# 从 GitHub 安装（推荐）
npx skills add liuqi1024/keepup-ai-tools -g -y

# 或：项目级安装（试用）
cp -r keepup-ai-tools .claude/skills/
```

<img src="docs/install-demo.png" alt="安装演示" width="600">

安装后在 Claude Code 中直接说：

| 指令 | 效果 |
|------|------|
| "检查更新" / "check updates" | 扫描所有工具，报告哪些有新版本 |
| "更新全部" / "update all" | 列出待更新项，确认后执行更新 |
| "工具状态" / "tool status" | 离线快照，不访问网络，速度最快 |
| "重置配置" / "reset config" | 重新运行环境检测（OS、代理、WSL） |

首次运行会自动检测操作系统，并询问是否需要配置代理。

## 示例输出

```
## 🔍 工具链更新检查报告

### CLI 工具
| 工具 | 当前版本 | 最新版本 | 状态 | 更新命令 |
|------|---------|---------|------|---------|
| Claude Code | 2.1.133 | 2.1.140 | 🔺可更新 | `npm update -g @anthropic-ai/claude-code` |
| Codex CLI | 0.134.0 | — | ✅最新 | — |
| Ollama | 0.5.0 | — | ✅最新 | — |

### Agent Skills（按来源分组）
| 来源 | 类型 | Skills 数量 | 状态 | 更新命令 |
|------|------|------------|------|---------|
| user/example-skill | GitHub | 1 | 🔺有变化 | `npx skills add user/example-skill -g -y` |

### Claude Code Plugins
| Plugin | Marketplace | 当前 SHA | 最新 SHA | 状态 |
|--------|-------------|---------|---------|------|
| superpowers | example-marketplace | abc1234 | abc1234 | ✅最新 |

---
> 📊 总计：2 项可更新 | 3 项最新 | 0 项检查失败
> 💡 回复"更新全部"来执行更新
```

## 首次配置

首次运行时，Skill 会自动检测你的环境并询问：

1. **代理**：是否需要为 GitHub/npm 配置代理？（中国大陆常见需求）
2. **WSL**（仅 Windows）：是否需要为 WSL 工具配置代理？

设置保存在 `~/.handy-tools-update.json`，删除该文件可重新配置。

### WSL 代理说明

WSL 无法直接访问宿主机的 `127.0.0.1`。Skill 会自动检测网关 IP：

```bash
wsl.exe -e sh -lc "ip route | grep default | awk '{print \$3}'"
# → 172.x.x.1
```

## 支持的工具

以下工具具有专用更新命令，但**扫描器发现的所有工具都会被报告**——不限于这些：

| 工具 | 安装来源 | 更新方式 |
|------|---------|---------|
| `claude` | npm: `@anthropic-ai/claude-code` | `npm update -g` |
| `codex` | npm: `@openai/codex` / winget | `npm update -g` / `winget upgrade` |
| `lark-cli` | npm: `@larksuite/cli` | `lark-cli update` |
| `mo` | npm: `@mowenxd/cli` | `npm update -g` |
| `hermes` | WSL / git | `git pull --ff-only` |
| `aider` | pipx: `aider-chat` | `pipx upgrade` |
| `ollama` | brew / 独立安装 | `brew upgrade` |
| `gemini` | npm | `npm update -g` |
| `cursor` | winget / 独立安装 | `winget upgrade` |
| `fabric` | go install / pipx | `go install` / `pipx upgrade` |

## 安全性

- **绝不静默自动更新** — 始终展示待更新内容，等待用户确认
- **无外部依赖** — 仅需 `bash` 和 `node`（用于 JSON 解析）
- **网络调用均为只读** — `npm outdated`、`git fetch`、`git ls-remote`
- **不收集凭据** — 不存储或传输 API 密钥、Token 或密码

## 文件结构

```
keepup-ai-tools/
├── SKILL.md                  # Skill 定义（自然语言指令）
├── README.md                 # 英文说明
├── README_zh.md              # 中文说明
└── scripts/
    ├── scan-npm.sh           # npm 全局包 + 过期检查
    ├── scan-wsl.sh           # WSL 工具检测（Hermes 等）
    ├── scan-skills.sh        # Skills 锁文件 + 目录扫描
    ├── scan-plugins.sh       # Claude Code Plugins 扫描
    └── scan-system.sh        # 系统 AI CLI + 包管理器（brew/winget/cargo/go）
```

## 贡献

欢迎提交 Issue 和 PR：[github.com/liuqi1024/keepup-ai-tools](https://github.com/liuqi1024/keepup-ai-tools)

## 许可证

MIT
