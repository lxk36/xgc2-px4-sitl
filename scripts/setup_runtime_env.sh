#!/usr/bin/env bash
set -euo pipefail

RUNTIME_ROOT="${PX4_SITL_RUNTIME_ROOT:-/opt/ros/noetic/share/px4_sitl_1_14/runtime}"

export PX4_SITL_RUNTIME_ROOT="${RUNTIME_ROOT}"
export PATH="${PX4_SITL_RUNTIME_ROOT}/bin:${PATH}"

echo "PX4_SITL_RUNTIME_ROOT=${PX4_SITL_RUNTIME_ROOT}"
