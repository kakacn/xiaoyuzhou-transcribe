# xiaoyuzhou-transcribe

Agent Skill：将小宇宙播客单集链接转为 Markdown 逐字稿。

- **默认后端：** 阿里云百炼 DashScope（`fun-asr`），国内稳定，整集直转
- **备选后端：** Groq Whisper（免费但不稳定）

仓库：https://github.com/kakacn/xiaoyuzhou-transcribe

## 首次配置（必做）

### 推荐：阿里云百炼

1. 打开 [百炼控制台](https://bailian.console.aliyun.com/) → API Key（`sk-` 开头）
2. 确保已开通 **语音识别**（fun-asr / Paraformer）按量计费
3. 配置：

```bash
bash scripts/configure.sh aliyun sk-你的Key
# 可选：--model paraformer-v2
```

4. 验证：

```bash
bash scripts/check.sh
# OK: ffmpeg ready, provider=aliyun, model=fun-asr, DashScope API key valid
```

### 备选：Groq

```bash
bash scripts/configure.sh groq gsk-你的Key
bash scripts/configure.sh default groq
```

配置目录：`~/.xiaoyuzhou-transcribe/`

## 使用

```bash
# 默认阿里云
bash scripts/transcribe.sh "https://www.xiaoyuzhoufm.com/episode/EPISODE_ID"

# 指定模型
bash scripts/transcribe.sh --model paraformer-v2 "EPISODE_URL"

# 强制 Groq
bash scripts/transcribe.sh --provider groq "EPISODE_URL"
```

对 AI 说：

```
帮我把这期小宇宙播客转成逐字稿
https://www.xiaoyuzhoufm.com/episode/EPISODE_ID
```

## 可选模型（阿里云）

| 模型 | 场景 |
|------|------|
| `fun-asr` | 默认，中文播客推荐 |
| `paraformer-v2` | 成熟通用，成本较低 |
| `fun-asr-mtl` | 中英混杂 |

## 安装

```bash
# OpenClaw
openclaw skills install git:kakacn/xiaoyuzhou-transcribe@main --global

# 一键（全平台）
curl -fsSL https://raw.githubusercontent.com/kakacn/xiaoyuzhou-transcribe/main/install.sh | bash -s -- --global --agent all -y
```

详见 SKILL.md 与各平台路径表。

## 目录结构

```
scripts/
├── configure.sh         # 配置 aliyun / groq
├── check.sh
├── transcribe.sh        # 主入口（多后端）
├── aliyun_transcribe.py # 百炼异步转写
└── lib/config.sh
```

## License

MIT
