#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/manifest.sh
source "${SCRIPT_DIR}/lib/manifest.sh"

RUNTIME_DIR="${RUNTIME_DIR:-}"
GZ_SIM_DIR="${GZ_SIM_DIR:-}"
OUTPUT_DIR="${OUTPUT_DIR:-${PWD}/debs}"
META_PACKAGE_NAME="$(require_manifest_value package_name)"
PACKAGE_VERSION="$(require_manifest_value debian_version)"
UPSTREAM_VERSION="${PACKAGE_VERSION%%-*}"
ROS_DISTRO="$(require_manifest_value ros_distro)"
RUNTIME_ROS_PACKAGE="$(require_manifest_value runtime_ros_package)"
GZ_SIM_ROS_PACKAGE="$(require_manifest_value gazebo_ros_package)"
META_ROS_PACKAGE="$(require_manifest_value meta_ros_package)"
INSTALL_PREFIX="$(require_manifest_value install_prefix)"
GZ_SIM_RUNTIME_PREFIX="$(require_manifest_value gazebo_runtime_prefix)"
PX4_TAG="$(require_manifest_value px4_tag)"
PX4_LINE="${PX4_TAG#v}"
PX4_LINE="${PX4_LINE%.*}"
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

ROS_PREFIX="/opt/ros/${ROS_DISTRO}"
AMENT_INDEX_ROOT="${ROS_PREFIX}/share/ament_index/resource_index/packages"
RUNTIME_DEB_PACKAGE="ros-${ROS_DISTRO}-xgc2-px4-sitl-${PX4_LINE//./-}"
GZ_SIM_DEB_PACKAGE="ros-${ROS_DISTRO}-xgc2-px4-gz-harmonic-${PX4_LINE//./-}"

build_deb() {
  local pkg_root="$1"
  local package_name="$2"
  local architecture="$3"
  mkdir -p "${OUTPUT_DIR}"
  local deb_path="${OUTPUT_DIR}/${package_name}_${PACKAGE_VERSION}_${architecture}.deb"
  dpkg-deb --root-owner-group --build "${pkg_root}" "${deb_path}" >&2
  echo "${deb_path}"
}

write_control() {
  local pkg_root="$1"
  local package_name="$2"
  local architecture="$3"
  local depends="$4"
  local description="$5"
  local details="$6"
  local installed_size
  installed_size="$(du -ks "${pkg_root}" | awk '{print $1}')"
  cat > "${pkg_root}/DEBIAN/control" <<CONTROL
Package: ${package_name}
Version: ${PACKAGE_VERSION}
Section: misc
Priority: optional
Architecture: ${architecture}
Installed-Size: ${installed_size}
Maintainer: XGC2 <xgc2@example.com>
Depends: ${depends}
Description: ${description}
 ${details}
CONTROL
}

install_ament_package_marker() {
  local pkg_root="$1"
  local package_name="$2"
  mkdir -p "${pkg_root}${AMENT_INDEX_ROOT}"
  : > "${pkg_root}${AMENT_INDEX_ROOT}/${package_name}"
}

runtime_root="${WORK_DIR}/${RUNTIME_DEB_PACKAGE}_${PACKAGE_VERSION}_${ARCHITECTURE}"
runtime_share="${runtime_root}${ROS_PREFIX}/share/${RUNTIME_ROS_PACKAGE}"
runtime_lib="${runtime_root}${ROS_PREFIX}/lib/${RUNTIME_ROS_PACKAGE}"
mkdir -p "${runtime_root}/DEBIAN" "${runtime_share}/runtime" "${runtime_share}/config" "${runtime_lib}"
cp -a "${RUNTIME_DIR}/." "${runtime_root}${INSTALL_PREFIX}/"
install -m 0755 "${SCRIPT_DIR}/run_px4_sitl.sh" "${runtime_lib}/run_px4_sitl.sh"
install -m 0755 "${SCRIPT_DIR}/setup_runtime_env.sh" "${runtime_lib}/setup_runtime_env.sh"
install -m 0644 "${SCRIPT_DIR}/../config/runtime.env" "${runtime_share}/config/runtime.env"
install_ament_package_marker "${runtime_root}" "${RUNTIME_ROS_PACKAGE}"

cat > "${runtime_share}/package.xml" <<EOF_XML
<?xml version="1.0"?>
<package format="3">
  <name>${RUNTIME_ROS_PACKAGE}</name>
  <version>${UPSTREAM_VERSION}</version>
  <description>PX4 v${PX4_LINE} SITL runtime wrapper for ROS Jazzy.</description>
  <maintainer email="xgc2@example.com">XGC2</maintainer>
  <license>BSD-3-Clause</license>
  <exec_depend>bash</exec_depend>
  <exec_depend>${GZ_SIM_ROS_PACKAGE}</exec_depend>
  <export>
    <build_type>ament_cmake</build_type>
  </export>
</package>
EOF_XML

cat > "${runtime_root}${INSTALL_PREFIX}/setup.bash" <<EOF_SETUP
#!/usr/bin/env bash
export PX4_SITL_RUNTIME_ROOT="${INSTALL_PREFIX}"
export PX4_GZ_SIM_ROOT="${GZ_SIM_RUNTIME_PREFIX}"
export PX4_GZ_SIM_BIN="${ROS_PREFIX}/lib/${GZ_SIM_ROS_PACKAGE}"
export PATH="\${PX4_SITL_RUNTIME_ROOT}/bin:\${PX4_GZ_SIM_BIN}:\${PATH}"
export GZ_SIM_RESOURCE_PATH="\${PX4_GZ_SIM_ROOT}/models:\${GZ_SIM_RESOURCE_PATH:-}"
export GZ_SIM_SERVER_CONFIG_PATH="\${PX4_GZ_SIM_ROOT}/server.config"
EOF_SETUP
chmod 0755 "${runtime_root}${INSTALL_PREFIX}/setup.bash"

write_control \
  "${runtime_root}" \
  "${RUNTIME_DEB_PACKAGE}" \
  "${ARCHITECTURE}" \
  "libc6, libstdc++6, libgcc-s1 | libgcc1, python3, ${GZ_SIM_DEB_PACKAGE} (= ${PACKAGE_VERSION}), ros-jazzy-ros-environment" \
  "PX4 v${PX4_LINE} SITL runtime wrapper for ROS Jazzy" \
  "Installs the ${RUNTIME_ROS_PACKAGE} ROS 2 package extracted from PX4-Autopilot ${PX4_TAG}."

gz_root="${WORK_DIR}/${GZ_SIM_DEB_PACKAGE}_${PACKAGE_VERSION}_${ARCHITECTURE}"
gz_share="${gz_root}${ROS_PREFIX}/share/${GZ_SIM_ROS_PACKAGE}"
gz_lib="${gz_root}${ROS_PREFIX}/lib/${GZ_SIM_ROS_PACKAGE}"
mkdir -p "${gz_root}/DEBIAN" "${gz_share}" "${gz_lib}"
cp -a "${GZ_SIM_DIR}/models" "${gz_share}/models"
cp -a "${GZ_SIM_DIR}/worlds" "${gz_share}/worlds"
install -m 0644 "${GZ_SIM_DIR}/server.config" "${gz_share}/server.config"
install -m 0755 "${GZ_SIM_DIR}/simulation-gazebo" "${gz_share}/simulation-gazebo"
install_ament_package_marker "${gz_root}" "${GZ_SIM_ROS_PACKAGE}"

cat > "${gz_lib}/simulation-gazebo" <<EOF_BIN
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
EOF_BIN
chmod 0755 "${gz_lib}/simulation-gazebo"

cat > "${gz_share}/package.xml" <<EOF_XML
<?xml version="1.0"?>
<package format="3">
  <name>${GZ_SIM_ROS_PACKAGE}</name>
  <version>${UPSTREAM_VERSION}</version>
  <description>PX4 v${PX4_LINE} Gazebo Sim Harmonic models and worlds for ROS Jazzy.</description>
  <maintainer email="xgc2@example.com">XGC2</maintainer>
  <license>BSD-3-Clause</license>
  <exec_depend>gz-harmonic</exec_depend>
  <export>
    <build_type>ament_cmake</build_type>
  </export>
</package>
EOF_XML

write_control \
  "${gz_root}" \
  "${GZ_SIM_DEB_PACKAGE}" \
  "${ARCHITECTURE}" \
  "gz-harmonic" \
  "PX4 v${PX4_LINE} Gazebo Sim Harmonic assets for ROS Jazzy" \
  "Installs the ${GZ_SIM_ROS_PACKAGE} ROS 2 package with PX4 Gazebo Sim models, worlds, and helper scripts."

meta_root="${WORK_DIR}/${META_PACKAGE_NAME}_${PACKAGE_VERSION}_all"
meta_share="${meta_root}${ROS_PREFIX}/share/${META_ROS_PACKAGE}"
mkdir -p "${meta_root}/DEBIAN" "${meta_share}"
install_ament_package_marker "${meta_root}" "${META_ROS_PACKAGE}"
cat > "${meta_share}/package.xml" <<EOF_XML
<?xml version="1.0"?>
<package format="3">
  <name>${META_ROS_PACKAGE}</name>
  <version>${UPSTREAM_VERSION}</version>
  <description>Meta package for the XGC2 PX4 v${PX4_LINE} SITL suite on ROS Jazzy.</description>
  <maintainer email="xgc2@example.com">XGC2</maintainer>
  <license>BSD-3-Clause</license>
  <exec_depend>${RUNTIME_ROS_PACKAGE}</exec_depend>
  <exec_depend>${GZ_SIM_ROS_PACKAGE}</exec_depend>
  <export>
    <build_type>ament_cmake</build_type>
  </export>
</package>
EOF_XML

write_control \
  "${meta_root}" \
  "${META_PACKAGE_NAME}" \
  "all" \
  "${RUNTIME_DEB_PACKAGE} (= ${PACKAGE_VERSION}), ${GZ_SIM_DEB_PACKAGE} (= ${PACKAGE_VERSION})" \
  "XGC2 PX4 v${PX4_LINE} SITL suite for ROS Jazzy" \
  "Depends on the runtime and Gazebo Sim packages for PX4-Autopilot ${PX4_TAG}."

build_deb "${gz_root}" "${GZ_SIM_DEB_PACKAGE}" "${ARCHITECTURE}"
build_deb "${runtime_root}" "${RUNTIME_DEB_PACKAGE}" "${ARCHITECTURE}"
build_deb "${meta_root}" "${META_PACKAGE_NAME}" "all"
