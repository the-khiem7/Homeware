# AWS Session Manager plugin

| Field | Value |
|---|---|
| Tool | [Session Manager plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html) - lets the AWS CLI open Systems Manager sessions and port forwards to managed instances |
| Tested version | `1.2.896.0` on Windows 11 (AMD64) |
| Method | Portable: unpack the vendor zip into the user profile, check the code signature, add a user PATH entry |
| Admin needed | No |
| Install location | `%LOCALAPPDATA%\Programs\session-manager-plugin` |

The plugin is the program that `aws ssm start-session` starts to carry the session data. Without it the command fails with `SessionManagerPlugin is not found`. It is what makes a private database or host reachable from your machine through an SSM-managed instance, with no inbound port and no SSH key.

## Why the default installer needs admin

The vendor zip ships an `install.bat` next to a `package.zip`. The script refuses to run without elevation (it checks `net session`), copies the plugin into `C:\Program Files\Amazon\SessionManagerPlugin`, registers it as an automatic Windows service with `sc create`, and edits PATH. The standalone `SessionManagerPluginSetup.exe` (the Burn installer behind `winget install Amazon.SessionManagerPlugin`) is the other vendor route, and `winget show` lists no per-user variant for it. The plugin itself is a single self-contained `session-manager-plugin.exe` that needs none of that.

## Rejected approaches

| Approach | Why rejected |
|---|---|
| Run `install.bat` | Needs administrator rights, writes to `C:\Program Files` and registers a Windows service |
| `SessionManagerPluginSetup.exe` or `winget install Amazon.SessionManagerPlugin` | Burn installer with no per-user variant listed by `winget show`; not tried, so not shown to avoid elevation |
| Run the installer through a UAC bypass or a scheduled task | Evades a security control |

## Prerequisites

- A Windows standard user account.
- [AWS CLI v2](../aws-cli-v2-sso/README.md) installed and signed in with a profile that is allowed to call `ssm:StartSession`.
- Windows PowerShell 5.1 (`Expand-Archive` and `Get-AuthenticodeSignature` ship with it).

## Install

### 1. Download

Download into a new, empty folder under `%TEMP%`. Do not extract or run anything from `Downloads`.

```powershell
$work = Join-Path $env:TEMP "session-manager-plugin"
New-Item -ItemType Directory -Path $work -Force | Out-Null
Invoke-WebRequest -Uri "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/windows/SessionManagerPlugin.zip" -OutFile (Join-Path $work "SessionManagerPlugin.zip")
```

### 2. Unpack into the user profile

The outer zip holds `package.zip`, `install.bat` and `uninstall.bat`. Take only `package.zip`, and do not run either script.

```powershell
Expand-Archive -Path (Join-Path $work "SessionManagerPlugin.zip") -DestinationPath (Join-Path $work "outer") -Force
$installDir = Join-Path $env:LOCALAPPDATA "Programs\session-manager-plugin"
Expand-Archive -Path (Join-Path $work "outer\package.zip") -DestinationPath $installDir -Force
```

### 3. Check the code signature

AWS publishes no checksum for this zip, so the Authenticode signature of the binary is the integrity check. Delete `$installDir` and stop if the status is not `Valid` or the signer is not Amazon.

```powershell
$sig = Get-AuthenticodeSignature (Join-Path $installDir "bin\session-manager-plugin.exe")
$sig.Status
$sig.SignerCertificate.Subject
```

The status must be `Valid` and the subject must start with `CN="Amazon Web Services, Inc."`.

### 4. Remove the download

```powershell
Remove-Item -Recurse -Force $work
```

## Integrate

Add the `bin` folder to the user PATH, skipping it when it is already there.

```powershell
$binDir = Join-Path $installDir "bin"
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if (-not $userPath) { $userPath = "" }
if (($userPath -split ";") -notcontains $binDir) {
    [Environment]::SetEnvironmentVariable("Path", ($userPath.TrimEnd(";") + ";" + $binDir), "User")
}
$env:Path += ";$binDir"
```

New terminals pick up the entry. The last line makes it work in the current one.

## Verify

| Check | Command | Expected |
|---|---|---|
| Plugin runs | `session-manager-plugin --version` | `1.2.896.0` or newer |
| Signature | `(Get-AuthenticodeSignature "$env:LOCALAPPDATA\Programs\session-manager-plugin\bin\session-manager-plugin.exe").Status` | `Valid` |
| Target is managed | `aws ssm describe-instance-information --profile <profile-name>` | the instance is listed with `PingStatus` `Online` |
| Session opens | `aws ssm start-session --target <instance-id> --profile <profile-name>` | a shell prompt on the instance; type `exit` to leave |

Verified as a standard user: the download, the unpack, the signature check and `session-manager-plugin --version`. Not run here, taken from the vendor documentation and the conventions of this repository: the user PATH step, the uninstall steps and the session checks in the last two rows.

## Use

Open a shell on a managed instance:

```powershell
aws ssm start-session --target <instance-id> --profile <profile-name>
```

Forward a local port to a private host that the managed instance can reach, for example a database. Keep the command running; the forward closes when it ends.

```powershell
aws ssm start-session --target <instance-id> --document-name AWS-StartPortForwardingSessionToRemoteHost --parameters host=<private-host>,portNumber=<remote-port>,localPortNumber=<local-port> --profile <profile-name>
```

Then point the client at `127.0.0.1:<local-port>`. The security group of the private host must admit the managed instance on `<remote-port>`; the forward does not bypass it.

## Uninstall

```powershell
$installDir = Join-Path $env:LOCALAPPDATA "Programs\session-manager-plugin"
$binDir = Join-Path $installDir "bin"
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
$kept = ($userPath -split ";") | Where-Object { $_ -and $_ -ne $binDir }
[Environment]::SetEnvironmentVariable("Path", ($kept -join ";"), "User")
Remove-Item -Recurse -Force $installDir
```

The install writes nothing to the registry and creates no shortcut or service, so these two changes are the whole footprint.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `SessionManagerPlugin is not found` | The `bin` folder is not on PATH in this terminal | Open a new terminal, or run `$env:Path += ";$env:LOCALAPPDATA\Programs\session-manager-plugin\bin"` |
| `TargetNotConnected` | The instance has no SSM agent, no instance profile for Systems Manager, or no route to the endpoints | Check `aws ssm describe-instance-information`; fix the instance role or network |
| `AccessDeniedException` on `StartSession` | The signed-in identity may not call `ssm:StartSession` on that instance | Ask for the permission, or use a profile that has it |
| The forward opens but the client is refused | The security group of the private host does not admit the managed instance on that port | Add an ingress rule for the instance's security group |
| `The security token included in the request is expired` | The SSO session ended | Run `aws sso login --sso-session <sso-session-name>` |
| The forward fails to listen | `<local-port>` is already in use | Pick another `<local-port>` |
