# Crane

| Field | Value |
|---|---|
| Tool | [crane](https://github.com/google/go-containerregistry/tree/main/cmd/crane) - CLI to inspect, copy and push container images and registry manifests without a Docker daemon |
| Tested version | `0.22.1` |
| Method | Portable archive from the GitHub release, SHA256 verified |
| Admin needed | No |
| Install location | `%LOCALAPPDATA%\Programs\crane` |

## Why the default installer needs admin

Crane ships no installer. The usual instructions copy the binary into a machine-wide directory such as `C:\Program Files` or a system `PATH` folder, which needs elevation. The release archive contains a single self-contained `crane.exe`, so it runs from the user profile.

## Rejected approaches

| Approach | Why rejected |
|---|---|
| `go install github.com/google/go-containerregistry/cmd/crane@latest` | Needs a Go toolchain and compiles from source. The release binary is faster and its checksum is published. |
| Copy `crane.exe` to `C:\Program Files` or `C:\Windows` | Needs administrator rights. |
| Docker Desktop (bundles registry tooling) | Machine-wide install, needs elevation, and crane does not need a Docker daemon. |

## Prerequisites

- A Windows standard user account.
- Windows PowerShell 5.1 and `tar` (both ship with Windows 10 and 11).
- Network access to `github.com`.

## Install

### 1. Download and verify

The archive is untrusted until its checksum matches the one published in the same release. Set `$tag` to the version you want, taken from the [releases page](https://github.com/google/go-containerregistry/releases).

```powershell
$ErrorActionPreference = "Stop"
$tag = "v0.22.1"
$base = "https://github.com/google/go-containerregistry/releases/download/$tag"
$dl = Join-Path $env:TEMP "crane-dl"
New-Item -ItemType Directory -Force $dl | Out-Null
$tgz = Join-Path $dl "go-containerregistry_Windows_x86_64.tar.gz"
Invoke-WebRequest "$base/go-containerregistry_Windows_x86_64.tar.gz" -OutFile $tgz
Invoke-WebRequest "$base/checksums.txt" -OutFile (Join-Path $dl "checksums.txt")
$want = ((Get-Content (Join-Path $dl "checksums.txt")) -match 'Windows_x86_64\.tar\.gz' -split '\s+')[0]
$got = (Get-FileHash $tgz -Algorithm SHA256).Hash
if ($want -ne $got) { throw "checksum mismatch" }
```

### 2. Extract into the user profile

```powershell
$dest = Join-Path $env:LOCALAPPDATA "Programs\crane"
New-Item -ItemType Directory -Force $dest | Out-Null
tar -xzf $tgz -C $dest crane.exe
Remove-Item $dl -Recurse -Force
```

## Integrate

Add the folder to the user `PATH` with a duplicate check. Open a new terminal afterwards.

```powershell
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if (($userPath -split ';') -notcontains $dest) {
    [Environment]::SetEnvironmentVariable("Path", ($userPath.TrimEnd(';') + ";" + $dest), "User")
}
```

## Verify

| Check | Command | Expected |
|---|---|---|
| Binary runs | `crane version` | `0.22.1` |
| Resolves on PATH | `(Get-Command crane).Source` | Path under `%LOCALAPPDATA%\Programs\crane` |
| Registry access | `crane digest alpine:3.20` | A `sha256:...` digest |

The registry check was not run as part of this guide and comes from the vendor documentation.

## Use

| Task | Command |
|---|---|
| List tags | `crane ls <registry>/<repo>` |
| Get image digest | `crane digest <image>` |
| Show manifest | `crane manifest <image>` |
| Copy image between registries | `crane copy <src-image> <dst-image>` |
| Export filesystem to tar | `crane export <image> out.tar` |
| Log in to a registry | `crane auth login <registry> -u <user> --password-stdin` |

Crane reads credentials from the Docker config file (`%USERPROFILE%\.docker\config.json`). Never paste a token into a command line that is stored in shell history; use `--password-stdin`.

## Uninstall

```powershell
Remove-Item (Join-Path $env:LOCALAPPDATA "Programs\crane") -Recurse -Force
$dest = Join-Path $env:LOCALAPPDATA "Programs\crane"
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
$new = (($userPath -split ';') | Where-Object { $_ -and $_ -ne $dest }) -join ';'
[Environment]::SetEnvironmentVariable("Path", $new, "User")
```

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `crane` is not recognized | The terminal started before the PATH change | Open a new terminal, or run the binary by its full path |
| `checksum mismatch` | Incomplete download or the file was altered | Delete `%TEMP%\crane-dl`, download again, and stop if it still differs |
| `tar` fails to extract | Archive name differs for the chosen release | List assets on the release page and adjust the file name in the script |
| `UNAUTHORIZED` from a registry | No credentials for that registry | Run `crane auth login <registry>` |
