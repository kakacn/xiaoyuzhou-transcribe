# xiaoyuzhou-transcribe

Agent Skill：将小宇宙播客单集链接转为 Markdown 逐字稿（Groq Whisper），可选内容总结。

遵循 [Agent Skills 规范](https://agentskills.io/specification)，可用于 **OpenClaw**、**Cursor**、**Claude Code**、**Codex**、**OpenCode**、**GitHub Copilot** 等支持 skills 的 AI 工具。

仓库地址：https://github.com/kakacn/xiaoyuzhou-transcribe

## 首次配置（必做）

转写需要 **Groq API Key**（免费）：

1. 打开 [Groq Console](https://console.groq.com/keys) 注册/登录
2. 点击 **Create API Key**，复制 `gsk_` 开头的完整 Key
3. 配置 Key：

```bash
bash ~/.openclaw/skills/xiaoyuzhou-transcribe/scripts/configure.sh "gsk_你的Key"
# 或安装目录下的 scripts/configure.sh
```

4. 验证：

```bash
bash scripts/check.sh
# 应输出: OK: ffmpeg ready, Groq API key valid
```

> Key 保存在 `~/.xiaoyuzhou-transcribe/groq_api_key`，不会写入 skill 目录。

## 安装

### OpenClaw（推荐）

```bash
# 当前工作区
openclaw skills install git:kakacn/xiaoyuzhou-transcribe@main

# 全局（所有 agent 可用）
openclaw skills install git:kakacn/xiaoyuzhou-transcribe@main --global
```

验证：

```bash
openclaw skills list
```

安装后**新开一个会话**，对 OpenClaw 说：

```
帮我把这期小宇宙播客转成逐字稿 https://www.xiaoyuzhoufm.com/episode/EPISODE_ID
```

首次使用 Agent 会引导你配置 Groq API Key。

手动安装：

```bash
git clone https://github.com/kakacn/xiaoyuzhou-transcribe.git ~/.openclaw/skills/xiaoyuzhou-transcribe
chmod +x ~/.openclaw/skills/xiaoyuzhou-transcribe/scripts/*.sh
```

### Cursor / Claude Code / Codex（`npx skills`）

```bash
# 全局安装（所有支持的 agent）
npx skills add kakacn/xiaoyuzhou-transcribe -g -y

# 只装到 Cursor
npx skills add kakacn/xiaoyuzhou-transcribe -g -a cursor -y

# 只装到 Claude Code
npx skills add kakacn/xiaoyuzhou-transcribe -g -a claude-code -y
```

### GitHub CLI

```bash
gh skill install kakacn/xiaoyuzhou-transcribe xiaoyuzhou-transcribe --agent cursor --scope user
gh skill install kakacn/xiaoyuzhou-transcribe xiaoyuzhou-transcribe --agent claude-code --scope user
```

### curl 一键脚本

全部 agent（含 OpenClaw）：

```bash
curl -fsSL https://raw.githubusercontent.com/kakacn/xiaoyuzhou-transcribe/main/install.sh | bash -s -- --global --agent all -y
```

仅 OpenClaw：

```bash
curl -fsSL https://raw.githubusercontent.com/kakacn/xiaoyuzhou-transcribe/main/install.sh | bash -s -- --global --agent openclaw -y
```

仅 Cursor：

```bash
curl -fsSL https://raw.githubusercontent.com/kakacn/xiaoyuzhou-transcribe/main/install.sh | bash -s -- --global --agent cursor -y
```

### 手动 clone（通用）

| 工具 | 全局安装路径 |
|------|-------------|
| OpenClaw | `~/.openclaw/skills/xiaoyuzhou-transcribe` |
| Cursor | `~/.cursor/skills/xiaoyuzhou-transcribe` |
| Claude Code | `~/.claude/skills/xiaoyuzhou-transcribe` |
| Codex | `~/.codex/skills/xiaoyuzhou-transcribe` |
| OpenCode | `~/.opencode/skills/xiaoyuzhou-transcribe` |

项目级 OpenClaw：`./skills/xiaoyuzhou-transcribe`

```bash
git clone https://github.com/kakacn/xiaoyuzhou-transcribe.git ~/.openclaw/skills/xiaoyuzhou-transcribe
chmod +x ~/.openclaw/skills/xiaoyuzhou-transcribe/scripts/*.sh
```

## 使用

安装 skill 并配置 Groq Key 后，对 AI 说：

```
帮我把这期小宇宙播客转成逐字稿并总结核心内容
https://www.xiaoyuzhoufm.com/episode/6a1d7d39989e711d01e30345
```

直接运行脚本：

```bash
bash scripts/transcribe.sh "https://www.xiaoyuzhoufm.com/episode/EPISODE_ID" ./output.md
bash scripts/transcribe.sh --polish "EPISODE_URL"   # 额外用 Llama 补标点
```

## 目录结构

```
xiaoyuzhou-transcribe/
├── SKILL.md              # Agent 指令（必需）
├── README.md             # 本文件
├── reference.md          # 手动兜底参考
├── examples.md           # 使用示例
├── install.sh            # 多平台一键安装
├── LICENSE
└── scripts/
    ├── configure.sh      # 保存 Groq API Key
    ├── check.sh          # 检查依赖与 Key
    └── transcribe.sh     # 下载 + 转写 + 清理
```

## 依赖与限制

- 需要 `ffmpeg`、`curl`、`python3`、Groq API Key
- 小宇宙无公开逐字稿 API，只能转写音频
- ~1 小时节目约需 3–5 分钟转写
- Groq 免费额度有速率限制（HTTP 429 时脚本会等待重试）
- 专有名词可能有识别误差，建议人工校对

## License

MIT
