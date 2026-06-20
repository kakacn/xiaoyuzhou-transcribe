---
name: xiaoyuzhou-transcribe
description: >-
  Transcribe Xiaoyuzhou (小宇宙) podcast episodes to Markdown. Providers: Aliyun DashScope
  (default), Volcengine Doubao speech, SiliconFlow ASR. On episode URL: auto-save transcript
  and LLM summary locally under ~/.xiaoyuzhou-transcribe/output/ using podcast title as filename.
  Use when user shares xiaoyuzhoufm.com/episode link or asks for 小宇宙播客逐字稿/转写/总结.
license: MIT
homepage: https://github.com/kakacn/xiaoyuzhou-transcribe
metadata: {"openclaw":{"requires":{"bins":["curl","ffmpeg","ffprobe","python3"]},"emoji":"🎙️","homepage":"https://github.com/kakacn/xiaoyuzhou-transcribe"}}
---

# 小宇宙播客转写

用户发送小宇宙单集 URL 后，**一条命令完成转写 + 总结 + 双文件本地落盘**，再在对话中把路径与总结正文发给用户。

## 触发条件

- 用户分享 `xiaoyuzhoufm.com/episode/...` 链接
- 用户要求小宇宙播客逐字稿、转写、总结

## 本地输出规则

| 文件 | 路径 |
|------|------|
| 逐字稿 | `~/.xiaoyuzhou-transcribe/output/<播客标题>.md` |
| 总结 | `~/.xiaoyuzhou-transcribe/output/<播客标题> - 总结.md` |

- 文件名**直接使用播客原标题**（保留中文），不用 episode ID、拼音或英文 slug
- 非法文件名字符会自动剔除；标题过长会截断
- 可通过环境变量 `XIAOYUZHOU_OUTPUT_DIR` 或 `~/.xiaoyuzhou-transcribe/output_dir` 自定义目录

## 转写与总结后端

| 环节 | 默认 | 说明 |
|------|------|------|
| **ASR 转写** | aliyun | DashScope `fun-asr`，公网 URL 直转 |
| | doubao | 火山引擎豆包「大模型录音文件极速版」 |
| | siliconflow | 硅基流动 SenseVoice / TeleSpeech |
| **总结** | DashScope `qwen-long` | 转写完成后自动调用；需配置百炼 API Key |

> 即使用 doubao / siliconflow 做 ASR，总结仍走百炼文本模型（同一 `sk-` Key）。未配置 Key 时只保存逐字稿。

## 安装后必须提示用户（中文原文）

（配置 API Key 话术见 `setup-hint.sh`）

**未配置 Key 前不得执行 `transcribe.sh`。**

## 标准工作流（用户发 URL）

```
- [ ] 1. bash {baseDir}/scripts/check.sh
- [ ] 2. bash {baseDir}/scripts/transcribe.sh "<episode_url>"
       → 自动：ASR 转写 → 保存逐字稿 → DashScope 生成总结 → 保存总结
       → 写入 last_run.env（TRANSCRIPT_PATH / SUMMARY_PATH）
- [ ] 3. 读取两个本地文件，在回复中：
       - 告知逐字稿与总结的完整路径
       - 粘贴总结 Markdown 正文（或核心段落）
       - 逐字稿过长时可只给路径，不必全文粘贴
```

**禁止**只跑转写却不等总结完成就结束；**禁止**只在聊天里写总结而不落盘（`transcribe.sh` 已自动落盘，Agent 只需读取文件回复）。

### 可选：跳过自动总结

```bash
bash {baseDir}/scripts/transcribe.sh --no-summary "<episode_url>"
```

### 可选：手动覆盖总结

若用户对自动总结不满意，可重写后覆盖：

```bash
bash {baseDir}/scripts/save_summary.sh \
  --transcript "$HOME/.xiaoyuzhou-transcribe/output/播客标题.md" \
  ./summary_draft.md
```

## Quick Start

```bash
bash {baseDir}/scripts/transcribe.sh "https://www.xiaoyuzhoufm.com/episode/EPISODE_ID"
```

选项：

- `--provider aliyun|doubao|siliconflow` — ASR 后端
- `--model MODEL` — ASR 模型
- `--no-summary` — 仅转写，不生成总结
- 第三参数 — 覆盖逐字稿输出路径

配置总结模型：`configure.sh aliyun sk-... --summary-model qwen-plus`（短播客可改用 plus 提速）

## 故障排查

| 现象 | 处理 |
|------|------|
| 未配置任何 Key | 运行 `setup-hint.sh`，向用户索取 Key |
| 有逐字稿无总结 | 检查百炼 Key；或手动 `save_summary.sh` |
| 总结质量不佳 / 输出截断 | 确认使用 `qwen-long`（默认）；或重跑 `transcribe.sh` |
| 文件名不对 | 检查 `__NEXT_DATA__` 中的 title；可手动指定输出路径 |

## 附加资源

- [README.md](README.md) · [reference.md](reference.md) · [examples.md](examples.md)
