# Terraform

| Field | Value |
|---|---|
| Tool | [Terraform](https://github.com/hashicorp/terraform) - infrastructure as code CLI |
| Tested version | `1.17.1` (64-bit) |
| Method | `winget install --scope user` (portable zip, SHA256 verified by winget) + user PATH entry |
| Admin needed | No |
| Install location | `%LOCALAPPDATA%\Microsoft\WinGet\Packages\Hashicorp.Terraform_Microsoft.Winget.Source_8wekyb3d8bbwe` |

## Why the default installer needs admin

HashiCorp ships Terraform as a single `terraform.exe` inside a zip, with no installer. Admin rights come from the usual wrappers: machine-wide package managers and manual copies into `C:\Program Files` or a system-wide PATH entry. Unpacking the zip under the user profile and adding that folder to the user PATH needs none of it.

## Rejected approaches

| Approach | Why rejected |
|---|---|
| Chocolatey | Installs machine-wide and needs an elevated shell |
| `winget install` without `--scope user` | May select a machine-scope install and raise a UAC prompt |
| Manual zip into `C:\Program Files\Terraform` | Writes to `C:\Program Files` and needs the machine PATH |
| Rely on the winget `terraform` alias | The alias is reported as added, but `%LOCALAPPDATA%\Microsoft\WinGet\Links` stays empty, so `terraform` is not found |

## Prerequisites

- A Windows standard user account with `winget` (App Installer) available.

## Install

```powershell
winget install --id Hashicorp.Terraform --scope user --exact
```

Winget downloads the zip from `releases.hashicorp.com`, verifies its SHA256 and extracts `terraform.exe` into the package folder above. No UAC prompt appears.

## Integrate

Add the package folder to the user PATH, with a duplicate check:

```powershell
$dir  = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\Hashicorp.Terraform_Microsoft.Winget.Source_8wekyb3d8bbwe"
$user = [Environment]::GetEnvironmentVariable("Path", "User")
if (($user -split ';') -notcontains $dir) {
    [Environment]::SetEnvironmentVariable("Path", ($user.TrimEnd(';') + ";" + $dir), "User")
}
```

Open a new terminal afterwards. Terminals opened before this step keep the old PATH.

## Verify

| Check | Command | Expected |
|---|---|---|
| Version | `terraform version` | `Terraform v1.17.1` (or newer) |
| Location | `(Get-Command terraform).Source` | A path under `%LOCALAPPDATA%\Microsoft\WinGet\Packages` |

## Use

```powershell
terraform fmt -recursive
terraform init
terraform validate
terraform plan
```

Review the plan before running `terraform apply`.

## Update

```powershell
winget upgrade --id Hashicorp.Terraform --scope user --exact
```

Winget can lag behind HashiCorp releases: when `terraform version` reports a newer release, winget may still answer `No newer package versions are available`. Run the command again later. The PATH entry stays valid only while the package folder name is unchanged, so verify with `terraform version` after every upgrade. This step was not run against a newer package version.

## Uninstall

This step is taken from the winget documentation and was not run.

```powershell
winget uninstall --id Hashicorp.Terraform
$dir  = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\Hashicorp.Terraform_Microsoft.Winget.Source_8wekyb3d8bbwe"
$user = [Environment]::GetEnvironmentVariable("Path", "User")
[Environment]::SetEnvironmentVariable("Path", (($user -split ';' | Where-Object { $_ -and $_ -ne $dir }) -join ';'), "User")
```

Per-project `.terraform` folders and state files are not touched. Delete them per project if no longer needed.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `terraform` is not recognized after install | The winget alias was not created and the package folder is not on the PATH | Run the PATH step under Integrate, then open a new terminal |
| `terraform` is not recognized in a terminal that was already open | The terminal holds the PATH from before the change | Open a new terminal |
| "Your version of Terraform is out of date" | HashiCorp released a newer version than the installed one | Run the Update step; if winget has no newer version yet, ignore the notice |
