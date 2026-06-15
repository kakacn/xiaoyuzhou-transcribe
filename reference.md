# 参考手册

仓库：https://github.com/kakacn/xiaoyuzhou-transcribe

## 配置命令

```bash
# 阿里云（推荐）
bash scripts/configure.sh aliyun sk-xxxxxxxx [--model fun-asr]

# 豆包语音
bash scripts/configure.sh doubao <api-key>
bash scripts/configure.sh doubao --legacy <app-key> <access-key>

# 硅基流动
bash scripts/configure.sh siliconflow sk-xxxxxxxx [--model FunAudioLLM/SenseVoiceSmall]

# 切换默认后端
bash scripts/configure.sh default aliyun|doubao|siliconflow

# 查看全部后端配置
bash scripts/configure.sh status
```

## 阿里云百炼

1. https://bailian.console.aliyun.com/
2. 创建 API Key（`sk-` 开头）
3. 开通「语音识别」→ 录音文件识别（fun-asr / Paraformer）

提交任务：

```bash
curl -X POST 'https://dashscope.aliyuncs.com/api/v1/services/audio/asr/transcription' \
  -H "Authorization: Bearer $DASHSCOPE_API_KEY" \
  -H "Content-Type: application/json" \
  -H "X-DashScope-Async: enable" \
  -d '{
    "model": "fun-asr",
    "input": {"file_urls": ["https://media.xyzcdn.net/.../xxx.mp4a"]},
    "parameters": {"channel_id": [0], "language_hints": ["zh", "en"]}
  }'
```

成功后从 `output.results[0].transcription_url` 下载 JSON，取 `transcripts[0].text`。

## 豆包语音（极速版）

- 端点：`POST https://openspeech.bytedance.com/api/v3/auc/bigmodel/recognize/flash`
- 新版控制台：`X-Api-Key` + `X-Api-Resource-Id: volc.bigasr.auc_turbo`
- 支持公网 URL 或 base64 音频（WAV/MP3/OGG/OPUS）
- 小宇宙音频常为 `.mp4a`，URL 可能失败，脚本会自动下载转 mp3 后 base64 重试

## 硅基流动

- 端点：`POST https://api.siliconflow.cn/v1/audio/transcriptions`
- OpenAI 兼容 multipart 上传
- 默认模型 `FunAudioLLM/SenseVoiceSmall`
- 大文件按约 24MB 自动切片

```bash
curl https://api.siliconflow.cn/v1/audio/transcriptions \
  -H "Authorization: Bearer $SILICONFLOW_API_KEY" \
  -F file=@audio.mp3 \
  -F model="FunAudioLLM/SenseVoiceSmall"
```

## 小宇宙音频 URL 提取

从页面 `__NEXT_DATA__` 或正则取 `media.xyzcdn.net/...mp4a`。

百炼、豆包支持 **公网 HTTPS URL** 直转；硅基流动需本地下载。

## 费用参考（以各控制台为准）

- 阿里云 fun-asr：按音频时长，单集 1 小时通常几毛钱量级
- 豆包极速版：按调用量/时长计费
- 硅基流动：按 token/调用计费，SenseVoice 性价比较高

## 与 agent-reach 的关系

agent-reach 内置小宇宙工具与本 skill 独立。本 skill 面向国内多后端（百炼 / 豆包 / 硅基流动），可单独安装使用。
