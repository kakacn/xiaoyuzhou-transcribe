---
name: xiaoyuzhou-transcribe
description: >-
  Transcribe Xiaoyuzhou (小宇宙) podcast episodes to Markdown. Default provider Aliyun
  DashScope (fun-asr); Groq Whisper fallback. Use when user shares xiaoyuzhoufm.com/episode
  link or asks for 小宇宙播客逐字稿/转写/字幕. Requires DashScope API Key (sk-) or Groq (gsk-).
license: MIT
homepage: https://github.com/kakacn/xiaoyuzhou-transcribe
metadata: {"openclaw":{"requires":{"bins":["curl","ffmpeg","ffprobe","python3"]},"emoji":"🎙️","homepage":"https://github.com/kakacn/xiaoyuzhou-transcribe"}}
---

# 小宇宙播客转写

将 [小宇宙](https://www.xiaoyuzhoufm.com) 单集链接转为 Markdown 逐字稿；可选内容总结。

## 转写后端

| 后端 | 默认 | 说明 |
|------|------|------|
| **aliyun** | 是 | 阿里云百炼 DashScope `fun-asr`，国内稳，整集 URL 直转 |
| **groq** | 备选 | Groq Whisper，免费但不稳定，需切片 |

## 首次使用（必须先完成）

**未配置 API Key 时不得转写。**

### 推荐：阿里云百炼（国内）

1. 用中文告知用户：
   > 请打开 [百炼控制台](https://bailian.console.aliyun.com/) 注册/登录，创建 **API Key**（`sk-` 开头），发给我。需开通「语音识别 / fun-asr」按量计费。
2. 配置：
   ```bash
   bash {baseDir}/scripts/configure.sh aliyun sk-用户的Key
   # 可选模型：--model paraformer-v2
   ```
3. 验证：`bash {baseDir}/scripts/check.sh` → 输出 `OK`

### 备选：Groq（免费）

```bash
bash {baseDir}/scripts/configure.sh groq gsk-用户的Key
bash {baseDir}/scripts/configure.sh default groq
```

**安全：** Key 勿提交 Git；泄露后于控制台删除重建。

## 配置文件

目录 `~/.xiaoyuzhou-transcribe/`：

| 文件 | 说明 |
|------|------|
| `provider` | `aliyun`（默认）或 `groq` |
| `dashscope_api_key` | 百炼 API Key |
| `dashscope_model` | 默认 `fun-asr` |
| `groq_api_key` | Groq Key（可选 fallback） |

## Quick Start

```bash
bash {baseDir}/scripts/transcribe.sh "https://www.xiaoyuzhoufm.com/episode/EPISODE_ID" [输出.md]
```

选项：

- `--provider aliyun|groq` 覆盖默认后端
- `--model fun-asr|paraformer-v2` 指定百炼模型
- `--polish` 用 Groq Llama 补标点（需 Groq Key）

## 任务清单

```
- [ ] 1. bash {baseDir}/scripts/check.sh
- [ ] 2. bash {baseDir}/scripts/transcribe.sh <url> [output]
- [ ] 3. 确认字数合理（通常 > 5000 字/小时）
- [ ] 4. 用户要总结时：核心内容 / 建议 / 金句
```

## 通用步骤

**Aliyun（默认）：**

```
episode URL → 解析公网音频 URL → DashScope 异步任务 → 轮询 → 下载 JSON → Markdown
```

**Groq：**

```
episode URL → 下载 → ffmpeg 切片 → Whisper 转写 → 合并清理 → Markdown
```

Aliyun 失败且已配置 Groq Key 时，自动 fallback 到 Groq。

## 可选总结

基于**清理后逐字稿**输出：核心内容、个人建议、金句。Show Notes 不能替代全文。

## 故障排查

| 现象 | 处理 |
|------|------|
| DashScope 401 | 检查 sk- Key；百炼控制台是否开通语音服务 |
| Aliyun 子任务失败 | 自动试 Groq；或 `--provider groq` |
| Groq 429 | 等待重试；建议改 `--provider aliyun` |
| 无法提取音频 | 检查 `/episode/` URL；见 reference.md |

## 附加资源

- [README.md](README.md) 安装说明
- [reference.md](reference.md) API 参考
- [examples.md](examples.md) 示例
