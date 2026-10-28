<h1 align="center"><picture><source media="(prefers-color-scheme: dark)" srcset="assets/readme/hero-dark.webp"><img src="assets/readme/hero.webp" alt="Homeware - make yourself at home on a locked-down machine. Illustration: an isometric room with a locked door, a shelf and a desk, furnished with numbered parts; the label %LOCALAPPDATA% marks it as the place where everything goes." width="100%"></picture></h1>

<p align="center">
<a href="#guides"><picture><source media="(prefers-color-scheme: dark)" srcset="assets/readme/btn-guides-dark.webp"><img src="assets/readme/btn-guides.webp" alt="1 Guides" height="40"></picture></a>
<a href="#ground-rules"><picture><source media="(prefers-color-scheme: dark)" srcset="assets/readme/btn-rules-dark.webp"><img src="assets/readme/btn-rules.webp" alt="2 Ground rules" height="40"></picture></a>
<a href="#general-techniques"><picture><source media="(prefers-color-scheme: dark)" srcset="assets/readme/btn-techniques-dark.webp"><img src="assets/readme/btn-techniques.webp" alt="3 Techniques" height="40"></picture></a>
<a href="#contributing"><picture><source media="(prefers-color-scheme: dark)" srcset="assets/readme/btn-contributing-dark.webp"><img src="assets/readme/btn-contributing.webp" alt="4 Contributing" height="40"></picture></a>
</p>

Homeware is a registry of step-by-step guides for installing developer tools on Windows as a **standard user** - no administrator rights, no UAC prompt, nothing written to `C:\Program Files`, `C:\Windows` or `HKEY_LOCAL_MACHINE`.

Guides include only steps that were run as a standard user. A step taken from vendor docs and not tested says so in the guide.

<picture><source media="(prefers-color-scheme: dark)" srcset="assets/readme/problem-dark.webp"><img src="assets/readme/problem.webp" alt="Two panels. The default installer, machine scope, asks for admin: it raises a UAC prompt, writes to C:\Program Files, and a standard user cannot approve it. A Homeware guide, user scope, for a standard user: no UAC prompt, nothing written to C:\Program Files, C:\Windows or HKEY_LOCAL_MACHINE, and everything lives in the user profile, for example %LOCALAPPDATA%\Programs\&lt;App&gt;." width="100%"></picture>

## Guides

<picture><source media="(prefers-color-scheme: dark)" srcset="assets/readme/guide-dark.webp"><img src="assets/readme/guide.webp" alt="Every guide follows one template: templates/guide-template.md becomes guides/&lt;tool-name&gt;/README.md. The sections, in order: summary table, why the default installer needs admin, rejected approaches, prerequisites, install, integrate, verify, use, uninstall, troubleshooting." width="100%"></picture>

| Tool | Category | Method | Tested version | Guide |
|---|---|---|---|---|
| AWS CLI v2 + SSO | Cloud CLI | `msiexec /a` administrative install + `sso-session` config | 2.36.x | [guides/aws-cli-v2-sso](guides/aws-cli-v2-sso/README.md) |
| Crane | Container registry CLI | Portable archive, SHA256 verified | 0.22.1 | [guides/crane](guides/crane/README.md) |
| Docker Engine in WSL2 + Portainer | Container runtime | WSL2 distro + Docker apt repository, Portainer CE as GUI | 29.9.0 | [guides/docker-engine-wsl](guides/docker-engine-wsl/README.md) |
| Floci CLI | Local cloud emulator | Official installer script, user scope | 0.2.2 | [guides/floci](guides/floci/README.md) |
| GitHub CLI | Developer CLI | Portable zip, SHA256 verified | 2.102.0 | [guides/github-cli](guides/github-cli/README.md) |
| GitLab MCP server | Agent tooling | `npx`, no global install | - | [guides/gitlab-mcp](guides/gitlab-mcp/README.md) |
| Go + Wails 3 CLI | Language toolchain | Portable zip, SHA256 verified + `go install` | Go 1.27.2, Wails v3.0.0-beta.30 | [guides/go-wails3](guides/go-wails3/README.md) |
| OBS Studio | Screen recording and streaming | Portable zip, SHA256 verified | 33.0.0 | [guides/obs-studio](guides/obs-studio/README.md) |
| Sublime Text 4 | Editor | Portable zip + `HKCU` integration | Build 4213 | [guides/sublime-text-4](guides/sublime-text-4/README.md) |
| Trivy | Security scanner | `winget --scope user` | 0.74.0 | [guides/trivy](guides/trivy/README.md) |
| VS Code startup layout + Claude Code | Editor setup | User settings + per-user Auto Run Command extension | VS Code 1.142.0 | [guides/vscode-claude-code-startup](guides/vscode-claude-code-startup/README.md) |

## Ground rules

<picture><source media="(prefers-color-scheme: dark)" srcset="assets/readme/rules-dark.webp"><img src="assets/readme/rules.webp" alt="Cross-section of a building. The left side, The building, holds three locked floors that need admin rights, so ask IT: C:\Program Files, C:\Windows and HKEY_LOCAL_MACHINE. The right side, Your room, is the user profile for a standard user and holds %LOCALAPPDATA%, %APPDATA%, %USERPROFILE% and HKEY_CURRENT_USER." width="100%"></picture>

- Everything lives in the user profile: `%LOCALAPPDATA%`, `%APPDATA%`, `%USERPROFILE%` and `HKEY_CURRENT_USER`.
- These guides use features Windows provides for per-user installs. They **do not** bypass UAC, disable security controls or exploit anything. If a tool genuinely needs admin rights (drivers, services, Docker Desktop, Hyper-V/WSL), ask your IT team instead.
- Respect your organization's software policy. "Can be installed without admin" is not the same as "is allowed to be installed".

## General techniques

Try these in order. Each guide says which one it uses and why the others did not work.

<picture><source media="(prefers-color-scheme: dark)" srcset="assets/readme/techniques-dark.webp"><img src="assets/readme/techniques.webp" alt="Flow chart, try in order. Technique 1: winget install --id &lt;id&gt; --scope user, when the package has a user-scope installer. If not, technique 2: official portable zip, when the vendor ships a zip build. If not, technique 3: administrative install with msiexec /a, when only a machine-wide MSI exists and the app is self-contained. If not, technique 4: language package managers in user mode, for CLI tools published to npm, PyPI, etc. If not, technique 5: per-user installer script, when the vendor script installs under the user profile. A match at any technique leads to Integrate: user PATH, Start Menu shortcut, HKCU keys. If none matches, Ask IT: drivers, services, Docker Desktop and Hyper-V/WSL need admin rights." width="100%"></picture>

<details>
<summary>The same techniques as a table, with an example for each</summary>

| Technique | When it works | Example |
|---|---|---|
| `winget install --id <id> --scope user` | The package has a user-scope installer | `winget install --id AquaSecurity.Trivy --scope user` |
| Official portable zip | The vendor ships a zip build | Extract to `%LOCALAPPDATA%\Programs\<App>` |
| Administrative install, `msiexec /a <file>.msi /qn TARGETDIR=<dir>` | Only a machine-wide MSI exists and the app is self-contained | AWS CLI v2 |
| Language package managers in user mode | CLI tools published to npm, PyPI, etc. | `uv tool install <pkg>`, `npx -y <pkg>`, `npm` with a user prefix |
| Per-user installer scripts | The vendor script installs under the user profile | Download, read, then run - never pipe unknown scripts straight into `iex` |

</details>

<picture><source media="(prefers-color-scheme: dark)" srcset="assets/readme/integrate-dark.webp"><img src="assets/readme/integrate.webp" alt="Integrate without admin. The app folder %LOCALAPPDATA%\Programs\&lt;App&gt; stays in the user profile and Windows is told where it is. Step 1, user PATH: add the folder to HKCU\Environment, skipping duplicates. Step 2, Start Menu shortcut at %APPDATA%\Microsoft\Windows\Start Menu\Programs\&lt;App&gt;.lnk. Step 3, refresh PATH in this terminal by reading the user and the machine PATH again. Also, only what applies: file associations and context menu entries under HKCU\Software\Classes." width="100%"></picture>

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

<picture><source media="(prefers-color-scheme: dark)" srcset="assets/readme/contribute-dark.webp"><img src="assets/readme/contribute.webp" alt="Add a guide, the short path from CONTRIBUTING.md. Step 1, copy the template: templates/guide-template.md to guides/&lt;tool-name&gt;/README.md. Step 2, fill in every section, in English and instructional tense; helper scripts go next to the guide. Step 3, add a row to the Guides table in README.md, sorted by tool name. Step 4, scan before every commit with trivy fs --scanners secret . The result is guides/&lt;tool-name&gt; holding README.md and any *.ps1 helper scripts. Only include steps you actually ran as a standard user; if a step is taken from vendor docs and not tested, say so in the guide." width="100%"></picture>

See [CONTRIBUTING.md](CONTRIBUTING.md) and start from [templates/guide-template.md](templates/guide-template.md).

## License

[MIT](LICENSE). The guides are provided as-is; check each vendor's license terms for the software itself.
