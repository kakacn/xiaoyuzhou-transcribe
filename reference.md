# 参考手册

仓库：https://github.com/kakacn/xiaoyuzhou-transcribe

## 阿里云百炼 API Key

1. https://bailian.console.aliyun.com/
2. 创建 API Key（`sk-` 开头）
3. 开通「语音识别」→ 录音文件识别（fun-asr / Paraformer）
4. `bash scripts/configure.sh aliyun sk-xxx`

## 配置命令

```bash
# 阿里云（推荐）
bash scripts/configure.sh aliyun sk-xxxxxxxx [--model fun-asr]

# Groq 备选
bash scripts/configure.sh groq gsk-xxxxxxxx

# 切换默认后端
bash scripts/configure.sh default aliyun
bash scripts/configure.sh default groq
```

## 百炼 REST API（手动）

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

查询任务：

```bash
curl -H "Authorization: Bearer $DASHSCOPE_API_KEY" \
  "https://dashscope.aliyuncs.com/api/v1/tasks/TASK_ID"
```

成功后从 `output.results[0].transcription_url` 下载 JSON，取 `transcripts[0].text`。

## 小宇宙音频 URL 提取

见原 manual 流程；注意后缀常为 **`.mp4a`**。

百炼要求 **公网 HTTPS URL**。小宇宙 CDN 链接通常可直接用于 `file_urls`，无需本地下载。

## Groq 手动调用（fallback）

```bash
GROQ_API_KEY=$(tr -d '[:space:]' < ~/.xiaoyuzhou-transcribe/groq_api_key)
curl -s https://api.groq.com/openai/v1/audio/transcriptions \
  -H "Authorization: Bearer $GROQ_API_KEY" \
  -F file="@chunk.mp3" \
  -F model="whisper-large-v3" \
  -F language="zh" \
  -F response_format="text"
```

## 费用参考（阿里云，以控制台为准）

- fun-asr / paraformer：按音频时长计费，通常远低于 OpenAI Whisper
- 单集 1 小时播客：约几毛钱量级（请以账单为准）

## 与 agent-reach 的关系

agent-reach 小宇宙工具仍走 Groq。本 skill 独立维护，**默认阿里云**，更适合国内用户。
