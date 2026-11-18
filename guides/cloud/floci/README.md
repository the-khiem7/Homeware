# Floci CLI

| Field | Value |
|---|---|
| Tool | [Floci CLI](https://github.com/floci-io/floci-cli) - local emulator for AWS, Azure, GCP and OCI services |
| Tested version | `0.2.2` (windows-amd64) |
| Method | Official PowerShell installer script, user scope |
| Admin needed | No (for the CLI). Docker must already be available - see Prerequisites |
| Install location | `%LOCALAPPDATA%\floci\bin\floci.exe` |

## Prerequisites

- A Windows standard user account.
- A working Docker engine. Floci runs the emulated cloud services in Docker containers. Docker Desktop itself usually needs admin rights to install; if it is not already on the machine, ask IT to install it. This guide does not work around that.

## Install

The official installer is a remote script. Download it and read it before running it, instead of piping it straight into `iex`:

```powershell
$installer = Join-Path $env:TEMP "floci-install.ps1"
Invoke-WebRequest -Uri "https://floci.io/install.ps1" -OutFile $installer
notepad $installer   # review the script first
& $installer
Remove-Item $installer
```

The installer places `floci.exe` in `%LOCALAPPDATA%\floci\bin` and adds that folder to the **user** `PATH`. No UAC prompt appears.

> The original notes recorded the resulting install location and PATH change but not the exact install command. The command above is the one documented in the floci-cli README; verify it against the upstream README if it has changed.

## Refresh PATH in the current terminal

New terminals pick up the PATH change automatically. To use `floci` in the terminal that is already open:

```powershell
$env:Path = [Environment]::GetEnvironmentVariable("Path", "User") + ";" + [Environment]::GetEnvironmentVariable("Path", "Machine")
floci --version
```

## Use

1. Start Docker.
2. Start the emulator:
   ```powershell
   floci start
   ```
3. Point the AWS CLI or Terraform at the emulator:
   ```powershell
   $env:AWS_ENDPOINT_URL = "http://localhost:4566"
   ```
4. Check the environment:
   ```powershell
   floci doctor
   ```

## Uninstall

```powershell
Remove-Item -Recurse -Force "$env:LOCALAPPDATA\floci"
$p = [Environment]::GetEnvironmentVariable("Path", "User") -split ';' | Where-Object { $_ -and $_ -ne "$env:LOCALAPPDATA\floci\bin" }
[Environment]::SetEnvironmentVariable("Path", ($p -join ';'), "User")
```

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `floci` not recognized | Terminal opened before the install | Open a new terminal or run the PATH refresh above |
| `floci start` fails | Docker engine not running | Start Docker, then run `floci doctor` |
