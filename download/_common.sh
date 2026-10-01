# Shared helpers for the per-model scripts in this directory.
# Sourced by those scripts. Running this file on its own does nothing useful.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "Run one of the model scripts, for example ./download/glm52.sh DEST" >&2
  exit 1
fi

DOWNLOAD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$DOWNLOAD_DIR/.." && pwd)"

resolve_dest() {
  name="$1"
  given="${2:-}"
  if [[ -n "$given" ]]; then
    printf '%s\n' "$given"
    return 0
  fi
  if [[ -n "${COLI_MODELS:-}" ]]; then
    printf '%s\n' "${COLI_MODELS%/}/${name}"
    return 0
  fi
  printf '%s\n' "$ROOT/models/${name}"
}

abs_dir() {
  python3 -c 'import os, sys; print(os.path.abspath(sys.argv[1]))' "$1"
}

guard_dest() {
  dest="$1"
  case "$dest" in
    "$ROOT/models"|"$ROOT/models"/*)
      return 0
      ;;
    "$ROOT"|"$ROOT"/*)
      echo "Refusing to write weights inside the colibri checkout:" >&2
      echo "  ${dest}" >&2
      echo "The default directory is models/. Pass a path outside the checkout to use another disk." >&2
      exit 2
      ;;
  esac
}

# Homebrew Python refuses system-wide pip (PEP 668). Packages for these
# scripts live in the checkout's .venv.
DOWNLOAD_PYTHON=""

ensure_download_python() {
  venv="$ROOT/.venv"
  py="$venv/bin/python"
  if [[ ! -x "$py" ]]; then
    echo "creating .venv"
    python3 -m venv "$venv"
  fi
  DOWNLOAD_PYTHON="$py"
  if [[ $# -eq 0 ]]; then
    return 0
  fi
  missing="$("$py" -c '
import importlib.util
import sys
names = [name for name in sys.argv[1:] if importlib.util.find_spec(name) is None]
if names:
    sys.stdout.write(" ".join(names))
' "$@")"
  if [[ -n "$missing" ]]; then
    echo "installing into .venv: ${missing}"
    "$py" -m pip install $missing
  fi
}

# Sets DEST. The caller defines usage(). Exits on --help, a missing
# destination, or a destination inside this checkout.
take_dest() {
  name="$1"
  shift
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
  fi
  if [[ $# -gt 1 ]]; then
    echo "too many arguments" >&2
    usage >&2
    exit 2
  fi
  if ! picked="$(resolve_dest "$name" "${1:-}")"; then
    usage >&2
    exit 2
  fi
  DEST="$(abs_dir "$picked")"
  guard_dest "$DEST"
  mkdir -p "$DEST"
}

hf_snapshot() {
  repo="$1"
  dest="$2"
  revision="${3:-}"
  allow="${4:-}"
  ignore="${5:-}"
  echo "downloading ${repo}"
  echo "  -> ${dest}"
  if [[ -n "$revision" ]]; then
    echo "  revision ${revision}"
  fi
  if [[ -n "$allow" ]]; then
    echo "  include ${allow}"
  fi
  if [[ -n "$ignore" ]]; then
    echo "  skip ${ignore}"
  fi
  echo "  a second run resumes"
  ensure_download_python huggingface_hub
  "$DOWNLOAD_PYTHON" - "$repo" "$dest" "$revision" "$allow" "$ignore" <<'PY'
import sys
from huggingface_hub import snapshot_download
repo, dest, revision, allow, ignore = sys.argv[1:6]
kwargs = {"repo_id": repo, "local_dir": dest}
if revision:
    kwargs["revision"] = revision
if allow:
    kwargs["allow_patterns"] = [part for part in allow.split(",") if part]
if ignore:
    kwargs["ignore_patterns"] = [part for part in ignore.split(",") if part]
snapshot_download(**kwargs)
PY
  if [[ "${HF_SNAPSHOT_QUIET_READY:-}" != "1" ]]; then
    echo "ready: ${dest}"
    echo "  ./start.sh --model ${dest}"
  fi
}
