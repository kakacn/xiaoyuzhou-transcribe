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

## 示例 3：豆包语音转写

```bash
bash scripts/configure.sh doubao <火山API-Key>
bash scripts/transcribe.sh --provider doubao "EPISODE_URL"
```

## 示例 4：硅基流动转写

```bash
bash scripts/configure.sh siliconflow sk-xxxxxxxx
bash scripts/transcribe.sh --provider siliconflow "EPISODE_URL"
```

## 示例 5：转写 + 总结（本地双文件）

```bash
bash scripts/transcribe.sh "EPISODE_URL"
# → ~/.xiaoyuzhou-transcribe/output/播客原标题.md

# Agent 撰写总结后保存
bash scripts/save_summary.sh - <<'EOF'
## 核心内容
...
EOF
# → ~/.xiaoyuzhou-transcribe/output/播客原标题 - 总结.md
```

Agent 流程：`transcribe.sh` → 读逐字稿写总结 → `save_summary.sh` → 回复用户并给出两个文件路径。
