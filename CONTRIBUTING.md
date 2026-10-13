# Contributing to Homeware

## Adding a guide

1. Copy [templates/guide-template.md](templates/guide-template.md) to `guides/<tool-name>/README.md` (lowercase, hyphenated folder name).
2. Fill in every section. Write in English, in instructional tense ("Run ...", not "I ran ...").
3. Put helper scripts next to the guide (`guides/<tool-name>/*.ps1`). Messages and comments in English.
4. Add a row to the **Guides** table in [README.md](README.md), keeping it sorted by tool name.
5. Only include steps you actually ran as a standard user. If a step is taken from vendor docs and not tested, say so in the guide.

## What a guide must not need

- Administrator rights, a UAC prompt, or "Run as administrator".
- Writes to `C:\Program Files`, `C:\Program Files (x86)`, `C:\Windows` or `HKEY_LOCAL_MACHINE`.
- Installing or starting Windows services or drivers, machine-wide scheduled tasks, firewall changes, or enabling Windows features.
- Anything that disables, evades or tricks a security control.

If the only way needs one of these, the guide should say so and stop.

## Sanitization checklist (before every commit)

This is a public repository. Replace anything that identifies a person, a machine or an organization:

| Remove | Replace with |
|---|---|
| Real usernames, hostnames, domain names | `%USERPROFILE%`, `%LOCALAPPDATA%`, `<hostname>` |
| Absolute paths such as `C:\Users\<name>\...` | Environment variables (`%LOCALAPPDATA%\Programs\...`) |
| Company or project names, internal repo names | Neutral words ("your organization", `<project>`) |
| Email addresses | `<your-email>` |
| Cloud account IDs, ARNs, role IDs, SSO URLs, profile and session names | `<account-id>`, `<sso-start-url>`, `<profile-name>`, `<sso-session-name>` |
| API keys, tokens, passwords, connection strings | `<PASTE_YOUR_TOKEN_HERE>` - and rotate the real one if it was ever written down |
| Screenshots showing URLs, account names or browser profiles | Describe the step in text instead |

Then scan the working tree for secrets:

```powershell
trivy fs --scanners secret .
```
