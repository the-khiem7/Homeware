# <Tool name>

| Field | Value |
|---|---|
| Tool | [<Tool name>](<official-url>) - one-line description |
| Tested version | `<version>` |
| Method | `winget --scope user` / portable zip / `msiexec /a` / `npx` / vendor script |
| Admin needed | No |
| Install location | `%LOCALAPPDATA%\Programs\<Tool>` |

## Why the default installer needs admin

What the vendor's normal installer does (UAC prompt, writes to `C:\Program Files`, machine-scope MSI, ...).

## Rejected approaches

| Approach | Why rejected |
|---|---|
| <approach> | <reason> |

## Prerequisites

- A Windows standard user account.
- <other tools needed>

## Install

### 1. Download

```powershell
```

### 2. Extract / install into the user profile

```powershell
```

## Integrate

PATH, Start Menu shortcut, file associations or context menu - only what applies.

```powershell
```

## Verify

| Check | Command | Expected |
|---|---|---|
| <check> | `<command>` | `<result>` |

## Use

Most common commands.

## Uninstall

```powershell
```

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| <symptom> | <cause> | <fix> |
