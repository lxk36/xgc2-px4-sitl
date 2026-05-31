#!/usr/bin/env bash
set -euo pipefail

RUNTIME_ROOT="${PX4_SITL_RUNTIME_ROOT:-/opt/ros/jazzy/share/px4_sitl_runtime_1_16/runtime}"
GZ_SIM_ROOT="${PX4_GZ_SIM_ROOT:-/opt/ros/jazzy/share/px4_gz_sim_1_16}"
GZ_SIM_BIN="${PX4_GZ_SIM_BIN:-/opt/ros/jazzy/lib/px4_gz_sim_1_16}"

export PX4_SITL_RUNTIME_ROOT="${RUNTIME_ROOT}"
export PX4_GZ_SIM_ROOT="${GZ_SIM_ROOT}"
export PX4_GZ_SIM_BIN="${GZ_SIM_BIN}"
export GZ_SIM_RESOURCE_PATH="${PX4_GZ_SIM_ROOT}/models:${GZ_SIM_RESOURCE_PATH:-}"
export GZ_SIM_SERVER_CONFIG_PATH="${PX4_GZ_SIM_ROOT}/server.config"
export PATH="${PX4_SITL_RUNTIME_ROOT}/bin:${PX4_GZ_SIM_BIN}:${PATH}"

echo "PX4_SITL_RUNTIME_ROOT=${PX4_SITL_RUNTIME_ROOT}"
echo "PX4_GZ_SIM_ROOT=${PX4_GZ_SIM_ROOT}"
echo "PX4_GZ_SIM_BIN=${PX4_GZ_SIM_BIN}"
