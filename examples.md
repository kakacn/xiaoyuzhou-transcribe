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

## 示例 5：转写 + 总结

用户：

```
帮我把这期小宇宙播客转成逐字稿并总结
https://www.xiaoyuzhoufm.com/episode/EPISODE_ID
```

Agent：`check.sh` → 配置 API Key → `transcribe.sh` → 输出核心内容 / 建议 / 金句
