# xiaoyuzhou-transcribe

Agent Skill：将小宇宙播客单集链接转为 Markdown 逐字稿，并**自动生成总结**，双文件本地保存。

| 后端 | 说明 |
|------|------|
| **aliyun**（默认） | 阿里云百炼 DashScope `fun-asr`，公网 URL 直转 |
| **doubao** | 火山引擎豆包大模型录音文件极速版 |
| **siliconflow** | 硅基流动 SenseVoice / TeleSpeech ASR |

安装后运行 `bash scripts/setup-hint.sh` 查看向用户索取 API Key 的标准话术。

仓库：https://github.com/kakacn/xiaoyuzhou-transcribe

## 首次配置（必做）

### 阿里云百炼（推荐）

```bash
bash scripts/configure.sh aliyun sk-你的Key
# 总结模型默认 qwen-long（长播客）；短播客可改为 qwen-plus
bash scripts/configure.sh aliyun sk-你的Key --summary-model qwen-long
bash scripts/check.sh
```

控制台：https://bailian.console.aliyun.com/

### 豆包语音

```bash
bash scripts/configure.sh doubao <API-Key>
# 或旧版：configure.sh doubao --legacy <app-key> <access-key>
```

### 硅基流动

```bash
bash scripts/configure.sh siliconflow sk-你的Key
```

切换默认：`bash scripts/configure.sh default doubao`

配置目录：`~/.xiaoyuzhou-transcribe/`

## 使用

```bash
# 转写 + 自动总结 → 两个文件
bash scripts/transcribe.sh "https://www.xiaoyuzhoufm.com/episode/EPISODE_ID"
# ~/.xiaoyuzhou-transcribe/output/<播客标题>.md
# ~/.xiaoyuzhou-transcribe/output/<播客标题> - 总结.md

# 仅转写，不要总结
bash scripts/transcribe.sh --no-summary "EPISODE_URL"
```

对 AI 说：

```
帮我把这期小宇宙播客转成逐字稿并总结
https://www.xiaoyuzhoufm.com/episode/EPISODE_ID
```

## 可选模型

**阿里云：** `fun-asr`（默认）、`paraformer-v2`、`fun-asr-mtl`

**硅基流动：** `FunAudioLLM/SenseVoiceSmall`（默认）、`TeleAI/TeleSpeechASR`

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
├── configure.sh           # 配置 aliyun / doubao / siliconflow
├── check.sh
├── transcribe.sh          # 主入口（转写 + 自动总结）
├── summarize_transcript.py # DashScope 总结
├── save_summary.sh        # 手动覆盖总结
├── aliyun_transcribe.py
├── doubao_transcribe.py
├── siliconflow_transcribe.py
└── lib/config.sh, paths.py
```

## License

MIT
