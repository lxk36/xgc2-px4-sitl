# XGC2 PX4 SITL Package Builder

This repository builds Debian packages for selected PX4 SITL runtime lines. The
`master` branch is the repository entrance: it documents the package layout and
stores the GitHub Actions workflows. Runtime package code lives on versioned
branches.

## Package Branches

| Branch | PX4 | ROS | Ubuntu distribution | Packages |
| --- | --- | --- | --- | --- |
| `v1.12-noetic` | `v1.12.3` | ROS Noetic | `focal` | `ros-noetic-xgc2-px4-sitl-1-12`, `ros-noetic-xgc2-px4-gazebo-classic-1-12`, `ros-noetic-xgc2-sim-1-12` |
| `v1.14-noetic` | `v1.14.4` | ROS Noetic | `focal` | `ros-noetic-xgc2-px4-sitl-1-14`, `ros-noetic-xgc2-px4-gazebo-classic-1-14`, `ros-noetic-xgc2-sim-1-14` |
| `v1.16-jazzy` | `v1.16.2` | ROS 2 Jazzy | `noble` | `ros-jazzy-xgc2-px4-sitl-1-16`, `ros-jazzy-xgc2-px4-gz-harmonic-1-16`, `ros-jazzy-xgc2-sim-1-16` |

Each runtime line produces separate Debian packages for functional ROS packages
plus one meta package:

```text
runtime deb       -> PX4 SITL runtime ROS package
Gazebo/GZ deb     -> simulator assets/plugins/helper ROS package
xgc2-sim meta deb -> depends on the runtime and simulator debs
```

Users normally install the meta package for their line:

```bash
sudo apt install ros-noetic-xgc2-sim-1-12
sudo apt install ros-noetic-xgc2-sim-1-14
sudo apt install ros-jazzy-xgc2-sim-1-16
```

## Connect APT Publishing

Package publishing is optional. Configure these repository secrets to publish to
a self-hosted APT repository over SSH:

```text
APT_REPO_HOST
APT_REPO_PORT
APT_REPO_SSH_KEY
APT_REPO_KNOWN_HOSTS
```

`APT_REPO_SSH_KEY` must be the complete private key, including:

```text
-----BEGIN OPENSSH PRIVATE KEY-----
...
-----END OPENSSH PRIVATE KEY-----
```

Generate `APT_REPO_KNOWN_HOSTS` with the same host and port used by CI:

```bash
APT_REPO_HOST=apt-ssh.example.com
APT_REPO_PORT=2222
ssh-keyscan -t ed25519 -p "$APT_REPO_PORT" "$APT_REPO_HOST"
```

Paste the full output line into `APT_REPO_KNOWN_HOSTS`, for example:

```text
[apt-ssh.example.com]:2222 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA...
```

## Build Workflows

Run `check-apt-ssh` first to verify APT SSH secrets. It only runs the remote
`health` command and does not publish packages.

Run `build-runtime` manually and choose a package branch. The workflow checks out
that branch, builds `amd64` and `arm64` Debian packages, uploads artifacts, and
publishes to APT when the APT secrets are configured.

Scheduled builds run from `master` for all package branches.

## Client Install Template

Replace `APT_BASE_URL` with your own public HTTPS APT endpoint.

```bash
APT_BASE_URL=https://apt.example.com
curl -fsSL "$APT_BASE_URL/xgc2-archive-keyring.gpg" | \
  sudo gpg --dearmor -o /usr/share/keyrings/xgc2-archive-keyring.gpg
```

For Noetic/Focal:

```bash
echo "deb [signed-by=/usr/share/keyrings/xgc2-archive-keyring.gpg arch=amd64] $APT_BASE_URL focal main" | \
  sudo tee /etc/apt/sources.list.d/xgc2-px4-sitl.list
sudo apt update
sudo apt install ros-noetic-xgc2-sim-1-14
```

For Jazzy/Noble:

```bash
echo "deb [signed-by=/usr/share/keyrings/xgc2-archive-keyring.gpg arch=amd64] $APT_BASE_URL noble main" | \
  sudo tee /etc/apt/sources.list.d/xgc2-px4-sitl.list
sudo apt update
sudo apt install ros-jazzy-xgc2-sim-1-16
```
