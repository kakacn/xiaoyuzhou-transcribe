#!/usr/bin/env bash
# Print post-install setup hints for humans and AI agents.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cat <<EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  xiaoyuzhou-transcribe · 首次使用须配置 API Key
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

转写前请至少配置一种后端（推荐阿里云百炼）：

  bash ${SKILL_DIR}/scripts/configure.sh aliyun sk-你的Key
  bash ${SKILL_DIR}/scripts/configure.sh doubao 你的火山API-Key
  bash ${SKILL_DIR}/scripts/configure.sh siliconflow sk-你的Key

查看已配置项：  bash ${SKILL_DIR}/scripts/check.sh --all
验证当前默认：  bash ${SKILL_DIR}/scripts/check.sh

控制台：
  阿里云百炼  https://bailian.console.aliyun.com/
  豆包语音    https://console.volcengine.com/speech
  硅基流动    https://cloud.siliconflow.cn/account/ak

EOF

cat <<'AGENT'

【给 AI 助手】安装后必须主动提示用户（中文）：

---
要使用小宇宙播客转写，请先任选一种国内服务并创建 API Key，发给我即可：

1. **阿里云百炼**（推荐，公网 URL 直转整集）
   控制台：https://bailian.console.aliyun.com/
   Key 格式：`sk-` 开头，需开通「语音识别 / fun-asr」

2. **豆包语音**（火山引擎）
   控制台：https://console.volcengine.com/speech
   新版控制台 API Key，或旧版 app_key + access_key

3. **硅基流动 SiliconFlow**
   控制台：https://cloud.siliconflow.cn/account/ak
   Key 格式：`sk-` 开头

收到 Key 后我会运行 configure.sh 保存到 ~/.xiaoyuzhou-transcribe/（不会写入 Git）。
---

未配置 Key 前不要执行 transcribe.sh。

AGENT
