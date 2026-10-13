# Trivy

| Field | Value |
|---|---|
| Tool | [Trivy](https://github.com/aquasecurity/trivy) - vulnerability, misconfiguration and secret scanner |
| Tested version | `0.74.0` (64-bit) |
| Method | `winget install --scope user` |
| Admin needed | No |
| Install location | `%LOCALAPPDATA%\Microsoft\WinGet\Packages\AquaSecurity.Trivy_*` (winget adds a `trivy` alias to the user PATH) |

## Prerequisites

- A Windows standard user account with `winget` (App Installer) available.
- Optional: Visual Studio Code, for the editor extension.

## Install the CLI

```powershell
winget install --id AquaSecurity.Trivy --scope user
```

`--scope user` installs into the user profile, creates the command alias and updates the user PATH. No UAC prompt appears. Open a new terminal afterwards.

## Global configuration

Create `%USERPROFILE%\.trivy\trivy.yaml`:

```yaml
severity:
  - HIGH
  - CRITICAL
scan:
  scanners:
    - vuln
    - misconfig
    - secret
  skip-dirs:
    - "**/.terraform"
    - "**/.git"
misconfiguration:
  terraform:
    exclude-downloaded-modules: true
```

What it does:

- Reports only `HIGH` and `CRITICAL` findings.
- Enables the vulnerability, misconfiguration and secret scanners.
- Skips heavy cache folders (`.terraform`, `.git`).
- Ignores third-party Terraform modules downloaded into `.terraform`.

## VS Code extension

```powershell
code --install-extension AquaSecurityOfficial.trivy-vulnerability-scanner
```

Tested with extension version `1.8.11`. It shows Trivy findings directly in the editor.

## Pre-download the databases

```powershell
trivy fs --download-db-only
```

This pulls `trivy-db` and `trivy-checks` from `mirror.gcr.io` into the user cache (`%LOCALAPPDATA%\trivy`). Run it again whenever you want fresh vulnerability data.

## Verify

```powershell
trivy --version                                   # expect: Version: 0.74.0 (or newer)
code --list-extensions | Select-String "trivy"    # expect: aquasecurityofficial.trivy-vulnerability-scanner
```

## Use

```powershell
# Scan IaC / Terraform in the current folder
trivy config --config "$env:USERPROFILE\.trivy\trivy.yaml" .

# Scan source, dependencies and leaked secrets in the current folder
trivy fs --config "$env:USERPROFILE\.trivy\trivy.yaml" .
```

On a Terraform codebase, expect findings such as `AWS-0132` (S3 bucket encryption), `AWS-0104` (security group egress to `0.0.0.0/0`) or `AWS-0053` (public load balancer). Scanning does not change or create files in the scanned folder.

## Uninstall

```powershell
winget uninstall --id AquaSecurity.Trivy
Remove-Item -Recurse -Force "$env:USERPROFILE\.trivy", "$env:LOCALAPPDATA\trivy"
```
