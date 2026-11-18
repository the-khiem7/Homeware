# uv

| Field | Value |
|---|---|
| Tool | [uv](https://docs.astral.sh/uv/) - fast Python package and project manager, also runs and installs Python versions and CLI tools |
| Tested version | `0.13.9` |
| Method | Official installer script (`install.ps1`), downloaded, reviewed, then run with `UV_INSTALL_DIR` |
| Admin needed | No |
| Install location | `%LOCALAPPDATA%\Programs\uv` |

## Why the default installer needs admin

It does not. The one-line command in the vendor docs (`irm https://astral.sh/uv/install.ps1 | iex`) installs per user into `%USERPROFILE%\.local\bin` and edits only the user `Path` in `HKCU\Environment`. This guide changes two things: it downloads the script and reads it before running it, and it installs under `%LOCALAPPDATA%\Programs\uv` like the other guides in this registry.

## Rejected approaches

| Approach | Why rejected |
|---|---|
| `irm ... \| iex` | Runs a remote script unread. Download, review, then run. |
| Default install location `%USERPROFILE%\.local\bin` | Works, but mixes uv with unrelated tools that also install there. A dedicated folder is easier to remove. |
| `winget install --id astral-sh.uv --scope user` | Valid alternative, but the package may lag behind the latest release. The vendor script always installs the latest build. |
| `pip install uv` | Needs an existing Python and ties uv to that interpreter. |
| Machine-wide MSI or `Program Files` copy | Needs admin. |

## Prerequisites

- A Windows standard user account.
- Windows PowerShell 5.1 or later with an execution policy of `RemoteSigned`, `Unrestricted` or `Bypass` for the running process. The installer stops with an error otherwise. Step 3 uses a per-process bypass, so the policy is not changed.
- Internet access to `astral.sh` and `github.com`.

## Install

### 1. Download the installer

```powershell
$script = "$env:TEMP\uv-installer.ps1"
Invoke-WebRequest https://astral.sh/uv/install.ps1 -OutFile $script -UseBasicParsing
```

### 2. Review it

Open `%TEMP%\uv-installer.ps1` and read it. The checks that matter: it writes only under the install directory and `HKCU\Environment`, and it never touches `HKLM`, `Program Files` or the execution policy.

```powershell
notepad "$env:TEMP\uv-installer.ps1"
```

### 3. Run it into the user profile

`-ExecutionPolicy Bypass` applies to this one PowerShell process only and runs the script you just reviewed. It does not change any stored policy.

```powershell
$env:UV_INSTALL_DIR = "$env:LOCALAPPDATA\Programs\uv"
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:TEMP\uv-installer.ps1"
Remove-Item Env:\UV_INSTALL_DIR
```

The script downloads the release archive from GitHub, places `uv.exe`, `uvx.exe` and `uvw.exe` in the install folder and adds that folder to the user `Path`.

## Integrate

The installer already adds the folder to the user PATH. Open a new terminal to pick it up, or refresh the current one:

```powershell
$env:Path = [Environment]::GetEnvironmentVariable("Path", "User") + ";" + [Environment]::GetEnvironmentVariable("Path", "Machine")
```

If the PATH entry is missing, add it with a duplicate check:

```powershell
$dir = "$env:LOCALAPPDATA\Programs\uv"
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if (($userPath -split ';') -notcontains $dir) {
    [Environment]::SetEnvironmentVariable("Path", ($userPath.TrimEnd(';') + ";" + $dir), "User")
}
```

Tools installed with `uv tool install` put their executables in a separate folder. Print it and add it to the user PATH the same way, or let uv do it:

```powershell
uv tool dir --bin
uv tool update-shell
```

`uv tool update-shell` is taken from the vendor docs and was not run for this guide.

## Verify

| Check | Command | Expected |
|---|---|---|
| Binary runs | `& "$env:LOCALAPPDATA\Programs\uv\uv.exe" --version` | `uv 0.13.9 (...)` |
| On PATH (new terminal) | `Get-Command uv \| Select-Object -ExpandProperty Source` | `...\Programs\uv\uv.exe` |
| User PATH entry | `[Environment]::GetEnvironmentVariable("Path","User") -split ';' \| Select-String 'Programs\\uv'` | One match |
| No admin used | `([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)` | `False` |

## Use

| Task | Command |
|---|---|
| Update uv | `uv self update` |
| Install a Python version | `uv python install 3.13` |
| Create a project | `uv init my-app` then `cd my-app` |
| Add a dependency | `uv add requests` |
| Run a command in the project environment | `uv run python main.py` |
| Create a virtual environment | `uv venv` |
| Install a CLI tool in isolation | `uv tool install ruff` |
| Run a tool without installing it | `uvx ruff --version` |
| Show where uv keeps data | `uv python dir`, `uv tool dir`, `uv cache dir` |

`uv self update` works for a script-based install. The commands in this table come from the vendor docs; only `--version` was run for this guide.

## Uninstall

Remove installed tools and Python versions first if you no longer need them, then the binaries, the PATH entry and the cached data.

```powershell
uv cache clean
$pythonDir = uv python dir
$toolDir = uv tool dir
$cacheDir = uv cache dir

Remove-Item -Recurse -Force $pythonDir, $toolDir, $cacheDir -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "$env:LOCALAPPDATA\Programs\uv"
Remove-Item "$env:TEMP\uv-installer.ps1" -ErrorAction SilentlyContinue

$dir = "$env:LOCALAPPDATA\Programs\uv"
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
$kept = ($userPath -split ';') | Where-Object { $_ -and $_ -ne $dir }
[Environment]::SetEnvironmentVariable("Path", ($kept -join ';'), "User")
```

If you added the `uv tool dir --bin` folder to the user PATH, remove that entry in the same way and delete any leftover executables in that folder. Executables of tools installed with `uv tool install` live there and stop working once the tool directory is removed.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `uv` is not recognized | The terminal started before the PATH change | Open a new terminal, or run the PATH refresh from the Integrate section. |
| Installer throws about the execution policy | The effective policy is `Restricted` or `AllSigned` | Run the script as in step 3 with `-ExecutionPolicy Bypass` for that process. |
| Installer fails to download | Proxy or TLS inspection blocks GitHub | Set `HTTPS_PROXY`, or download the release zip from the uv GitHub releases page in a browser and extract `uv.exe`, `uvx.exe` and `uvw.exe` into `%LOCALAPPDATA%\Programs\uv`. |
| A tool installed with `uv tool install` is not found | The tool bin folder is not on PATH | Run `uv tool update-shell`, or add the output of `uv tool dir --bin` to the user PATH. |
| Python download is blocked or slow | Corporate filter on GitHub release assets | Point uv at an existing Python with `uv python find` or `--python <path>`. |
