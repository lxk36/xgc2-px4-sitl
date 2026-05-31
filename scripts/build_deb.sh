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
UPSTREAM_VERSION="${PACKAGE_VERSION%%-*}"
ROS_DISTRO="$(require_manifest_value ros_distro)"
RUNTIME_ROS_PACKAGE="$(require_manifest_value runtime_ros_package)"
GAZEBO_ROS_PACKAGE="$(require_manifest_value gazebo_ros_package)"
INSTALL_PREFIX="$(require_manifest_value install_prefix)"
GAZEBO_RUNTIME_PREFIX="$(require_manifest_value gazebo_runtime_prefix)"
GAZEBO_PLUGIN_PREFIX="$(require_manifest_value gazebo_plugin_prefix)"
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
ROS_PREFIX="/opt/ros/${ROS_DISTRO}"
RUNTIME_SHARE="${PKG_ROOT}${ROS_PREFIX}/share/${RUNTIME_ROS_PACKAGE}"
RUNTIME_LIB="${PKG_ROOT}${ROS_PREFIX}/lib/${RUNTIME_ROS_PACKAGE}"
GAZEBO_SHARE="${PKG_ROOT}${ROS_PREFIX}/share/${GAZEBO_ROS_PACKAGE}"
GAZEBO_LIB="${PKG_ROOT}${ROS_PREFIX}/lib/${GAZEBO_ROS_PACKAGE}"

mkdir -p "${PKG_ROOT}/DEBIAN"
mkdir -p "${RUNTIME_SHARE}/runtime" "${RUNTIME_SHARE}/launch" "${RUNTIME_SHARE}/config" "${RUNTIME_LIB}"
cp -a "${RUNTIME_DIR}/." "${PKG_ROOT}${INSTALL_PREFIX}/"
install -m 0755 "${SCRIPT_DIR}/run_px4_sitl.sh" "${RUNTIME_LIB}/run_px4_sitl.sh"
install -m 0755 "${SCRIPT_DIR}/setup_runtime_env.sh" "${RUNTIME_LIB}/setup_runtime_env.sh"
install -m 0644 "${SCRIPT_DIR}/../launch/iris_mavros_gazebo.launch" "${RUNTIME_SHARE}/launch/iris_mavros_gazebo.launch"
install -m 0644 "${SCRIPT_DIR}/../config/runtime.env" "${RUNTIME_SHARE}/config/runtime.env"

cat > "${RUNTIME_SHARE}/package.xml" <<EOF
<?xml version="1.0"?>
<package format="2">
  <name>${RUNTIME_ROS_PACKAGE}</name>
  <version>${UPSTREAM_VERSION}</version>
  <description>PX4 v1.12 SITL runtime wrapper for ROS Noetic.</description>
  <maintainer email="lxk@example.com">lxk</maintainer>
  <license>BSD-3-Clause</license>
  <exec_depend>bash</exec_depend>
  <exec_depend>gazebo_ros</exec_depend>
  <exec_depend>mavros</exec_depend>
  <exec_depend>${GAZEBO_ROS_PACKAGE}</exec_depend>
</package>
EOF

if [[ -n "${GAZEBO_DIR}" ]]; then
  mkdir -p "${GAZEBO_SHARE}" "${GAZEBO_LIB}"
  cp -a "${GAZEBO_DIR}/models" "${GAZEBO_SHARE}/models"
  cp -a "${GAZEBO_DIR}/worlds" "${GAZEBO_SHARE}/worlds"
  find "${GAZEBO_DIR}/lib" -maxdepth 1 -type f -name '*.so' -exec cp -a {} "${GAZEBO_LIB}/" \;

  cat > "${GAZEBO_SHARE}/package.xml" <<EOF
<?xml version="1.0"?>
<package format="2">
  <name>${GAZEBO_ROS_PACKAGE}</name>
  <version>${UPSTREAM_VERSION}</version>
  <description>PX4 v1.12 Gazebo Classic models, worlds, and plugins for ROS Noetic.</description>
  <maintainer email="lxk@example.com">lxk</maintainer>
  <license>BSD</license>
  <exec_depend>gazebo_ros</exec_depend>
  <exec_depend>geometry_msgs</exec_depend>
  <exec_depend>mavlink</exec_depend>
  <exec_depend>mavros</exec_depend>
  <exec_depend>mavros_msgs</exec_depend>
  <exec_depend>roscpp</exec_depend>
  <exec_depend>sensor_msgs</exec_depend>
  <exec_depend>std_msgs</exec_depend>
  <export>
    <gazebo_ros plugin_path="${GAZEBO_PLUGIN_PREFIX}" gazebo_media_path="\${prefix}" gazebo_model_path="\${prefix}/models"/>
  </export>
</package>
EOF
fi

cat > "${PKG_ROOT}${INSTALL_PREFIX}/setup.bash" <<EOF
#!/usr/bin/env bash
export PX4_SITL_RUNTIME_ROOT="${INSTALL_PREFIX}"
export SITL_GAZEBO_CLASSIC_ROOT="${GAZEBO_RUNTIME_PREFIX}"
export SITL_GAZEBO_CLASSIC_PLUGIN_ROOT="${GAZEBO_PLUGIN_PREFIX}"
export PATH="\${PX4_SITL_RUNTIME_ROOT}/bin:\${PATH}"
export GAZEBO_PLUGIN_PATH="\${SITL_GAZEBO_CLASSIC_PLUGIN_ROOT}:\${GAZEBO_PLUGIN_PATH:-}"
export GAZEBO_MODEL_PATH="\${SITL_GAZEBO_CLASSIC_ROOT}/models:\${GAZEBO_MODEL_PATH:-}"
export LD_LIBRARY_PATH="\${SITL_GAZEBO_CLASSIC_PLUGIN_ROOT}:\${LD_LIBRARY_PATH:-}"
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
Depends: libc6, libstdc++6, libgcc-s1 | libgcc1, gazebo11, gstreamer1.0-plugins-bad, gstreamer1.0-plugins-good, gstreamer1.0-plugins-ugly, ros-noetic-gazebo-ros, ros-noetic-geometry-msgs, ros-noetic-mavlink, ros-noetic-mavros, ros-noetic-mavros-msgs, ros-noetic-roscpp, ros-noetic-sensor-msgs, ros-noetic-std-msgs
Description: XGC2 PX4 v1.12 SITL suite for ROS Noetic
 Installs two ROS packages, ${RUNTIME_ROS_PACKAGE} and ${GAZEBO_ROS_PACKAGE}, extracted from PX4-Autopilot v1.12 for Gazebo Classic simulation.
EOF

mkdir -p "${OUTPUT_DIR}"
DEB_PATH="${OUTPUT_DIR}/${PACKAGE_NAME}_${PACKAGE_VERSION}_${ARCHITECTURE}.deb"
dpkg-deb --root-owner-group --build "${PKG_ROOT}" "${DEB_PATH}" >&2
echo "${DEB_PATH}"
