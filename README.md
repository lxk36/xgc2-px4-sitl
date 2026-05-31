# px4_sitl_runtime

ROS Jazzy CI control package for PX4 SITL runtime Debian packages.

This repository intentionally does **not** store PX4 binaries, PX4 source trees, Gazebo plugin binaries, or Debian artifacts. Runtime binaries are built in target Ubuntu/ROS environments by CI, packaged as `.deb`, and published to an APT repository.

## Versioning

The Debian package name is stable:

```bash
ros-jazzy-px4-sitl-runtime
```

The package version follows the PX4 tag:

```text
PX4 v1.16.2 -> ros-jazzy-px4-sitl-runtime 1.16.2-1
```

The suffix after `-` is the packaging revision. If PX4 stays at `v1.16.2` but packaging changes, publish `1.16.2-2`.

Branch names identify maintenance lines, for example:

```text
v1.16-noetic
v1.16-jazzy
v1.12-noetic
```

## User Installation

Add the XGC APT key and source list:

```bash
curl -fsSL https://apt.example.com/xgc-archive-keyring.gpg | \
  sudo tee /usr/share/keyrings/xgc-archive-keyring.gpg >/dev/null

echo "deb [signed-by=/usr/share/keyrings/xgc-archive-keyring.gpg] https://apt.example.com noble main" | \
  sudo tee /etc/apt/sources.list.d/xgc-sim.list
```

Install the runtime packages:

```bash
sudo apt update
sudo apt install ros-jazzy-px4-sitl-runtime
```

Install a specific PX4 runtime version:

```bash
sudo apt install ros-jazzy-px4-sitl-runtime=1.16.2-1
```

Check available versions:

```bash
apt-cache madison ros-jazzy-px4-sitl-runtime
```

This branch currently packages the PX4 SITL runtime. A ROS 2/Gazebo Sim launch wrapper should be added separately from the old ROS 1/MAVROS/Gazebo Classic launch flow.

```bash
source /opt/ros/jazzy/setup.bash
```

## Runtime Layout

The runtime Debian package installs PX4 files under:

```text
/opt/xgc/px4_sitl_runtime/1.16.2/
├── bin/
│   ├── px4
│   ├── px4-alias.sh
│   └── px4-* -> px4
└── etc/
    ├── init.d/
    ├── init.d-posix/
    └── extras/
```

Gazebo Sim runtime files are expected under:

```text
/opt/xgc/px4_gz_sim/1.16.2/
├── lib/
├── models/
└── worlds/
```

The launch file uses a writable work directory under `/tmp/px4_sitl_runtime` so generated files such as `parameters.bson`, `dataman`, and logs do not pollute installed runtime files.

## Local Runtime Build

The recommended local path builds inside the official ROS Jazzy image:

```bash
scripts/build_runtime_deb_in_docker.sh \
  --work-dir /tmp/px4-runtime-work \
  --output-dir debs
```

This command pulls `osrf/ros:jazzy-desktop-full-noble`, clones the configured PX4 tag, initializes PX4 submodules, runs PX4's `Tools/setup/ubuntu.sh --no-nuttx` inside the container, builds `px4_sitl_default`, extracts the runtime, builds a Debian package, installs that package inside the same disposable container, and checks that the installed PX4 runtime can start.

Build and extract a runtime locally:

```bash
scripts/fetch_px4.sh --work-dir /tmp/px4-runtime-work
scripts/build_px4_runtime.sh --px4-dir /tmp/px4-runtime-work/PX4-Autopilot
scripts/extract_px4_runtime.sh \
  --px4-dir /tmp/px4-runtime-work/PX4-Autopilot \
  --output-dir /tmp/px4-runtime-stage
scripts/check_px4_runtime.sh /tmp/px4-runtime-stage
```

Build a Debian package:

```bash
scripts/build_deb.sh \
  --runtime-dir /tmp/px4-runtime-stage \
  --output-dir debs
```

## CI

The `build-runtime` GitHub Actions workflow:

1. Reads `manifest/px4_runtime.yaml`.
2. Pulls `osrf/ros:jazzy-desktop-full-noble`.
3. Runs the full build inside a disposable Docker container.
4. Clones PX4-Autopilot at the configured tag and initializes submodules.
5. Runs PX4's `Tools/setup/ubuntu.sh --no-nuttx` for build and simulation dependencies.
6. Builds `px4_sitl_default`.
7. Extracts `bin/px4`, `bin/px4-alias.sh`, `bin/px4-*` symlinks, and `etc/`.
8. Builds a Debian package.
9. Installs the Debian package inside the container.
10. Checks that the installed PX4 runtime can start.
11. Uploads the `.deb` as a workflow artifact.

APT publishing is intentionally not enabled in this workflow yet. The helper script is kept for the later publishing stage:

```bash
scripts/publish_apt_repo.sh --deb-dir debs
```

It expects these environment variables:

```text
APT_REPO_HOST
APT_REPO_USER
APT_REPO_PATH
APT_REPO_SSH_KEY
APT_GPG_KEY_ID
```

`APT_GPG_KEY_ID` is optional for unsigned staging repositories, but production repositories should use signed `Release` metadata.
