#!/usr/bin/env bash
# Qwen3.8-Flash-Next FP8 official checkpoint. No conversion. About 185 GB.
# Revision pinned in docs/qwen38.md.
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

REVISION="bcd9f01ddc9cff2316eb84281bebcd5b058bddce"

usage() {
  cat <<EOF
Usage: ./download/qwen38.sh [DEST]

Downloads Qwen/Qwen3.8-Flash-Next-FP8 (~185 GB), pinned to
revision ${REVISION}. The engine reads this checkpoint directly.
With no DEST, weights go to models/qwen38. A second run resumes.

A gated repo needs a Hugging Face token: hf auth login, or HF_TOKEN.
EOF
}

take_dest qwen38 "$@"
hf_snapshot "Qwen/Qwen3.8-Flash-Next-FP8" "$DEST" "$REVISION"
