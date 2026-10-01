#!/usr/bin/env bash
# DeepSeek V4 Flash REAP 150B. Same engine, no conversion. About 85 GB.
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

usage() {
  cat <<'EOF'
Usage: ./download/deepseek-v4-reap.sh [DEST]

Downloads puwaer/DeepSeek-V4-Flash-0731-reap-150b (~85 GB).
The DeepSeek V4 engine reads it directly. With no DEST, weights go to
models/deepseek-v4-reap. A second run resumes.

A gated repo needs a Hugging Face token: hf auth login, or HF_TOKEN.
EOF
}

take_dest deepseek-v4-reap "$@"
hf_snapshot "puwaer/DeepSeek-V4-Flash-0731-reap-150b" "$DEST"
