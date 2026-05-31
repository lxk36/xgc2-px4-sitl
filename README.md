# px4_sitl_runtime

Build rules for the XGC2 PX4 v1.12 SITL Debian package on ROS Noetic.

This repository is intentionally small. It does not store PX4 source trees, PX4 binaries, Gazebo plugin binaries, or built `.deb` files. CI clones the configured PX4 tag, builds the SITL runtime and Gazebo Classic plugins in the target Ubuntu/ROS environment, and packages only the runtime artifacts users need.

## Package Model

This branch builds one Debian package:

```bash
ros-noetic-xgc2-px4-sitl-1-12
```

That Debian package installs two ROS packages under `/opt/ros/noetic`:

```text
px4_sitl_runtime_1_12
sitl_gazebo_1_12
```

`px4_sitl_runtime_1_12` contains the launch wrapper, runtime environment helpers, and extracted PX4 SITL runtime files. `sitl_gazebo_1_12` contains the PX4 Gazebo Classic models, worlds, and plugin libraries from PX4 v1.12.

The PX4 maintenance line is encoded in the Debian package name. The Debian `Version` tracks the exact PX4 tag plus a packaging revision:

```text
PX4 v1.12.3 -> ros-noetic-xgc2-px4-sitl-1-12 1.12.3-1
PX4 v1.12.3 packaging fix -> ros-noetic-xgc2-px4-sitl-1-12 1.12.3-2
```

Later Ubuntu 20.04 compatible PX4 lines can use separate package names such as `ros-noetic-xgc2-px4-sitl-1-14`. This keeps APT versioning for revisions within the same PX4 line instead of using it to switch major runtime layouts.

## User Installation

Once the GitHub Pages APT repository is enabled, install the runtime with:

```bash
sudo apt update
sudo apt install ros-noetic-xgc2-px4-sitl-1-12
```

Check available packaging revisions:

```bash
apt-cache madison ros-noetic-xgc2-px4-sitl-1-12
```

Launch Iris with MAVROS and Gazebo Classic:

```bash
source /opt/ros/noetic/setup.bash
roslaunch px4_sitl_runtime_1_12 iris_mavros_gazebo.launch vehicle:=iris gui:=true
```

## Installed Layout

PX4 SITL runtime:

```text
/opt/ros/noetic/share/px4_sitl_runtime_1_12/
├── config/
├── launch/
├── package.xml
└── runtime/
    ├── bin/
    │   ├── px4
    │   ├── px4-alias.sh
    │   └── px4-* -> px4
    ├── etc/
    └── setup.bash
```

Gazebo Classic runtime:

```text
/opt/ros/noetic/share/sitl_gazebo_1_12/
├── models/
├── package.xml
└── worlds/

/opt/ros/noetic/lib/sitl_gazebo_1_12/
└── lib*.so
```

The launch file uses `/tmp/px4_sitl_runtime` as the writable rootfs so generated PX4 files such as `parameters.bson`, `dataman`, and logs do not pollute installed files.

## Local Build

The normal local path builds inside the official ROS Noetic image:

```bash
scripts/build_runtime_deb_in_docker.sh \
  --work-dir /tmp/px4-runtime-work \
  --output-dir debs
```

The script pulls `osrf/ros:noetic-desktop-full-focal`, clones PX4 v1.12.3, initializes PX4 submodules, runs PX4's `Tools/setup/ubuntu.sh --no-nuttx` when available, builds `px4_sitl_default` and `sitl_gazebo`, extracts runtime artifacts, runs a headless `gzserver` + PX4 SITL + MAVROS check, builds the Debian package, installs it in the same disposable container, and verifies that both ROS packages are discoverable by `rospack`.

For lower-level debugging, run the stages directly:

```bash
scripts/fetch_px4.sh --work-dir /tmp/px4-runtime-work
scripts/build_px4_runtime.sh --px4-dir /tmp/px4-runtime-work/PX4-Autopilot
scripts/extract_px4_runtime.sh \
  --px4-dir /tmp/px4-runtime-work/PX4-Autopilot \
  --output-dir /tmp/px4-runtime-stage
scripts/extract_gazebo_classic_runtime.sh \
  --px4-dir /tmp/px4-runtime-work/PX4-Autopilot \
  --output-dir /tmp/gazebo-runtime-stage
scripts/check_gazebo_mavros_e2e.sh \
  --runtime-root /tmp/px4-runtime-stage \
  --gazebo-root /tmp/gazebo-runtime-stage
scripts/build_deb.sh \
  --runtime-dir /tmp/px4-runtime-stage \
  --gazebo-dir /tmp/gazebo-runtime-stage \
  --output-dir debs
```

## CI

The `build-runtime` GitHub Actions workflow:

1. Reads `manifest/px4_runtime.yaml`.
2. Pulls `osrf/ros:noetic-desktop-full-focal`.
3. Runs the full build inside a disposable Docker container.
4. Clones PX4-Autopilot at the configured tag and initializes all PX4 submodules.
5. Runs PX4's Ubuntu dependency setup when present.
6. Builds `px4_sitl_default` and the Gazebo Classic `sitl_gazebo` target.
7. Extracts PX4 runtime files, Gazebo Classic models, worlds, and plugins.
8. Runs a headless Gazebo Classic + PX4 SITL + MAVROS end-to-end check.
9. Builds `ros-noetic-xgc2-px4-sitl-1-12`.
10. Installs the `.deb` inside the container.
11. Checks `px4_sitl_runtime_1_12` and `sitl_gazebo_1_12` with `rospack`.
12. Uploads the `.deb` as a workflow artifact.

APT publishing is intentionally a later stage. GitHub Pages can host the static Debian repository metadata and `pool/` tree after the build artifact is proven installable.
