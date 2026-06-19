---
name: xiaoyuzhou-transcribe
description: >-
  Transcribe Xiaoyuzhou (小宇宙) podcast episodes to Markdown. Providers: Aliyun DashScope
  (default), Volcengine Doubao speech, SiliconFlow ASR. Saves transcript and summary
  locally under ~/.xiaoyuzhou-transcribe/output/ using podcast title as filename.
  Use when user shares xiaoyuzhoufm.com/episode link or asks for 小宇宙播客逐字稿/转写/总结.
license: MIT
homepage: https://github.com/kakacn/xiaoyuzhou-transcribe
metadata: {"openclaw":{"requires":{"bins":["curl","ffmpeg","ffprobe","python3"]},"emoji":"🎙️","homepage":"https://github.com/kakacn/xiaoyuzhou-transcribe"}}
---

# 小宇宙播客转写

将 [小宇宙](https://www.xiaoyuzhoufm.com) 单集链接转为 Markdown 逐字稿；可选内容总结。**逐字稿与总结均保存到本地**，再在对话中发给用户。

## 本地输出规则

| 文件 | 路径 |
|------|------|
| 逐字稿 | `~/.xiaoyuzhou-transcribe/output/<播客标题>.md` |
| 总结 | `~/.xiaoyuzhou-transcribe/output/<播客标题> - 总结.md` |

- 文件名**直接使用播客原标题**（保留中文），不用 episode ID、拼音或英文 slug
- 非法文件名字符会自动剔除；标题过长会截断
- 可通过环境变量 `XIAOYUZHOU_OUTPUT_DIR` 或 `~/.xiaoyuzhou-transcribe/output_dir` 自定义目录

## 转写后端

| 后端 | 默认 | 说明 |
|------|------|------|
| **aliyun** | 是 | 阿里云百炼 DashScope `fun-asr`，公网 URL 直转 |
| **doubao** | | 火山引擎豆包「大模型录音文件极速版」 |
| **siliconflow** | | 硅基流动 SenseVoice / TeleSpeech |

## 安装后必须提示用户（中文原文）

（配置 API Key 话术同前，见 `setup-hint.sh`）

**未配置 Key 前不得执行 `transcribe.sh`。**

## 标准工作流（含总结）

```
- [ ] 1. bash {baseDir}/scripts/check.sh
- [ ] 2. bash {baseDir}/scripts/transcribe.sh <episode_url>
       → 本地保存逐字稿，记录 TRANSCRIPT_PATH / SUMMARY_PATH（last_run.env）
- [ ] 3. 阅读逐字稿，撰写总结（核心内容 / 建议 / 金句）
- [ ] 4. bash {baseDir}/scripts/save_summary.sh -   # 从 stdin 写入总结
       或: save_summary.sh /tmp/summary.md
- [ ] 5. 在回复中告知用户两个本地路径，并粘贴总结正文
```

**用户要总结时：必须先 `save_summary.sh` 落盘，再发送内容。** 不要只在聊天里总结而不写文件。

### 保存总结示例

```bash
bash {baseDir}/scripts/save_summary.sh - <<'EOF'
## 核心内容
...

## 建议
...

## 金句
...
EOF
```

或指定逐字稿路径：

```bash
bash {baseDir}/scripts/save_summary.sh \
  --transcript "$HOME/.xiaoyuzhou-transcribe/output/播客标题.md" \
  ./summary_draft.md
```

## Quick Start

```bash
bash {baseDir}/scripts/transcribe.sh "https://www.xiaoyuzhoufm.com/episode/EPISODE_ID"
```

选项：`--provider aliyun|doubao|siliconflow`、`--model MODEL`、可选第三参数覆盖输出路径

## 故障排查

| 现象 | 处理 |
|------|------|
| 未配置任何 Key | 运行 `setup-hint.sh`，向用户索取 Key |
| save_summary 找不到逐字稿 | 先运行 `transcribe.sh`，或传 `--transcript` |
| 文件名乱码/不对 | 检查页面 `__NEXT_DATA__` 中的 title；可手动指定输出路径 |

## 附加资源

- [README.md](README.md) · [reference.md](reference.md) · [examples.md](examples.md)
