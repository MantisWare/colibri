#!/usr/bin/env bash
# DeepSeek V4 Flash official checkpoint. No conversion. About 167 GB.
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

usage() {
  cat <<'EOF'
Usage: ./download/deepseek-v4.sh [DEST]

Downloads deepseek-ai/DeepSeek-V4-Flash-0731 (~167 GB).
The engine reads this checkpoint directly. With no DEST, weights go to
models/deepseek-v4. A second run resumes.

The smaller REAP-pruned checkpoint is ./download/deepseek-v4-reap.sh.
A gated repo needs a Hugging Face token: hf auth login, or HF_TOKEN.
EOF
}

take_dest deepseek-v4 "$@"
hf_snapshot "deepseek-ai/DeepSeek-V4-Flash-0731" "$DEST"
