#!/usr/bin/env bash
set -euo pipefail

PX4_DIR="${PX4_DIR:-}"
OUTPUT_DIR="${OUTPUT_DIR:-${PWD}/gz_sim_runtime_stage}"

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
    *)
      echo "unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

GZ_SOURCE_DIR="${PX4_DIR}/Tools/simulation/gz"

if [[ -z "${OUTPUT_DIR}" || "${OUTPUT_DIR}" == "/" || "${OUTPUT_DIR}" == "/tmp" || "${OUTPUT_DIR}" == "${HOME}" ]]; then
  echo "unsafe --output-dir: ${OUTPUT_DIR}" >&2
  exit 1
fi

if [[ ! -d "${GZ_SOURCE_DIR}" ]]; then
  echo "missing Gazebo Sim source directory: ${GZ_SOURCE_DIR}" >&2
  exit 1
fi

rm -rf "${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}"

cp -a "${GZ_SOURCE_DIR}/models" "${OUTPUT_DIR}/models"
cp -a "${GZ_SOURCE_DIR}/worlds" "${OUTPUT_DIR}/worlds"
install -m 0644 "${GZ_SOURCE_DIR}/server.config" "${OUTPUT_DIR}/server.config"
install -m 0755 "${GZ_SOURCE_DIR}/simulation-gazebo" "${OUTPUT_DIR}/simulation-gazebo"

test -f "${OUTPUT_DIR}/models/x500/model.sdf"
test -f "${OUTPUT_DIR}/worlds/default.sdf"
test -f "${OUTPUT_DIR}/server.config"
test -x "${OUTPUT_DIR}/simulation-gazebo"

echo "${OUTPUT_DIR}"
