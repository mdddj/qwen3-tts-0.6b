# Qwen3 TTS 0.6B

本地语音生成工具，基于 Qwen3-TTS 模型，支持中国网络环境的代理和镜像配置。默认 `0.6B-Base` 模型为克隆模式，需要参考音频和参考文本。

## 功能特性

- 本地 TTS 语音合成
- 支持语音克隆（使用参考音频）
- 支持自定义说话人和风格
- 支持语音风格设计
- 中国网络友好（支持镜像和代理）
- 一键安装和预热

## 快速开始

### 一键安装

```bash
bash scripts/install_and_warmup.sh
```

### 基础使用

```bash
bash scripts/agent_use.sh \
  --voice-mode clone \
  --text "你好，这是一段测试语音。" \
  --output outputs/reply.wav \
  --spk-audio ./sample_ref.wav \
  --spk-text "这是参考音频对应的文字"
```

### 语音克隆

```bash
bash scripts/agent_use.sh \
  --voice-mode clone \
  --spk-audio ./sample_ref.wav \
  --spk-text "这是参考音频对应的文字" \
  --text "用这个声音说话" \
  --output outputs/clone.wav
```

### 自定义说话人

```bash
bash scripts/agent_use.sh \
  --voice-mode custom \
  --model-id Qwen/Qwen3-TTS-12Hz-0.6B-CustomVoice \
  --speaker Cherry \
  --instruct "Please speak in a warm and friendly tone." \
  --text "欢迎使用我们的产品。" \
  --output outputs/custom.wav
```

### Voice Design

```bash
bash scripts/agent_use.sh \
  --model-id Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign \
  --voice-mode design \
  --instruct "Generate a calm, deep, and professional male narration style." \
  --text "这是产品介绍的开场白。" \
  --output outputs/design.wav
```

## 中国网络环境

使用镜像加速：

```bash
bash scripts/agent_use.sh \
  --text "你好" \
  --output outputs/reply.wav
```

使用代理：

```bash
bash scripts/agent_use.sh \
  --text "你好" \
  --output outputs/reply.wav \
  --http-proxy http://127.0.0.1:7890 \
  --https-proxy http://127.0.0.1:7890
```

## 文档

- [安装和代理配置指南](references/setup-and-proxy.md)
- [技能文档](SKILL.md)

## 系统要求

- Python 3.8+
- sox
- ffmpeg
- espeak-ng

## License

MIT
