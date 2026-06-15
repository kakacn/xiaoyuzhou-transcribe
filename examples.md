# 使用示例

## 示例 1：阿里云转写（默认）

```bash
bash scripts/configure.sh aliyun sk-xxxxxxxx
bash scripts/check.sh
bash scripts/transcribe.sh "https://www.xiaoyuzhoufm.com/episode/EPISODE_ID"
```

## 示例 2：指定 Paraformer 模型

```bash
bash scripts/transcribe.sh --model paraformer-v2 "EPISODE_URL" ./out.md
```

## 示例 3：Groq 转写

```bash
bash scripts/configure.sh groq gsk-xxxxxxxx
bash scripts/transcribe.sh --provider groq "EPISODE_URL"
```

## 示例 4：转写 + 总结

用户：

```
帮我把这期小宇宙播客转成逐字稿并总结
https://www.xiaoyuzhoufm.com/episode/EPISODE_ID
```

Agent：`check.sh` → 配置百炼 Key → `transcribe.sh` → 输出核心内容 / 建议 / 金句

## 示例 5：带标点润色（需 Groq Key）

```bash
bash scripts/transcribe.sh --polish "EPISODE_URL" ./transcript.md
```

阿里云转写 + Groq Llama 补标点。
