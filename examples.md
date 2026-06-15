# 使用示例

## 示例 1：转写单集

用户：

```
帮我把这期小宇宙播客转成逐字稿
https://www.xiaoyuzhoufm.com/episode/6a1d7d39989e711d01e30345
```

Agent 流程：

1. `bash {baseDir}/scripts/check.sh`
2. 若未配置 Key → 引导用户打开 https://console.groq.com/keys 并提供 `gsk_` Key
3. `bash {baseDir}/scripts/configure.sh "gsk_..."`
4. `bash {baseDir}/scripts/transcribe.sh "URL" /tmp/episode.md`
5. 汇报输出路径与字数

## 示例 2：转写 + 总结

用户：

```
读取这期播客逐字稿，总结核心内容、个人建议和金句
https://www.xiaoyuzhoufm.com/episode/EPISODE_ID
```

Agent 在转写完成后，基于全文输出：

- 节目概览（嘉宾、时长、主题）
- 核心内容（分 4–6 个主题）
- 个人建议（3–5 条行动项）
- 金句摘录（10 条左右，保留引号）

## 示例 3：OpenClaw 会话

```
/openclaw skills list
```

确认 `xiaoyuzhou-transcribe` 已安装后：

```
帮我把这期小宇宙播客转成逐字稿 https://www.xiaoyuzhoufm.com/episode/EPISODE_ID
```

## 示例 4：仅配置 Key

```bash
bash scripts/configure.sh "gsk_xxxxxxxxxxxxxxxx"
bash scripts/check.sh
```

期望输出：

```
OK: ffmpeg ready, Groq API key valid
```

## 示例 5：带标点润色

```bash
bash scripts/transcribe.sh --polish \
  "https://www.xiaoyuzhoufm.com/episode/EPISODE_ID" \
  ./transcript_polished.md
```

适合对阅读体验要求高的长节目（更慢，多一轮 Groq LLM 调用）。
