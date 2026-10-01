#!/usr/bin/env bash
# DeepSeek V4.1 Flash official checkpoint, then the engram sidecar. About 510 GB.
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

usage() {
  cat <<'EOF'
Usage: ./download/deepseek-v41.sh [DEST]

Downloads deepseek-ai/DeepSeek-V4.1-Flash (~510 GB), then writes
dsv41_engram.json beside config.json. With no DEST, weights go to
models/deepseek-v41. A second run resumes the download.

The sidecar step installs transformers, tokenizers, and numpy into .venv.
A gated repo needs a Hugging Face token: hf auth login, or HF_TOKEN.
EOF
}

take_dest deepseek-v41 "$@"
ensure_download_python transformers tokenizers numpy
HF_SNAPSHOT_QUIET_READY=1 hf_snapshot "deepseek-ai/DeepSeek-V4.1-Flash" "$DEST"
"$DOWNLOAD_PYTHON" "$ROOT/c/tools/prepare_dsv41.py" --model "$DEST"
echo "ready: ${DEST}"
echo "  ./start.sh --model ${DEST}"
