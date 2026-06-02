#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.xgc2/scripts/lib/manifest.sh
source "${SCRIPT_DIR}/lib/manifest.sh"

DEB_DIR="${DEB_DIR:-${PWD}/debs}"
REPO_DIR="${REPO_DIR:-${PWD}/.work/local-apt-repo}"
APT_DISTRIBUTION="${APT_DISTRIBUTION:-$(require_manifest_value ubuntu_codename)}"
APT_COMPONENT="${APT_COMPONENT:-main}"
APT_ARCHITECTURE="${APT_ARCHITECTURE:-$(dpkg --print-architecture)}"
PACKAGE_NAME="$(require_manifest_value package_name)"
SOURCE_LIST="/etc/apt/sources.list.d/xgc2-px4-sitl-local.list"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --deb-dir)
      DEB_DIR="$2"
      shift 2
      ;;
    --repo-dir)
      REPO_DIR="$2"
      shift 2
      ;;
    --distribution)
      APT_DISTRIBUTION="$2"
      shift 2
      ;;
    --component)
      APT_COMPONENT="$2"
      shift 2
      ;;
    --architecture)
      APT_ARCHITECTURE="$2"
      shift 2
      ;;
    *)
      echo "unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

"${SCRIPT_DIR}/build_apt_repository.sh" \
  --deb-dir "${DEB_DIR}" \
  --repo-dir "${REPO_DIR}" \
  --distribution "${APT_DISTRIBUTION}" \
  --component "${APT_COMPONENT}" \
  --architecture "${APT_ARCHITECTURE}" >/dev/null

repo_abs="$(cd "${REPO_DIR}" && pwd)"
source_line="deb [trusted=yes arch=${APT_ARCHITECTURE}] file:${repo_abs} ${APT_DISTRIBUTION} ${APT_COMPONENT}"

echo "${source_line}" | sudo tee "${SOURCE_LIST}" >/dev/null
sudo apt-get update
sudo apt-get install -y "${PACKAGE_NAME}"

"${SCRIPT_DIR}/check_installed_runtime.sh"

echo "Local APT install passed: ${PACKAGE_NAME}"
echo "Source list: ${SOURCE_LIST}"
