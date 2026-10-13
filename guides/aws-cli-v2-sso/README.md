# AWS CLI v2 + IAM Identity Center (SSO) token provider

| Field | Value |
|---|---|
| Tool | [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/) |
| Tested version | `aws-cli/2.36.x` on Windows 11 (AMD64) |
| Method | Administrative install of the official MSI (`msiexec /a`) into the user profile, then `sso-session` configuration |
| Admin needed | No |
| Install location | `%LOCALAPPDATA%\Programs\Amazon\AWSCLIV2` |
| Script | [`install-awscli-v2.ps1`](install-awscli-v2.ps1) |

This guide covers two things:

1. Installing AWS CLI v2 as a standard user, with no UAC prompt, and getting rid of a broken AWS CLI v1 shim.
2. Configuring IAM Identity Center (AWS SSO) with the auto-refreshing token provider (`sso-session`), including a way to keep existing Terraform code and scripts working when profile names change.

---

## Part 1 - Install AWS CLI v2 without admin

### Why the normal routes fail

- AWS ships no portable `.zip` for Windows (only for Linux). The only Windows channel is the MSI: `https://awscli.amazonaws.com/AWSCLIV2.msi`.
- That MSI is built for a machine-wide install. Double-clicking it or running `winget install Amazon.AWSCLI` asks for admin right away; `winget show Amazon.AWSCLI --scope user` reports `No applicable installer found`.
- PyPI only has AWS CLI **v1** (`pip install awscli` / `uv tool install awscli`). v1:
  1. does not support the SSO token provider (`sso-session`) or automatic token refresh;
  2. installs an `aws.cmd` shim in `%USERPROFILE%\.local\bin` that depends on the `.py` file association. If that association is missing, Windows falls through to the Microsoft Store alias and `aws` fails with `File association not found for extension .py` (exit code 9009).

### The technique: administrative install (`msiexec /a`)

```powershell
msiexec.exe /a "AWSCLIV2.msi" /qn TARGETDIR="<target-folder>"
```

- `/a` - administrative install. Windows Installer only unpacks the files from the MSI's cabinet streams into a folder (originally meant for a network install point). It does **not** run privileged custom actions, does **not** write to `HKLM` or `C:\Program Files`, and does **not** register the product in Add/Remove Programs.
- `/qn` - fully quiet, no UI.
- `TARGETDIR` - where to unpack. When it points into a folder the user owns (`%TEMP%`, `%LOCALAPPDATA%\Programs\...`), the whole process runs at the user's normal (medium) integrity level, so no UAC prompt appears.
- Result: the app lands in `<TARGETDIR>\Amazon\AWSCLIV2\`. It contains a standalone `aws.exe` with its own bundled Python runtime, DLLs and compiled modules. It needs no separate Python and no `.py` file association.

Trade-off: because nothing is registered with Windows, there are no automatic updates and no entry in Add/Remove Programs. To upgrade, run the script again; to uninstall, delete the folder (see below).

### Steps

#### 1. Download the official MSI

```powershell
$msiPath = Join-Path $env:TEMP "AWSCLIV2.msi"
Invoke-WebRequest -Uri "https://awscli.amazonaws.com/AWSCLIV2.msi" -OutFile $msiPath
```

#### 2. Create the per-user target folder

`%LOCALAPPDATA%\Programs` is the Windows convention for per-user applications.

```powershell
$installDir = Join-Path $env:LOCALAPPDATA "Programs\Amazon\AWSCLIV2"
New-Item -ItemType Directory -Path $installDir -Force | Out-Null
```

#### 3. Unpack with `msiexec /a`

```powershell
$tempExtractDir = Join-Path $env:TEMP "awscli_extract"
$process = Start-Process msiexec.exe -ArgumentList @('/a', "`"$msiPath`"", '/qn', "TARGETDIR=`"$tempExtractDir`"") -Wait -PassThru
if ($process.ExitCode -ne 0) {
    throw "MSI unpack failed, exit code $($process.ExitCode)"
}
```

#### 4. Copy the binaries into place

```powershell
$extractedBinDir = Join-Path $tempExtractDir "Amazon\AWSCLIV2"
Copy-Item -Path "$extractedBinDir\*" -Destination $installDir -Recurse -Force
```

#### 5. Add the folder to the user `Path`

This writes to `HKCU\Environment`, so both CMD and PowerShell find `aws`.

```powershell
$currentUserPath = [System.Environment]::GetEnvironmentVariable('Path', 'User')
if ($currentUserPath -split ';' -notcontains $installDir) {
    # Prepend so this copy wins over any older aws shim
    [System.Environment]::SetEnvironmentVariable('Path', "$installDir;$currentUserPath", 'User')
}
$env:PATH = "$installDir;$env:PATH"   # current session
```

#### 6. Remove AWS CLI v1 and temporary files

```powershell
uv tool uninstall awscli 2>$null   # only if v1 was installed with uv; use pip uninstall awscli for pip
Remove-Item -Path $msiPath -Force -ErrorAction SilentlyContinue
Remove-Item -Path $tempExtractDir -Recurse -Force -ErrorAction SilentlyContinue
```

Check that no stale `aws.cmd` / `aws` shim pointing at Python is left in `%USERPROFILE%\.local\bin`.

#### 7. Verify

```powershell
aws --version          # expect: aws-cli/2.x.x Python/3.x.x Windows/11 exe/AMD64
aws configure sso help # expect: the v2 help page, no errors
```

### All-in-one script

[`install-awscli-v2.ps1`](install-awscli-v2.ps1) runs steps 1-7. Run it from a normal PowerShell window (not "Run as administrator"):

```powershell
powershell -ExecutionPolicy Bypass -File .\install-awscli-v2.ps1
```

`-ExecutionPolicy Bypass` here applies to that one process only; it does not change machine policy. Read the script before running it.

### Uninstall

```powershell
$installDir = Join-Path $env:LOCALAPPDATA "Programs\Amazon\AWSCLIV2"
Remove-Item -Recurse -Force $installDir
$p = [Environment]::GetEnvironmentVariable("Path", "User") -split ';' | Where-Object { $_ -and $_ -ne $installDir }
[Environment]::SetEnvironmentVariable("Path", ($p -join ';'), "User")
```

---

## Part 2 - Configure the SSO token provider

### Before you start

- You have been granted IAM Identity Center access to the AWS account(s) you need. If not, ask whoever administers AWS SSO in your organization.
- You know, for each account: the SSO start URL, the SSO region, the account ID and the permission set (role) name. Get these from the AWS access portal or your SSO administrator - not by copying another person's config.

### Legacy SSO vs token provider

| | Legacy SSO profile | Token provider (`sso-session`) |
|---|---|---|
| Availability | AWS CLI v1 (late versions) and early v2 | AWS CLI v2 only (2.9.0+) |
| Where configured | `sso_start_url`, `sso_region` repeated in every `[profile]` | One `[sso-session]` block, referenced by each profile |
| Key settings | `sso_start_url`, `sso_account_id`, `sso_role_name` | `sso_session`, `sso_registration_scopes = sso:account:access` |
| Token refresh | None; when the token expires the next command fails | Refreshed in the background with an OIDC refresh token |
| Session lifetime | Lifetime of a single access token | Lifetime of the refresh token, as set by the organization |
| Login | Per profile | Once per session, shared by every profile that references it |

### 1. Shared SSO session (`%USERPROFILE%\.aws\config`)

```ini
[sso-session <sso-session-name>]
sso_start_url = https://<your-org>.awsapps.com/start
sso_region = <sso-region>
sso_registration_scopes = sso:account:access
```

`<sso-region>` is the region where IAM Identity Center is enabled, e.g. `us-east-1` or `ap-southeast-1`.

### 2. One profile per account / role

```ini
[profile <profile-name>]
sso_session = <sso-session-name>
sso_account_id = <account-id>
sso_role_name = <permission-set-name>
region = <working-region>
output = json
```

Add one block per account. Use a team-wide naming convention (for example `<project>-<environment>`) so profile names match across machines.

### 3. Keep existing code working when profile names change

If Terraform code or scripts hard-code an older profile name (`profile = "<legacy-profile-name>"` in `providers.tf` or `backend.tf`, `--profile` in scripts), you do not have to refactor them. Add a second profile with the legacy name that points at the **same** account, role and session:

```ini
[profile <new-profile-name>]
sso_session = <sso-session-name>
sso_account_id = <account-id>
sso_role_name = <permission-set-name>
region = <working-region>
output = json

# Alias kept so existing Terraform code and scripts keep working unchanged
[profile <legacy-profile-name>]
sso_session = <sso-session-name>
sso_account_id = <account-id>
sso_role_name = <permission-set-name>
region = <working-region>
output = json
```

### 4. The static credentials file (`%USERPROFILE%\.aws\credentials`)

Credential resolution order is: environment variables, then `~/.aws/credentials`, then `~/.aws/config`.

- Keep this file only for IAM users with static access keys, where SSO is not available.
- **Do not** declare SSO profiles here. If a profile name exists in both files, the SDK picks the static key from `credentials` first - often an old, disabled key - and fails with `AccessDenied`.
- When moving a profile from static keys to SSO, back up the file, then delete the old entry instead of leaving both.
- Never print, share or commit access keys.

---

## Part 3 - Verify

### 1. Log in

```powershell
aws sso login --sso-session <sso-session-name>
```

- The browser opens the AWS access portal (`https://<your-org>.awsapps.com/start`).
- Check that the code shown in the terminal matches the code in the browser.
- The portal asks: **Allow botocore-client-<sso-session-name> to access your data?** Click **Allow access**.
- The browser is redirected to a local callback (`http://127.0.0.1:<port>/oauth/callback?...`) and shows **Your credentials have been shared successfully**. Close the tab.
- The token is cached in `%USERPROFILE%\.aws\sso\cache\`.

### 2. Check the identity of each profile

```powershell
aws sts get-caller-identity --profile <profile-name>
```

Expected shape:

```json
{
    "UserId": "AROAXXXXXXXXXXXXXXXXX:<your-sso-username>",
    "Account": "<account-id>",
    "Arn": "arn:aws:sts::<account-id>:assumed-role/AWSReservedSSO_<permission-set-name>_<suffix>/<your-sso-username>"
}
```

A correct `Account` and an `assumed-role/AWSReservedSSO_...` ARN confirm the profile works. Run it for the legacy alias profile too, if you created one.

### 3. Check Terraform (if you use it)

```powershell
terraform -chdir=<module-path> plan
```

The Terraform AWS provider (AWS SDK for Go v2) reads the same `~/.aws/config` and the cached SSO token. If the S3 backend, state lock and data sources load without authentication errors, the setup is done - no change to `providers.tf` or `backend.tf` needed.

---

## Daily operation

- Access tokens last a few hours; the refresh token keeps the session alive up to the limit your organization sets in IAM Identity Center.
- When the session finally expires, commands fail with:
  ```text
  aws: [ERROR]: Error when retrieving token from sso: Token has expired and refresh failed
  ```
  Log in again with one command - every profile on that session is refreshed at once:
  ```powershell
  aws sso login --sso-session <sso-session-name>
  ```
- Log out to remove the cached token (before handing over a machine, or when switching roles):
  ```powershell
  aws sso logout --sso-session <sso-session-name>
  ```
- Each person manages their own profiles and session. Never copy `~/.aws/sso/cache/` between machines.
- Profile names are local to each machine. On a shared Terraform repo, agree on names with the team or set `AWS_PROFILE`.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `aws` not recognized right after install | Terminal still has the old environment | Open a new terminal, or run `$env:Path = [Environment]::GetEnvironmentVariable("Path","User") + ";" + [Environment]::GetEnvironmentVariable("Path","Machine")` |
| `File association not found for extension .py` when running `aws` | Old AWS CLI v1 shim pointing at Python | `uv tool uninstall awscli` (or `pip uninstall awscli`), clean the stale shim from `%USERPROFILE%\.local\bin` |
| `Token has expired and refresh failed` | SSO session expired | `aws sso login --sso-session <sso-session-name>` |
| `Unable to locate credentials` | Missing `[profile ...]` block, or a typo in `--profile` | Check the profile name in `~/.aws/config` |
| `AccessDenied`, or the SDK keeps using an old static key after moving to SSO | Same profile name still present in `~/.aws/credentials` | Remove (or comment out) that block in `credentials` |
| Terraform cannot read the S3 backend / lock table | Profile in `provider` / `backend` does not match a logged-in SSO profile | Compare profile names between the Terraform code and `~/.aws/config`; add a legacy alias profile (Part 2, step 3) |
