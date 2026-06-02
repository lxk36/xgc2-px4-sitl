#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.xgc2/scripts/lib/manifest.sh
source "${SCRIPT_DIR}/lib/manifest.sh"

PX4_DIR="${PX4_DIR:-}"
BUILD_TARGET="$(require_manifest_value build_target)"
PX4_CMAKE_BUILD_TYPE="${PX4_CMAKE_BUILD_TYPE:-$(manifest_value px4_cmake_build_type)}"
OPTIMIZATION_LEVEL="${OPTIMIZATION_LEVEL:-$(manifest_value optimization_level)}"
PX4_CMAKE_BUILD_TYPE="${PX4_CMAKE_BUILD_TYPE:-RelWithDebInfo}"
OPTIMIZATION_LEVEL="${OPTIMIZATION_LEVEL:-O3}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --px4-dir)
      PX4_DIR="$2"
      shift 2
      ;;
    --target)
      BUILD_TARGET="$2"
      shift 2
      ;;
    *)
      echo "unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "${PX4_DIR}" || ! -d "${PX4_DIR}" ]]; then
  echo "--px4-dir is required and must point to a PX4-Autopilot checkout" >&2
  exit 1
fi

export PX4_CMAKE_BUILD_TYPE
export CFLAGS="${CFLAGS:-} -${OPTIMIZATION_LEVEL} -DNDEBUG"
export CXXFLAGS="${CXXFLAGS:-} -${OPTIMIZATION_LEVEL} -DNDEBUG"

echo "PX4 build type: ${PX4_CMAKE_BUILD_TYPE}"
echo "PX4 optimization level: -${OPTIMIZATION_LEVEL}"

make -C "${PX4_DIR}" "${BUILD_TARGET}"
