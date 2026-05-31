#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/manifest.sh
source "${SCRIPT_DIR}/lib/manifest.sh"

REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DOCKER_IMAGE="$(require_manifest_value docker_image)"
WORK_DIR="${PX4_DOCKER_WORK_DIR:-${REPO_ROOT}/.work/docker}"
OUTPUT_DIR="${PX4_DOCKER_OUTPUT_DIR:-${REPO_ROOT}/debs}"
PULL_IMAGE=true
INSTALL_CHECK=true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --image)
      DOCKER_IMAGE="$2"
      shift 2
      ;;
    --work-dir)
      WORK_DIR="$2"
      shift 2
      ;;
    --output-dir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --no-pull)
      PULL_IMAGE=false
      shift
      ;;
    --skip-install-check)
      INSTALL_CHECK=false
      shift
      ;;
    *)
      echo "unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

mkdir -p "${WORK_DIR}" "${OUTPUT_DIR}"

if [[ "${PULL_IMAGE}" == "true" ]]; then
  docker pull "${DOCKER_IMAGE}"
fi

docker run --rm \
  -e DEBIAN_FRONTEND=noninteractive \
  -e INSTALL_CHECK="${INSTALL_CHECK}" \
  -v "${REPO_ROOT}:/workspace/px4_sitl_runtime:ro" \
  -v "${WORK_DIR}:/workspace/work" \
  -v "${OUTPUT_DIR}:/workspace/out" \
  "${DOCKER_IMAGE}" \
  bash -lc '
    set -euo pipefail

    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y --no-install-recommends \
      ca-certificates \
      dpkg-dev \
      git \
      gnupg \
      lsb-release \
      sudo \
      wget

    cd /workspace/px4_sitl_runtime
    PX4_DIR="$(scripts/fetch_px4.sh --work-dir /workspace/work)"

    if [[ -x "${PX4_DIR}/Tools/setup/ubuntu.sh" ]]; then
      bash "${PX4_DIR}/Tools/setup/ubuntu.sh" --no-nuttx
    fi

    scripts/build_px4_runtime.sh --px4-dir "${PX4_DIR}"
    scripts/extract_px4_runtime.sh --px4-dir "${PX4_DIR}" --output-dir /workspace/work/runtime-stage
    scripts/check_px4_runtime.sh /workspace/work/runtime-stage
    scripts/build_deb.sh --runtime-dir /workspace/work/runtime-stage --output-dir /workspace/out

    if [[ "${INSTALL_CHECK}" == "true" ]]; then
      apt-get install -y /workspace/out/*.deb
      source scripts/lib/manifest.sh
      INSTALL_PREFIX="$(manifest_value install_prefix)"
      scripts/check_px4_runtime.sh "${INSTALL_PREFIX}"
    fi
  '

echo "Debian package output:"
find "${OUTPUT_DIR}" -maxdepth 1 -type f -name "*.deb" -print | sort
