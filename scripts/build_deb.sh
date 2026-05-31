#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/manifest.sh
source "${SCRIPT_DIR}/lib/manifest.sh"

RUNTIME_DIR="${RUNTIME_DIR:-}"
GAZEBO_DIR="${GAZEBO_DIR:-}"
OUTPUT_DIR="${OUTPUT_DIR:-${PWD}/debs}"
PACKAGE_NAME="$(require_manifest_value package_name)"
PACKAGE_VERSION="$(require_manifest_value debian_version)"
INSTALL_PREFIX="$(require_manifest_value install_prefix)"
GAZEBO_RUNTIME_PREFIX="$(require_manifest_value gazebo_runtime_prefix)"
ARCHITECTURE="${ARCHITECTURE:-$(dpkg --print-architecture)}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --runtime-dir)
      RUNTIME_DIR="$2"
      shift 2
      ;;
    --gazebo-dir)
      GAZEBO_DIR="$2"
      shift 2
      ;;
    --output-dir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --architecture)
      ARCHITECTURE="$2"
      shift 2
      ;;
    *)
      echo "unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "${RUNTIME_DIR}" || ! -d "${RUNTIME_DIR}" ]]; then
  echo "--runtime-dir is required and must point to extracted PX4 runtime files" >&2
  exit 1
fi

test -x "${RUNTIME_DIR}/bin/px4"
test -f "${RUNTIME_DIR}/bin/px4-alias.sh"
test -d "${RUNTIME_DIR}/etc"

if [[ -n "${GAZEBO_DIR}" ]]; then
  test -d "${GAZEBO_DIR}/lib"
  test -d "${GAZEBO_DIR}/models"
  test -d "${GAZEBO_DIR}/worlds"
  test -f "${GAZEBO_DIR}/models/iris/iris.sdf"
  test -f "${GAZEBO_DIR}/worlds/empty.world"
fi

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"' EXIT

PKG_ROOT="${WORK_DIR}/${PACKAGE_NAME}_${PACKAGE_VERSION}_${ARCHITECTURE}"
mkdir -p "${PKG_ROOT}/DEBIAN"
mkdir -p "${PKG_ROOT}${INSTALL_PREFIX}"
cp -a "${RUNTIME_DIR}/." "${PKG_ROOT}${INSTALL_PREFIX}/"

if [[ -n "${GAZEBO_DIR}" ]]; then
  mkdir -p "${PKG_ROOT}${GAZEBO_RUNTIME_PREFIX}"
  cp -a "${GAZEBO_DIR}/." "${PKG_ROOT}${GAZEBO_RUNTIME_PREFIX}/"
fi

cat > "${PKG_ROOT}${INSTALL_PREFIX}/setup.bash" <<EOF
#!/usr/bin/env bash
export PX4_SITL_RUNTIME_ROOT="${INSTALL_PREFIX}"
export SITL_GAZEBO_CLASSIC_ROOT="${GAZEBO_RUNTIME_PREFIX}"
export PATH="\${PX4_SITL_RUNTIME_ROOT}/bin:\${PATH}"
export GAZEBO_PLUGIN_PATH="\${SITL_GAZEBO_CLASSIC_ROOT}/lib:\${GAZEBO_PLUGIN_PATH:-}"
export GAZEBO_MODEL_PATH="\${SITL_GAZEBO_CLASSIC_ROOT}/models:\${GAZEBO_MODEL_PATH:-}"
export LD_LIBRARY_PATH="\${SITL_GAZEBO_CLASSIC_ROOT}/lib:\${LD_LIBRARY_PATH:-}"
EOF
chmod 0755 "${PKG_ROOT}${INSTALL_PREFIX}/setup.bash"

installed_size="$(du -ks "${PKG_ROOT}" | awk '{print $1}')"

cat > "${PKG_ROOT}/DEBIAN/control" <<EOF
Package: ${PACKAGE_NAME}
Version: ${PACKAGE_VERSION}
Section: misc
Priority: optional
Architecture: ${ARCHITECTURE}
Installed-Size: ${installed_size}
Maintainer: lxk <lxk@example.com>
Depends: libc6, libstdc++6, libgcc-s1 | libgcc1, gazebo11, ros-noetic-gazebo-ros, ros-noetic-mavros
Description: PX4 SITL runtime for ROS Noetic
 Minimal PX4 SITL runtime and Gazebo Classic plugins extracted from PX4-Autopilot for ROS Noetic simulation.
EOF

mkdir -p "${OUTPUT_DIR}"
DEB_PATH="${OUTPUT_DIR}/${PACKAGE_NAME}_${PACKAGE_VERSION}_${ARCHITECTURE}.deb"
dpkg-deb --root-owner-group --build "${PKG_ROOT}" "${DEB_PATH}"
echo "${DEB_PATH}"
