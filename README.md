# Homeware

> Make yourself at home on a locked-down machine.

Homeware is a registry of step-by-step guides for installing developer tools on Windows as a **standard user** - no administrator rights, no UAC prompt, nothing written to `C:\Program Files`, `C:\Windows` or `HKEY_LOCAL_MACHINE`.

Every guide here was carried out on a real locked-down Windows 11 workstation and then rewritten as a reusable recipe.

## Ground rules

- Everything lives in the user profile: `%LOCALAPPDATA%`, `%APPDATA%`, `%USERPROFILE%` and `HKEY_CURRENT_USER`.
- These guides use features Windows provides for per-user installs. They **do not** bypass UAC, disable security controls or exploit anything. If a tool genuinely needs admin rights (drivers, services, Docker Desktop, Hyper-V/WSL), ask your IT team instead.
- Respect your organization's software policy. "Can be installed without admin" is not the same as "is allowed to be installed".

## Guides

| Tool | Category | Method | Tested version | Guide |
|---|---|---|---|---|
| AWS CLI v2 + SSO | Cloud CLI | `msiexec /a` administrative install + `sso-session` config | 2.36.x | [guides/aws-cli-v2-sso](guides/aws-cli-v2-sso/README.md) |
| Floci CLI | Local cloud emulator | Official installer script, user scope | 0.2.2 | [guides/floci](guides/floci/README.md) |
| GitLab MCP server | Agent tooling | `npx`, no global install | - | [guides/gitlab-mcp](guides/gitlab-mcp/README.md) |
| Sublime Text 4 | Editor | Portable zip + `HKCU` integration | Build 4213 | [guides/sublime-text-4](guides/sublime-text-4/README.md) |
| Trivy | Security scanner | `winget --scope user` | 0.74.0 | [guides/trivy](guides/trivy/README.md) |

## General techniques

Try these in order. Each guide says which one it uses and why the others did not work.

| Technique | When it works | Example |
|---|---|---|
| `winget install --id <id> --scope user` | The package has a user-scope installer | `winget install --id AquaSecurity.Trivy --scope user` |
| Official portable zip | The vendor ships a zip build | Extract to `%LOCALAPPDATA%\Programs\<App>` |
| Administrative install, `msiexec /a <file>.msi /qn TARGETDIR=<dir>` | Only a machine-wide MSI exists and the app is self-contained | AWS CLI v2 |
| Language package managers in user mode | CLI tools published to npm, PyPI, etc. | `uv tool install <pkg>`, `npx -y <pkg>`, `npm` with a user prefix |
| Per-user installer scripts | The vendor script installs under the user profile | Download, read, then run - never pipe unknown scripts straight into `iex` |

Integration without admin:

```powershell
# Add a folder to the user PATH (HKCU\Environment)
$dir = "$env:LOCALAPPDATA\Programs\<App>"
$p = [Environment]::GetEnvironmentVariable("Path", "User")
if (($p -split ';') -notcontains $dir) { [Environment]::SetEnvironmentVariable("Path", "$p;$dir", "User") }

# Start Menu shortcut for the current user
$sc = (New-Object -ComObject WScript.Shell).CreateShortcut("$env:APPDATA\Microsoft\Windows\Start Menu\Programs\<App>.lnk")
$sc.TargetPath = "$dir\<app>.exe"; $sc.Save()

# Refresh PATH in the current terminal
$env:Path = [Environment]::GetEnvironmentVariable("Path", "User") + ";" + [Environment]::GetEnvironmentVariable("Path", "Machine")
```

File associations and context-menu entries go under `HKCU\Software\Classes` - see the [Sublime Text guide](guides/sublime-text-4/README.md) for a full example.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) and start from [templates/guide-template.md](templates/guide-template.md).

## License

[MIT](LICENSE). The guides are provided as-is; check each vendor's license terms for the software itself.
