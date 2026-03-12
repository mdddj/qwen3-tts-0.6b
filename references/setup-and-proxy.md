# Setup and Proxy Guide

## One-command setup for customers

Run:

```bash
bash scripts/install_and_warmup.sh
```

This script creates `.venv`, installs `qwen-tts`, and pre-downloads model to `model_cache`.

Windows PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\install_and_warmup.ps1
```

This script does the same setup flow on Windows.

## How AI should operate after GitHub install

After skill is installed from GitHub, run commands from the skill root:

```bash
bash scripts/agent_use.sh --text "安装后自检" --output outputs/smoke.wav
```

Windows:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\agent_use.ps1 -Text "安装后自检" -Output outputs\smoke.wav
```

Then use the same command for normal replies:

```bash
bash scripts/agent_use.sh --text "这是用户请求的语音回复" --output outputs/reply.wav
```

Windows:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\agent_use.ps1 -Text "这是用户请求的语音回复" -Output outputs\reply.wav
```

Clone voice with reference audio:

```bash
bash scripts/agent_use.sh \
  --voice-mode clone \
  --spk-audio ./sample_ref.wav \
  --spk-text "这是参考音频对应文案" \
  --text "请用这个人的声音回复" \
  --output outputs/clone.wav
```

Windows:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\agent_use.ps1 `
  -VoiceMode clone `
  -SpkAudio .\sample_ref.wav `
  -SpkText "这是参考音频对应文案" `
  -Text "请用这个人的声音回复" `
  -Output outputs\clone.wav
```

Custom speaker with style instruction:

```bash
bash scripts/agent_use.sh \
  --voice-mode custom \
  --speaker Cherry \
  --instruct "Please speak in a warm, elegant narration tone." \
  --text "欢迎来到我们的产品演示。" \
  --output outputs/custom.wav
```

Windows:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\agent_use.ps1 `
  -VoiceMode custom `
  -Speaker Cherry `
  -Instruct "Please speak in a warm, elegant narration tone." `
  -Text "欢迎来到我们的产品演示。" `
  -Output outputs\custom.wav
```

If proxy is required:

```bash
bash scripts/agent_use.sh \
  --text "带代理的语音回复" \
  --output outputs/reply.wav \
  --http-proxy http://127.0.0.1:7890 \
  --https-proxy http://127.0.0.1:7890
```

Windows:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\agent_use.ps1 `
  -Text "带代理的语音回复" `
  -Output outputs\reply.wav `
  -HttpProxy "http://127.0.0.1:7890" `
  -HttpsProxy "http://127.0.0.1:7890"
```

## Windows prerequisites

- Install Python 3.12+ and ensure `python` (or `py`) is available in terminal.
- Run PowerShell with script execution allowed for this command (the examples use `-ExecutionPolicy Bypass`).
- For China networks, keep default mirror settings or pass proxy values.

## Customer first-time usage

Yes. The script supports first-run model download automatically.
When customer runs synthesis the first time, model files are downloaded and cached locally, and later runs reuse cache.

Pre-download model only:

```bash
python3 scripts/qwen3_tts.py \
  --output outputs/placeholder.wav \
  --download-only \
  --cn-mirror
```

Use a fixed cache directory (recommended for customer deployment):

```bash
python3 scripts/qwen3_tts.py \
  --output outputs/placeholder.wav \
  --download-only \
  --cache-dir ./model_cache \
  --cn-mirror
```

Offline run after cache is prepared:

```bash
python3 scripts/qwen3_tts.py \
  --text "离线模式语音合成测试" \
  --output outputs/reply.wav \
  --cache-dir ./model_cache \
  --local-files-only
```

## Install runtime dependencies

Install Python package:

```bash
python3 -m pip install -U qwen-tts
```

In China, use a PyPI mirror:

```bash
python3 -m pip install -U qwen-tts -i https://pypi.tuna.tsinghua.edu.cn/simple
```

Install system dependencies:

```bash
# Ubuntu / Debian
sudo apt-get update
sudo apt-get install -y ffmpeg espeak-ng
```

## China-friendly model download

Use the built-in mirror flag:

```bash
python3 scripts/qwen3_tts.py --text "你好" --output outputs/reply.wav --cn-mirror
```

Or set endpoint directly:

```bash
export HF_ENDPOINT=https://hf-mirror.com
```

For customers, `--cn-mirror` is usually enough for first run.

## Proxy options

Pass proxy in command:

```bash
python3 scripts/qwen3_tts.py \
  --text "你好" \
  --output outputs/reply.wav \
  --http-proxy http://127.0.0.1:7890 \
  --https-proxy http://127.0.0.1:7890
```

Or use environment variables:

```bash
export HTTP_PROXY=http://127.0.0.1:7890
export HTTPS_PROXY=http://127.0.0.1:7890
```

## Common issues

- ImportError for `qwen_tts`: reinstall `qwen-tts` in the same Python environment used to run the script.
- Model download timeout: use `--cn-mirror` plus proxy.
- Missing audio backend tools: install `ffmpeg` and `espeak-ng`.
- Offline mode cannot find model: run `--download-only` first and keep `--cache-dir` consistent.
- Certain voice modes may depend on selected model capability. If `custom/design` fails, switch to `--voice-mode clone` with reference audio.
