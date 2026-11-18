# Rust + Tauri 2

| Field | Value |
|---|---|
| Tool | [Rust](https://www.rust-lang.org/) - `rustc`, `cargo`, `rustup`, and [Tauri 2](https://tauri.app/) - build desktop apps with a Rust backend and web frontend |
| Tested version | Rust `1.100.0` (MSVC target), MSVC `14.44.35207`, Windows SDK `10.0.26100`, `@tauri-apps/cli` `2.12.5`, `create-tauri-app` `4.7.5` |
| Method | Rust: `rustup-init` (per-user, SHA256 verified). C++ build tools: portable MSVC + Windows SDK unpacked with `msiexec /a`. Tauri CLI: npm dev dependency |
| Admin needed | No |
| Install location | Rust: `%USERPROFILE%\.cargo` and `%USERPROFILE%\.rustup`. MSVC and SDK: `%LOCALAPPDATA%\Programs\MSVC`. Tauri bundler tools: `%LOCALAPPDATA%\tauri` |

## Why the default installer needs admin

The Rust installer itself is per-user. The blocker is the linker. Rust on Windows uses the MSVC target by default, and Tauri requires it. That target needs `link.exe` and the Windows SDK libraries, which the official route installs with "Visual Studio Build Tools" (`vs_BuildTools.exe`). That installer needs elevation, writes under `C:\Program Files (x86)` and registers machine-wide components. This guide replaces it with an unpacked copy of the same Microsoft packages in the user profile.

## Rejected approaches

| Approach | Why rejected |
|---|---|
| Visual Studio Build Tools installer | Needs elevation and writes machine-wide. Use it instead of the portable copy if IT can install it for you. |
| `x86_64-pc-windows-gnu` Rust toolchain with MinGW | Tauri documents and tests the MSVC target only. Many crates also compile C code and expect an MSVC-compatible build. |
| `winget install Rustlang.Rustup` | Not tested. It wraps the same `rustup-init` and does not remove the MSVC requirement. |
| `cargo install tauri-cli` | Compiles the CLI from source (long, and needs the full MSVC setup first). The npm package ships a prebuilt binary and pins the CLI version per project. |
| Persisting `vcvars` in a `.ps1` helper | Many standard-user profiles block script execution (`running scripts is disabled`). User-scope environment variables need no script at build time. |

## Prerequisites

- A Windows standard user account.
- Windows PowerShell 5.1.
- Python 3 on PATH, only to run the portable MSVC script once. Remove it afterwards if you do not need it.
- Node.js with `npm`, for the Tauri CLI and the frontend. Use `npm.cmd` instead of `npm` if `npm.ps1` is blocked by the execution policy.
- Microsoft Edge WebView2 Runtime. It ships with Windows 11 and Microsoft Edge. If it is missing, ask IT, because the standalone runtime installer is machine-wide.
- You accept the [Visual Studio Build Tools license](https://visualstudio.microsoft.com/license-terms/vs2022-ga-diagnostic-buildtools/) for the portable MSVC copy. Check that your organization allows this route before you use it.
- About 4 GB free disk space for toolchains, plus about 1.5 GB per Tauri project for build output.

## Install

Run each block in Windows PowerShell as the standard user. Native tools write progress to stderr, so blocks that call them set `$ErrorActionPreference = "Continue"` or use `cmd /c`.

### 1. Download rustup-init and verify it

```powershell
$dl = Join-Path $env:TEMP "rust-dl"
New-Item -ItemType Directory -Force $dl | Out-Null
$exe = Join-Path $dl "rustup-init.exe"
Invoke-WebRequest "https://static.rust-lang.org/rustup/dist/x86_64-pc-windows-msvc/rustup-init.exe" -OutFile $exe -UseBasicParsing
$expected = ([Text.Encoding]::ASCII.GetString((Invoke-WebRequest "https://static.rust-lang.org/rustup/dist/x86_64-pc-windows-msvc/rustup-init.exe.sha256" -UseBasicParsing).Content)).Trim().Split(' ')[0]
$actual = (Get-FileHash $exe -Algorithm SHA256).Hash
if ($actual -ne $expected.ToUpper()) { throw "Checksum mismatch: $actual" }
```

Use `aarch64-pc-windows-msvc` in both URLs on ARM devices.

### 2. Install Rust into the user profile

```powershell
cmd /c "`"$exe`" -y --default-toolchain stable --profile minimal --no-modify-path 2>&1"
```

`--profile minimal` installs `rustc`, `cargo` and the standard library only (about 600 MB). `--no-modify-path` leaves PATH to the Integrate step. The warning `installing msvc toolchain without its prerequisites` is expected, because the C++ tools come from step 3.

### 3. Download, review and run the portable MSVC script

The script is a community tool that downloads Microsoft's own packages, checks every SHA256 against Microsoft's manifest and unpacks them with `msiexec /a`. It does not install anything machine-wide.

```powershell
$msvcDl = Join-Path $env:TEMP "msvc-dl"
New-Item -ItemType Directory -Force $msvcDl | Out-Null
Invoke-WebRequest "https://gist.githubusercontent.com/mmozeiko/7f3162ec2988e81e56d5c4e22cde9977/raw/portable-msvc.py" -OutFile (Join-Path $msvcDl "portable-msvc.py") -UseBasicParsing
(Get-FileHash (Join-Path $msvcDl "portable-msvc.py")).Hash
notepad (Join-Path $msvcDl "portable-msvc.py")
```

Read the script before you run it. The version reviewed for this guide has SHA256 `1791CCCCA594FF083CE8D3E0A139E6156D2C312E24332A909E608010F0230A51`. If your hash differs, the script changed, so review it again.

```powershell
Set-Location $msvcDl
python portable-msvc.py --show-versions
python portable-msvc.py --accept-license --msvc-version 14.44 --sdk-version 26100
Move-Item (Join-Path $msvcDl "msvc") (Join-Path $env:LOCALAPPDATA "Programs\MSVC")
```

Pick versions from the `--show-versions` list. The download is about 460 MB and unpacks to about 1.2 GB. `--accept-license` records that you accepted the license shown by the script. Leave it out to be asked interactively.

### 4. Remove the download folders

```powershell
Set-Location $env:USERPROFILE
Remove-Item $dl, $msvcDl -Recurse -Force
```

## Integrate

Add the Cargo, MSVC and SDK tool folders to the user PATH, and set `INCLUDE` and `LIB` at user scope so `rustc` finds the headers and libraries from any terminal or editor.

```powershell
$root = Join-Path $env:LOCALAPPDATA "Programs\MSVC"
$msvc = (Get-ChildItem "$root\VC\Tools\MSVC" -Directory | Sort-Object Name | Select-Object -Last 1).FullName
$kits = "$root\Windows Kits\10"
$sdk = (Get-ChildItem "$kits\Include" -Directory | Sort-Object Name | Select-Object -Last 1).Name

[Environment]::SetEnvironmentVariable("INCLUDE", "$msvc\include;$kits\Include\$sdk\ucrt;$kits\Include\$sdk\shared;$kits\Include\$sdk\um;$kits\Include\$sdk\winrt", "User")
[Environment]::SetEnvironmentVariable("LIB", "$msvc\lib\x64;$kits\Lib\$sdk\ucrt\x64;$kits\Lib\$sdk\um\x64", "User")

$user = [Environment]::GetEnvironmentVariable("Path", "User")
$parts = @($user -split ';' | Where-Object { $_ })
foreach ($dir in @("$msvc\bin\Hostx64\x64", "$kits\bin\$sdk\x64", (Join-Path $env:USERPROFILE ".cargo\bin"))) {
  if ($parts -notcontains $dir) { $parts += $dir }
}
[Environment]::SetEnvironmentVariable("Path", ($parts -join ';'), "User")

foreach ($v in "INCLUDE", "LIB") { Set-Item "Env:$v" ([Environment]::GetEnvironmentVariable($v, "User")) }
$env:Path = [Environment]::GetEnvironmentVariable("Path", "User") + ";" + [Environment]::GetEnvironmentVariable("Path", "Machine")
```

The MSVC and SDK paths contain version numbers. After you unpack a newer MSVC or SDK, run this block again and remove the old folders from the user PATH (see Uninstall for the filter pattern).

### Install the Tauri CLI

Add the CLI to each project instead of installing it globally. `npm create tauri-app` does this for you (see Use). To add it to an existing frontend project:

```powershell
npm.cmd install --save-dev @tauri-apps/cli@latest
```

This downloads a prebuilt `tauri.exe` per platform, so no Rust compile is needed.

## Verify

Verified as a standard user: the Rust install, the portable MSVC setup, Integrate, `cargo run`, `npm create tauri-app`, `tauri build` with MSI and NSIS bundles, `cargo clean` and `npm cache verify`. Steps taken from vendor documentation and not run are marked in the text.

| Check | Command | Expected |
|---|---|---|
| Rust runs | `rustc --version` | `rustc 1.100.0 (...)` |
| Cargo runs | `cargo --version` | `cargo 1.100.0 (...)` |
| Active toolchain | `rustup show active-toolchain` | `stable-x86_64-pc-windows-msvc` |
| Cargo resolved from user profile | `(Get-Command cargo).Source` | Path under `%USERPROFILE%\.cargo\bin` |
| MSVC linker found | `(Get-Command link.exe).Source` | Path under `%LOCALAPPDATA%\Programs\MSVC\VC\Tools\MSVC` |
| Rust links an executable | `cargo new hello-rs; cd hello-rs; cargo run` | `Hello, world!` |
| Tauri app builds | See Use | `src-tauri\target\release\<name>.exe` exists |

If `link.exe` resolves to a path under `Git\usr\bin`, that is the Git `link` utility, not the MSVC linker. Move the MSVC `bin` folder before it in the user PATH.

## Use

Create, run and build a sample app. The `hello-tauri` folder is a throwaway name. Run these in a terminal that was opened after Integrate.

```powershell
npm.cmd create tauri-app@latest hello-tauri -- --manager npm --template vanilla --identifier com.example.hello --yes
cd hello-tauri
npm.cmd install
npm.cmd run tauri dev
```

`tauri dev` compiles all dependencies on first use, which takes several minutes, then opens a native window backed by WebView2. Later runs rebuild only what changed. Stop it with `Ctrl+C`. `tauri dev` itself was not run for this guide, only `tauri build`, which compiles the same code.

```powershell
npm.cmd run tauri build
```

The release build took about 7 minutes on first run. It writes `src-tauri\target\release\hello-tauri.exe`, plus an MSI and an NSIS setup under `src-tauri\target\release\bundle\`. On first use the bundler downloads WiX 3.14 and NSIS 3.13 into `%LOCALAPPDATA%\tauri` (user scope, no elevation). According to the Tauri documentation, the NSIS setup installs per user by default and the MSI installs machine-wide, so run only the NSIS setup without admin rights. This installer behavior was not run for this guide.

| Command | Purpose |
|---|---|
| `npm.cmd run tauri dev` | Run with live reload |
| `npm.cmd run tauri build` | Release build and installers |
| `npm.cmd run tauri build -- --no-bundle` | Release executable only, skips WiX and NSIS downloads. Flag from Tauri docs, not run. |
| `npm.cmd run tauri build -- --bundles nsis` | Build only the NSIS setup |
| `npm.cmd run tauri info` | Print the environment report |
| `rustup update` | Update the Rust toolchain |

The generated project uses `com.example.hello` as its identifier. Replace it in `src-tauri\tauri.conf.json` before you ship.

## Reclaim disk space

Sizes below were measured after one release build of the sample app. The delete commands in this section follow the Cargo, npm and Tauri documentation, apart from `cargo clean`, which was run. Work from the cheapest, safest item down. Every item is rebuilt or re-downloaded on demand, so only time and bandwidth are lost.

| Level | What | Typical size | Command |
|---|---|---|---|
| 1 | Build output of one project (`target`) | 1.3 GB per project | `cargo clean` in `src-tauri` |
| 1 | Release build output only | most of the above | `cargo clean --release` in `src-tauri` |
| 2 | Frontend dependencies of one project | 15 MB and up | Delete `node_modules` in the project |
| 2 | npm download cache | 160 MB | `npm.cmd cache clean --force` |
| 3 | Cargo downloaded crates (archives and sources) | 320 MB | See below |
| 3 | Tauri bundler tools (WiX, NSIS) | 120 MB | Delete `%LOCALAPPDATA%\tauri` |
| 4 | Extra Rust toolchains and components | 600 MB each | `rustup toolchain uninstall <name>` |
| 5 | Portable MSVC and SDK | 1.2 GB | Delete `%LOCALAPPDATA%\Programs\MSVC` and reverse Integrate |
| 6 | Everything | about 3 GB | See Uninstall |

### Find the big projects first

`target` folders are the main cost. List them before deleting:

```powershell
Get-ChildItem $env:USERPROFILE -Directory -Recurse -Filter target -ErrorAction SilentlyContinue |
  Where-Object { Test-Path (Join-Path $_.Parent.FullName "Cargo.toml") } |
  ForEach-Object { [pscustomobject]@{ MB = [int]((Get-ChildItem $_.FullName -Recurse -File -Force | Measure-Object Length -Sum).Sum / 1MB); Path = $_.FullName } } |
  Sort-Object MB -Descending
```

Change `$env:USERPROFILE` to the folder that holds your projects to scan faster.

### Clean one project

```powershell
cd <project>\src-tauri
cargo clean
cd ..
Remove-Item node_modules -Recurse -Force
```

`cargo clean` prints `Removed N files, X GiB total`. The next `tauri dev` or `tauri build` recompiles everything, which costs several minutes.

### Clean the Cargo download cache

Cargo keeps downloaded `.crate` archives in `registry\cache` and their unpacked sources in `registry\src`. Keep `registry\index`, which is small and speeds up dependency resolution.

```powershell
$cargo = Join-Path $env:USERPROFILE ".cargo"
Remove-Item "$cargo\registry\cache", "$cargo\registry\src", "$cargo\git\db", "$cargo\git\checkouts" -Recurse -Force -ErrorAction SilentlyContinue
```

Close editors and `rust-analyzer` first, because they may hold files open. Do not delete `%USERPROFILE%\.cargo\bin`, which holds `cargo.exe`, `rustc.exe`, `rustup.exe` and any tool you installed with `cargo install`. Remove one tool with `cargo uninstall <name>`.

### Clean Tauri bundler tools and the npm cache

```powershell
Remove-Item (Join-Path $env:LOCALAPPDATA "tauri") -Recurse -Force
npm.cmd cache clean --force
```

The next `tauri build` downloads WiX and NSIS again. `npm cache verify` shows the cache size and removes only expired entries, if you prefer a lighter pass.

### Remove unused Rust toolchains

```powershell
rustup toolchain list
rustup toolchain uninstall <toolchain-name>
```

`rustup update` replaces the stable toolchain in place and does not keep old versions, so old toolchains only accumulate when you install pinned ones (for example `1.85.0`) or `nightly`.

### Remove the portable MSVC copy only

Use this if IT installs Visual Studio Build Tools later, or you stop building Rust code.

```powershell
$root = Join-Path $env:LOCALAPPDATA "Programs\MSVC"
$user = [Environment]::GetEnvironmentVariable("Path", "User")
$clean = (($user -split ';') | Where-Object { $_ -and ($_ -notlike "$root\*") }) -join ';'
[Environment]::SetEnvironmentVariable("Path", $clean, "User")
[Environment]::SetEnvironmentVariable("INCLUDE", $null, "User")
[Environment]::SetEnvironmentVariable("LIB", $null, "User")
Remove-Item $root -Recurse -Force
```

## Uninstall

This reverses every change from Install and Integrate. Remove build output of your own projects separately (see Reclaim disk space), because it lives next to your source.

```powershell
$root = Join-Path $env:LOCALAPPDATA "Programs\MSVC"
$cargoBin = Join-Path $env:USERPROFILE ".cargo\bin"

$user = [Environment]::GetEnvironmentVariable("Path", "User")
$clean = (($user -split ';') | Where-Object { $_ -and ($_ -notlike "$root\*") -and ($_ -ne $cargoBin) }) -join ';'
[Environment]::SetEnvironmentVariable("Path", $clean, "User")
[Environment]::SetEnvironmentVariable("INCLUDE", $null, "User")
[Environment]::SetEnvironmentVariable("LIB", $null, "User")

cmd /c "rustup self uninstall -y 2>&1"
Remove-Item $root -Recurse -Force
Remove-Item (Join-Path $env:LOCALAPPDATA "tauri") -Recurse -Force -ErrorAction SilentlyContinue
npm.cmd cache clean --force
```

`rustup self uninstall` removes `%USERPROFILE%\.rustup` and `%USERPROFILE%\.cargo`, including the crate cache and every tool installed with `cargo install`. This step follows the rustup documentation and was not run for this guide. If the `.cargo` folder is still present afterwards, delete it by hand. No Start Menu shortcut or `HKCU` key is created by this guide, except the user environment variables `INCLUDE` and `LIB` that the block above clears.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `linker 'link.exe' not found` or `please ensure that Visual Studio 2017 or later ... were installed` | `INCLUDE`, `LIB` or the MSVC `bin` PATH entry is missing in this terminal | Open a new terminal after Integrate, or run the last two lines of Integrate. Check with `Get-Command link.exe`. |
| `LINK : fatal error LNK1104: cannot open file 'kernel32.lib'` | `LIB` is empty or points to a removed SDK folder | Run Integrate again and open a new terminal. |
| `fatal error C1083: Cannot open include file` | `INCLUDE` is empty or stale | Run Integrate again and open a new terminal. |
| `link.exe` is Git's `link` utility | Git `usr\bin` is earlier on PATH | Move the MSVC `bin` entry earlier in the user PATH. |
| `running scripts is disabled on this system` for `npm` | Execution policy blocks `npm.ps1` | Call `npm.cmd` instead of `npm`. Do not change the machine policy. |
| `rustup-init` stops right after the `without its prerequisites` warning | `$ErrorActionPreference = "Stop"` turns native stderr output into an error | Run it through `cmd /c` as in step 2, or set `$ErrorActionPreference = "Continue"`. |
| `failed to run 'cargo metadata' ... program not found` | The terminal was opened before PATH changed | Open a new terminal, or refresh `$env:Path` as in Integrate. |
| `Checksum mismatch` | Corrupted download or altered file | Delete the download folder, download again. If it persists, do not use the file. |
| Download of WiX or NSIS fails during `tauri build` | A proxy or TLS inspection blocks `github.com` | Ask IT for the proxy settings, or build with `-- --no-bundle`. |
| Windows warns about the MSI or asks for admin | The MSI is a machine-wide installer | Distribute the NSIS setup, which installs per user by default, or the plain `.exe`. |
| `tauri dev` window stays blank | WebView2 Runtime missing | Run `npm.cmd run tauri info`. If WebView2 shows as missing, ask IT. |
| Antivirus quarantines `build-script-build.exe` or slows builds | Real-time scanning of freshly compiled files | Ask IT for an exclusion for `src-tauri\target`, or accept the slower build. Do not disable the antivirus. |
| Build is slow at the start | First build compiles all dependencies | Later builds are incremental. Keep `target` between builds. |
