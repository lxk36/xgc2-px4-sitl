# px4_sitl_runtime

Build rules for the XGC2 PX4 v1.16 SITL Debian package on ROS Jazzy.

This repository does not store PX4 source trees, PX4 binaries, Gazebo Sim assets, or built `.deb` files. CI clones the configured PX4 tag, builds the SITL runtime in the target Ubuntu/ROS environment, extracts the PX4 Gazebo Sim Harmonic model store, and packages only the runtime artifacts users need.

## Package Model

This branch builds one Debian package:

```bash
ros-jazzy-xgc2-sim-1-16
```

That Debian package installs three ROS 2 packages under `/opt/ros/jazzy`:

```text
px4_sitl_runtime_1_16
px4_gz_sim_1_16
xgc2_sim_1_16
```

`px4_sitl_runtime_1_16` contains the extracted PX4 SITL runtime files and helper scripts. `px4_gz_sim_1_16` contains PX4 v1.16 Gazebo Sim Harmonic models, worlds, `server.config`, and the `simulation-gazebo` helper. `xgc2_sim_1_16` is a meta package that depends on both runtime packages.

The PX4 maintenance line is encoded in the Debian package name. The Debian `Version` tracks the exact PX4 tag plus a packaging revision:

```text
PX4 v1.16.2 -> ros-jazzy-xgc2-sim-1-16 1.16.2-1
PX4 v1.16.2 packaging fix -> ros-jazzy-xgc2-sim-1-16 1.16.2-2
```

## User Installation

Once the self-hosted APT repository is enabled, install the runtime with:

```bash
curl -fsSL https://APT_DOMAIN/xgc2-archive-keyring.gpg | \
  sudo gpg --dearmor -o /usr/share/keyrings/xgc2-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/xgc2-archive-keyring.gpg arch=amd64] https://APT_DOMAIN noble main" | \
  sudo tee /etc/apt/sources.list.d/xgc2.list

sudo apt update
sudo apt install ros-jazzy-xgc2-sim-1-16
```

Check available packaging revisions:

```bash
apt-cache madison ros-jazzy-xgc2-sim-1-16
```

Confirm the ROS 2 packages are discoverable:

```bash
source /opt/ros/jazzy/setup.bash
ros2 pkg prefix px4_sitl_runtime_1_16
ros2 pkg prefix px4_gz_sim_1_16
ros2 pkg prefix xgc2_sim_1_16
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
/opt/ros/jazzy/share/xgc2_sim_1_16/
└── package.xml
```

## Local Build

The normal local path builds inside the official ROS Jazzy image:

```bash
.xgc2/scripts/build_runtime_deb_in_docker.sh \
  --work-dir /tmp/px4-runtime-work \
  --output-dir debs
```

The script pulls `ros:jazzy-ros-core-noble`, clones PX4 v1.16.2, initializes PX4 submodules, installs explicit build tooling, runs PX4's `Tools/setup/ubuntu.sh --no-nuttx` when available, builds `px4_sitl_default`, extracts PX4 runtime files and Gazebo Sim Harmonic assets, builds the Debian package, installs it in the same disposable container, and verifies all three ROS 2 packages with `ros2 pkg prefix`.

For lower-level debugging, run the stages directly:

```bash
.xgc2/scripts/fetch_px4.sh --work-dir /tmp/px4-runtime-work
.xgc2/scripts/build_px4_runtime.sh --px4-dir /tmp/px4-runtime-work/PX4-Autopilot
.xgc2/scripts/extract_px4_runtime.sh \
  --px4-dir /tmp/px4-runtime-work/PX4-Autopilot \
  --output-dir /tmp/px4-runtime-stage
.xgc2/scripts/extract_gz_sim_runtime.sh \
  --px4-dir /tmp/px4-runtime-work/PX4-Autopilot \
  --output-dir /tmp/gz-sim-runtime-stage
.xgc2/scripts/check_px4_runtime.sh /tmp/px4-runtime-stage
.xgc2/scripts/check_gz_sim_runtime.sh /tmp/gz-sim-runtime-stage
.xgc2/scripts/build_deb.sh \
  --runtime-dir /tmp/px4-runtime-stage \
  --gz-sim-dir /tmp/gz-sim-runtime-stage \
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
3. Pulls `ros:jazzy-ros-core-noble`.
4. Runs the full build inside a disposable Docker container.
5. Clones PX4-Autopilot at the configured tag and initializes all PX4 submodules.
6. Runs PX4's Ubuntu dependency setup when present.
7. Builds `px4_sitl_default`.
8. Extracts PX4 runtime files and `Tools/simulation/gz`.
9. Builds `ros-jazzy-xgc2-px4-sitl-1-16`, `ros-jazzy-xgc2-px4-gz-harmonic-1-16`, and `ros-jazzy-xgc2-sim-1-16`.
10. Installs the `.deb` inside the container.
11. Checks `px4_sitl_runtime_1_16`, `px4_gz_sim_1_16`, and `xgc2_sim_1_16` with `ros2 pkg prefix`.
12. Uploads the `.deb` as a workflow artifact named by Debian architecture.
13. Publishes to the self-hosted APT repository when these repository secrets
    are configured: `APT_REPO_HOST`, `APT_REPO_PORT`, `APT_REPO_SSH_KEY`, and
    `APT_REPO_KNOWN_HOSTS`.

If the APT repository secrets are absent, CI still builds and uploads artifacts
without publishing.
