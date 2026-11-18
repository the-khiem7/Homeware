# OBS Studio

| Field | Value |
|---|---|
| Tool | [OBS Studio](https://obsproject.com/) - free, open source screen recording and live streaming |
| Tested version | `33.0.0` (Windows x64 zip) |
| Method | Official zip from the GitHub release, SHA256 verified, per-user Start Menu shortcut |
| Admin needed | No (the Virtual Camera feature needs admin - see Rejected approaches) |
| Install location | `%LOCALAPPDATA%\Programs\OBS Studio` |

## Why the default installer needs admin

The standard setup (`OBS-Studio-<version>-Windows-x64-Installer.exe`, also what `winget install OBSProject.OBSStudio` downloads) is a Nullsoft installer. It installs machine-wide under `C:\Program Files\obs-studio`, which a standard user cannot write to. The winget manifest declares no user-scope installer, so `--scope user` has no effect. This step was read from the manifest and was not run, because it would raise a UAC prompt.

## Rejected approaches

| Approach | Why rejected |
|---|---|
| Vendor installer `.exe` (direct download or `winget install OBSProject.OBSStudio`) | Machine-wide install under `C:\Program Files`; stops at the UAC prompt |
| `winget install ... --scope user` | The package ships no user-scope installer; the flag is ignored or the install fails |
| `virtualcam-install.bat` (OBS Virtual Camera) | The script checks `net session` and runs `regsvr32` for a DirectShow filter registered under `HKLM\SOFTWARE\Classes\CLSID`; it exits with "Administrative rights are required". Skip the feature, or request it from IT as a prerequisite |
| Enabling `portable_mode` | Not needed: the zip works from a user folder, and the default settings location `%APPDATA%\obs-studio` is already per-user |

## Prerequisites

- A Windows standard user account, Windows 10 or later, 64-bit.
- PowerShell 5.1 or later.
- About 550 MB free disk space for the extracted folder (the zip is about 214 MB).

## Install

Set the variables once; every step below uses them. Check <https://github.com/obsproject/obs-studio/releases/latest> for the current version and the SHA256 shown next to the `Windows-x64.zip` asset.

```powershell
$version    = "33.0.0"
$sha256     = "3369a3ecd67b5669a8a08d77357f87cc786d1fba42fbbd1054d841a69f6271a7"
$zipName    = "OBS-Studio-$version-Windows-x64.zip"
$downloadDir = Join-Path $env:TEMP "obs-download"
$zipPath    = Join-Path $downloadDir $zipName
$installDir = Join-Path $env:LOCALAPPDATA "Programs\OBS Studio"
$binDir     = Join-Path $installDir "bin\64bit"
$exe        = Join-Path $binDir "obs64.exe"
```

### 1. Download and verify the zip

```powershell
$ProgressPreference = "SilentlyContinue"
New-Item -ItemType Directory -Path $downloadDir -Force | Out-Null
Invoke-WebRequest -Uri "https://github.com/obsproject/obs-studio/releases/download/$version/$zipName" -OutFile $zipPath
if ((Get-FileHash $zipPath -Algorithm SHA256).Hash -ne $sha256) { throw "SHA256 mismatch - do not extract this file" }
```

About 214 MB over HTTPS. `$ProgressPreference` is silenced because the Windows PowerShell 5.1 progress bar slows large downloads a lot.

### 2. Extract into the user programs folder

```powershell
New-Item -ItemType Directory -Path $installDir -Force | Out-Null
Expand-Archive -Path $zipPath -DestinationPath $installDir -Force
Remove-Item -Recurse -Force $downloadDir
```

The folder now holds `bin\64bit\obs64.exe`, `core` (first-party plugins) and `data`. The zip bundles the runtime DLLs it needs; no Visual C++ redistributable install is required.

## Integrate

### Start Menu shortcut

OBS must start with `bin\64bit` as its working directory, so the shortcut sets it explicitly.

```powershell
$lnk   = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\OBS Studio.lnk"
$shell = New-Object -ComObject WScript.Shell
$sc    = $shell.CreateShortcut($lnk)
$sc.TargetPath       = $exe
$sc.WorkingDirectory = $binDir
$sc.IconLocation     = "$exe,0"
$sc.Save()
```

No PATH entry, registry key or file association is needed; OBS is a GUI application.

## Verify

| Check | Command | Expected |
|---|---|---|
| Main executable | `Test-Path $exe` | `True` |
| Version | `(Get-Item $exe).VersionInfo.ProductVersion` | `33.0.0` |
| Vendor signature | `(Get-AuthenticodeSignature $exe).Status` | `Valid` (signer `OBS Project, LLC`) |
| Start Menu shortcut | `Test-Path $lnk` | `True` |
| Runs without elevation | Launch from the Start Menu, then read the first lines of the newest file in `%APPDATA%\obs-studio\logs` | `Running as administrator: false` and `Portable mode: false` |
| Hardware encoder | Search the same log for `Available Encoders` | `obs_qsv11_v2 (QuickSync H.264)` listed on a machine with an Intel iGPU |

## Use

- Start Menu: press `Win`, type `OBS Studio`.
- First launch: OBS may open the Auto-Configuration Wizard. Choose **Optimize just for recording** unless you stream.
- Settings live in `%APPDATA%\obs-studio` (profiles, scenes, logs). Back up that folder to move your setup to another machine.
- Suggested starting encoder choices by hardware (not benchmarked; adjust to your machine):

| Hardware | Encoder in **Settings > Output** | Notes |
|---|---|---|
| Intel iGPU (QuickSync) | `QuickSync H.264` | Lowest CPU load on a laptop without a discrete GPU; verified present in the log of the tested machine |
| No hardware encoder | `x264`, preset `veryfast`, 1080p at 30 fps | Higher CPU load; lower the output resolution or frame rate if frames drop |
| NVIDIA GPU | `NVIDIA NVENC H.264` | Needs the NVIDIA driver; not available on the tested machine |

- Capture sources `Display Capture` and `Window Capture` use the Windows Graphics Capture API, which does not need elevation (vendor documentation; the capture itself was not tested here).

## Uninstall

This guide writes only the install folder, the Start Menu shortcut and, once OBS has run, the settings folder. No PATH entry and no `HKCU` key is created.

```powershell
Get-Process obs64 -ErrorAction SilentlyContinue | Stop-Process
Remove-Item -Recurse -Force (Join-Path $env:LOCALAPPDATA "Programs\OBS Studio")
Remove-Item (Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\OBS Studio.lnk")
# Settings, scenes and logs live in %APPDATA%\obs-studio - delete it too for a clean removal.
Remove-Item -Recurse -Force (Join-Path $env:APPDATA "obs-studio")
```

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Log lines `Failed to initialize module 'aja.dll'`, `'decklink.dll'`, `'obs-nvenc.dll'`, `NVENC not supported` | Optional modules for capture-card hardware or an NVIDIA GPU that this machine does not have | Ignore; they are expected on a machine without that hardware |
| Log line `CoreAudio AAC encoder not installed` | The CoreAudio AAC encoder needs Apple components that are not part of the zip | Ignore; OBS falls back to its built-in AAC encoder |
| **Start Virtual Camera** button fails or the camera is missing in other apps | The DirectShow filter must be registered under `HKLM`, which needs admin | Request the registration from IT, or use `Window Capture` or screen sharing in the target app instead |
| Log line `[twitch ingest update] ... schannel ... SEC_E_ILLEGAL_MESSAGE` at startup | Observed once on a network with a TLS-inspecting security product; the cause was not diagnosed | OBS keeps its cached ingest list and still starts; recheck on another network if streaming to Twitch fails |
| An elevated (run as administrator) window cannot be captured | A non-elevated process cannot capture an elevated window (vendor documentation; not tested here) | Run the captured app as a standard user |
