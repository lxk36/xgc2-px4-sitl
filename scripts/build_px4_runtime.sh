#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/manifest.sh
source "${SCRIPT_DIR}/lib/manifest.sh"

PX4_DIR="${PX4_DIR:-}"
BUILD_TARGET="$(require_manifest_value build_target)"
GAZEBO_BUILD_TARGET="$(manifest_value gazebo_build_target)"

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
    --gazebo-target)
      GAZEBO_BUILD_TARGET="$2"
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

make -C "${PX4_DIR}" "${BUILD_TARGET}"

if [[ -n "${GAZEBO_BUILD_TARGET}" ]]; then
  make -C "${PX4_DIR}" "${BUILD_TARGET}" "${GAZEBO_BUILD_TARGET}"
fi
