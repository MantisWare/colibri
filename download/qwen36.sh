#!/usr/bin/env bash
# Qwen3.6 group-scaled int4 container. Ready to run. About 20 GB.
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

usage() {
  cat <<'EOF'
Usage: ./download/qwen36.sh [DEST]

Downloads Kreuzzelg/qwen36-35b-a3b-colibri-i4-gs64 (~20 GB).
With no DEST, weights go to models/qwen36. A second run resumes.

A gated repo needs a Hugging Face token: hf auth login, or HF_TOKEN.
EOF
}

take_dest qwen36 "$@"
hf_snapshot "Kreuzzelg/qwen36-35b-a3b-colibri-i4-gs64" "$DEST"
