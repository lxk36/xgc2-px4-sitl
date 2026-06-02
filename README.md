# px4_sitl_runtime

Build rules for the XGC2 PX4 v1.14 SITL Debian package on ROS Noetic.

This repository is intentionally small. It does not store PX4 source trees, PX4 binaries, Gazebo plugin binaries, or built `.deb` files. CI clones the configured PX4 tag, builds the SITL runtime and Gazebo Classic plugins in the target Ubuntu/ROS environment, and packages only the runtime artifacts users need.

## Package Model

This branch publishes one user-facing Gazebo Classic Debian package:

```bash
ros-noetic-xgc2-gz-classic-px4-1-14
```

The build emits a PX4 SITL runtime package and a Gazebo Classic package. Installing `ros-noetic-xgc2-gz-classic-px4-1-14` also installs the matching PX4 runtime dependency and provides these ROS packages under `/opt/ros/noetic`:

```text
px4_sitl_runtime_1_14
sitl_gazebo_1_14
```

`px4_sitl_runtime_1_14` contains PX4 SITL runtime files and helper scripts. `sitl_gazebo_1_14` contains the PX4 Gazebo Classic models, worlds, plugin libraries, and combined MAVROS/Gazebo launch file from PX4 v1.14.

The PX4 maintenance line is encoded in the Debian package name. The Debian `Version` tracks the exact PX4 tag plus a packaging revision:

```text
PX4 v1.14.4 -> ros-noetic-xgc2-gz-classic-px4-1-14 1.14.4-1
PX4 v1.14.4 packaging fix -> ros-noetic-xgc2-gz-classic-px4-1-14 1.14.4-2
```

Other Ubuntu 20.04 compatible PX4 lines can use separate package names such as `ros-noetic-xgc2-gz-classic-px4-1-12`. This keeps APT versioning for revisions within the same PX4 line instead of using it to switch major runtime layouts.

## User Installation

Once the self-hosted APT repository is enabled, install the runtime with:

```bash
curl -fsSL https://APT_DOMAIN/xgc2-archive-keyring.gpg | \
  sudo gpg --dearmor -o /usr/share/keyrings/xgc2-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/xgc2-archive-keyring.gpg arch=amd64] https://APT_DOMAIN focal main" | \
  sudo tee /etc/apt/sources.list.d/xgc2.list

sudo apt update
sudo apt install ros-noetic-xgc2-gz-classic-px4-1-14
```

Check available packaging revisions:

```bash
apt-cache madison ros-noetic-xgc2-gz-classic-px4-1-14
```

Launch Iris with MAVROS and Gazebo Classic:

```bash
source /opt/ros/noetic/setup.bash
roslaunch sitl_gazebo_1_14 iris_mavros_gazebo.launch vehicle:=iris gui:=true
```

## Installed Layout

PX4 SITL runtime:

```text
/opt/ros/noetic/share/px4_sitl_runtime_1_14/
├── config/
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
/opt/ros/noetic/share/sitl_gazebo_1_14/
├── launch/
├── models/
├── package.xml
└── worlds/

/opt/ros/noetic/lib/sitl_gazebo_1_14/
└── lib*.so
```

The launch file uses `/tmp/px4_sitl_runtime` as the writable rootfs so generated PX4 files such as `parameters.bson`, `dataman`, and logs do not pollute installed files.

## Local Build

The normal local path builds inside the official ROS Noetic image:

```bash
.xgc2/scripts/build_runtime_deb_in_docker.sh \
  --work-dir /tmp/px4-runtime-work \
  --output-dir debs
```

The script pulls `ros:noetic-ros-base-focal`, clones PX4 v1.14.4, initializes PX4 submodules, installs explicit Gazebo Classic build dependencies, runs PX4's `Tools/setup/ubuntu.sh --no-nuttx` when available, builds `px4_sitl_default` and `sitl_gazebo-classic`, extracts runtime artifacts, runs lightweight runtime checks, builds the Debian package, installs it in the same disposable container, and verifies that both ROS packages are discoverable by `rospack`.

For lower-level debugging, run the stages directly:

```bash
.xgc2/scripts/fetch_px4.sh --work-dir /tmp/px4-runtime-work
.xgc2/scripts/build_px4_runtime.sh --px4-dir /tmp/px4-runtime-work/PX4-Autopilot
.xgc2/scripts/extract_px4_runtime.sh \
  --px4-dir /tmp/px4-runtime-work/PX4-Autopilot \
  --output-dir /tmp/px4-runtime-stage
.xgc2/scripts/extract_gazebo_classic_runtime.sh \
  --px4-dir /tmp/px4-runtime-work/PX4-Autopilot \
  --output-dir /tmp/gazebo-runtime-stage
.xgc2/scripts/check_px4_runtime.sh /tmp/px4-runtime-stage
.xgc2/scripts/build_deb.sh \
  --runtime-dir /tmp/px4-runtime-stage \
  --gazebo-dir /tmp/gazebo-runtime-stage \
  --output-dir debs
```

## Self-Hosted APT Publishing

The `build-runtime` workflow can publish `.deb` artifacts directly to the
self-hosted XGC2 APT repository over SSH. Publishing is enabled only when these
repository secrets exist:

```bash
APT_REPO_HOST
APT_REPO_PORT
APT_REPO_SSH_KEY
APT_REPO_KNOWN_HOSTS
```

`APT_REPO_HOST` is the SSH publish host. `APT_REPO_PORT` is the container SSH
publish port. `APT_REPO_SSH_KEY` is the private half of the CI deploy key whose
public half is installed in the APT server `authorized_keys`.
`APT_REPO_SSH_KEY` must be the full multi-line private key, including these
first and last lines:

```text
-----BEGIN OPENSSH PRIVATE KEY-----
...
-----END OPENSSH PRIVATE KEY-----
```

Do not paste the `.pub` public key into `APT_REPO_SSH_KEY`.
`APT_REPO_KNOWN_HOSTS` is the pinned SSH host key line for strict host checking.
It proves to CI that the SSH endpoint is the expected APT server before any
package data is sent.

Create `APT_REPO_KNOWN_HOSTS` from the same host and port that CI will use:

```bash
APT_REPO_HOST=server.example.com
APT_REPO_PORT=2222

ssh-keyscan -p "$APT_REPO_PORT" "$APT_REPO_HOST" > apt_known_hosts
cat apt_known_hosts
```

Paste the full `cat apt_known_hosts` output into the GitHub secret. Copy the
whole line, including `[host]:port`, `ssh-ed25519`, and the long key value. Do
not paste only the `AAAAC3...` part.

Correct `APT_REPO_KNOWN_HOSTS` value:

```text
[server.example.com]:2222 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA...
```

Wrong value:

```text
AAAAC3NzaC1lZDI1NTE5AAAA...
```

If `APT_REPO_HOST` is an IP address, generate the line with that IP address. If
it is a domain name, generate the line with that domain name. Do not use
`127.0.0.1` unless GitHub Actions will connect to `127.0.0.1`.

## CI

The `build-runtime` GitHub Actions workflow:

1. Reads `manifest/px4_runtime.yaml`.
2. Builds in parallel for `amd64` and `arm64` on native GitHub-hosted runners.
3. Pulls `ros:noetic-ros-base-focal`.
4. Runs the full build inside a disposable Docker container.
5. Clones PX4-Autopilot at the configured tag and initializes all PX4 submodules.
6. Runs PX4's Ubuntu dependency setup when present.
7. Builds `px4_sitl_default` and the Gazebo Classic `sitl_gazebo-classic` target.
8. Extracts PX4 runtime files, Gazebo Classic models, worlds, and plugins.
9. Runs lightweight PX4 runtime and package layout checks.
10. Builds `ros-noetic-xgc2-px4-sitl-1-14` and `ros-noetic-xgc2-gz-classic-px4-1-14`.
11. Installs the `.deb` inside the container.
12. Checks `px4_sitl_runtime_1_14` and `sitl_gazebo_1_14` with `rospack`.
13. Uploads the `.deb` as a workflow artifact named by Debian architecture.
14. Publishes to the self-hosted APT repository when these repository secrets
    are configured: `APT_REPO_HOST`, `APT_REPO_PORT`, `APT_REPO_SSH_KEY`, and
    `APT_REPO_KNOWN_HOSTS`.

If the APT repository secrets are absent, CI still builds and uploads artifacts
without publishing.
