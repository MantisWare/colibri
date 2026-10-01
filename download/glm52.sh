#!/usr/bin/env bash
# GLM-5.2 group-scaled int4 with the int8 MTP head. Ready to run. About 372 GB.
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

usage() {
  cat <<'EOF'
Usage: ./download/glm52.sh [DEST]

Downloads mastouri/GLM-5.2-colibri-int4-g64-with-int8-mtp (~372 GB).
With no DEST, weights go to models/glm52. A second run resumes.

A gated repo needs a Hugging Face token: hf auth login, or HF_TOKEN.
EOF
}

take_dest glm52 "$@"
hf_snapshot "mastouri/GLM-5.2-colibri-int4-g64-with-int8-mtp" "$DEST"
