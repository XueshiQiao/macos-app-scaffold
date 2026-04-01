# macos-app-scaffold

[English](README.md) | [日本語](README_JA.md) | [Deutsch](README_DE.md)

用于创建和增强生产级 macOS 应用的 AI Agent Skill。支持 Claude Code、Cursor、Codex、Gemini 等 40+ AI 编程助手。

从多个已上架的 macOS 应用中提取的真实模式，涵盖 XcodeGen、GitHub Actions、SwiftUI 和 Apple 公证。

## 支持的能力

所有功能均为交互式 — 按需选择，无需全选。

**项目初始化**
- 从零创建新的 macOS 应用（菜单栏 / 窗口 / 混合模式）
- XcodeGen（`project.yml`）作为唯一配置源
- 开箱即用的 SwiftUI 启动代码
- Git 初始化 + 标准 `.gitignore`
- `AGENTS.md` + `CLAUDE.md` 符号链接，支持多 Agent 工作流

**构建与分发**
- GitHub Actions CI/CD（构建、签名、公证、DMG、发布）
- 通用二进制（arm64 + x86_64）
- 代码签名 & Apple 公证（可选 — 没有 Apple 开发者账号也能用）
- 推送 `v*` 标签自动创建 GitHub Release
- 多语言 Release Notes（英文、中文、日语、德语等）
- Homebrew Cask 公式

**应用功能**
- 自动更新（GitHub API 轮询 或 Sparkle）
- 开机自启（`SMAppService`）
- 辅助功能权限引导
- 设置 / 偏好设置窗口
- 文件日志（`~/Library/Logs/<AppName>.log`）
- 本地化（多语言）
- 分析（Aptabase，隐私友好）
- 引导页 / 欢迎窗口

**代码质量**
- SwiftLint 配置（合理的默认规则）
- 单元测试 Target（XCTest）
- App Sandbox 开关（附 App Store 上架说明）

**许可证与文档**
- LICENSE 文件（MIT / GPL-3.0 / Apache-2.0）
- README.md 带徽章（构建状态、macOS 版本、许可证）

## 快速开始

```
/macos-app-scaffold
```

就这么简单。Skill 会自动检测你当前是否在一个已有项目中，然后引导你进入对应的流程。

也可以直接指定：

```
/macos-app-scaffold new MyApp              # 创建新应用
/macos-app-scaffold enhance                # 为现有项目添加功能
```

## Skills

###  `/macos-app-scaffold` — 入口（自动路由）

检测当前上下文并提问：
- **检测到已有项目** → 引导添加功能（CI/CD、自动更新、日志等）
- **未检测到项目** → 进入新应用创建向导

### `/macos-app-scaffold-new` — 创建新项目

交互式向导，引导你完成应用名称、类型、功能和 CI/CD 选项，然后一键生成所有文件。

```
/macos-app-scaffold-new MyApp me.xueshi.myapp
```

### `/macos-app-scaffold-enhance` — 为已有项目添加功能

分析当前项目，展示已有功能，让你按需添加缺失的部分：

```
/macos-app-scaffold-enhance                  # 完整分析 + 选择功能
/macos-app-scaffold-enhance ci-cd            # 直接添加 CI/CD
/macos-app-scaffold-enhance auto-update      # 直接添加自动更新
/macos-app-scaffold-enhance logging          # 直接添加文件日志
```

## 安装

### 通用安装（支持 Claude Code、Cursor、Codex、Gemini 等 40+ AI 编程助手）

```bash
npx skills add XueshiQiao/macos-app-scaffold
```

### 仅 Claude Code

```
/plugin install github:XueshiQiao/macos-app-scaffold
```

### 手动安装

```bash
git clone https://github.com/XueshiQiao/macos-app-scaffold.git
cp -r macos-app-scaffold/skills/* ~/.claude/skills/
```

安装后，可用以下命令调用：

```
/macos-app-scaffold              # 入口（自动路由）
/macos-app-scaffold-new          # 创建新项目
/macos-app-scaffold-enhance      # 增强已有项目
```

## 生成的文件结构

```
MyApp/
├── .git/
├── .gitignore
├── project.yml                    # XcodeGen 配置（唯一配置源）
├── MyApp/
│   ├── Sources/
│   │   ├── MyAppApp.swift         # @main 入口
│   │   ├── ContentView.swift      # 主窗口（窗口模式）
│   │   ├── MenuBarView.swift      # 菜单栏 UI（菜单栏模式）
│   │   ├── SettingsView.swift     # 偏好设置窗口
│   │   ├── AppDelegate.swift      # 应用生命周期
│   │   ├── FileLog.swift          # 日志工具
│   │   └── ...                    # 其他所选功能
│   ├── Resources/
│   │   └── MyApp.entitlements
│   └── Assets.xcassets/
├── .github/workflows/
│   └── build.yml                  # CI/CD 流水线
├── AGENTS.md                      # AI Agent 约定
├── CLAUDE.md → AGENTS.md          # 符号链接
├── LICENSE
└── README.md
```

## CI/CD 流水线

生成的 GitHub Actions 工作流支持：

- 构建通用二进制（arm64 + x86_64）
- Developer ID 证书签名（可选 — 没有 Apple 开发者账号也能用）
- 创建带拖拽安装的 DMG
- Apple 公证（可选）
- 装订公证凭据（可选）
- 推送 `v*` 标签时自动创建 GitHub Release

### 所需 GitHub Secrets（如果有 Apple 开发者账号）

| Secret | 说明 |
|--------|------|
| `MAC_CERTS_P12_BASE64` | Base64 编码的 Developer ID Application 证书 |
| `MAC_CERTS_P12_PASSWORD` | .p12 文件的密码 |
| `APPLE_ID` | 用于公证的 Apple ID 邮箱 |
| `APPLE_TEAM_ID` | Apple 开发者团队 ID |
| `APP_SPECIFIC_PASSWORD` | 用于公证的 App 专用密码 |

如果没有 Apple 开发者账号，流水线会构建未签名的 DMG — 仍然可以正常分发使用。

## 默认配置

| 配置项 | 默认值 |
|--------|--------|
| Swift | 6.0 |
| macOS | 14.0+ |
| UI | SwiftUI |
| 沙箱 | 否（用户选择） |
| 架构 | Universal（arm64 + x86_64） |
| 构建系统 | XcodeGen |

## 许可证

MIT
