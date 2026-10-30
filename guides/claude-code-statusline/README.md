# Claude Code status line

| Field | Value |
|---|---|
| Tool | [Claude Code status line](https://code.claude.com/docs/en/statusline) - one Bash script that shows model and effort, a context bar colored by absolute token count, unsaved work since the last documentation-pack write, a prompt-cache countdown and the active AWS profile, wrapping onto extra rows in narrow terminals |
| Tested version | Claude Code `2.1.302`, jq `1.8.2`, Git for Windows `2.55.0` (Bash `5.3.15`) |
| Method | `statusLine` in the Claude Code user settings + [`statusline.sh`](statusline.sh), jq through `winget --scope user` |
| Admin needed | No |
| Install location | `%USERPROFILE%\.claude\statusline.sh`, `%USERPROFILE%\.claude\settings.json`, jq under `%LOCALAPPDATA%\Microsoft\WinGet\Packages`, state files under `%TEMP%\claude-statusline` |

Example, one row in a wide terminal. This guide writes the bar as `#` for a filled cell and `.` for an empty one; the script draws block characters. The pack and cache segments start with a book and a clock emoji, written here as `[book]` and `[clock]`:

```
Opus 5.5 (xhigh) | [#.........] 17% | 165k/1M tokens | [book] +245L +5k | [clock] 42m | aws:<profile-name>
```

## Why a workaround is needed

Nothing here needs admin rights. Every file lives in the user profile and jq installs per user. The work is in the script, because the default status line and the raw payload do not cover these points on Windows:

| Gap | How the script handles it |
|---|---|
| Claude Code runs the status line command through Git Bash when Git Bash is installed ([docs](https://code.claude.com/docs/en/statusline#:~:text=On%20Windows%2C%20Claude%20Code%20runs%20status%20line%20commands%20through%20Git%20Bash)) | The script is Bash and uses `cygpath` to turn the Windows paths in the payload into Git Bash paths |
| The payload is JSON | jq parses it. The Windows build of jq ends lines with CRLF, which breaks shell arithmetic, so every jq output goes through `tr -d '\r'` |
| A winget portable package is not always on the PATH that the status line process sees | The script falls back to `%LOCALAPPDATA%\Microsoft\WinGet\Packages\jqlang.jq_*\jq.exe` |
| The payload has no terminal width, and `tput cols` cannot read the terminal from inside the script | Claude Code sets `COLUMNS` before running the script ([docs](https://code.claude.com/docs/en/statusline#:~:text=Read%20the%20COLUMNS%20and%20LINES%20environment%20variables%20instead)). The script packs segments into rows that fit it |
| The status line only redraws on conversation events, so a countdown freezes while idle | `refreshInterval` re-runs the command on a timer ([docs](https://code.claude.com/docs/en/statusline#:~:text=re%2Druns%20your%20command%20every%20N%20seconds)) |

## Rejected approaches

| Approach | Why rejected |
|---|---|
| Color the context bar by percent of the window | With a 1M window, 400k tokens is only 40% and would still look safe, yet every prompt at that size resends 400k tokens. Absolute token thresholds per model match cost and quota drain |
| Pack indicator by time since the last pack write | Sitting idle, or only asking questions about the pack, turns it red although nothing new needs saving |
| Pack indicator by context tokens since the last pack write | Reading the pack adds tens of thousands of tokens of tool output and looks like new work |
| A hook that asks a small model whether each turn produced something worth saving | Spends quota and adds latency on every turn |
| Show the cache expiry as a clock time instead of a countdown | Only needed when the status line cannot refresh while idle. `refreshInterval` solves that |
| Parse the JSON with `sed` and `grep` instead of jq | Breaks on nested objects, escaped quotes and field order changes |
| Fixed pure white (truecolor `255,255,255`) for uncolored text | Renders as low-contrast grey on a light terminal theme. The script cannot pick a color per theme: the payload carries no theme, and the terminal background cannot be queried because Claude Code captures the script's output |
| Read the terminal width with `stty size < /dev/tty`, `mode con` or `[Console]::WindowWidth` | The script has no console attached. All three fail; `COLUMNS` works |
| `source` the per-session state file | Executes whatever the file contains. The script parses it and accepts only known keys with integer values |
| Run the verify commands with plain `bash` from PowerShell | `bash` on the PowerShell PATH is often the WSL launcher in `%LOCALAPPDATA%\Microsoft\WindowsApps`, which has no jq and no access to the Windows-side files the script expects |

## Prerequisites

- A Windows standard user account.
- Claude Code with `refreshInterval` support for `statusLine` (present in `2.1.302`).
- Git for Windows, which provides Git Bash with `bash`, `cygpath`, `find`, `sed` and `wc`. Either the per-user or the machine-wide install works.
- A terminal font that renders emoji and block characters, such as the default font of Windows Terminal.

## Install

### 1. Install jq

```powershell
winget install --id jqlang.jq --exact --scope user
```

> Untested on a profile that does not have jq yet. winget places the portable `jq.exe` under `%LOCALAPPDATA%\Microsoft\WinGet\Packages`.

### 2. Copy the script into the Claude Code user folder

Run from the root of this repository:

```powershell
Copy-Item .\guides\claude-code-statusline\statusline.sh "$env:USERPROFILE\.claude\statusline.sh"
```

Read the script before using it. It runs on every status line refresh and reads the session transcript to count dialogue characters. It writes only counters to `%TEMP%\claude-statusline\<session-id>.state`, never conversation text.

### 3. Point Claude Code at the script

Open `%USERPROFILE%\.claude\settings.json` and add this key inside the top-level `{ ... }`. If a `statusLine` key already exists, replace it; do not add a second one.

```json
"statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline.sh",
    "refreshInterval": 30
}
```

| Key | Effect |
|---|---|
| `command` | Claude Code runs it through Git Bash, where `bash` is Git's Bash and `~` expands to `%USERPROFILE%`. Use forward slashes in any path you put here |
| `refreshInterval` | Re-runs the script every 30 seconds in addition to conversation events, so the cache countdown keeps moving while you are idle |

The new status line appears at the next redraw. Restart Claude Code if it does not.

## Integrate

| Feature | What to do |
|---|---|
| AWS profile segment | Set `AWS_PROFILE` before starting Claude Code, for example `$env:AWS_PROFILE = "<profile-name>"; claude`. The segment shows only the profile name, never credentials, and turns bold red when the name contains `prod`. A profile passed with `--profile` on individual commands is not visible to the status line |
| Documentation pack segment | Shown only when `<project root>\docs\baseline` exists. Change `pack_subdir` in the settings block at the top of the script to use another folder |
| Thresholds and colors | Edit `thresholds()`, `pack_dialogue_warn`, `cache_warn_minutes`, `bar_width` and `text_color` in the settings block at the top of the script |
| Orca | When the script runs inside an Orca pane and `%USERPROFILE%\.orca\agent-hooks\claude-statusline.cmd` exists, the script forwards the payload to it so Orca keeps showing usage. Orca may rewrite `statusLine.command` to its own hook when it starts; set it back to `bash ~/.claude/statusline.sh` if that happens |

## Verify

Run in PowerShell from the root of this repository. The first line finds Git Bash next to `git.exe`, which avoids the WSL `bash` launcher.

```powershell
$gitBash = Join-Path (Split-Path (Split-Path (Get-Command git).Source)) "bin\bash.exe"
$json = '{"model":{"id":"claude-opus-5-5","display_name":"Opus 5.5"},"effort":{"level":"high"},"context_window":{"context_window_size":1000000,"used_percentage":15,"current_usage":{"input_tokens":150000}}}'
$json | & $gitBash ~/.claude/statusline.sh
$env:COLUMNS = "40"; $json | & $gitBash ~/.claude/statusline.sh; Remove-Item Env:COLUMNS
```

| Check | Command or action | Expected |
|---|---|---|
| jq reachable | `& $gitBash -c "command -v jq"` | A path to `jq.exe`. Empty output is fine as long as the next check passes, because the script also looks in the winget package folder |
| Script renders | Third line above | `Opus 5.5 (high) \| [#.........] 15% \| 150k/1M tokens`, with the color codes `[33m` (yellow) around the bar and the tokens. PowerShell prints the escape codes as text |
| Rows wrap | Fourth line above | Two rows: `150k/1M tokens` above `Opus 5.5 (high) \| [#.........] 15%` |
| Settings | `(Get-Content "$env:USERPROFILE\.claude\settings.json" -Raw \| ConvertFrom-Json).statusLine` | `command` is `bash ~/.claude/statusline.sh`, `refreshInterval` is `30` |
| Live | Start `claude` and send a message | The status line appears under the prompt box in color |
| Narrow pane | Make the terminal narrower and send a message, or wait up to 30 seconds | Segments that no longer fit move to rows above, without a trailing `...` |

## Use

### Segments

| Segment | Example | Meaning |
|---|---|---|
| Model and effort | `Opus 5.5 (xhigh)` | Model display name without the `(1M context)` suffix, and the live effort level. Models without effort show no brackets |
| Context bar | `[##........] 17%` or `--%` | 10 cells, one per 10% of the window. `--%` means the size is not known yet, see Tokens |
| Tokens | `165k/1M tokens` or `?/1M tokens` | Tokens in the context window (input plus cache reads and writes of the last request) over the window size, rounded down to thousands. `?` before the first reply of a session and right after `/compact`, until the next reply reports the new size; bar and tokens use the default foreground then |
| Pack (book) | `+245L +5k` | Since the last write to any file under `docs/baseline`: lines Claude edited (`L`) and tokens of dialogue, meaning your prompts plus Claude's reply text, estimated as characters / 4. Tool output, file reads and thinking are not counted |
| Cache (clock) | `42m` or `cold 109k` | Minutes until the prompt cache expires. When cold, the number is the tokens the next request writes back into the cache |
| AWS | `aws:<profile-name>` | Value of `AWS_PROFILE` when Claude Code started |

### Colors

| Segment | Green | Yellow | Red |
|---|---|---|---|
| Bar and tokens, Opus 5.5 | up to 100k | 100k to 200k | above 200k |
| Bar and tokens, Sonnet 5.5 | up to 150k | 150k to 250k | above 250k |
| Bar and tokens, Haiku 5.5 | up to 60k | 60k to 100k | above 100k |
| Bar and tokens, other models | default foreground, no thresholds | | |
| Pack | 0 lines and under 2k dialogue tokens | anything more | anything more while the context is red |
| Cache | - | under 10 minutes left | expired or cold |
| AWS | - | - | name contains `prod` (bold) |

The thresholds are absolute because every prompt resends the whole context: cost and quota drain follow the token count, not the percentage of the window. Long contexts also lose detail from early in the session.

Text without a status color - the model and effort, the cache countdown above 10 minutes, a non-prod AWS profile and the context of other models - uses the terminal's default foreground at normal intensity: white on a dark theme, black on a light theme. It follows a theme switch without any change to the script.

### Working with it

- Pack yellow or red: save the session into the documentation pack, then run `/compact`. The pack write resets the segment to `+0L +0`.
- Cache below 10 minutes and you are about to step away: save and compact first, or accept that the next prompt re-caches the whole context.
- The first run in a session counts everything since the session started as unsaved, because the script has no earlier baseline.
- In a narrow terminal the first row keeps model and context; later segments move to rows above it.

## Uninstall

Open `%USERPROFILE%\.claude\settings.json` and delete the `statusLine` key, or put back the value it had before. Then:

```powershell
Remove-Item "$env:USERPROFILE\.claude\statusline.sh"
Remove-Item "$env:TEMP\claude-statusline" -Recurse -Force -ErrorAction SilentlyContinue
```

Remove jq only if nothing else uses it:

```powershell
winget uninstall --id jqlang.jq --exact
```

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `statusline: jq not found in PATH` | jq is not installed, or it is in neither PATH nor the winget package folder | Run the install step, then check `Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Filter "jqlang.jq*"` |
| Same message only when testing from PowerShell | Plain `bash` started the WSL launcher, not Git Bash | Use `$gitBash` from the Verify section |
| No status line at all | `command` uses backslashes, which Git Bash strips, or `settings.json` has a syntax error | Use `bash ~/.claude/statusline.sh` exactly; validate the file with `Get-Content ... -Raw \| ConvertFrom-Json` |
| `integer expected` or `arithmetic syntax error` | A CR from jq reached shell arithmetic in a modified copy of the script | Keep the `\| tr -d '\r'` after every jq call |
| The line ends with `...` | Old copy of the script without row wrapping, or `COLUMNS` not set | Copy the current script. Check that Claude Code is `2.1.302` or newer |
| Boxes instead of the bar, book or clock | The terminal font lacks those glyphs | Use Windows Terminal with its default font, or replace `full`, `empty`, `book` and `clock` in the script with ASCII |
| Pack shows a large number right after opening a session | First run in the session has no baseline | Expected. It resets on the next pack write |
| Cache segment missing | No API response yet in this session, so the payload has no `prompt_cache` | Send a message |
| `--% \| ?/1M tokens` right after `/compact` | Claude Code sends `current_usage` and `used_percentage` as `null` until the next API call ([docs](https://code.claude.com/docs/en/statusline#:~:text=again%20immediately%20after%20/compact%20until%20the%20next%20API%20call%20repopulates%20it)) | Expected. Send a message; older copies of the script showed `0/1M` here |
| Status line changed back to something else | Another tool, such as Orca, rewrote `statusLine.command` | Set it back to `bash ~/.claude/statusline.sh` |
