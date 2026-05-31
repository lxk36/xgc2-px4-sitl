#!/usr/bin/env bash
set -euo pipefail

RUNTIME_ROOT="${PX4_SITL_RUNTIME_ROOT:-/opt/ros/jazzy/share/px4_sitl_runtime_1_16/runtime}"
WORK_DIR="${PX4_SITL_WORK_DIR:-/tmp/px4_sitl_runtime/iris_0}"
INSTANCE="0"
STARTUP_SCRIPT="etc/init.d-posix/rcS"
EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --runtime-root)
      RUNTIME_ROOT="$2"
      shift 2
      ;;
    --work-dir)
      WORK_DIR="$2"
      shift 2
      ;;
    --instance)
      INSTANCE="$2"
      shift 2
      ;;
    --script)
      STARTUP_SCRIPT="$2"
      shift 2
      ;;
    --)
      shift
      EXTRA_ARGS+=("$@")
      break
      ;;
    *)
      EXTRA_ARGS+=("$1")
      shift
      ;;
  esac
done

PX4_BIN="${RUNTIME_ROOT}/bin/px4"
PX4_ETC="${RUNTIME_ROOT}/etc"

if [[ ! -x "${PX4_BIN}" ]]; then
  echo "PX4 binary is missing or not executable: ${PX4_BIN}" >&2
  exit 1
fi

if [[ ! -f "${PX4_ETC}/${STARTUP_SCRIPT}" ]]; then
  echo "PX4 startup script is missing: ${PX4_ETC}/${STARTUP_SCRIPT}" >&2
  exit 1
fi

mkdir -p "${WORK_DIR}"
cd "${WORK_DIR}"

export PATH="${RUNTIME_ROOT}/bin:${PATH}"

exec "${PX4_BIN}" "${PX4_ETC}" -s "${STARTUP_SCRIPT}" -i "${INSTANCE}" "${EXTRA_ARGS[@]}"
