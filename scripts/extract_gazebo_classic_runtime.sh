#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/manifest.sh
source "${SCRIPT_DIR}/lib/manifest.sh"

PX4_DIR="${PX4_DIR:-}"
OUTPUT_DIR="${OUTPUT_DIR:-${PWD}/gazebo_runtime_stage}"
BUILD_TARGET="$(require_manifest_value build_target)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --px4-dir)
      PX4_DIR="$2"
      shift 2
      ;;
    --output-dir)
      OUTPUT_DIR="$2"
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

BUILD_DIR="${PX4_DIR}/build/${BUILD_TARGET}"

if [[ -d "${BUILD_DIR}/build_gazebo-classic" ]]; then
  GAZEBO_BUILD_DIR="${BUILD_DIR}/build_gazebo-classic"
elif [[ -d "${BUILD_DIR}/build_gazebo" ]]; then
  GAZEBO_BUILD_DIR="${BUILD_DIR}/build_gazebo"
else
  GAZEBO_BUILD_DIR="${BUILD_DIR}/build_gazebo-classic"
fi

if [[ -d "${PX4_DIR}/Tools/simulation/gazebo-classic/sitl_gazebo-classic" ]]; then
  GAZEBO_SOURCE_DIR="${PX4_DIR}/Tools/simulation/gazebo-classic/sitl_gazebo-classic"
elif [[ -d "${PX4_DIR}/Tools/sitl_gazebo" ]]; then
  GAZEBO_SOURCE_DIR="${PX4_DIR}/Tools/sitl_gazebo"
else
  GAZEBO_SOURCE_DIR="${PX4_DIR}/Tools/simulation/gazebo-classic/sitl_gazebo-classic"
fi

if [[ -z "${OUTPUT_DIR}" || "${OUTPUT_DIR}" == "/" || "${OUTPUT_DIR}" == "/tmp" || "${OUTPUT_DIR}" == "${HOME}" ]]; then
  echo "unsafe --output-dir: ${OUTPUT_DIR}" >&2
  exit 1
fi

if [[ ! -d "${GAZEBO_SOURCE_DIR}" ]]; then
  echo "missing Gazebo Classic source directory: ${GAZEBO_SOURCE_DIR}" >&2
  exit 1
fi

if [[ ! -d "${GAZEBO_BUILD_DIR}" ]]; then
  echo "missing Gazebo Classic build directory: ${GAZEBO_BUILD_DIR}" >&2
  exit 1
fi

rm -rf "${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}/lib"

find "${GAZEBO_BUILD_DIR}" -maxdepth 1 -type f -name '*.so' -exec cp -a {} "${OUTPUT_DIR}/lib/" \;
cp -a "${GAZEBO_SOURCE_DIR}/models" "${OUTPUT_DIR}/models"
cp -a "${GAZEBO_SOURCE_DIR}/worlds" "${OUTPUT_DIR}/worlds"

if [[ -d "${GAZEBO_SOURCE_DIR}/launch" ]]; then
  cp -a "${GAZEBO_SOURCE_DIR}/launch" "${OUTPUT_DIR}/launch"
fi

if [[ -f "${GAZEBO_SOURCE_DIR}/package.xml" ]]; then
  cp -a "${GAZEBO_SOURCE_DIR}/package.xml" "${OUTPUT_DIR}/package.xml"
fi

if ! find "${OUTPUT_DIR}/lib" -maxdepth 1 -type f -name '*.so' | grep -q .; then
  echo "no Gazebo Classic plugin libraries were extracted from ${GAZEBO_BUILD_DIR}" >&2
  exit 1
fi

test -f "${OUTPUT_DIR}/models/iris/iris.sdf"
test -f "${OUTPUT_DIR}/worlds/empty.world"

echo "${OUTPUT_DIR}"
