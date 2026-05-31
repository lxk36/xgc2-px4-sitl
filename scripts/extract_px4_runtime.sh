#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/manifest.sh
source "${SCRIPT_DIR}/lib/manifest.sh"

PX4_DIR="${PX4_DIR:-}"
OUTPUT_DIR="${OUTPUT_DIR:-${PWD}/runtime_stage}"
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
PX4_BIN="${BUILD_DIR}/bin/px4"
PX4_ALIAS="${BUILD_DIR}/bin/px4-alias.sh"
PX4_ETC="${BUILD_DIR}/etc"

if [[ -z "${OUTPUT_DIR}" || "${OUTPUT_DIR}" == "/" || "${OUTPUT_DIR}" == "/tmp" || "${OUTPUT_DIR}" == "${HOME}" ]]; then
  echo "unsafe --output-dir: ${OUTPUT_DIR}" >&2
  exit 1
fi

if [[ ! -x "${PX4_BIN}" ]]; then
  echo "missing PX4 binary: ${PX4_BIN}" >&2
  exit 1
fi

if [[ ! -f "${PX4_ALIAS}" ]]; then
  echo "missing PX4 alias script: ${PX4_ALIAS}" >&2
  exit 1
fi

if [[ ! -d "${PX4_ETC}" ]]; then
  echo "missing PX4 etc directory: ${PX4_ETC}" >&2
  exit 1
fi

rm -rf "${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}/bin"
install -m 0755 "${PX4_BIN}" "${OUTPUT_DIR}/bin/px4"
install -m 0644 "${PX4_ALIAS}" "${OUTPUT_DIR}/bin/px4-alias.sh"
find "${BUILD_DIR}/bin" -maxdepth 1 -type l -name 'px4-*' -exec cp -a {} "${OUTPUT_DIR}/bin/" \;
cp -a "${PX4_ETC}" "${OUTPUT_DIR}/etc"

find "${OUTPUT_DIR}" -name parameters.bson -o -name parameters_backup.bson -o -name dataman -o -name log | while read -r path; do
  rm -rf "${path}"
done

echo "${OUTPUT_DIR}"
