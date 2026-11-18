<#
.SYNOPSIS
    Installs AWS CLI v2 per-user on Windows without administrator rights or a UAC prompt.
.DESCRIPTION
    Uses a Windows Installer administrative install (msiexec /a) to unpack the official
    AWSCLIV2.msi into %LOCALAPPDATA%\Programs\Amazon\AWSCLIV2, then adds that folder to
    the user Path. Run it from a normal (non-elevated) PowerShell session.
#>

$ErrorActionPreference = "Stop"

Write-Host "[1/6] Preparing paths..." -ForegroundColor Cyan
$msiUrl         = "https://awscli.amazonaws.com/AWSCLIV2.msi"
$msiPath        = Join-Path $env:TEMP "AWSCLIV2.msi"
$tempExtractDir = Join-Path $env:TEMP "awscli_extract"
$targetDir      = Join-Path $env:LOCALAPPDATA "Programs\Amazon\AWSCLIV2"

Write-Host "[2/6] Downloading AWSCLIV2.msi from AWS..." -ForegroundColor Cyan
if (-not (Test-Path $msiPath)) {
    Invoke-WebRequest -Uri $msiUrl -OutFile $msiPath
}

Write-Host "[3/6] Unpacking the MSI with an administrative install (msiexec /a)..." -ForegroundColor Cyan
if (Test-Path $tempExtractDir) { Remove-Item -Path $tempExtractDir -Recurse -Force }
$proc = Start-Process msiexec.exe -ArgumentList @('/a', "`"$msiPath`"", '/qn', "TARGETDIR=`"$tempExtractDir`"") -Wait -PassThru
if ($proc.ExitCode -ne 0) {
    throw "MSI unpack failed with exit code $($proc.ExitCode)"
}

Write-Host "[4/6] Copying files to $targetDir..." -ForegroundColor Cyan
if (-not (Test-Path $targetDir)) { New-Item -ItemType Directory -Path $targetDir -Force | Out-Null }
$sourceBinDir = Join-Path $tempExtractDir "Amazon\AWSCLIV2"
Copy-Item -Path "$sourceBinDir\*" -Destination $targetDir -Recurse -Force

Write-Host "[5/6] Updating the user Path..." -ForegroundColor Cyan
$userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -split ';' -notcontains $targetDir) {
    # Prepend so this copy wins over any older aws shim further down the Path.
    [System.Environment]::SetEnvironmentVariable("Path", "$targetDir;$userPath", "User")
    Write-Host "Added $targetDir to the user Path." -ForegroundColor Green
} else {
    Write-Host "$targetDir is already in the user Path." -ForegroundColor Yellow
}
$env:PATH = "$targetDir;$env:PATH"

Write-Host "[6/6] Removing AWS CLI v1 (if installed with uv) and temporary files..." -ForegroundColor Cyan
if (Get-Command uv -ErrorAction SilentlyContinue) {
    uv tool uninstall awscli 2>$null
}
Remove-Item -Path $msiPath -Force -ErrorAction SilentlyContinue
Remove-Item -Path $tempExtractDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "`n=== RESULT ===" -ForegroundColor Green
& "$targetDir\aws.exe" --version
Write-Host "Done. Open a new terminal so every process sees the updated Path.`n" -ForegroundColor Green
