# Docker Engine in WSL2 + Portainer

| Field | Value |
|---|---|
| Tool | [Docker Engine](https://docs.docker.com/engine/) (Apache 2.0) running in a WSL2 Linux distro, with [Portainer CE](https://www.portainer.io/) as the browser GUI - a Docker Desktop replacement with no Docker Desktop licence |
| Tested version | Docker Engine `29.9.0`, Compose `v5.6.0`, Portainer CE `2.45.2`, Ubuntu `24.04.5 LTS`, WSL `2.7.10.0` |
| Method | `wsl --install --web-download` for the distro, Docker's official apt repository for the engine, Portainer as a container |
| Admin needed | No, provided WSL2 is already enabled on the machine |
| Install location | `%LOCALAPPDATA%\wsl\<guid>\ext4.vhdx` (the distro disk) |

## Why the default installer needs admin

Docker Desktop is the vendor's Windows product. It is subject to a paid subscription in larger organizations (check the current Docker terms and ask your legal or procurement team), which is why many companies forbid it. Docker Engine itself is open source and free, so the route here runs the engine inside a WSL2 distro and skips Docker Desktop entirely.

WSL2 itself is a Windows feature. Enabling it needs administrator rights, so this guide treats an already enabled WSL2 as a prerequisite to request from IT. Installing a distro and everything inside it needs no elevation: the distro lives in the user profile, and `sudo` or root inside the distro is Linux root in the virtual machine, not a Windows UAC prompt.

## Rejected approaches

| Approach | Why rejected |
|---|---|
| Docker Desktop | Licence concern in an enterprise, the reason for this guide. |
| Rancher Desktop (MSI, version 1.24.0) | The installer is a dual-purpose MSI, but running it for the current user (`MSIINSTALLPERUSER=1 ALLUSERS=""`) still raises a UAC prompt. The Windows Installer log shows `Elevation required to install product`, and the package does not carry the flag that declares no elevation is needed. It needs IT to install it machine-wide. |
| Podman Desktop | Not tested. The vendor docs offer a per-user install scope, but state that enabling WSL needs administrator rights and do not say whether creating the Podman machine on an already enabled WSL needs them too. |
| Finch | CLI only, so it does not give a GUI. Its Windows MSI was not tested for elevation. |
| Docker Engine on TCP `2375` for a Windows `docker.exe` | The API has no authentication and is root-equivalent on the engine. Reachable by every local process once WSL forwards localhost. Not used. |

## Prerequisites

- A Windows standard user account.
- WSL2 enabled. Check with `wsl --status`: it must report `Default Version: 2`. If WSL is not installed, ask IT to enable it and stop here.
- Network access to `download.docker.com`, `registry-1.docker.io` and the Ubuntu WSL image host.

## Install

### 1. Install the Ubuntu distro

`--no-launch` skips the interactive first-run user prompt, so every later step is scripted.

```powershell
wsl --install -d Ubuntu-24.04 --web-download --no-launch
wsl -d Ubuntu-24.04 -u root -- bash -c "ps -p 1 -o comm="
```

The second command prints `systemd`. Ubuntu 24.04 images enable systemd by default through `/etc/wsl.conf`, which Docker needs to run as a service.

### 2. Install Docker Engine from Docker's apt repository

Open a root shell in the distro with `wsl -d Ubuntu-24.04 -u root`, then run the following (it is Docker's documented apt method for Ubuntu).

```bash
set -e
apt-get update
apt-get install -y ca-certificates curl

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

. /etc/os-release
cat > /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: ${UBUNTU_CODENAME:-$VERSION_CODENAME}
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker
docker --version
```

### 3. Work around the WSL DNS tunnel (still in the root shell)

The Go DNS resolver inside `dockerd` can fail against the WSL DNS proxy, so `docker pull` reports `lookup registry-1.docker.io on 10.255.255.254:53: server misbehaving` while `curl` in the same distro works. Force the system resolver for the engine only.

```bash
install -d /etc/systemd/system/docker.service.d
cat > /etc/systemd/system/docker.service.d/override.conf <<'EOF'
[Service]
Environment="GODEBUG=netdns=cgo"
EOF
systemctl daemon-reload
systemctl restart docker
```

### 4. Create a Linux user for daily work (still in the root shell)

Running as root works, but a non-root user in the `docker` group is the normal setup. The name `dev` is an example.

```bash
adduser --disabled-password --gecos "" dev
usermod -aG docker dev
cat > /etc/wsl.conf <<'EOF'
[boot]
systemd=true

[user]
default=dev
EOF
exit
```

Back in PowerShell, restart the distro so the default user takes effect.

```powershell
wsl --terminate Ubuntu-24.04
```

### 5. Start Portainer CE

Portainer is a container that talks to the engine through its socket. Bind it to `127.0.0.1` only, and use `unless-stopped` so a container you stopped by hand stays stopped after a restart.

```powershell
wsl -d Ubuntu-24.04 -- docker volume create portainer_data
wsl -d Ubuntu-24.04 -- docker run -d --name portainer --restart unless-stopped -p 127.0.0.1:9443:9443 -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce:lts
```

Open `https://localhost:9443` and accept the self-signed certificate warning. Create the admin account immediately: Portainer locks the first-run setup after a few minutes (vendor behavior, untested), and `docker restart portainer` re-opens it.

## Integrate

No PATH, Start Menu or `HKCU` change is needed. Run the engine through `wsl`, or open a shell with `wsl -d Ubuntu-24.04`. A Windows-side `docker.exe` is not part of this guide.

## Verify

| Check | Command | Expected |
|---|---|---|
| Engine runs as a service | `wsl -d Ubuntu-24.04 -- systemctl is-active docker` | `active` |
| Non-root user can use Docker | `wsl -d Ubuntu-24.04 -- docker run --rm hello-world` | `Hello from Docker!` |
| Compose plugin | `wsl -d Ubuntu-24.04 -- docker compose version` | `Docker Compose version v5.6.0` |
| Portainer from Windows | `curl.exe -k -s -o NUL -w "%{http_code}" https://127.0.0.1:9443/` | `200` |
| Distro disk in user profile | `Get-ChildItem "$env:LOCALAPPDATA\wsl" -Recurse -Filter ext4.vhdx` | One `ext4.vhdx` file |

## Use

```powershell
wsl -d Ubuntu-24.04 -- docker ps
wsl -d Ubuntu-24.04 -- docker run --rm -it alpine:3.20 sh
wsl -d Ubuntu-24.04 -- docker compose up -d
wsl -d Ubuntu-24.04 -- docker stop portainer
wsl -d Ubuntu-24.04 -- docker start portainer
```

Mounting the Docker socket into Portainer gives it root-equivalent control of the engine. Keep the port bound to `127.0.0.1`, set a strong admin password, and do not publish `9443` on other interfaces. On a shared Windows host, other local users can reach a port WSL forwards to localhost.

## Uninstall

`wsl --unregister` deletes the whole distro, including every image, container and volume in it. Export what you need first.

```powershell
wsl --export Ubuntu-24.04 "$env:USERPROFILE\ubuntu-24.04-backup.tar"
wsl --unregister Ubuntu-24.04
```

Untested step. `wsl --unregister` removes the distro disk under `%LOCALAPPDATA%\wsl` and the `Lxss` entry in `HKCU`. Check afterwards for a leftover Start Menu folder named after the distro and delete it if present.

```powershell
$sm = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Ubuntu-24.04"
if (Test-Path $sm) { Remove-Item $sm -Recurse -Force }
```

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `docker pull` fails with `lookup ... on 10.255.255.254:53: server misbehaving` | The Go resolver in `dockerd` does not work with the WSL DNS proxy | Apply step 3, then retry. |
| `dial tcp [2600:...]:443: connect: network is unreachable` | The distro has no IPv6 route and the pull tried an IPv6 address first | Apply step 3. If it persists, disabling IPv6 in the distro with `sysctl net.ipv6.conf.all.disable_ipv6=1` is a possible fallback (untested as a fix). |
| `permission denied` on `/var/run/docker.sock` | The Linux user is not in the `docker` group, or the distro was not restarted | Run step 4 again, then `wsl --terminate Ubuntu-24.04`. |
| `Cannot connect to the Docker daemon` | systemd is off or the service stopped | `wsl -d Ubuntu-24.04 -u root -- systemctl status docker`. |
| `https://localhost:9443` does not load | The container is stopped, or the first-run setup timed out | `wsl -d Ubuntu-24.04 -- docker restart portainer`. |
| `wsl --install` asks for elevation or reports WSL is missing | WSL2 is not enabled on this machine | Stop and ask IT to enable WSL2. |
