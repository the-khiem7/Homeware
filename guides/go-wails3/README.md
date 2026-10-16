# Go + Wails 3 CLI

| Field | Value |
|---|---|
| Tool | [Go](https://go.dev/) - the Go toolchain, and [Wails 3](https://v3.wails.io/) - `wails3`, build desktop apps with Go and web technologies |
| Tested version | Go `1.27.2`, Wails `v3.0.0-beta.30` |
| Method | Go: official portable zip, SHA256 verified. Wails: `go install` into the user profile |
| Admin needed | No |
| Install location | Go: `%LOCALAPPDATA%\Programs\Go`. Wails and other Go tools: `%USERPROFILE%\go\bin` |

## Why the default installer needs admin

The Go download page offers a Windows MSI that installs to `C:\Program Files\Go` and edits the machine PATH, which needs elevation. The same page ships a plain zip build that runs from any folder. Wails has no installer: the CLI is a Go program that `go install` compiles into `%USERPROFILE%\go\bin`, so it needs no elevation once Go is present.

## Rejected approaches

| Approach | Why rejected |
|---|---|
| MSI installer from go.dev | Machine-scope install under `C:\Program Files`, needs admin. |
| `winget install --id GoLang.Go` | Not tested. The package is an MSI and may default to machine scope and raise a UAC prompt. The zip route avoids the question. |
| Setting `GOROOT` | Not needed. The `go` binary finds its own root from its location, and a stale `GOROOT` breaks the toolchain after a move or upgrade. |
| Installing a C compiler (MinGW, MSYS2) for Wails | Not needed on Windows. Wails 3 builds with `CGO_ENABLED=0` and loads WebView2 through a pure Go loader. |

## Prerequisites

- A Windows standard user account.
- Windows PowerShell 5.1.
- Network access to `go.dev` (zip download) and `proxy.golang.org` (Go module downloads).
- Microsoft Edge WebView2 Runtime. It ships with Windows 11 and with Microsoft Edge. `wails3 doctor` reports its version. If it is missing, ask IT, because the standalone runtime installer is machine-wide.
- Node.js with `npm`, only if the project template uses a frontend build (the default template does).

## Install

### 1. Look up the release and its checksum

```powershell
$rel = (Invoke-RestMethod "https://go.dev/dl/?mode=json")[0]
$file = $rel.files | Where-Object { $_.os -eq 'windows' -and $_.arch -eq 'amd64' -and $_.kind -eq 'archive' }
$file.filename
$file.sha256
```

The first entry of the list is the newest stable release. Use `arch -eq 'arm64'` on ARM devices.

### 2. Download, verify and extract into the user profile

```powershell
$ErrorActionPreference = "Stop"
$dl = Join-Path $env:TEMP "go-dl"
New-Item -ItemType Directory -Force $dl | Out-Null
$zip = Join-Path $dl $file.filename
Invoke-WebRequest "https://go.dev/dl/$($file.filename)" -OutFile $zip -UseBasicParsing

$actual = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLower()
if ($actual -ne $file.sha256) { throw "Checksum mismatch: $actual" }

$extract = Join-Path $dl "extract"
Expand-Archive $zip -DestinationPath $extract
$dest = Join-Path $env:LOCALAPPDATA "Programs\Go"
if (Test-Path $dest) { throw "$dest already exists - follow Upgrade instead" }
Move-Item (Join-Path $extract "go") $dest
Remove-Item $dl -Recurse -Force
```

The zip contains a single top-level `go` folder, which becomes `%LOCALAPPDATA%\Programs\Go`.

## Integrate

Add the Go `bin` folder and the Go tools folder to the user PATH, skipping duplicates, then refresh PATH in the current terminal. `%USERPROFILE%\go\bin` is where `go install` places `wails3.exe`.

```powershell
$user = [Environment]::GetEnvironmentVariable("Path", "User")
$parts = @($user -split ';' | Where-Object { $_ })
foreach ($dir in @((Join-Path $env:LOCALAPPDATA "Programs\Go\bin"), (Join-Path $env:USERPROFILE "go\bin"))) {
  if ($parts -notcontains $dir) { $parts += $dir }
}
[Environment]::SetEnvironmentVariable("Path", ($parts -join ';'), "User")
$env:Path = [Environment]::GetEnvironmentVariable("Path", "User") + ";" + [Environment]::GetEnvironmentVariable("Path", "Machine")
```

### Install the Wails 3 CLI

```powershell
go install github.com/wailsapp/wails/v3/cmd/wails3@latest
```

Wails 3 is published as a beta, and `@latest` resolves to the newest beta tag. To get a reproducible install, pin the tag instead, for example `@v3.0.0-beta.30`. The first run downloads about a hundred Go modules into `%USERPROFILE%\go\pkg\mod`, so it takes a few minutes.

## Verify

| Check | Command | Expected |
|---|---|---|
| Go runs | `go version` | `go version go1.27.2 windows/amd64` |
| Go resolved from user profile | `(Get-Command go).Source` | Path under `%LOCALAPPDATA%\Programs\Go\bin` |
| Go paths | `go env GOROOT GOPATH` | `%LOCALAPPDATA%\Programs\Go` and `%USERPROFILE%\go` |
| Wails runs | `wails3 version` | `v3.0.0-beta.30` |
| Wails resolved from user profile | `(Get-Command wails3).Source` | Path under `%USERPROFILE%\go\bin` |
| Environment check | `wails3 doctor` | `Your system is ready for Wails development!` |
| Sample app builds | See Use | `bin\hello.exe` exists |

`wails3 doctor` lists NSIS, the MSIX Packaging Tool, `MakeAppx.exe`, `SignTool.exe` and the Android SDK as "Not Installed". They are only needed for installer packaging, code signing or Android targets, and the diagnosis stays green without them. Installing the Windows SDK or NSIS machine-wide needs admin, so ask IT only if a project requires them.

## Use

Create, build and run a sample app. The `hello` folder is a throwaway name.

```powershell
wails3 init -n hello
cd hello
wails3 build
.\bin\hello.exe
```

`wails3 init` scaffolds a Go backend and a Vanilla TypeScript frontend. `wails3 build` runs the frontend build and then `go build`, and writes `bin\hello.exe`. The built executable opens a native window backed by WebView2, with no admin prompt.

`wails3 dev` runs `npm install` on first use, starts the Vite dev server on `http://localhost:9245`, builds the Go side and opens the same window with live reload. Stop it with `Ctrl+C`.

| Command | Purpose |
|---|---|
| `wails3 dev` | Run with live reload |
| `wails3 build` | Production build into `bin\` |
| `wails3 doctor` | Check the build environment |
| `wails3 docs` | Open the documentation |
| `go install github.com/wailsapp/wails/v3/cmd/wails3@<tag>` | Upgrade the CLI to another tag |

### Upgrade Go

Extract the new zip as in Install, but replace the old folder first. Close terminals and editors that run `go` or `gopls`, then:

```powershell
Remove-Item (Join-Path $env:LOCALAPPDATA "Programs\Go") -Recurse -Force
```

Then run step 2 again. Reinstall the Wails CLI afterwards so it is rebuilt with the new toolchain. PATH is already set, so Integrate is not repeated.

## Uninstall

```powershell
go clean -modcache

$remove = @((Join-Path $env:LOCALAPPDATA "Programs\Go\bin"), (Join-Path $env:USERPROFILE "go\bin"))
$user = [Environment]::GetEnvironmentVariable("Path", "User")
$clean = (($user -split ';') | Where-Object { $_ -and ($remove -notcontains $_) }) -join ';'
[Environment]::SetEnvironmentVariable("Path", $clean, "User")

Remove-Item (Join-Path $env:LOCALAPPDATA "Programs\Go") -Recurse -Force
Remove-Item (Join-Path $env:USERPROFILE "go") -Recurse -Force
Remove-Item (Join-Path $env:LOCALAPPDATA "go-build") -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item (Join-Path $env:APPDATA "go") -Recurse -Force -ErrorAction SilentlyContinue
```

`go clean -modcache` runs first because the module cache is read-only and `Remove-Item` can fail on it. Run it while `go` is still installed. The folders removed are the Go toolchain, the Go tools and module cache (`%USERPROFILE%\go`, which also holds `wails3.exe`), the build cache (`%LOCALAPPDATA%\go-build`) and the Go settings folder (`%APPDATA%\go`). No Start Menu shortcut or `HKCU` key is created by this guide.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `go` or `wails3` is not recognized | The terminal started before the user PATH changed | Open a new terminal, or run the PATH refresh line from Integrate. |
| `Expand-Archive` runs for several minutes | Windows PowerShell 5.1 extracts the roughly 10,000 files of the Go zip one by one, and antivirus scans each one | Wait for it to finish. Do not interrupt it, or the target folder is left half-written. |
| `Checksum mismatch` | Corrupted or incomplete download, or the file was altered | Delete `%TEMP%\go-dl`, download again. If it persists, do not use the file. |
| `already exists - follow Upgrade instead` | Go is already installed in the target folder | Follow Upgrade Go. |
| `go install` fails with a network or TLS error | A proxy or TLS inspection blocks `proxy.golang.org` | Ask IT for the proxy settings, or set `GOPROXY` to the approved internal mirror. |
| `wails3 doctor` reports WebView2 missing | The Edge WebView2 Runtime is not installed | Ask IT. The standalone runtime installer is machine-wide. |
| `npm` not found during `wails3 build` | Node.js is not installed or not on PATH | Install Node.js per-user (for example with `fnm` or `nvm-windows` in user mode) and open a new terminal. |
| `wails3` still reports the old version after reinstall | An older `wails3.exe` earlier on PATH | Run `Get-Command wails3 -All` and remove the stale copy. |
