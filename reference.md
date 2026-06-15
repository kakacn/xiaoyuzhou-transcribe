# 小宇宙播客转写 — 参考手册

仓库：https://github.com/kakacn/xiaoyuzhou-transcribe

## Groq API Key 获取步骤（给安装人）

1. 打开 https://console.groq.com
2. 用 Google / GitHub / 邮箱注册并登录
3. 进入 https://console.groq.com/keys
4. 点击 **Create API Key**，命名（如 `xiaoyuzhou`）
5. **立即复制**完整 Key（`gsk_` 开头，只显示一次）
6. 交给 Agent 或自行执行：
   ```bash
   bash scripts/configure.sh "gsk_xxxxxxxx"
   ```

## 手动提取音频 URL

```bash
EPISODE_URL="https://www.xiaoyuzhoufm.com/episode/EPISODE_ID"
curl -sL "$EPISODE_URL" -o /tmp/xyz.html

# 方法 A：正则（含 .mp4a）
grep -oE 'https://media\.xyzcdn\.net/[^"[:space:]]+\.(m4a|mp3|mp4a)' /tmp/xyz.html | head -1

# 方法 B：__NEXT_DATA__ JSON
python3 <<'PY'
import re, json
html = open("/tmp/xyz.html", encoding="utf-8").read()
m = re.search(r'<script id="__NEXT_DATA__" type="application/json">(.*?)</script>', html, re.S)
ep = json.loads(m.group(1))["props"]["pageProps"]["episode"]
media = ep.get("media", {})
print(media.get("backupSource", {}).get("url") or ep.get("enclosure", {}).get("url"))
print("title:", ep.get("title"))
print("duration:", ep.get("duration"), "sec")
PY
```

## 手动 Groq Whisper 调用

```bash
GROQ_API_KEY=$(tr -d '[:space:]' < "$HOME/.xiaoyuzhou-transcribe/groq_api_key")

curl -s https://api.groq.com/openai/v1/audio/transcriptions \
  -H "Authorization: Bearer $GROQ_API_KEY" \
  -F file="@chunk_0.mp3" \
  -F model="whisper-large-v3" \
  -F language="zh" \
  -F prompt="以下是一段中文普通话播客录音，请输出包含完整中文标点的转写文本。" \
  -F response_format="text"
```

## 噪声清理正则（Python）

```python
import re
NOISE = [
    r"请不吝点赞\s*订阅\s*转发\s*打赏支持明镜与点点栏目",
    r"请不吝点赞\s*订阅\s*转发\s*打赏支持明镜及点点栏目",
    r"请输出包含完整中文标点[^。]*。",
    r"请输出包含文本。",
]
for p in NOISE:
    text = re.sub(p, "", text)
```

## 与 agent-reach 的关系

若已安装 [Agent Reach](https://github.com/Panniantong/Agent-Reach)，也可：

```bash
agent-reach configure groq-key gsk_xxx
~/.agent-reach/tools/xiaoyuzhou/transcribe.sh --polish "EPISODE_URL"
```

注意：agent-reach 内置脚本可能未匹配 `.mp4a` 后缀；本 skill 的 `transcribe.sh` 已修复。
