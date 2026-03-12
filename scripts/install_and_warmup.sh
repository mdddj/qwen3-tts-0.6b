#!/usr/bin/env bash
set -euo pipefail

# One-step setup for customer machines:
# 1) create virtualenv
# 2) install qwen-tts (with optional China PyPI mirror)
# 3) pre-download model to local cache

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV_DIR="${ROOT_DIR}/.venv"
CACHE_DIR="${ROOT_DIR}/model_cache"
PYPI_INDEX_URL="${PYPI_INDEX_URL:-https://pypi.tuna.tsinghua.edu.cn/simple}"
USE_CN_MIRROR="${USE_CN_MIRROR:-1}"

echo "[1/4] create virtualenv: ${VENV_DIR}"
python3 -m venv "${VENV_DIR}"

echo "[2/4] install qwen-tts"
"${VENV_DIR}/bin/python" -m pip install -U pip
"${VENV_DIR}/bin/python" -m pip install -U qwen-tts -i "${PYPI_INDEX_URL}"

echo "[3/4] warm up model cache: ${CACHE_DIR}"
if [[ "${USE_CN_MIRROR}" == "1" ]]; then
  "${VENV_DIR}/bin/python" "${ROOT_DIR}/scripts/qwen3_tts.py" \
    --output "${ROOT_DIR}/outputs/placeholder.wav" \
    --download-only \
    --cache-dir "${CACHE_DIR}" \
    --cn-mirror
else
  "${VENV_DIR}/bin/python" "${ROOT_DIR}/scripts/qwen3_tts.py" \
    --output "${ROOT_DIR}/outputs/placeholder.wav" \
    --download-only \
    --cache-dir "${CACHE_DIR}"
fi

echo "[4/4] done"
echo "Run TTS with:"
echo "  ${VENV_DIR}/bin/python ${ROOT_DIR}/scripts/qwen3_tts.py --text '你好' --output ${ROOT_DIR}/outputs/reply.wav --cache-dir ${CACHE_DIR}"
