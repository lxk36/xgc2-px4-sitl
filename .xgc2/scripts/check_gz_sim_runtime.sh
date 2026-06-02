#!/usr/bin/env bash
set -euo pipefail

GZ_SIM_ROOT="${1:-${PX4_GZ_SIM_ROOT:-}}"

if [[ -z "${GZ_SIM_ROOT}" ]]; then
  echo "usage: check_gz_sim_runtime.sh GZ_SIM_ROOT" >&2
  exit 1
fi

test -d "${GZ_SIM_ROOT}/models"
test -d "${GZ_SIM_ROOT}/worlds"
test -f "${GZ_SIM_ROOT}/models/x500/model.sdf"
test -f "${GZ_SIM_ROOT}/worlds/default.sdf"
test -f "${GZ_SIM_ROOT}/server.config"
test -x "${GZ_SIM_ROOT}/simulation-gazebo"

if command -v gz >/dev/null 2>&1; then
  gz sim --versions >/tmp/px4-gz-sim-versions.log 2>&1
fi

echo "Gazebo Sim runtime check passed: ${GZ_SIM_ROOT}"
