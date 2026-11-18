# Sublime Text 4

| Field | Value |
|---|---|
| Tool | [Sublime Text 4](https://www.sublimetext.com/) |
| Tested version | Build 4213, 64-bit |
| Method | Official portable zip + per-user integration (Start Menu, PATH, context menu under `HKCU`) |
| Admin needed | No |
| Install location | `%LOCALAPPDATA%\Programs\Sublime Text` |

## Why the default installer needs admin

The standard setup (`sublime_text_build_<build>_x64_setup.exe`, also what `winget install SublimeHQ.SublimeText.4` runs) is an Inno Setup installer built with `PrivilegesRequired=admin`. It raises a UAC prompt and writes to `C:\Program Files`. A standard user cannot approve it.

## Rejected approaches

| Approach | Why rejected |
|---|---|
| Standard Inno Setup installer (direct download or winget) | Requires admin; stops at the UAC prompt |
| winget package `SublimeHQ.SublimeText.3.Portable` | It is Sublime Text 3 (build 3211), not version 4 |
| `New-Item -Path 'HKCU:\Software\Classes\*\shell\...'` | The PowerShell registry provider treats `*` in `-Path` as a wildcard and walks every subkey; the command hangs. Use the .NET registry API instead (step 5) |

## Prerequisites

- A Windows standard user account.
- PowerShell 5.1 or later.

## Install

Set the variables once; every step below uses them. Check <https://www.sublimetext.com/download> for the current build number.

```powershell
$build      = "4213"
$zipName    = "sublime_text_build_${build}_x64.zip"
$zipPath    = Join-Path $env:TEMP $zipName
$installDir = Join-Path $env:LOCALAPPDATA "Programs\Sublime Text"
$exe        = Join-Path $installDir "sublime_text.exe"
```

### 1. Download the portable zip

```powershell
Invoke-WebRequest -Uri "https://download.sublimetext.com/$zipName" -OutFile $zipPath
```

About 28 MB, over HTTPS from the official Sublime HQ server.

### 2. Extract into the user programs folder

```powershell
New-Item -ItemType Directory -Path $installDir -Force | Out-Null
Expand-Archive -Path $zipPath -DestinationPath $installDir -Force
Remove-Item $zipPath
```

The folder now holds `sublime_text.exe`, the command-line helper `subl.exe`, the bundled Python runtime and the default packages.

### 3. Start Menu shortcut

```powershell
$lnk   = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Sublime Text.lnk"
$shell = New-Object -ComObject WScript.Shell
$sc    = $shell.CreateShortcut($lnk)
$sc.TargetPath       = $exe
$sc.WorkingDirectory = $installDir
$sc.IconLocation     = "$exe,0"
$sc.Save()
```

### 4. Add to the user PATH (enables `subl`)

```powershell
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if (($userPath -split ';') -notcontains $installDir) {
    [Environment]::SetEnvironmentVariable("Path", "$userPath;$installDir", "User")
}
$env:Path = "$env:Path;$installDir"
```

### 5. "Open with Sublime Text" context menu

Writes only under `HKEY_CURRENT_USER\Software\Classes`, through the .NET API so `*` is taken literally.

```powershell
$entries = @(
    @{ Key = 'Software\Classes\*\shell\Open with Sublime Text';                    Arg = '%1' },  # any file
    @{ Key = 'Software\Classes\Directory\shell\Open with Sublime Text';            Arg = '%V' },  # a folder
    @{ Key = 'Software\Classes\Directory\Background\shell\Open with Sublime Text'; Arg = '%V' }   # folder background
)
foreach ($e in $entries) {
    $k = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($e.Key)
    $k.SetValue('', 'Open with Sublime Text')
    $k.SetValue('Icon', $exe)
    $cmd = $k.CreateSubKey('command')
    $cmd.SetValue('', "`"$exe`" `"$($e.Arg)`"")
    $cmd.Close(); $k.Close()
}
```

On Windows 11 these entries appear under **Show more options** in the right-click menu.

## Verify

| Check | Command | Expected |
|---|---|---|
| Main executable | `Test-Path $exe` | `True` |
| CLI helper | `Test-Path (Join-Path $installDir 'subl.exe')` | `True` |
| Start Menu shortcut | `Test-Path $lnk` | `True` |
| User PATH | `[Environment]::GetEnvironmentVariable('Path','User') -split ';' -contains $installDir` | `True` |
| File context menu | `(Get-Item -LiteralPath 'HKCU:\Software\Classes\*\shell\Open with Sublime Text\command').GetValue('')` | `"<installDir>\sublime_text.exe" "%1"` |
| Folder context menu | `(Get-Item -LiteralPath 'HKCU:\Software\Classes\Directory\shell\Open with Sublime Text\command').GetValue('')` | `"<installDir>\sublime_text.exe" "%V"` |

## Use

- Start Menu: press `Win`, type `Sublime Text`.
- Terminal (new window): `subl .` opens the current folder, `subl <file>` opens a file.
- File Explorer: right-click a file, a folder or empty space in a folder, then **Open with Sublime Text**.
- Package Control: `Ctrl+Shift+P`, type `Install Package Control`, press `Enter`.

## Uninstall

```powershell
$installDir = Join-Path $env:LOCALAPPDATA "Programs\Sublime Text"
Remove-Item -Recurse -Force $installDir
Remove-Item (Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Sublime Text.lnk")
foreach ($k in 'Software\Classes\*\shell\Open with Sublime Text',
               'Software\Classes\Directory\shell\Open with Sublime Text',
               'Software\Classes\Directory\Background\shell\Open with Sublime Text') {
    [Microsoft.Win32.Registry]::CurrentUser.DeleteSubKeyTree($k, $false)
}
$p = [Environment]::GetEnvironmentVariable("Path", "User") -split ';' | Where-Object { $_ -and $_ -ne $installDir }
[Environment]::SetEnvironmentVariable("Path", ($p -join ';'), "User")
# User settings and packages live in %APPDATA%\Sublime Text - delete it too for a clean removal.
```
