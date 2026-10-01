#!/usr/bin/env bash
# Kimi K3 original checkpoint. No conversion. About 1.6 TB.
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

usage() {
  cat <<'EOF'
Usage: ./download/kimi-k3.sh [DEST]

Downloads moonshotai/Kimi-K3 (~1.6 TB). The engine reads this checkpoint
directly. With no DEST, weights go to models/kimi-k3. A second run resumes.

A gated repo needs a Hugging Face token: hf auth login, or HF_TOKEN.
EOF
}

take_dest kimi-k3 "$@"
hf_snapshot "moonshotai/Kimi-K3" "$DEST"
