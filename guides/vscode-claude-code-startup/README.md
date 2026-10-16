# VS Code startup layout + Claude Code

| Field | Value |
|---|---|
| Tool | [Visual Studio Code](https://code.visualstudio.com/) - start with the right panel closed, no Welcome tab and a Claude Code tab opened automatically |
| Tested version | VS Code `1.142.0`, Claude Code extension `2.1.300`, Auto Run Command extension `1.6.0` |
| Method | VS Code user settings + per-user extension [`gabrielgrinberg.auto-run-command`](https://marketplace.visualstudio.com/items?itemName=gabrielgrinberg.auto-run-command) |
| Admin needed | No |
| Install location | Settings in `%APPDATA%\Code\User\settings.json`, extension in `%USERPROFILE%\.vscode\extensions` |

## Why a workaround is needed

Nothing here needs admin rights. The extension and the settings live in the user profile. The workaround exists because VS Code has no setting that runs a command at startup, and the Claude Code extension has no "open on startup" option. Closing the right panel and removing the Welcome tab are plain settings; opening the Claude Code tab needs a small extension that runs a VS Code command when the window opens.

## Rejected approaches

| Approach | Why rejected |
|---|---|
| Run `claude-vscode.editor.open` from the startup rule | The command always creates a new tab. If a Claude Code tab was open when VS Code last closed, VS Code restores it and the rule opens a second one |
| Run `claude-vscode.editor.openLast` from the startup rule | When `claudeCode.preferredLocation` is `panel`, the command only forwards to `claude-vscode.editor.open`, so it does not avoid the duplicate. Source: Claude Code extension code, not run as a test |
| A `claudeCode.*` setting | Version `2.1.300` has no setting that opens Claude Code on startup |
| A `tasks.json` task with `"runOn": "folderOpen"` | Tasks run shell commands, not VS Code commands, and live in each workspace's `.vscode` folder instead of applying to every folder |
| Rely only on VS Code restoring the last session | The tab comes back only if it was open at the last close. A folder opened for the first time gets nothing |
| Write a custom extension that checks the open tabs first | More code to maintain. Keep it as the fallback if `claude-vscode.focus` still produces duplicates |

## Prerequisites

- A Windows standard user account.
- Visual Studio Code installed per user, with the `code` command on the user PATH.
- The Claude Code extension (`anthropic.claude-code`) installed in VS Code.
- Your organization allows third-party VS Code extensions. The Auto Run Command extension can run any VS Code command, and shell commands if a rule sets `shellCommand` to `true`. The rule in this guide uses a VS Code command only.

## Install

### 1. Install the Auto Run Command extension

```powershell
code --install-extension gabrielgrinberg.auto-run-command
```

The extension installs under `%USERPROFILE%\.vscode\extensions`. No UAC prompt appears.

### 2. Add the settings

Open the user settings file: press `Ctrl+Shift+P`, run `Preferences: Open User Settings (JSON)`. Add these three keys inside the existing top-level `{ ... }`. Do not create a second `{ ... }` block and do not duplicate a key that is already present.

```json
"workbench.secondarySideBar.defaultVisibility": "hidden",
"workbench.startupEditor": "none",
"auto-run-command.rules": [
    {
        "condition": "always",
        "command": "claude-vscode.focus"
    }
]
```

| Key | Effect |
|---|---|
| `workbench.secondarySideBar.defaultVisibility` | `hidden` closes the right-hand Secondary Side Bar by default. Other values: `visibleInWorkspace` (default), `visible`, `maximizedInWorkspace`, `maximized` |
| `workbench.startupEditor` | `none` removes the Welcome tab. It does not close tabs restored from the last session |
| `auto-run-command.rules` | Runs `claude-vscode.focus` after a window opens. The extension waits about 5 seconds so the command is registered first |

`claude-vscode.focus` is the "Claude Code: Focus input" command. Read from the Claude Code extension code: it reveals an existing Claude Code view when one exists, and otherwise opens one through `claude-vscode.editor.openLast`. With `claudeCode.preferredLocation` set to `panel` (the default) that opens an editor tab.

> Untested: whether `claude-vscode.focus` avoids the duplicate tab after a restart. The deduplication behavior comes from reading the extension code. The earlier rule that used `claude-vscode.editor.open` was run and did produce a duplicate. Run the checks in the Verify section before relying on this.

### 3. Restart VS Code

Quit VS Code completely and start it again. Reload Window is not enough to test startup behavior.

## Integrate

The right panel setting is only a default. A workspace that already stored its layout keeps its last state. Close the panel once in each such workspace with `Ctrl+Alt+B`; it stays closed after that.

Keep `claudeCode.preferredLocation` at `panel` if you want the Claude Code tab in the editor area. Set it to `sidebar` to open Claude Code in the side bar instead.

## Verify

| Check | Command or action | Expected |
|---|---|---|
| Extension installed | `code --list-extensions --show-versions \| Select-String "auto-run-command"` | `gabrielgrinberg.auto-run-command@1.6.0` or newer |
| Settings present | Open User Settings (JSON) | The three keys from the Install section, once each |
| Clean start | Quit VS Code, open a folder | No right panel, no Welcome tab, a Claude Code tab appears after about 5 seconds |
| No duplicate | Leave a Claude Code tab open, quit, reopen the same folder | One Claude Code tab. Untested, see the note above |
| Reopen after close | Close the Claude Code tab, quit, reopen the same folder | One new Claude Code tab |

## Use

Press `Ctrl+Esc` to move focus between the editor and the Claude Code input. This is the same `claude-vscode.focus` command the rule runs.

Limit the rule to one folder by changing the condition. The condition values are `always`, `hasFile: <name>`, `isLanguage: <id>`, `isRootFolder: <folder-name>` and `isRunningInContainer`.

```json
"auto-run-command.rules": [
    {
        "condition": "isRootFolder: <folder-name>",
        "command": "claude-vscode.focus"
    }
]
```

## Uninstall

```powershell
code --uninstall-extension gabrielgrinberg.auto-run-command
```

Then open User Settings (JSON) and delete these keys, which restores the VS Code defaults:

- `auto-run-command.rules`
- `workbench.startupEditor`
- `workbench.secondarySideBar.defaultVisibility`

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Right panel is still open | The workspace stored its layout, so the default does not apply | Press `Ctrl+Alt+B` once in that workspace |
| Two Claude Code tabs after a restart | A Claude Code tab was restored and the rule opened another, or the rule still uses `claude-vscode.editor.open` | Check the rule uses `claude-vscode.focus`. Close the extra tab. As a workaround, close the Claude Code tab before quitting VS Code |
| No Claude Code tab appears | Extension missing, still starting, or settings JSON has a syntax error | Check the Verify table, wait 5 to 10 seconds, fix any error flagged in the settings file |
| `command 'claude-vscode.focus' not found` | The Claude Code extension is not installed or not active | Install `anthropic.claude-code`, then restart VS Code |
| Selected text shows up in the Claude Code input | `claude-vscode.focus` attaches the active editor selection as an `@` mention | Clear the selection before the rule fires, or accept it |
| A Claude Code tab opens in windows that have no folder | The `always` condition matches every window | Use `isRootFolder: <folder-name>` as in the Use section |
| Welcome tab still appears | `workbench.startupEditor` is missing or overridden by a workspace setting | Check the user settings and the workspace `.vscode/settings.json` |
