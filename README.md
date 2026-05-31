# px4_sitl_runtime

Build rules for the XGC2 PX4 v1.16 SITL Debian package on ROS Jazzy.

This repository does not store PX4 source trees, PX4 binaries, Gazebo Sim assets, or built `.deb` files. CI clones the configured PX4 tag, builds the SITL runtime in the target Ubuntu/ROS environment, extracts the PX4 Gazebo Sim Harmonic model store, and packages only the runtime artifacts users need.

## Package Model

This branch builds one Debian package:

```bash
ros-jazzy-xgc2-px4-sitl-1-16
```

That Debian package installs three ROS 2 packages under `/opt/ros/jazzy`:

```text
px4_sitl_runtime_1_16
px4_gz_sim_1_16
xgc2_px4_sitl_1_16
```

`px4_sitl_runtime_1_16` contains the extracted PX4 SITL runtime files and helper scripts. `px4_gz_sim_1_16` contains PX4 v1.16 Gazebo Sim Harmonic models, worlds, `server.config`, and the `simulation-gazebo` helper. `xgc2_px4_sitl_1_16` is a meta package that depends on both runtime packages.

The PX4 maintenance line is encoded in the Debian package name. The Debian `Version` tracks the exact PX4 tag plus a packaging revision:

```text
PX4 v1.16.2 -> ros-jazzy-xgc2-px4-sitl-1-16 1.16.2-1
PX4 v1.16.2 packaging fix -> ros-jazzy-xgc2-px4-sitl-1-16 1.16.2-2
```

## User Installation

Once the GitHub Pages APT repository is enabled, install the runtime with:

```bash
sudo apt update
sudo apt install ros-jazzy-xgc2-px4-sitl-1-16
```

Check available packaging revisions:

```bash
apt-cache madison ros-jazzy-xgc2-px4-sitl-1-16
```

Confirm the ROS 2 packages are discoverable:

```bash
source /opt/ros/jazzy/setup.bash
ros2 pkg prefix px4_sitl_runtime_1_16
ros2 pkg prefix px4_gz_sim_1_16
ros2 pkg prefix xgc2_px4_sitl_1_16
```

Run the packaged Gazebo Sim helper against the installed model store:

```bash
ros2 run px4_gz_sim_1_16 simulation-gazebo --world default
```

## Installed Layout

PX4 SITL runtime:

```text
/opt/ros/jazzy/share/px4_sitl_runtime_1_16/
├── config/
├── package.xml
└── runtime/
    ├── bin/
    │   ├── px4
    │   ├── px4-alias.sh
    │   └── px4-* -> px4
    ├── etc/
    └── setup.bash

/opt/ros/jazzy/lib/px4_sitl_runtime_1_16/
├── run_px4_sitl.sh
└── setup_runtime_env.sh
```

Gazebo Sim Harmonic runtime:

```text
/opt/ros/jazzy/share/px4_gz_sim_1_16/
├── models/
├── package.xml
├── server.config
├── simulation-gazebo
└── worlds/

/opt/ros/jazzy/lib/px4_gz_sim_1_16/
└── simulation-gazebo
```

Meta package:

```text
/opt/ros/jazzy/share/xgc2_px4_sitl_1_16/
└── package.xml
```

## Local Build

The normal local path builds inside the official ROS Jazzy image:

```bash
scripts/build_runtime_deb_in_docker.sh \
  --work-dir /tmp/px4-runtime-work \
  --output-dir debs
```

The script pulls `osrf/ros:jazzy-desktop-full-noble`, clones PX4 v1.16.2, initializes PX4 submodules, runs PX4's `Tools/setup/ubuntu.sh --no-nuttx` when available, builds `px4_sitl_default`, extracts PX4 runtime files and Gazebo Sim Harmonic assets, builds the Debian package, installs it in the same disposable container, and verifies all three ROS 2 packages with `ros2 pkg prefix`.

For lower-level debugging, run the stages directly:

```bash
scripts/fetch_px4.sh --work-dir /tmp/px4-runtime-work
scripts/build_px4_runtime.sh --px4-dir /tmp/px4-runtime-work/PX4-Autopilot
scripts/extract_px4_runtime.sh \
  --px4-dir /tmp/px4-runtime-work/PX4-Autopilot \
  --output-dir /tmp/px4-runtime-stage
scripts/extract_gz_sim_runtime.sh \
  --px4-dir /tmp/px4-runtime-work/PX4-Autopilot \
  --output-dir /tmp/gz-sim-runtime-stage
scripts/check_px4_runtime.sh /tmp/px4-runtime-stage
scripts/check_gz_sim_runtime.sh /tmp/gz-sim-runtime-stage
scripts/build_deb.sh \
  --runtime-dir /tmp/px4-runtime-stage \
  --gz-sim-dir /tmp/gz-sim-runtime-stage \
  --output-dir debs
```

## CI

The `build-runtime` GitHub Actions workflow:

1. Reads `manifest/px4_runtime.yaml`.
2. Builds in parallel for `amd64` and `arm64` on native GitHub-hosted runners.
3. Pulls `osrf/ros:jazzy-desktop-full-noble`.
4. Runs the full build inside a disposable Docker container.
5. Clones PX4-Autopilot at the configured tag and initializes all PX4 submodules.
6. Runs PX4's Ubuntu dependency setup when present.
7. Builds `px4_sitl_default`.
8. Extracts PX4 runtime files and `Tools/simulation/gz`.
9. Builds `ros-jazzy-xgc2-px4-sitl-1-16`.
10. Installs the `.deb` inside the container.
11. Checks `px4_sitl_runtime_1_16`, `px4_gz_sim_1_16`, and `xgc2_px4_sitl_1_16` with `ros2 pkg prefix`.
12. Uploads the `.deb` as a workflow artifact named by Debian architecture.

APT publishing is intentionally a later stage. GitHub Pages can host the static Debian repository metadata and `pool/` tree after the build artifact is proven installable.
