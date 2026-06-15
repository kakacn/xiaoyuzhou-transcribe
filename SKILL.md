---
name: xiaoyuzhou-transcribe
description: >-
  Transcribe Xiaoyuzhou (小宇宙) podcast episodes to Markdown via Groq Whisper.
  Downloads audio, segments long files, cleans hallucinations, optionally summarizes.
  Use when the user shares xiaoyuzhoufm.com/episode link, asks for 小宇宙播客逐字稿/转写/字幕,
  or wants podcast transcript and summary. Requires Groq API Key (free).
license: MIT
homepage: https://github.com/kakacn/xiaoyuzhou-transcribe
metadata: {"openclaw":{"requires":{"bins":["curl","ffmpeg","ffprobe","python3"]},"emoji":"🎙️","homepage":"https://github.com/kakacn/xiaoyuzhou-transcribe"}}
---

# 小宇宙播客转写

将 [小宇宙](https://www.xiaoyuzhoufm.com) 单集链接转为 Markdown 逐字稿；可选内容总结。

## 首次使用（必须先完成）

**没有 Groq API Key 时，不得开始转写。** 先引导安装人完成注册与配置：

1. 用中文告知用户：
   > 本 skill 需要 **Groq API Key**（免费）才能转写音频。请打开 [Groq Console](https://console.groq.com/keys) 注册/登录，点击 **Create API Key** 创建密钥（以 `gsk_` 开头），创建后把完整 Key 发给我。Key 只显示一次，请立即复制。
2. 收到 Key 后执行配置：
   ```bash
   bash {baseDir}/scripts/configure.sh "gsk_用户的Key"
   ```
3. 验证：
   ```bash
   bash {baseDir}/scripts/check.sh
   ```
   输出 `OK` 后方可转写。

**安全：** 提醒用户勿将 Key 提交到 Git 或公开渠道；若已泄露，应在 Groq Console 删除并重建。

## 前置依赖

| 依赖 | 安装 |
|------|------|
| `ffmpeg` / `ffprobe` | `brew install ffmpeg` |
| `curl` | 系统通常已有 |
| `python3` | 清理逐字稿噪声时需要 |
| Groq API Key | 见上方「首次使用」 |

配置文件：`~/.xiaoyuzhou-transcribe/groq_api_key`（`configure.sh` 写入，权限 `600`）。

## Quick Start

用户给出小宇宙单集链接后：

```bash
bash {baseDir}/scripts/transcribe.sh "https://www.xiaoyuzhoufm.com/episode/EPISODE_ID" [输出.md]
```

默认输出：`/tmp/xiaoyuzhou_<episode_id>.md`

加 `--polish` 可用 Groq Llama 补中文标点（长节目更慢，按需使用）。

## 任务清单

```
- [ ] 1. bash {baseDir}/scripts/check.sh — 未配置则走「首次使用」流程
- [ ] 2. bash {baseDir}/scripts/transcribe.sh <episode_url> [output]
- [ ] 3. 确认输出文件存在且字数合理（通常 > 5000 字/小时）
- [ ] 4. 用户要总结时，基于逐字稿输出：核心内容 / 建议 / 金句
```

脚本失败时再走 [reference.md](reference.md) 中的手动兜底。

## 通用步骤（方法论）

```
episode URL → 解析元数据 → 下载音频 → ffmpeg 64k mono MP3
→ 按 ≤20MB 切片 → Groq Whisper 转写 → 合并清理 → Markdown
```

要点：

- 小宇宙**无公开文字逐字稿**；`transcript` 字段通常指向音频
- 音频 URL：正则匹配 `media.xyzcdn.net`（含 **`.mp4a`**）或解析 `__NEXT_DATA__`
- Groq 单文件 ≤25MB，脚本按 20MB 切片
- Whisper 中文幻觉需后处理（脚本已内置）

## 可选总结

用户要求总结时，基于**清理后的逐字稿**输出：

- 核心内容（分主题）
- 个人建议 / 行动项
- 金句摘录（保留原文引号）

Show Notes 可作对照，不能替代全文。

## 故障排查

| 现象 | 处理 |
|------|------|
| Key 未配置 | `bash {baseDir}/scripts/configure.sh gsk_...` |
| 无法提取音频 | 检查 `/episode/` URL；见 reference.md 手动解析 |
| `ffmpeg not found` | `brew install ffmpeg` |
| HTTP 429 | 等待后重跑；Groq 免费额度限速 |

## 附加资源

- 安装与各平台说明：[README.md](README.md)
- 手动 API / 兜底：[reference.md](reference.md)
- 使用示例：[examples.md](examples.md)
- Groq Key：[console.groq.com/keys](https://console.groq.com/keys)
