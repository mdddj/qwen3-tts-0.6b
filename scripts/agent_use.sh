#!/usr/bin/env bash
set -euo pipefail

# Agent-friendly wrapper:
# - if runtime is missing, install it
# - if model cache is missing, warm it up
# - run TTS generation

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV_DIR="${ROOT_DIR}/.venv"
PYTHON_BIN="${VENV_DIR}/bin/python"
CACHE_DIR="${ROOT_DIR}/model_cache"
MODEL_ID="Qwen/Qwen3-TTS-12Hz-0.6B-Base"
TEXT=""
OUTPUT=""
USE_CN_MIRROR=1
HTTP_PROXY_URL=""
HTTPS_PROXY_URL=""
PROXY_ARGS=()
VOICE_MODE="auto"
SPEAKER=""
INSTRUCT=""
SPK_AUDIO=""
SPK_TEXT=""
LANGUAGE=""
VOICE_ARGS=()

usage() {
  cat <<'EOF'
Usage:
  bash scripts/agent_use.sh --text "你好" --output outputs/reply.wav [options]

Options:
  --text <text>                 Text to synthesize
  --output <path>               Output wav path
  --cache-dir <dir>             Model cache dir (default: ./model_cache)
  --model-id <id>               Hugging Face model id
  --voice-mode <mode>           auto|base|clone|custom|design
  --speaker <name>              Speaker name for custom mode
  --instruct <text>             Style instruction for custom/design mode
  --spk-audio <path>            Reference audio for clone mode
  --spk-text <text>             Transcript for reference audio in clone mode
  --language <lang>             Optional language hint for clone mode
  --no-cn-mirror                Disable HF mirror shortcut
  --http-proxy <url>            HTTP proxy
  --https-proxy <url>           HTTPS proxy
  --help                        Show help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --text)
      TEXT="${2:-}"
      shift 2
      ;;
    --output)
      OUTPUT="${2:-}"
      shift 2
      ;;
    --cache-dir)
      CACHE_DIR="${2:-}"
      shift 2
      ;;
    --model-id)
      MODEL_ID="${2:-}"
      shift 2
      ;;
    --voice-mode)
      VOICE_MODE="${2:-}"
      shift 2
      ;;
    --speaker)
      SPEAKER="${2:-}"
      shift 2
      ;;
    --instruct)
      INSTRUCT="${2:-}"
      shift 2
      ;;
    --spk-audio)
      SPK_AUDIO="${2:-}"
      shift 2
      ;;
    --spk-text)
      SPK_TEXT="${2:-}"
      shift 2
      ;;
    --language)
      LANGUAGE="${2:-}"
      shift 2
      ;;
    --no-cn-mirror)
      USE_CN_MIRROR=0
      shift
      ;;
    --http-proxy)
      HTTP_PROXY_URL="${2:-}"
      shift 2
      ;;
    --https-proxy)
      HTTPS_PROXY_URL="${2:-}"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown arg: $1" >&2
      usage
      exit 2
      ;;
  esac
done

if [[ -z "${TEXT}" || -z "${OUTPUT}" ]]; then
  echo "error: --text and --output are required." >&2
  usage
  exit 2
fi

if [[ ! -x "${PYTHON_BIN}" ]]; then
  echo "info: runtime missing, running install_and_warmup.sh ..."
  bash "${ROOT_DIR}/scripts/install_and_warmup.sh"
fi

if ! "${PYTHON_BIN}" -c "import qwen_tts" >/dev/null 2>&1; then
  echo "info: qwen-tts not found in venv, installing ..."
  "${PYTHON_BIN}" -m pip install -U qwen-tts -i "${PYPI_INDEX_URL:-https://pypi.tuna.tsinghua.edu.cn/simple}"
fi

mkdir -p "${CACHE_DIR}"

if [[ -n "${HTTP_PROXY_URL}" ]]; then
  PROXY_ARGS+=(--http-proxy "${HTTP_PROXY_URL}")
fi
if [[ -n "${HTTPS_PROXY_URL}" ]]; then
  PROXY_ARGS+=(--https-proxy "${HTTPS_PROXY_URL}")
fi
if [[ -n "${VOICE_MODE}" ]]; then
  VOICE_ARGS+=(--voice-mode "${VOICE_MODE}")
fi
if [[ -n "${SPEAKER}" ]]; then
  VOICE_ARGS+=(--speaker "${SPEAKER}")
fi
if [[ -n "${INSTRUCT}" ]]; then
  VOICE_ARGS+=(--instruct "${INSTRUCT}")
fi
if [[ -n "${SPK_AUDIO}" ]]; then
  VOICE_ARGS+=(--spk-audio "${SPK_AUDIO}")
fi
if [[ -n "${SPK_TEXT}" ]]; then
  VOICE_ARGS+=(--spk-text "${SPK_TEXT}")
fi
if [[ -n "${LANGUAGE}" ]]; then
  VOICE_ARGS+=(--language "${LANGUAGE}")
fi

if [[ ! -d "${CACHE_DIR}/hub" ]]; then
  echo "info: model cache missing, pre-downloading ..."
  if [[ "${USE_CN_MIRROR}" == "1" ]]; then
    "${PYTHON_BIN}" "${ROOT_DIR}/scripts/qwen3_tts.py" \
      --output "${ROOT_DIR}/outputs/placeholder.wav" \
      --download-only \
      --cache-dir "${CACHE_DIR}" \
      --cn-mirror \
      "${PROXY_ARGS[@]}"
  else
    "${PYTHON_BIN}" "${ROOT_DIR}/scripts/qwen3_tts.py" \
      --output "${ROOT_DIR}/outputs/placeholder.wav" \
      --download-only \
      --cache-dir "${CACHE_DIR}" \
      "${PROXY_ARGS[@]}"
  fi
fi

if [[ "${USE_CN_MIRROR}" == "1" ]]; then
  "${PYTHON_BIN}" "${ROOT_DIR}/scripts/qwen3_tts.py" \
    --text "${TEXT}" \
    --output "${OUTPUT}" \
    --cache-dir "${CACHE_DIR}" \
    --model-id "${MODEL_ID}" \
    --cn-mirror \
    "${PROXY_ARGS[@]}" \
    "${VOICE_ARGS[@]}"
else
  "${PYTHON_BIN}" "${ROOT_DIR}/scripts/qwen3_tts.py" \
    --text "${TEXT}" \
    --output "${OUTPUT}" \
    --cache-dir "${CACHE_DIR}" \
    --model-id "${MODEL_ID}" \
    "${PROXY_ARGS[@]}" \
    "${VOICE_ARGS[@]}"
fi
