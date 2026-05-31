#!/usr/bin/env bash
set -euo pipefail

RUNTIME_ROOT="${1:-${PX4_SITL_RUNTIME_ROOT:-}}"

if [[ -z "${RUNTIME_ROOT}" ]]; then
  echo "usage: check_px4_runtime.sh RUNTIME_ROOT" >&2
  exit 1
fi

test -x "${RUNTIME_ROOT}/bin/px4"
test -f "${RUNTIME_ROOT}/bin/px4-alias.sh"
test -f "${RUNTIME_ROOT}/etc/init.d-posix/rcS"
test -d "${RUNTIME_ROOT}/etc/init.d-posix/airframes"
test -d "${RUNTIME_ROOT}/etc/init.d"

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"' EXIT

(
  cd "${WORK_DIR}"
  export PATH="${RUNTIME_ROOT}/bin:${PATH}"
  export PX4_SIM_MODEL=shell
  set +e
  timeout 10 "${RUNTIME_ROOT}/bin/px4" "${RUNTIME_ROOT}/etc" -s etc/init.d-posix/rcS -d >/tmp/px4-runtime-smoke.log 2>&1
  set -e
  if ! grep -q "Startup script returned successfully" /tmp/px4-runtime-smoke.log; then
    cat /tmp/px4-runtime-smoke.log >&2
    exit 1
  fi
  if grep -Eq "not found|error binding socket|error connecting to socket" /tmp/px4-runtime-smoke.log; then
    cat /tmp/px4-runtime-smoke.log >&2
    exit 1
  fi
)

echo "PX4 runtime smoke check passed: ${RUNTIME_ROOT}"
