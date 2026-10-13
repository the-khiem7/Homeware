# AGENTS.md

Instructions for coding agents working in this repository.

## What this repo is

Homeware: a public registry of guides for installing developer tools on Windows as a standard user, with no administrator rights and no UAC prompt. Content is Markdown plus small PowerShell helper scripts. There is no build, no package and no runtime.

## Layout

| Path | Contents |
|---|---|
| `README.md` | Hero banner and navigation buttons, overview, **Guides** index table, ground rules, general techniques |
| `assets/readme/` | Rendered README images as WebP, one light and one `-dark` file per image |
| `assets/source/` | HTML sources of those images (`shared.css`, `shared.js`, one page per image set); the render command is in each page's header comment |
| `CONTRIBUTING.md` | How to add a guide, forbidden actions, sanitization checklist |
| `templates/guide-template.md` | Required skeleton for every guide |
| `guides/<tool-name>/README.md` | One guide per tool; folder name lowercase and hyphenated |
| `guides/<tool-name>/*.ps1` | Optional helper scripts for that guide |

## Hard rules

1. **Public repository.** Never write real usernames, hostnames, absolute user paths (`C:\Users\<name>\...`), company or project names, internal repo names, email addresses, cloud account IDs, ARNs, SSO URLs, profile or session names, API keys, tokens or passwords. Use environment variables (`%LOCALAPPDATA%`, `%USERPROFILE%`) and placeholders (`<account-id>`, `<sso-start-url>`, `<profile-name>`, `<PASTE_YOUR_TOKEN_HERE>`). The full mapping is in `CONTRIBUTING.md`.
2. **No screenshots** showing URLs, account names, browser profiles or tokens. Describe the step in text.
3. **No admin, ever.** A guide must not need elevation, writes to `C:\Program Files`, `C:\Windows` or `HKEY_LOCAL_MACHINE`, Windows services or drivers, machine-scope scheduled tasks, firewall changes, or Windows features. If a tool genuinely needs one of these, the guide states it as a prerequisite to request from IT and stops.
4. **Never bypass security controls.** No UAC bypass, no policy evasion, no disabling of security software. Per-process `-ExecutionPolicy Bypass` to run a reviewed local script is the only allowed exception, and the guide must say it applies to that process only.
5. **Remote scripts:** never write `iwr ... | iex` as the primary instruction. Download to `%TEMP%`, tell the reader to review it, then run it.
6. **Untested steps are labeled.** Only present a step as verified if it was actually run as a standard user. Steps taken from vendor docs carry a note saying so.

## Writing a guide

- Start from `templates/guide-template.md` and keep every section: summary table, why the default installer needs admin, rejected approaches, prerequisites, install, integrate, verify, use, uninstall, troubleshooting. Drop a section only if it truly does not apply.
- English only, in instructional tense ("Run ...", not "I ran ..." or "was installed on your machine").
- ASCII only: hyphen `-`, never en or em dashes; no smart quotes.
- Do not hard-wrap paragraphs. One paragraph is one line.
- Prefer tables for options, comparisons, verification checks and troubleshooting.
- Record rejected approaches with the reason, so they are not proposed again.
- Every guide has an **Uninstall** section that reverses every change: files, user PATH entry, Start Menu shortcut and `HKCU` keys.
- Keep tested version numbers and official download URLs; they are public information.
- Add or update the row in the `README.md` **Guides** table (sorted by tool name) in the same change.

## PowerShell conventions

- Target Windows PowerShell 5.1; do not use PowerShell 7-only syntax (`&&`, `||`, `?:`, `??`).
- Install under `%LOCALAPPDATA%\Programs\<App>` unless the vendor installer picks its own per-user location.
- Change PATH only at user scope: `[Environment]::SetEnvironmentVariable("Path", ..., "User")`, with a duplicate check.
- Registry writes only under `HKCU`. For keys containing `*` (e.g. `Software\Classes\*\shell`), use `[Microsoft.Win32.Registry]::CurrentUser`, not `New-Item -Path`, which treats `*` as a wildcard.
- Scripts use `$ErrorActionPreference = "Stop"`, English progress messages, and comments only where the reason is not obvious.

## Verify before finishing

Run all of these from the repo root and fix anything they report:

```powershell
# 1. Secret scan - expect no findings
trivy fs --scanners secret .

# 2. Non-ASCII characters (dashes, smart quotes, non-English text) - expect no output
Select-String -Path (Get-ChildItem -Recurse -File -Exclude *.png,*.webp | Where-Object FullName -notmatch '\\.git\\').FullName -Pattern '[^\x00-\x7F]'

# 3. Leftover identifiers - expect only deliberate placeholders
Select-String -Path (Get-ChildItem -Recurse -File | Where-Object FullName -notmatch '\\.git\\').FullName -Pattern '\b\d{12}\b', '[\w.]+@[\w-]+\.\w+', 'C:\\Users\\(?!<)'

# 4. Syntax-check every helper script - expect no errors
Get-ChildItem guides -Recurse -Filter *.ps1 | ForEach-Object { $null = [ScriptBlock]::Create((Get-Content -Raw $_.FullName)) }
```

Also check by eye that every link in the `README.md` **Guides** table points to an existing `guides/<tool-name>/README.md`.

## Git

- Never commit `*.txt` key files, `credentials` files, `.env`, archives or installers; `.gitignore` blocks them, so do not force-add.
- Conventional Commits, e.g. `docs(trivy): add uninstall steps`, `feat(guides): add <tool> guide`.
- Commit or push only when the user asks.
