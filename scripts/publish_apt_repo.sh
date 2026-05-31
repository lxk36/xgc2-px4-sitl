#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/manifest.sh
source "${SCRIPT_DIR}/lib/manifest.sh"

DEB_DIR="${DEB_DIR:-${PWD}/debs}"
APT_REPO_HOST="${APT_REPO_HOST:-}"
APT_REPO_USER="${APT_REPO_USER:-}"
APT_REPO_PATH="${APT_REPO_PATH:-}"
APT_DISTRIBUTION="${APT_DISTRIBUTION:-$(require_manifest_value ubuntu_codename)}"
APT_COMPONENT="${APT_COMPONENT:-main}"
APT_ARCHITECTURE="${APT_ARCHITECTURE:-$(dpkg --print-architecture)}"
APT_GPG_KEY_ID="${APT_GPG_KEY_ID:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --deb-dir)
      DEB_DIR="$2"
      shift 2
      ;;
    *)
      echo "unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "${APT_REPO_HOST}" || -z "${APT_REPO_USER}" || -z "${APT_REPO_PATH}" ]]; then
  echo "APT_REPO_HOST, APT_REPO_USER and APT_REPO_PATH are required" >&2
  exit 1
fi

if ! compgen -G "${DEB_DIR}/*.deb" >/dev/null; then
  echo "no .deb files found in ${DEB_DIR}" >&2
  exit 1
fi

remote="${APT_REPO_USER}@${APT_REPO_HOST}"
incoming="${APT_REPO_PATH}/incoming"

ssh "${remote}" "mkdir -p '${incoming}' '${APT_REPO_PATH}/pool/${APT_COMPONENT}' '${APT_REPO_PATH}/dists/${APT_DISTRIBUTION}/${APT_COMPONENT}/binary-${APT_ARCHITECTURE}'"
rsync -av --delete "${DEB_DIR}/"*.deb "${remote}:${incoming}/"

ssh "${remote}" "set -e
  cd '${APT_REPO_PATH}'
  cp '${incoming}'/*.deb 'pool/${APT_COMPONENT}/'
  dpkg-scanpackages --arch '${APT_ARCHITECTURE}' 'pool/${APT_COMPONENT}' /dev/null > 'dists/${APT_DISTRIBUTION}/${APT_COMPONENT}/binary-${APT_ARCHITECTURE}/Packages'
  gzip -kf 'dists/${APT_DISTRIBUTION}/${APT_COMPONENT}/binary-${APT_ARCHITECTURE}/Packages'
  if ! command -v apt-ftparchive >/dev/null 2>&1; then
    echo 'apt-ftparchive is required on the APT server' >&2
    exit 1
  fi
  apt-ftparchive release 'dists/${APT_DISTRIBUTION}' > 'dists/${APT_DISTRIBUTION}/Release'
  if [ -n '${APT_GPG_KEY_ID}' ] && command -v gpg >/dev/null 2>&1; then
    gpg --batch --yes --local-user '${APT_GPG_KEY_ID}' --clearsign -o 'dists/${APT_DISTRIBUTION}/InRelease' 'dists/${APT_DISTRIBUTION}/Release'
    gpg --batch --yes --local-user '${APT_GPG_KEY_ID}' -abs -o 'dists/${APT_DISTRIBUTION}/Release.gpg' 'dists/${APT_DISTRIBUTION}/Release'
  fi
"

echo "published ${DEB_DIR}/*.deb to ${remote}:${APT_REPO_PATH}"
