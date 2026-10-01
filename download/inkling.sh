#!/usr/bin/env bash
# Inkling pre-converted int4 experts and bf16 dense weights. About 469 GB.
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

usage() {
  cat <<'EOF'
Usage: ./download/inkling.sh [DEST]

Downloads nbeerbower/Inkling-colibri-int4 (~469 GB).
With no DEST, weights go to models/inkling. A second run resumes.

A gated repo needs a Hugging Face token: hf auth login, or HF_TOKEN.
EOF
}

take_dest inkling "$@"
hf_snapshot "nbeerbower/Inkling-colibri-int4" "$DEST"
