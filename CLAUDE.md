# keepup-ai-tools

跨 Agent Skill，一键检查并更新所有 AI CLI 工具、Skills 和 Plugins。

## 项目结构

```
keepup-ai-tools/          # Skill 主目录（npx skills add 安装的就是这个）
├── SKILL.md              # Skill 定义（自然语言指令 + frontmatter）
└── scripts/
    ├── scan-npm.sh       # npm 全局包扫描
    ├── scan-system.sh    # 系统 AI CLI + 包管理器（brew/winget/scoop/cargo/go）
    ├── scan-skills.sh    # Agent Skills 锁文件 + 目录扫描
    ├── scan-plugins.sh   # Claude Code Plugins 扫描（含 --check-remote）
    └── scan-wsl.sh       # WSL 工具检测（Hermes 等）
```

根目录的 `README.md` / `README_zh.md` 是 GitHub 仓库首页，SKILL.md 是 Skill 唯一定义文件。

## 技术要点

- 所有 scan 脚本采用「单 node 调用 + execSync」模式，避免 shell 变量嵌入 JS 字符串（Windows 兼容）
- CI 使用 `defaults.run.shell: bash` 确保 Windows 上也用 bash 执行
- Plugin 远程检查通过 `git fetch` + `git rev-parse` 获取 marketplace 最新 SHA
- 首次运行引导用户配置 `~/.handy-tools-update.json`（平台、代理、WSL）

## 版本规范

- 版本号定义在 `keepup-ai-tools/SKILL.md` 的 frontmatter `version` 字段
- 小版本递增：1.0.x

## CI

- `.github/workflows/test.yml`：三平台（ubuntu/macos/windows）测试所有 scan 脚本的 JSON 输出
- actions 版本：checkout@v5, setup-node@v5, Node.js 22
- 需要 gh CLI 调试：`gh run watch <id> --repo liuqi1024/keepup-ai-tools`
