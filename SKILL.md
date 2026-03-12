---
name: qwen3-tts-0-6b
description: Use Qwen/Qwen3-TTS-12Hz-0.6B-Base for local text-to-speech generation and optional voice style transfer with reference audio. Use when users ask for text-to-audio output, spoken replies, WAV synthesis, TTS demo generation, or AI responses that include downloadable voice files. Trigger on requests like "文本转语音", "TTS", "语音回复", "read this aloud", "生成音频", and when China network proxy/mirror configuration is needed for model download.
---

# Qwen3 TTS 0.6B

## Overview

Generate WAV audio from text with `Qwen3-TTS-12Hz-0.6B-Base`.
Support China-friendly setup via proxy variables and Hugging Face mirror endpoint.

## Workflow

1. Confirm output requirements: language, tone, output filename, and whether voice style transfer is needed.
2. For first run on a new machine, bootstrap runtime and model cache:
- Prefer `bash scripts/agent_use.sh --text "测试" --output outputs/smoke.wav` (auto setup + auto warmup + synthesis).
- If needed, run `bash scripts/install_and_warmup.sh` manually.
3. Run `scripts/qwen3_tts.py` or `scripts/agent_use.sh` to synthesize WAV.
4. Return both:
- The normal text reply.
- The generated audio file path for playback/download.

## Quick Commands

Basic synthesis:

```bash
python3 scripts/qwen3_tts.py \
  --text "你好，这是一段测试语音。" \
  --output outputs/reply.wav
```

Agent-safe one command (recommended after GitHub skill install):

```bash
bash scripts/agent_use.sh \
  --text "你好，这是一段给客户的语音回复。" \
  --output outputs/reply.wav
```

Windows PowerShell one command:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\agent_use.ps1 `
  -Text "你好，这是一段给客户的语音回复。" `
  -Output outputs\reply.wav
```

Use China mirror:

```bash
python3 scripts/qwen3_tts.py \
  --text "欢迎使用千问语音合成" \
  --output outputs/reply.wav \
  --cn-mirror
```

Pre-download model for customer machine first run:

```bash
python3 scripts/qwen3_tts.py \
  --output outputs/placeholder.wav \
  --download-only \
  --cache-dir ./model_cache \
  --cn-mirror
```

Windows pre-download:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\install_and_warmup.ps1
```

Use HTTP/HTTPS proxy:

```bash
python3 scripts/qwen3_tts.py \
  --text "这条音频通过代理下载模型后生成" \
  --output outputs/reply.wav \
  --http-proxy http://127.0.0.1:7890 \
  --https-proxy http://127.0.0.1:7890
```

Voice style transfer with reference audio:

```bash
python3 scripts/qwen3_tts.py \
  --voice-mode clone \
  --text "保持参考音频的说话风格来朗读这句话。" \
  --output outputs/styled.wav \
  --spk-audio sample_ref.wav \
  --spk-text "这是参考音频对应的文字"
```

Custom speaker + style instruction:

```bash
python3 scripts/qwen3_tts.py \
  --voice-mode custom \
  --speaker Cherry \
  --instruct "Please speak in a warm and friendly customer-support tone." \
  --text "您好，您的订单已经发货，预计明天送达。" \
  --output outputs/custom.wav
```

Voice design from text instruction:

```bash
python3 scripts/qwen3_tts.py \
  --voice-mode design \
  --instruct "Generate a calm, deep, and professional male narration style." \
  --text "这是产品介绍的开场白。" \
  --output outputs/design.wav
```

## Behavior Rules

Use this skill when user explicitly wants audio output instead of plain text.
If user asks for normal text only, do not run TTS.
If user asks for both, always provide text first, then provide generated file path.
Prefer WAV output for compatibility.
On a fresh environment, always execute one bootstrap synthesis command first to make sure runtime and model cache are ready.
Use `--voice-mode` to force behavior when needed:
- `clone`: use reference audio/text.
- `custom`: use predefined speaker plus optional style instruction.
- `design`: synthesize using style instruction text.
- `base`: plain synthesis.

## Resources

- `scripts/qwen3_tts.py`: CLI entrypoint for synthesis and proxy handling.
- `scripts/install_and_warmup.sh`: one-command setup for customer machines.
- `scripts/agent_use.sh`: one-command agent workflow (auto install, warmup, and synthesize).
- `scripts/install_and_warmup.ps1`: Windows one-command setup and warmup.
- `scripts/agent_use.ps1`: Windows one-command agent workflow.
- `references/setup-and-proxy.md`: dependency install, China mirror, troubleshooting.
