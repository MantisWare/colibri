#!/usr/bin/env bash
# GLM-5.3 group-scaled int4. Same engine as GLM-5.2, no MTP head. About 419 GB.
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

usage() {
  cat <<'EOF'
Usage: ./download/glm53.sh [DEST]

Downloads Justvugg/GLM-5.3-colibri-int4-g64 (~419 GB).
With no DEST, weights go to models/glm53. A second run resumes.

This container has no MTP head, so speculative decoding stays off.
A gated repo needs a Hugging Face token: hf auth login, or HF_TOKEN.
EOF
}

take_dest glm53 "$@"
hf_snapshot "Justvugg/GLM-5.3-colibri-int4-g64" "$DEST"
