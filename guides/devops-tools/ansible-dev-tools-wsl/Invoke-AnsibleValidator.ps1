<#
.SYNOPSIS
  Runs one script of the ansible-validator skill against a throwaway copy of your content inside WSL.
.DESCRIPTION
  Copies the skill and your content into a new directory under ~/work in the distro, converts CRLF to LF
  in the copy, runs the chosen validator script there, prints the output and removes the copy.
  The original files on Windows are never modified. If -Path is a file, its whole parent folder is copied
  (a playbook usually needs the templates and vars next to it); .git is left out.
.EXAMPLE
  .\Invoke-AnsibleValidator.ps1 -Path .\site.yml -Check playbook
.EXAMPLE
  .\Invoke-AnsibleValidator.ps1 -Path .\roles\web -Check role-security
#>
param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][ValidateSet('playbook', 'role', 'inventory', 'playbook-security', 'role-security', 'secret-scan', 'fqcn', 'molecule')][string]$Check,
    [string]$SkillRoot,
    [string]$Distro = 'Ubuntu-24.04',
    [switch]$Keep
)

$ErrorActionPreference = 'Stop'

$scripts = @{
    'playbook'          = 'validate_playbook.sh'
    'role'              = 'validate_role.sh'
    'inventory'         = 'validate_inventory.sh'
    'playbook-security' = 'validate_playbook_security.sh'
    'role-security'     = 'validate_role_security.sh'
    'secret-scan'       = 'scan_secrets.sh'
    'fqcn'              = 'check_fqcn.sh'
    'molecule'          = 'test_role.sh'
}

if (-not $SkillRoot) {
    $candidates = @(
        (Join-Path (Get-Location) '.claude\skills\ansible-validator'),
        (Join-Path $env:USERPROFILE '.claude\skills\ansible-validator')
    )
    $SkillRoot = $candidates | Where-Object { Test-Path -LiteralPath (Join-Path $_ 'scripts') } | Select-Object -First 1
    if (-not $SkillRoot) { throw "ansible-validator skill not found. Pass -SkillRoot <folder containing scripts\>." }
}

$full = (Resolve-Path -LiteralPath $Path).ProviderPath
if (Test-Path -LiteralPath $full -PathType Leaf) {
    $srcDir = Split-Path $full -Parent
    $rel = Split-Path $full -Leaf
} else {
    $srcDir = $full
    $rel = '.'
}
$skillFull = (Resolve-Path -LiteralPath $SkillRoot).ProviderPath
# The copy keeps the original folder name, because Molecule and Ansible resolve a role by its folder name.
$dirName = Split-Path $srcDir -Leaf
if (-not $dirName) { $dirName = 'content' }

function ConvertTo-WslPath([string]$WindowsPath) {
    $out = & wsl.exe -d $Distro --exec wslpath -a $WindowsPath
    if ($LASTEXITCODE -ne 0 -or -not $out) { throw "wslpath failed for $WindowsPath" }
    return ($out | Select-Object -First 1).Trim()
}

# The runner is written with LF endings; CRLF would break bash.
$runner = @'
set -uo pipefail
export PATH="$HOME/.local/bin:$PATH"
SKILL=$1; SRC=$2; REL=$3; SCRIPT=$4; KEEP=$5; NAME=$6
command -v ansible-lint >/dev/null || { echo "ansible-lint not found in the distro. Run install-tools.sh first." >&2; exit 2; }
mkdir -p "$HOME/work"
W=$(mktemp -d "$HOME/work/validate.XXXXXX")
mkdir "$W/.validator-skill" "$W/$NAME"
tar -C "$SKILL" -cf - . | tar -C "$W/.validator-skill" -xf -
tar -C "$SRC" --exclude=.git -cf - . | tar -C "$W/$NAME" -xf -
find "$W" -type f \( -name '*.sh' -o -name '*.py' -o -name '*.yml' -o -name '*.yaml' -o -name '*.j2' -o -name '*.cfg' -o -name '*.md' -o -name 'hosts' -o -name '.ansible-lint' -o -name '.yamllint' \) -exec sed -i 's/\r$//' {} +
chmod +x "$W"/.validator-skill/scripts/*.sh
if [ "$REL" = "." ]; then ARG="$W/$NAME"; else ARG="$W/$NAME/$REL"; fi
cd "$W/$NAME"
bash "$W/.validator-skill/scripts/$SCRIPT" "$ARG"
rc=$?
if [ "$KEEP" = "keep" ]; then echo "Copy kept at $W"; else case "$W" in "$HOME"/work/validate.*) rm -rf "$W";; esac; fi
exit $rc
'@
$runner = $runner -replace "`r`n", "`n"

$tmp = Join-Path $env:TEMP ("ansible-validator-" + [IO.Path]::GetRandomFileName() + ".sh")
try {
    [IO.File]::WriteAllText($tmp, $runner, (New-Object System.Text.UTF8Encoding($false)))
    $keepArg = if ($Keep) { 'keep' } else { 'drop' }
    # Windows PowerShell 5.1 turns native stderr into a terminating error under 'Stop'; the validators print warnings there.
    $ErrorActionPreference = 'Continue'
    & wsl.exe -d $Distro --exec bash (ConvertTo-WslPath $tmp) (ConvertTo-WslPath $skillFull) (ConvertTo-WslPath $srcDir) $rel $scripts[$Check] $keepArg $dirName
    exit $LASTEXITCODE
} finally {
    Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
}
