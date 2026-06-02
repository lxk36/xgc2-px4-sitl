#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.xgc2/scripts/lib/manifest.sh
source "${SCRIPT_DIR}/lib/manifest.sh"

DEB_DIR="${DEB_DIR:-${PWD}/debs}"
REPO_DIR="${REPO_DIR:-${PWD}/apt-repo}"
APT_DISTRIBUTION="${APT_DISTRIBUTION:-$(require_manifest_value ubuntu_codename)}"
APT_COMPONENT="${APT_COMPONENT:-main}"
APT_ARCHITECTURE="${APT_ARCHITECTURE:-$(dpkg --print-architecture)}"

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

if [[ -z "${REPO_DIR}" || "${REPO_DIR}" == "/" || "${REPO_DIR}" == "/tmp" || "${REPO_DIR}" == "${HOME}" ]]; then
  echo "unsafe --repo-dir: ${REPO_DIR}" >&2
  exit 1
fi

if ! compgen -G "${DEB_DIR}/*.deb" >/dev/null; then
  echo "no .deb files found in ${DEB_DIR}" >&2
  exit 1
fi

if ! command -v dpkg-scanpackages >/dev/null 2>&1; then
  echo "dpkg-scanpackages is required; install dpkg-dev" >&2
  exit 1
fi

pool_dir="${REPO_DIR}/pool/${APT_COMPONENT}"
binary_dir="${REPO_DIR}/dists/${APT_DISTRIBUTION}/${APT_COMPONENT}/binary-${APT_ARCHITECTURE}"

mkdir -p "${pool_dir}" "${binary_dir}"
cp -a "${DEB_DIR}/"*.deb "${pool_dir}/"

(
  cd "${REPO_DIR}"
  dpkg-scanpackages --arch "${APT_ARCHITECTURE}" "pool/${APT_COMPONENT}" /dev/null \
    > "dists/${APT_DISTRIBUTION}/${APT_COMPONENT}/binary-${APT_ARCHITECTURE}/Packages"
  gzip -kf "dists/${APT_DISTRIBUTION}/${APT_COMPONENT}/binary-${APT_ARCHITECTURE}/Packages"

  if command -v apt-ftparchive >/dev/null 2>&1; then
    apt-ftparchive release "dists/${APT_DISTRIBUTION}" > "dists/${APT_DISTRIBUTION}/Release"
  else
    cat > "dists/${APT_DISTRIBUTION}/Release" <<EOF
Origin: XGC2
Label: XGC2 PX4 SITL
Suite: ${APT_DISTRIBUTION}
Codename: ${APT_DISTRIBUTION}
Architectures: ${APT_ARCHITECTURE}
Components: ${APT_COMPONENT}
Description: XGC2 PX4 SITL static APT repository
Date: $(date -Ru)
EOF
  fi
)

echo "${REPO_DIR}"
