# XGC2 PX4 SITL Runtime Packages

This repository builds installable Debian packages for selected PX4 SITL
runtime lines. It is intentionally small: it does not store PX4 source trees,
PX4 binaries, Gazebo binaries, or generated `.deb` artifacts. GitHub Actions
clones the configured PX4 tag, builds in the target ROS/Ubuntu environment,
extracts only the runtime files, packages them as `.deb`, and can publish them
to a self-hosted APT repository.

## Branches And Packages

Each active branch maps to one PX4/ROS/Ubuntu runtime line:

| Branch | PX4 tag | ROS | Ubuntu APT distribution | Gazebo stack | Debian package |
| --- | --- | --- | --- | --- | --- |
| `v1.12-noetic` | `v1.12.3` | ROS Noetic | `focal` | Gazebo Classic | `ros-noetic-xgc2-gz-classic-px4-1-12` |
| `v1.14-noetic` | `v1.14.4` | ROS Noetic | `focal` | Gazebo Classic | `ros-noetic-xgc2-gz-classic-px4-1-14` |
| `v1.16-jazzy` | `v1.16.2` | ROS 2 Jazzy | `noble` | Gazebo Sim Harmonic | `ros-jazzy-xgc2-gz-harmonic-px4-1-16` |

The package name encodes the PX4 maintenance line. Debian package versions track
the PX4 tag plus a packaging revision, for example `1.12.3-1` then `1.12.3-2`.

## What Gets Installed

`v1.12-noetic` installs:

```text
px4_sitl_runtime_1_12
sitl_gazebo_1_12
```

`v1.14-noetic` installs:

```text
px4_sitl_runtime_1_14
sitl_gazebo_1_14
```

`v1.16-jazzy` installs:

```text
px4_sitl_runtime_1_16
px4_gz_sim_1_16
```

The PX4 SITL runtime packages contain only PX4 executable files and helper
scripts. The Gazebo packages contain models, worlds, and plugin assets. The
Gazebo packages depend on the matching PX4 SITL runtime package, so installing
the Gazebo package is the normal complete simulator install.

## CI Build

The `build-runtime` workflow runs on push, manual dispatch, and a weekly
schedule. For each branch it:

1. Reads `manifest/px4_runtime.yaml`.
2. Builds on native `amd64` and `arm64` GitHub-hosted runners.
3. Pulls the branch-specific ROS Docker image.
4. Clones PX4-Autopilot at the configured tag.
5. Initializes PX4 submodules.
6. Installs build dependencies inside a disposable container.
7. Builds the PX4 SITL target and matching Gazebo runtime.
8. Extracts runtime files into package staging directories.
9. Builds the Debian package.
10. Installs the package inside the build container.
11. Verifies package discovery with `rospack` or `ros2 pkg prefix`.
12. Uploads the `.deb` files as GitHub Actions artifacts.
13. Publishes to a self-hosted APT repository if publishing secrets are set.

If APT publishing secrets are missing, CI still builds and uploads artifacts;
the publish step is skipped.

## Connect Your APT Repository

The workflow publishes over SSH to an APT repository server that accepts a forced
command such as `publish focal` or `publish noble`. Configure these GitHub
repository secrets in the package repository:

```text
APT_REPO_HOST
APT_REPO_PORT
APT_REPO_SSH_KEY
APT_REPO_KNOWN_HOSTS
```

`APT_REPO_HOST` is the SSH host name or IP address reachable from GitHub
Actions. `APT_REPO_PORT` is the SSH publish port. `APT_REPO_SSH_KEY` is the
private deploy key. `APT_REPO_KNOWN_HOSTS` pins the SSH server host key for
strict host checking.

`APT_REPO_SSH_KEY` must be the complete multi-line private key:

```text
-----BEGIN OPENSSH PRIVATE KEY-----
...
-----END OPENSSH PRIVATE KEY-----
```

Do not paste the `.pub` public key into `APT_REPO_SSH_KEY`.

Generate `APT_REPO_KNOWN_HOSTS` with the same host and port that GitHub Actions
will use:

```bash
APT_REPO_HOST=apt-ssh.example.com
APT_REPO_PORT=2222

ssh-keyscan -t ed25519 -p "$APT_REPO_PORT" "$APT_REPO_HOST" > apt_known_hosts
cat apt_known_hosts
```

Paste the full output into `APT_REPO_KNOWN_HOSTS`. Correct value:

```text
[apt-ssh.example.com]:2222 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA...
```

Wrong value:

```text
AAAAC3NzaC1lZDI1NTE5AAAA...
```

If `APT_REPO_HOST` is an IP address, generate the line with that IP address. If
it is a domain name, generate the line with that domain name. Do not use
`127.0.0.1` unless GitHub Actions will actually connect to `127.0.0.1`.

Use the manual `check-apt-ssh` workflow to verify the secrets before running a
full package build. It only runs the server `health` command and does not upload
or publish packages.

## Install From Your APT Repository

After CI publishes successfully, clients install through the public HTTPS APT
endpoint of your own repository. Replace `APT_BASE_URL` with your repository
base URL.

Install the repository signing key:

```bash
APT_BASE_URL=https://apt.example.com

curl -fsSL "$APT_BASE_URL/xgc2-archive-keyring.gpg" | \
  sudo gpg --dearmor -o /usr/share/keyrings/xgc2-archive-keyring.gpg
```

For ROS Noetic / Ubuntu 20.04 `focal`:

```bash
APT_BASE_URL=https://apt.example.com

echo "deb [signed-by=/usr/share/keyrings/xgc2-archive-keyring.gpg arch=amd64] $APT_BASE_URL focal main" | \
  sudo tee /etc/apt/sources.list.d/xgc2-px4-sitl.list

sudo apt update
sudo apt install ros-noetic-xgc2-gz-classic-px4-1-12
sudo apt install ros-noetic-xgc2-gz-classic-px4-1-14
```

For ROS 2 Jazzy / Ubuntu 24.04 `noble`:

```bash
APT_BASE_URL=https://apt.example.com

echo "deb [signed-by=/usr/share/keyrings/xgc2-archive-keyring.gpg arch=amd64] $APT_BASE_URL noble main" | \
  sudo tee /etc/apt/sources.list.d/xgc2-px4-sitl.list

sudo apt update
sudo apt install ros-jazzy-xgc2-gz-harmonic-px4-1-16
```

Check available package versions:

```bash
apt-cache madison ros-noetic-xgc2-gz-classic-px4-1-12
apt-cache madison ros-noetic-xgc2-gz-classic-px4-1-14
apt-cache madison ros-jazzy-xgc2-gz-harmonic-px4-1-16
```

## Launch Examples

PX4 v1.12 / ROS Noetic:

```bash
source /opt/ros/noetic/setup.bash
roslaunch sitl_gazebo_1_12 iris_mavros_gazebo.launch vehicle:=iris gui:=true
```

PX4 v1.14 / ROS Noetic:

```bash
source /opt/ros/noetic/setup.bash
roslaunch sitl_gazebo_1_14 iris_mavros_gazebo.launch vehicle:=iris gui:=true
```

PX4 v1.16 / ROS 2 Jazzy:

```bash
source /opt/ros/jazzy/setup.bash
ros2 pkg prefix px4_sitl_runtime_1_16
ros2 pkg prefix px4_gz_sim_1_16
```

Run the packaged Gazebo Sim helper:

```bash
ros2 run px4_gz_sim_1_16 simulation-gazebo --world default
```

## Local Build

Build the current branch in Docker:

```bash
.xgc2/scripts/build_runtime_deb_in_docker.sh \
  --work-dir /tmp/px4-runtime-work \
  --output-dir debs
```

For lower-level debugging, run the stages directly:

```bash
.xgc2/scripts/fetch_px4.sh --work-dir /tmp/px4-runtime-work
.xgc2/scripts/build_px4_runtime.sh --px4-dir /tmp/px4-runtime-work/PX4-Autopilot
.xgc2/scripts/extract_px4_runtime.sh \
  --px4-dir /tmp/px4-runtime-work/PX4-Autopilot \
  --output-dir /tmp/px4-runtime-stage
.xgc2/scripts/check_px4_runtime.sh /tmp/px4-runtime-stage
.xgc2/scripts/build_deb.sh \
  --runtime-dir /tmp/px4-runtime-stage \
  --output-dir debs
```

Some branches require an additional Gazebo runtime staging argument; see the
branch scripts and `manifest/px4_runtime.yaml` for the exact branch-specific
build inputs.

## Notes

This repository is a package build and publication wrapper. It is not a PX4
source fork, not a binary artifact store, and not an APT server. Use your own APT
repository URL and GitHub Secrets when publishing from a fork.
