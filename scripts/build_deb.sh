#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/manifest.sh
source "${SCRIPT_DIR}/lib/manifest.sh"

RUNTIME_DIR="${RUNTIME_DIR:-}"
GZ_SIM_DIR="${GZ_SIM_DIR:-}"
OUTPUT_DIR="${OUTPUT_DIR:-${PWD}/debs}"
PACKAGE_NAME="$(require_manifest_value package_name)"
PACKAGE_VERSION="$(require_manifest_value debian_version)"
UPSTREAM_VERSION="${PACKAGE_VERSION%%-*}"
ROS_DISTRO="$(require_manifest_value ros_distro)"
RUNTIME_ROS_PACKAGE="$(require_manifest_value runtime_ros_package)"
GZ_SIM_ROS_PACKAGE="$(require_manifest_value gazebo_ros_package)"
META_ROS_PACKAGE="$(require_manifest_value meta_ros_package)"
INSTALL_PREFIX="$(require_manifest_value install_prefix)"
GZ_SIM_RUNTIME_PREFIX="$(require_manifest_value gazebo_runtime_prefix)"
ARCHITECTURE="${ARCHITECTURE:-$(dpkg --print-architecture)}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --runtime-dir)
      RUNTIME_DIR="$2"
      shift 2
      ;;
    --gz-sim-dir | --gazebo-dir)
      GZ_SIM_DIR="$2"
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

if [[ -z "${GZ_SIM_DIR}" || ! -d "${GZ_SIM_DIR}" ]]; then
  echo "--gz-sim-dir is required and must point to extracted PX4 Gazebo Sim files" >&2
  exit 1
fi

test -x "${RUNTIME_DIR}/bin/px4"
test -f "${RUNTIME_DIR}/bin/px4-alias.sh"
test -d "${RUNTIME_DIR}/etc"
test -f "${GZ_SIM_DIR}/models/x500/model.sdf"
test -f "${GZ_SIM_DIR}/worlds/default.sdf"
test -f "${GZ_SIM_DIR}/server.config"
test -x "${GZ_SIM_DIR}/simulation-gazebo"

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"' EXIT

PKG_ROOT="${WORK_DIR}/${PACKAGE_NAME}_${PACKAGE_VERSION}_${ARCHITECTURE}"
ROS_PREFIX="/opt/ros/${ROS_DISTRO}"
AMENT_INDEX="${PKG_ROOT}${ROS_PREFIX}/share/ament_index/resource_index/packages"
RUNTIME_SHARE="${PKG_ROOT}${ROS_PREFIX}/share/${RUNTIME_ROS_PACKAGE}"
RUNTIME_LIB="${PKG_ROOT}${ROS_PREFIX}/lib/${RUNTIME_ROS_PACKAGE}"
GZ_SIM_SHARE="${PKG_ROOT}${ROS_PREFIX}/share/${GZ_SIM_ROS_PACKAGE}"
GZ_SIM_LIB="${PKG_ROOT}${ROS_PREFIX}/lib/${GZ_SIM_ROS_PACKAGE}"
META_SHARE="${PKG_ROOT}${ROS_PREFIX}/share/${META_ROS_PACKAGE}"

mkdir -p "${PKG_ROOT}/DEBIAN" "${AMENT_INDEX}"

install_ament_package_marker() {
  local package_name="$1"
  : > "${AMENT_INDEX}/${package_name}"
}

mkdir -p "${RUNTIME_SHARE}/runtime" "${RUNTIME_SHARE}/config" "${RUNTIME_LIB}"
cp -a "${RUNTIME_DIR}/." "${PKG_ROOT}${INSTALL_PREFIX}/"
install -m 0755 "${SCRIPT_DIR}/run_px4_sitl.sh" "${RUNTIME_LIB}/run_px4_sitl.sh"
install -m 0755 "${SCRIPT_DIR}/setup_runtime_env.sh" "${RUNTIME_LIB}/setup_runtime_env.sh"
install -m 0644 "${SCRIPT_DIR}/../config/runtime.env" "${RUNTIME_SHARE}/config/runtime.env"
install_ament_package_marker "${RUNTIME_ROS_PACKAGE}"

cat > "${RUNTIME_SHARE}/package.xml" <<EOF
<?xml version="1.0"?>
<package format="3">
  <name>${RUNTIME_ROS_PACKAGE}</name>
  <version>${UPSTREAM_VERSION}</version>
  <description>PX4 v1.16 SITL runtime wrapper for ROS Jazzy.</description>
  <maintainer email="lxk@example.com">lxk</maintainer>
  <license>BSD-3-Clause</license>
  <exec_depend>bash</exec_depend>
  <exec_depend>${GZ_SIM_ROS_PACKAGE}</exec_depend>
  <export>
    <build_type>ament_cmake</build_type>
  </export>
</package>
EOF

mkdir -p "${GZ_SIM_SHARE}" "${GZ_SIM_LIB}"
cp -a "${GZ_SIM_DIR}/models" "${GZ_SIM_SHARE}/models"
cp -a "${GZ_SIM_DIR}/worlds" "${GZ_SIM_SHARE}/worlds"
install -m 0644 "${GZ_SIM_DIR}/server.config" "${GZ_SIM_SHARE}/server.config"
install -m 0755 "${GZ_SIM_DIR}/simulation-gazebo" "${GZ_SIM_SHARE}/simulation-gazebo"
install_ament_package_marker "${GZ_SIM_ROS_PACKAGE}"

cat > "${GZ_SIM_LIB}/simulation-gazebo" <<EOF
#!/usr/bin/env bash
set -euo pipefail

PX4_GZ_SIM_ROOT="\${PX4_GZ_SIM_ROOT:-${GZ_SIM_RUNTIME_PREFIX}}"
has_model_store=false
for arg in "\$@"; do
  if [[ "\${arg}" == "--model_store" || "\${arg}" == --model_store=* ]]; then
    has_model_store=true
    break
  fi
done

if [[ "\${has_model_store}" == "true" ]]; then
  exec "\${PX4_GZ_SIM_ROOT}/simulation-gazebo" "\$@"
fi

exec "\${PX4_GZ_SIM_ROOT}/simulation-gazebo" --model_store "\${PX4_GZ_SIM_ROOT}" "\$@"
EOF
chmod 0755 "${GZ_SIM_LIB}/simulation-gazebo"

cat > "${GZ_SIM_SHARE}/package.xml" <<EOF
<?xml version="1.0"?>
<package format="3">
  <name>${GZ_SIM_ROS_PACKAGE}</name>
  <version>${UPSTREAM_VERSION}</version>
  <description>PX4 v1.16 Gazebo Sim Harmonic models and worlds for ROS Jazzy.</description>
  <maintainer email="lxk@example.com">lxk</maintainer>
  <license>BSD-3-Clause</license>
  <exec_depend>gz-harmonic</exec_depend>
  <export>
    <build_type>ament_cmake</build_type>
  </export>
</package>
EOF

mkdir -p "${META_SHARE}"
install_ament_package_marker "${META_ROS_PACKAGE}"

cat > "${META_SHARE}/package.xml" <<EOF
<?xml version="1.0"?>
<package format="3">
  <name>${META_ROS_PACKAGE}</name>
  <version>${UPSTREAM_VERSION}</version>
  <description>Meta package for the XGC2 PX4 v1.16 SITL suite on ROS Jazzy.</description>
  <maintainer email="lxk@example.com">lxk</maintainer>
  <license>BSD-3-Clause</license>
  <exec_depend>${RUNTIME_ROS_PACKAGE}</exec_depend>
  <exec_depend>${GZ_SIM_ROS_PACKAGE}</exec_depend>
  <export>
    <build_type>ament_cmake</build_type>
  </export>
</package>
EOF

cat > "${PKG_ROOT}${INSTALL_PREFIX}/setup.bash" <<EOF
#!/usr/bin/env bash
export PX4_SITL_RUNTIME_ROOT="${INSTALL_PREFIX}"
export PX4_GZ_SIM_ROOT="${GZ_SIM_RUNTIME_PREFIX}"
export PX4_GZ_SIM_BIN="${ROS_PREFIX}/lib/${GZ_SIM_ROS_PACKAGE}"
export PATH="\${PX4_SITL_RUNTIME_ROOT}/bin:\${PX4_GZ_SIM_BIN}:\${PATH}"
export GZ_SIM_RESOURCE_PATH="\${PX4_GZ_SIM_ROOT}/models:\${GZ_SIM_RESOURCE_PATH:-}"
export GZ_SIM_SERVER_CONFIG_PATH="\${PX4_GZ_SIM_ROOT}/server.config"
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
Depends: libc6, libstdc++6, libgcc-s1 | libgcc1, python3, gz-harmonic, ros-jazzy-ros-environment
Description: XGC2 PX4 v1.16 SITL suite for ROS Jazzy
 Installs ${RUNTIME_ROS_PACKAGE}, ${GZ_SIM_ROS_PACKAGE}, and ${META_ROS_PACKAGE} for PX4-Autopilot v1.16 Gazebo Sim Harmonic simulation.
EOF

mkdir -p "${OUTPUT_DIR}"
DEB_PATH="${OUTPUT_DIR}/${PACKAGE_NAME}_${PACKAGE_VERSION}_${ARCHITECTURE}.deb"
dpkg-deb --root-owner-group --build "${PKG_ROOT}" "${DEB_PATH}" >&2
echo "${DEB_PATH}"
