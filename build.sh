#!/usr/bin/env bash
# Build colibrì from the repository root and, optionally, run the model-free tests.
#
#   ./build.sh                  native GLM engine (c/colibri)
#   ./build.sh --metal          same build, with the Apple Metal backend
#   ./build.sh --test           build, then run the dependency-free test suite
#   ./build.sh qwen36           one family (a c/Makefile target)
#   ./build.sh --all            every engine this machine can build
#
# ARCH defaults to native so the binary uses this CPU's vector instructions.
# Override it when you want a portable binary:  ARCH= ./build.sh
# (empty ARCH is the Makefile's portable macOS baseline).
#
# `make check` is the CI gate: it deletes the tree and rebuilds a portable
# binary. This script keeps the native binary you can actually run.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

usage() {
  cat <<'EOF'
Usage: ./build.sh [options] [target ...]

Options:
  --metal     Apple GPU backend (macOS only). Run later with COLI_METAL=1.
  --test      After the build, run `make -C c test` (no model download).
  --all       Build every engine this platform supports.
  -h, --help  Show this help.

Targets (default: colibri, the GLM-5.2/5.3 engine):
  colibri  glm53  inkling  kimi_k3  olmoe  qwen36  qwen38  deepseek_v41  deepseek-v4

Examples:
  ./build.sh
  ./build.sh --metal --test
  ./build.sh qwen36
  ARCH=native ./build.sh --all
EOF
}

METAL=0
RUN_TEST=0
BUILD_ALL=0
TARGETS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --metal) METAL=1 ;;
    --test) RUN_TEST=1 ;;
    --all) BUILD_ALL=1 ;;
    --) shift; break ;;
    -*) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
    *) TARGETS+=("$1") ;;
  esac
  shift
done

if [[ "$BUILD_ALL" -eq 1 && ${#TARGETS[@]} -gt 0 ]]; then
  echo "--all builds every engine; do not also name targets." >&2
  exit 2
fi

UNAME_S="$(uname -s)"
UNAME_M="$(uname -m)"

v4_supported() {
  case "$UNAME_M" in
    x86_64|amd64)
      case "$UNAME_S" in
        Linux|MINGW*|MSYS*) return 0 ;;
      esac
      ;;
    aarch64|arm64)
      case "$UNAME_S" in
        Linux|Darwin) return 0 ;;
      esac
      ;;
  esac
  return 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "$1 is missing. $2" >&2
    exit 1
  }
}

omp_probe=""
cleanup_omp_probe() {
  if [[ -n "$omp_probe" ]]; then
    rm -f "$omp_probe" "${omp_probe}.exe"
  fi
}
trap cleanup_omp_probe EXIT

echo "colibri — build"

require_cmd make "Install make (Xcode command line tools, build-essential, or MSYS2)."
require_cmd python3 "The coli launcher and the test suite need Python 3."

case "$UNAME_S" in
  Darwin)
    require_cmd clang "Install the Xcode command line tools: xcode-select --install"
    clang_ver="$(clang --version)"
    echo "  clang: ${clang_ver%%$'\n'*}"
    omp_ok=0
    if [[ -n "${OMPDIR:-}" && -f "${OMPDIR}/lib/libomp.dylib" ]]; then
      omp_ok=1
    fi
    if [[ "$omp_ok" -eq 0 ]] && command -v brew >/dev/null 2>&1; then
      brew_omp="$(brew --prefix libomp 2>/dev/null || true)"
      if [[ -n "$brew_omp" && -f "${brew_omp}/lib/libomp.dylib" ]]; then
        omp_ok=1
      fi
    fi
    if [[ "$omp_ok" -eq 0 ]]; then
      for prefix in /opt/homebrew/opt/libomp /usr/local/opt/libomp; do
        if [[ -f "${prefix}/lib/libomp.dylib" ]]; then
          omp_ok=1
          break
        fi
      done
    fi
    if [[ "$omp_ok" -eq 0 && -f /opt/local/lib/libomp/libomp.dylib ]]; then
      omp_ok=1
    fi
    if [[ "$omp_ok" -eq 1 ]]; then
      echo "  OpenMP: ok (libomp)"
    else
      echo "  OpenMP: libomp is missing — this build will be single-threaded."
      echo "          Install it with: brew install libomp"
    fi
    if [[ "$METAL" -eq 1 ]]; then
      echo "  Metal: on"
    fi
    ;;
  MINGW*|MSYS*)
    require_cmd gcc "Install MinGW-w64 gcc (pacman -S mingw-w64-ucrt-x86_64-gcc make)."
    echo "  gcc: $(gcc -dumpversion) · MinGW-w64"
    omp_probe="${TMPDIR:-/tmp}/colibri-omp-probe-$$"
    echo -n "  OpenMP: "
    echo 'int main(){return 0;}' | gcc -fopenmp -xc - -o "$omp_probe" 2>/dev/null \
      && echo ok \
      || { echo "libgomp is missing"; exit 1; }
    ;;
  *)
    require_cmd gcc "Install a C compiler (for example: sudo apt install build-essential)."
    cores="$(nproc 2>/dev/null || echo "?")"
    echo "  gcc: $(gcc -dumpversion) · ${cores} cores"
    omp_probe="${TMPDIR:-/tmp}/colibri-omp-probe-$$"
    echo -n "  OpenMP: "
    echo 'int main(){return 0;}' | gcc -fopenmp -xc - -o "$omp_probe" 2>/dev/null \
      && echo ok \
      || { echo "libgomp is missing"; exit 1; }
    ;;
esac

if [[ "$METAL" -eq 1 && "$UNAME_S" != "Darwin" ]]; then
  echo "METAL=1 is supported only on macOS." >&2
  exit 1
fi

cleanup_omp_probe
trap - EXIT

if [[ "$BUILD_ALL" -eq 1 ]]; then
  TARGETS=(colibri glm53 inkling kimi_k3 olmoe qwen36 qwen38 deepseek_v41)
  if v4_supported; then
    TARGETS+=(deepseek-v4)
  else
    echo "  skipping deepseek-v4 (not supported on ${UNAME_S} ${UNAME_M})"
  fi
elif [[ ${#TARGETS[@]} -eq 0 ]]; then
  TARGETS=(colibri)
fi

known=" colibri glm glm53 inkling kimi_k3 olmoe qwen36 qwen38 deepseek_v41 deepseek-v4 "
for target in "${TARGETS[@]}"; do
  case "$known" in
    *" ${target} "*) ;;
    *)
      echo "unknown target: ${target}" >&2
      echo "known targets:${known}" >&2
      exit 2
      ;;
  esac
  if [[ "$target" == "deepseek-v4" ]] && ! v4_supported; then
    echo "deepseek-v4 is supported on x86-64 Linux/Windows and arm64 Linux/macOS." >&2
    exit 1
  fi
done

if [[ -n "${JOBS:-}" ]]; then
  jobs="$JOBS"
else
  case "$UNAME_S" in
    Darwin) jobs="$(sysctl -n hw.ncpu)" ;;
    *) jobs="$(nproc 2>/dev/null || echo 1)" ;;
  esac
fi

arch_value="${ARCH-native}"
echo "  building: ${TARGETS[*]}"
echo "  ARCH=${arch_value:-<portable>}  METAL=${METAL}  -j${jobs}"

make -C "$ROOT/c" -j"$jobs" \
  ARCH="$arch_value" \
  METAL="$METAL" \
  "${TARGETS[@]}"

built_colibri=0
for target in "${TARGETS[@]}"; do
  if [[ "$target" == "colibri" || "$target" == "glm" ]]; then
    built_colibri=1
  fi
done

if [[ "$built_colibri" -eq 1 && -d "$ROOT/c/glm_tiny" && -f "$ROOT/c/ref_glm.json" ]]; then
  echo "  engine self-test…"
  result="$(
    cd "$ROOT/c" && \
      SNAP=./glm_tiny TF=1 ./colibri 64 16 16 2>/dev/null \
        | grep -oE "[0-9]+/[0-9]+ positions" || true
  )"
  echo "  engine self-test: ${result:-?}  (expected ~30-32/32; FP near-ties are toolchain-dependent)"
fi

if [[ "$RUN_TEST" -eq 1 ]]; then
  echo "  tests (no model required)…"
  make -C "$ROOT/c" -j"$jobs" \
    ARCH="$arch_value" \
    METAL="$METAL" \
    test
fi

echo
echo "ready."
echo "  launcher:  ./c/coli"
if [[ "$built_colibri" -eq 1 && -x "$ROOT/c/colibri" ]]; then
  echo "  engine:    c/colibri"
fi
echo
echo "A model directory is separate from this build (hundreds of GB). Then:"
echo "  COLI_MODEL=/path/to/model ./c/coli doctor"
echo "  COLI_MODEL=/path/to/model ./c/coli chat"
if [[ "$METAL" -eq 1 ]]; then
  echo "  COLI_METAL=1 COLI_MODEL=/path/to/model ./c/coli chat"
fi
if [[ "$RUN_TEST" -eq 0 ]]; then
  echo
  echo "Model-free tests:  ./build.sh --test"
fi
