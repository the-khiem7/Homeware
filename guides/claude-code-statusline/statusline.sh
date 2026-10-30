#!/usr/bin/env bash
# Claude Code status line for Git Bash on Windows. Reads the session JSON from stdin and prints:
# model (effort) | [context bar] percent | used/max tokens | pack unsaved | cache countdown | aws profile
# Segments that do not fit the terminal width move to extra rows above the first one.
# Requires jq. Without jq it prints a short fallback so the status line never errors.

# ---- Settings -------------------------------------------------------------
bar_width=10              # cells in the context bar
pack_subdir="docs/baseline"  # documentation pack folder, relative to the project root
pack_dialogue_warn=2000   # dialogue tokens since the last pack write that count as unsaved
cache_warn_minutes=10     # cache countdown turns yellow below this
# Text without a status color: normal intensity (22 cancels any dim attribute around the status line) in the terminal's default foreground (39),
# which is white on a dark theme and black on a light one. A fixed white turns low-contrast grey on a light theme, and the script cannot detect the theme.
text_color='\033[22;39m'
# Context color thresholds in absolute tokens: green up to the first number, yellow up to the second, red above.
thresholds() {
  case "$1" in
    *sonnet-5-5*) echo "150000 250000" ;;
    *opus-5-5*)   echo "100000 200000" ;;
    *haiku-5-5*)  echo "60000 100000" ;;
  esac
}
# ---------------------------------------------------------------------------

input=$(cat)

# UTF-8 bytes written as escapes so the file stays ASCII: full block, light shade, open book, clock.
full=$'\xe2\x96\x88'; empty=$'\xe2\x96\x91'; book=$'\xf0\x9f\x93\x96'; clock=$'\xf0\x9f\x95\x90'

# Optional: forward the payload to Orca's status line hook so Orca keeps showing usage. The hook prints nothing and exits at once outside an Orca pane.
orca_hook="$USERPROFILE\\.orca\\agent-hooks\\claude-statusline.cmd"
if [ -n "$ORCA_PANE_KEY" ] && [ -f "$orca_hook" ]; then
  printf '%s' "$input" | MSYS2_ARG_CONV_EXCL='*' cmd.exe /d /c "$orca_hook" >/dev/null 2>&1
fi

# winget installs jq as a portable package; when its folder is not on the PATH this process sees, fall back to the package folder.
if ! command -v jq >/dev/null 2>&1 && [ -n "$LOCALAPPDATA" ]; then
  for jq_exe in "$(cygpath -u "$LOCALAPPDATA" 2>/dev/null)"/Microsoft/WinGet/Packages/jqlang.jq_*/jq.exe; do
    [ -x "$jq_exe" ] && PATH="$(dirname "$jq_exe"):$PATH" && break
  done
fi

if ! command -v jq >/dev/null 2>&1; then
  printf 'statusline: jq not found in PATH'
  exit 0
fi

# Used tokens are what the last request put into the context window; fall back to the percentage when current_usage is absent.
# Both are null before the first reply of a session and again right after /compact until the next reply, so the size is unknown then and stays "-" instead of a misleading 0.
# Every field defaults to "-" because a tab IFS collapses empty fields and would shift the columns. Paths use forward slashes because @tsv doubles backslashes.
# tr removes the CR that the Windows build of jq adds, which would otherwise break shell arithmetic.
IFS=$'\t' read -r model_id model effort pct used size session_id transcript project_dir lines_now cache_warm cache_expires cache_recache < <(printf '%s' "$input" | jq -r '
  (.context_window.context_window_size // 200000) as $size
  | (.context_window.current_usage // null) as $u
  | (if $u then (($u.input_tokens // 0) + ($u.cache_creation_input_tokens // 0) + ($u.cache_read_input_tokens // 0))
     elif .context_window.used_percentage != null then (.context_window.used_percentage * $size / 100)
     else null end) as $used
  | (.context_window.used_percentage // (if $used == null then null else $used * 100 / $size end)) as $pct
  | def path_or_dash: if . == null or . == "" then "-" else gsub("\\\\"; "/") end;
  def floor_or_dash: if . == null then "-" else floor end;
  [ (.model.id // "-"),
    (.model.display_name // "?" | sub(" *\\([^)]*context\\)"; "")),
    (.effort.level // "-"),
    ($pct | floor_or_dash), ($used | floor_or_dash), $size,
    (.session_id // "-" | gsub("[^A-Za-z0-9-]"; "")),
    (.transcript_path | path_or_dash),
    (.workspace.project_dir // .workspace.current_dir | path_or_dash),
    (((.cost.total_lines_added // 0) + (.cost.total_lines_removed // 0)) | floor),
    (if .prompt_cache.warm == null then "-" else (.prompt_cache.warm | tostring) end),
    (.prompt_cache.expires_at // "-" | if type == "number" then floor else . end),
    (.prompt_cache.recache_tokens_if_cold // "-" | if type == "number" then floor else . end)
  ] | @tsv' | tr -d '\r')

# An empty or unparsable payload leaves every field blank; render a neutral line instead of shell errors.
: "${model:=?}" "${effort:=-}" "${pct:=-}" "${used:=-}" "${size:=200000}" "${session_id:=-}" "${transcript:=-}" "${project_dir:=-}"
: "${lines_now:=0}" "${cache_warm:=-}" "${cache_expires:=-}" "${cache_recache:=-}"

# 1234 -> 1k, 1000000 -> 1M
human() {
  if [ "$1" -ge 1000000 ] && [ $(( $1 % 1000000 )) -eq 0 ]; then printf '%dM' $(( $1 / 1000000 ))
  elif [ "$1" -ge 1000 ]; then printf '%dk' $(( $1 / 1000 ))
  else printf '%d' "$1"; fi
}

if [ "$used" = "-" ]; then
  filled=0; pct_text="--%"; used_text="?"
else
  filled=$(( pct * bar_width / 100 )); pct_text="${pct}%"; used_text=$(human "$used")
fi
[ "$filled" -gt "$bar_width" ] && filled=$bar_width
bar=""
for ((i = 0; i < bar_width; i++)); do
  if [ "$i" -lt "$filled" ]; then bar="$bar$full"; else bar="$bar$empty"; fi
done

# Models without an effort setting report no level, shown as "-" by the jq default above.
[ "$effort" != "-" ] && model="$model ($effort)"

# Context color by absolute tokens: each prompt resends the whole context, so cost and quota drain grow with token count, not with percent of a 1M window.
read -r green_max yellow_max <<< "$(thresholds "$model_id")"
color="$text_color"; reset='\033[0m'; ctx_red=""
if [ -n "$green_max" ] && [ "$used" != "-" ]; then
  if [ "$used" -le "$green_max" ]; then color='\033[32m'
  elif [ "$used" -le "$yellow_max" ]; then color='\033[33m'
  else color='\033[31m'; ctx_red=1; fi
fi

# Unsaved work since the documentation pack was last written. Counts lines Claude edited plus the dialogue itself (user prompts and Claude's reply text), never tool results, so reading the pack or sitting idle does not look like new content.
pack=""
pack_root=""
[ "$project_dir" != "-" ] && pack_root="$(cygpath -u "$project_dir" 2>/dev/null || printf '%s' "$project_dir")/$pack_subdir"
if [ -n "$pack_root" ] && [ -d "$pack_root" ] && [ "$session_id" != "-" ]; then
  pack_mtime=$(find "$pack_root" -type f -printf '%T@\n' 2>/dev/null | sort -n | tail -1)
  pack_mtime=${pack_mtime%.*}
  pack_mtime=${pack_mtime:-0}

  state_dir="${TMPDIR:-/tmp}/claude-statusline"
  state="$state_dir/$session_id.state"
  lines_done=0; dialogue_total=0; pack_mtime_seen=$pack_mtime; lines_at_save=0; dialogue_at_save=0
  # Parse instead of sourcing, and accept only known keys with integer values.
  if [ -f "$state" ]; then
    while IFS='=' read -r key val; do
      case "$val" in ''|*[!0-9]*) continue ;; esac
      case "$key" in
        lines_done|dialogue_total|pack_mtime_seen|lines_at_save|dialogue_at_save) printf -v "$key" '%s' "$val" ;;
      esac
    done < "$state"
  fi

  # Read only the transcript lines added since the last run; wc -l counts finished lines, so a line still being written waits for the next run.
  tp=""
  [ "$transcript" != "-" ] && tp=$(cygpath -u "$transcript" 2>/dev/null || printf '%s' "$transcript")
  if [ -n "$tp" ] && [ -f "$tp" ]; then
    n=$(wc -l < "$tp")
    [ "$n" -lt "$lines_done" ] && lines_done=0
    if [ "$n" -gt "$lines_done" ]; then
      added=$(sed -n "$((lines_done + 1)),${n}p" "$tp" | jq -Rn '
        def text_len: if type == "string" then length
          elif type == "array" then (map(select(.type == "text") | .text | length) | add // 0)
          else 0 end;
        [ inputs | fromjson? // empty
          | select(.isMeta != true and .isCompactSummary != true and .isSidechain != true)
          | select(.type == "user" or .type == "assistant")
          | (.message.content // "" | text_len) ] | add // 0' | tr -d '\r')
      dialogue_total=$(( dialogue_total + ${added:-0} ))
      lines_done=$n
    fi
  fi

  # A newer pack mtime means the pack was just written: move the baseline to now.
  if [ "$pack_mtime" -gt "$pack_mtime_seen" ]; then
    pack_mtime_seen=$pack_mtime; lines_at_save=$lines_now; dialogue_at_save=$dialogue_total
  fi
  # The lines counter restarts with the Claude Code process, for example after a resume.
  [ "$lines_now" -lt "$lines_at_save" ] && lines_at_save=0

  mkdir -p "$state_dir" 2>/dev/null
  printf 'lines_done=%s\ndialogue_total=%s\npack_mtime_seen=%s\nlines_at_save=%s\ndialogue_at_save=%s\n' \
    "$lines_done" "$dialogue_total" "$pack_mtime_seen" "$lines_at_save" "$dialogue_at_save" > "$state" 2>/dev/null

  d_lines=$(( lines_now - lines_at_save ))
  d_tok=$(( (dialogue_total - dialogue_at_save) / 4 ))
  if [ "$d_lines" -eq 0 ] && [ "$d_tok" -lt "$pack_dialogue_warn" ]; then pc='\033[32m'
  elif [ -n "$ctx_red" ]; then pc='\033[31m'
  else pc='\033[33m'; fi
  pack="${pc}${book} +${d_lines}L +$(human "$d_tok")\033[0m"
fi

# Prompt cache countdown. Once it expires the next prompt rewrites the whole context into the cache, which drains quota far faster than a cache read.
cache=""
if [ "$cache_warm" != "-" ] && [ "$cache_expires" != "-" ]; then
  left=$(( cache_expires - $(date +%s) ))
  if [ "$cache_warm" = "true" ] && [ "$left" -gt 0 ]; then
    mins=$(( (left + 59) / 60 ))
    if [ "$mins" -lt "$cache_warn_minutes" ]; then cache="\033[33m${clock} ${mins}m\033[0m"; else cache="${text_color}${clock} ${mins}m\033[0m"; fi
  else
    recache=""
    [ "$cache_recache" != "-" ] && recache=" $(human "$cache_recache")"
    cache="\033[31m${clock} cold${recache}\033[0m"
  fi
fi

# Profile name only, never credentials. Profiles whose name contains "prod" are flagged in bold red.
aws=""
if [ -n "$AWS_PROFILE" ]; then
  case "$AWS_PROFILE" in
    *prod*) aws="\033[1;31maws:$AWS_PROFILE\033[0m" ;;
    *)      aws="${text_color}aws:$AWS_PROFILE\033[0m" ;;
  esac
fi

segs=("${text_color}${model}\033[0m" "${color}[${bar}] ${pct_text}${reset}" "${color}${used_text}/$(human "$size") tokens${reset}")
[ -n "$pack" ] && segs+=("$pack")
[ -n "$cache" ] && segs+=("$cache")
[ -n "$aws" ] && segs+=("$aws")

# Claude Code passes the terminal width in COLUMNS. Git Bash counts an emoji as two UTF-16 units, which matches its two-column display width, so ${#s} works as the visible width.
vis_width() {
  local s
  s=$(printf '%b' "$1" | sed 's/\x1b\[[0-9;]*m//g')
  printf '%d' "${#s}"
}

# Pack segments into rows that fit the width, never splitting a segment. The first row holds model and context; overflow rows are printed above it.
budget=$(( ${COLUMNS:-0} - 4 ))
rows=(); cur=""; cur_w=0
for s in "${segs[@]}"; do
  w=$(vis_width "$s")
  if [ -z "$cur" ]; then cur=$s; cur_w=$w
  elif [ "${COLUMNS:-0}" -le 0 ] || [ $(( cur_w + 3 + w )) -le "$budget" ]; then cur="$cur | $s"; cur_w=$(( cur_w + 3 + w ))
  else rows+=("$cur"); cur=$s; cur_w=$w; fi
done
rows+=("$cur")

out=""
for (( i = ${#rows[@]} - 1; i >= 0; i-- )); do
  out+="${rows[$i]}"
  [ "$i" -gt 0 ] && out+=$'\n'
done
printf '%b' "$out"
