# GitHub CLI

| Field | Value |
|---|---|
| Tool | [GitHub CLI](https://cli.github.com/) - `gh`, work with pull requests, issues and repositories from the terminal |
| Tested version | `2.102.0` |
| Method | Portable zip from GitHub Releases, SHA256 verified |
| Admin needed | No |
| Install location | `%LOCALAPPDATA%\Programs\gh` |

## Why the default installer needs admin

The vendor's Windows installer is a machine-scope MSI that writes to `C:\Program Files\GitHub CLI` and edits the machine PATH, which needs elevation. The release page also ships a plain zip build that runs from any folder.

## Rejected approaches

| Approach | Why rejected |
|---|---|
| MSI installer from cli.github.com | Machine-scope install under `C:\Program Files`, needs admin. |
| `winget install --id GitHub.cli` | Not tested. The package is an MSI and may default to machine scope and raise a UAC prompt. The zip route avoids the question. |

## Prerequisites

- A Windows standard user account.
- Windows PowerShell 5.1.
- Network access to `github.com` (release download and `gh auth login`).

## Install

### 1. Look up the release and its checksum

```powershell
$r = Invoke-RestMethod https://api.github.com/repos/cli/cli/releases/latest -UseBasicParsing
$asset = $r.assets | Where-Object name -like '*windows_amd64.zip'
$asset.name
$asset.browser_download_url
$asset.digest
```

The `digest` field is the SHA256 that GitHub publishes for the zip. Use the `windows_arm64` zip instead on ARM devices.

### 2. Download, verify and extract into the user profile

```powershell
$ErrorActionPreference = "Stop"
$dl = Join-Path $env:TEMP "gh-dl"
New-Item -ItemType Directory -Force $dl | Out-Null
$zip = Join-Path $dl "gh.zip"
Invoke-WebRequest $asset.browser_download_url -OutFile $zip -UseBasicParsing

$expected = $asset.digest -replace '^sha256:', ''
$actual = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLower()
if ($actual -ne $expected) { throw "Checksum mismatch: $actual" }

$dest = Join-Path $env:LOCALAPPDATA "Programs\gh"
New-Item -ItemType Directory -Force $dest | Out-Null
Expand-Archive $zip -DestinationPath $dest -Force
Remove-Item $dl -Recurse -Force
```

## Integrate

Add the `bin` folder to the user PATH, skipping duplicates, then refresh PATH in the current terminal.

```powershell
$bin = Join-Path $env:LOCALAPPDATA "Programs\gh\bin"
$user = [Environment]::GetEnvironmentVariable("Path", "User")
if (($user -split ';') -notcontains $bin) {
  [Environment]::SetEnvironmentVariable("Path", ($user.TrimEnd(';') + ";" + $bin), "User")
}
$env:Path = [Environment]::GetEnvironmentVariable("Path", "User") + ";" + [Environment]::GetEnvironmentVariable("Path", "Machine")
```

## Verify

| Check | Command | Expected |
|---|---|---|
| Binary runs | `gh --version` | `gh version 2.102.0 ...` |
| Resolved from user profile | `(Get-Command gh).Source` | Path under `%LOCALAPPDATA%\Programs\gh\bin` |
| User PATH entry | `[Environment]::GetEnvironmentVariable("Path","User") -split ';' \| Select-String 'Programs\\gh'` | One match |

## Use

Sign in through the browser. The token is stored by `gh` in the user profile; never paste a token into a guide, script or commit.

```powershell
gh auth login --web
gh auth status
gh repo view <owner>/<repo>
gh pr list
```

`gh auth login --web` prints a one-time code and waits for it at `https://github.com/login/device`. The code expires after a few minutes, so open that page first, then run the command and enter the code straight away. `gh` keeps the token in the Windows credential store, not in a file.

## Uninstall

```powershell
gh auth logout

$bin = Join-Path $env:LOCALAPPDATA "Programs\gh\bin"
$user = [Environment]::GetEnvironmentVariable("Path", "User")
$clean = (($user -split ';') | Where-Object { $_ -and $_ -ne $bin }) -join ';'
[Environment]::SetEnvironmentVariable("Path", $clean, "User")

Remove-Item (Join-Path $env:LOCALAPPDATA "Programs\gh") -Recurse -Force
Remove-Item (Join-Path $env:APPDATA "GitHub CLI") -Recurse -Force -ErrorAction SilentlyContinue
```

The last line removes the `gh` config folder (settings and stored host entries). No Start Menu shortcut or `HKCU` key is created by this guide.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `gh` is not recognized | The terminal started before the user PATH changed | Open a new terminal, or run the PATH refresh line from Integrate. |
| `Checksum mismatch` | Corrupted or incomplete download, or the file was altered | Delete `%TEMP%\gh-dl`, download again. If it persists, do not use the file. |
| `Expand-Archive` fails with a path error | Old files locked by a running `gh` process | Close terminals using `gh`, then re-run the extract step. |
| Browser sign-in does not open | No default browser or a policy blocks it | Copy the one-time code and the URL that `gh auth login --web` prints, and open it manually. |
