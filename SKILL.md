---
name: xiaoyuzhou-transcribe
description: >-
  Transcribe Xiaoyuzhou (小宇宙) podcast episodes to Markdown. Providers: Aliyun DashScope
  (default), Volcengine Doubao speech, SiliconFlow ASR. Use when user shares
  xiaoyuzhoufm.com/episode link or asks for 小宇宙播客逐字稿/转写/字幕. Requires API Key from
  one provider. After install, prompt user for aliyun/doubao/siliconflow key.
license: MIT
homepage: https://github.com/kakacn/xiaoyuzhou-transcribe
metadata: {"openclaw":{"requires":{"bins":["curl","ffmpeg","ffprobe","python3"]},"emoji":"🎙️","homepage":"https://github.com/kakacn/xiaoyuzhou-transcribe"}}
---

# 小宇宙播客转写

将 [小宇宙](https://www.xiaoyuzhoufm.com) 单集链接转为 Markdown 逐字稿；可选内容总结。

## 转写后端

| 后端 | 默认 | 说明 |
|------|------|------|
| **aliyun** | 是 | 阿里云百炼 DashScope `fun-asr`，公网 URL 直转 |
| **doubao** | | 火山引擎豆包「大模型录音文件极速版」 |
| **siliconflow** | | 硅基流动 SenseVoice / TeleSpeech |

## 安装后必须提示用户（中文原文）

用户刚安装本 skill、或 `check.sh` 失败时，**必须用中文**发送以下话术，等待用户回复 API Key：

---

要使用小宇宙播客转写，请先**任选一种**国内服务并创建 API Key，发给我即可：

1. **阿里云百炼**（推荐，整集公网 URL 直转）
   - 控制台：https://bailian.console.aliyun.com/
   - Key：`sk-` 开头，需开通「语音识别 / fun-asr」

2. **豆包语音**（火山引擎）
   - 控制台：https://console.volcengine.com/speech
   - 新版 API Key，或旧版 app_key + access_key

3. **硅基流动 SiliconFlow**
   - 控制台：https://cloud.siliconflow.cn/account/ak
   - Key：`sk-` 开头

收到 Key 后我会运行 `configure.sh` 保存到 `~/.xiaoyuzhou-transcribe/`（不写入 Git）。

---

也可运行 `bash {baseDir}/scripts/setup-hint.sh` 打印完整说明。

**未配置 Key 前不得执行 `transcribe.sh`。**

## 配置命令

```bash
bash {baseDir}/scripts/configure.sh aliyun sk-用户的Key [--model fun-asr]
bash {baseDir}/scripts/configure.sh doubao <API-Key>
bash {baseDir}/scripts/configure.sh doubao --legacy <app-key> <access-key>
bash {baseDir}/scripts/configure.sh siliconflow sk-用户的Key [--model MODEL]
bash {baseDir}/scripts/configure.sh default aliyun|doubao|siliconflow
bash {baseDir}/scripts/configure.sh status    # 查看三后端配置状态
```

验证：

```bash
bash {baseDir}/scripts/check.sh --all   # 列出全部后端
bash {baseDir}/scripts/check.sh         # 验证当前默认后端
```

## 配置文件

目录 `~/.xiaoyuzhou-transcribe/`：

| 文件 | 说明 |
|------|------|
| `provider` | 默认 `aliyun` |
| `dashscope_api_key` / `dashscope_model` | 百炼 |
| `volcengine_*` | 豆包 |
| `siliconflow_*` | 硅基流动 |

## Quick Start

```bash
bash {baseDir}/scripts/transcribe.sh "https://www.xiaoyuzhoufm.com/episode/EPISODE_ID" [输出.md]
```

选项：`--provider aliyun|doubao|siliconflow`、`--model MODEL`

## 任务清单

```
- [ ] 1. 若无 Key：按上文话术向用户索取
- [ ] 2. bash {baseDir}/scripts/configure.sh <provider> <key>
- [ ] 3. bash {baseDir}/scripts/check.sh
- [ ] 4. bash {baseDir}/scripts/transcribe.sh <url> [output]
- [ ] 5. 用户要总结时：核心内容 / 建议 / 金句
```

## 故障排查

| 现象 | 处理 |
|------|------|
| 未配置任何 Key | 运行 `setup-hint.sh`，向用户索取 Key |
| DashScope 401 | 检查百炼语音服务是否开通 |
| 豆包 URL 失败 | 脚本自动转 mp3 重试 |

## 附加资源

- [README.md](README.md) · [reference.md](reference.md) · [examples.md](examples.md)
