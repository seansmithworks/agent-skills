# ─── Orchestrator shell launchers ──────────────────────────
#
# Provides `cco` and `ccp` — the shell entry points for the
# orchestrator thread pattern. `cco` opens a thread with the orchestrator
# system prompt loaded; project state arrives via a SessionStart hook, not
# a boot command.
# `ccp` is shorthand for `cco pickup`: it restores a worktree and delivers
# a saved pickup prompt as the new thread's opening message.
#
# zsh only. This file uses `${(j: :)...}` array joining, `${match[1]}`
# regex capture groups, and 1-indexed arrays throughout — none of that
# runs under bash.
#
# Requires:
#   - the `wrap-continue` skill from this repo (skills/wrap-continue) —
#     it's the thing that writes the pickup files `ccp` reads. Without
#     it, `ccp` has nothing to consume.
#   - `~/.claude/orchestrator-prompt.md` (copy from templates/ — see the
#     README's orchestrator family section).
#
# Remote control is off by default. `cco` only passes
# `--remote-control` to `claude` when `CCO_REMOTE_CONTROL` is set and
# non-empty (`export CCO_REMOTE_CONTROL=1`) — that flag opens an outbound
# control connection letting claude.ai/code drive the session.
#
# NOT included here: the worktree-isolation `claude()` wrapper that
# `wrap-continue`'s docs reference indirectly (the collision guard that
# auto-isolates a second concurrent session into its own worktree). That
# wrapper is part of a separate, private terminal-title setup and doesn't
# belong in a public skills repo. Without it, `cco`/`ccp` fall
# through to calling the plain `claude` binary — everything above still
# works, you just don't get automatic worktree isolation on collision.
#
# Portability: written for macOS/BSD userland (`stat -f %m`) with a GNU
# fallback (`stat -c %Y`) via the `_cc_mtime` helper below, and age
# arithmetic degrades to "?" rather than erroring if both fail. No other
# BSD-only or macOS-only commands (no `sed -i ''`, `pbcopy`, `date -r`,
# `readlink -f`) are used in this file.

# Portable mtime (seconds since epoch) — BSD stat (macOS) uses -f %m,
# GNU stat (Linux) uses -c %Y. Returns empty on failure; callers must
# handle that rather than assume a numeric result.
_cc_mtime() {
  stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null
}

# Where does this cwd's orchestrator state live? Claude mangles the project
# path by replacing every non-alphanumeric char with a dash.
_cco_memdir() {
  printf '%s/.claude/projects/%s/memory' "$HOME" "${PWD//[^a-zA-Z0-9]/-}"
}

# ─── Pickup-prompt handoff ─────────────────────
# /wrap-continue persists its pickup prompt to $HOME/.claude/pickup/<KEY>.md,
# keyed on the repo TOPLEVEL (not PWD) with the same non-alphanumeric-to-dash
# mangling _cco_memdir uses above — every worktree gets its own toplevel, so
# every worktree gets its own pickup file. `cco` never delivers a pickup on
# its own — it is the clean-slate path. `cco pickup` is the explicit
# resume path: think `claude --resume`, but for worktree + prompt instead
# of conversation history.
#
# File format (frontmatter — KEY mangling is lossy, so the absolute path
# is stored, not derived). Contract lives in this repo's
# skills/wrap-continue/SKILL.md — keep both in sync:
#
#   ---
#   thread: <user-set thread name, or empty>
#   repo: <basename of the main repo>
#   worktree: <basename of toplevel, or "main" if not in a worktree>
#   path: <absolute toplevel path>
#   ---
#   <prompt body>
#
# _cc_pk_parse sets _CC_PK_THREAD / _CC_PK_REPO / _CC_PK_WORKTREE /
# _CC_PK_PATH / _CC_PK_BODY from a pickup file. Body is byte-exact
# (trailing newline preserved) — pad-and-strip, since command substitution
# alone strips trailing newlines.
_cc_pk_parse() {
  local _pk_file="$1"
  _CC_PK_THREAD="" _CC_PK_REPO="" _CC_PK_WORKTREE="" _CC_PK_PATH="" _CC_PK_BODY=""

  local _pk_line _pk_in_fm=0 _pk_closed=0
  while IFS= read -r _pk_line; do
    if [[ $_pk_in_fm -eq 0 ]]; then
      [[ "$_pk_line" == "---" ]] && _pk_in_fm=1
      continue
    fi
    if [[ "$_pk_line" == "---" ]]; then
      _pk_closed=1
      break
    fi
    case "$_pk_line" in
      thread:*) _CC_PK_THREAD="${_pk_line#thread:}"; _CC_PK_THREAD="${_CC_PK_THREAD## }" ;;
      repo:*) _CC_PK_REPO="${_pk_line#repo:}"; _CC_PK_REPO="${_CC_PK_REPO## }" ;;
      worktree:*) _CC_PK_WORKTREE="${_pk_line#worktree:}"; _CC_PK_WORKTREE="${_CC_PK_WORKTREE## }" ;;
      path:*) _CC_PK_PATH="${_pk_line#path:}"; _CC_PK_PATH="${_CC_PK_PATH## }" ;;
    esac
  done < "$_pk_file"

  if [[ $_pk_closed -eq 1 ]]; then
    _CC_PK_BODY=$(awk 'BEGIN{c=0} /^---$/{c++; next} c>=2{print}' "$_pk_file"; printf 'x')
  else
    # No frontmatter found — treat the whole file as the body.
    _CC_PK_BODY=$(cat "$_pk_file"; printf 'x')
  fi
  _CC_PK_BODY="${_CC_PK_BODY%x}"
}

# Derives a one-line summary from an already-parsed body ($_CC_PK_BODY —
# call _cc_pk_parse first, never re-reads the file). Sets _CC_PK_SUMMARY to
# the first non-empty, non-metadata body line, with a leading "Objective:"
# (any case) stripped, truncated to 72 characters (character-safe for
# UTF-8) with a trailing "…" when cut. Empty body, or a body consisting
# only of metadata-style lines, leaves it "".
#
# A body line is skipped as metadata preamble (e.g. the "Thread: <name>"
# line /wrap-continue writes) when it is a single bare word immediately
# followed by ":" — no spaces before the colon, so an ordinary sentence
# that merely contains a colon ("Ship the thing: it needs...") is never
# mistaken for a label — AND the text after the colon is short (<=60
# chars, a label value rather than prose). "Objective:" is always treated
# as the real summary line regardless of value length, matching the
# existing strip-and-use handling below.
_cc_pk_summary() {
  _CC_PK_SUMMARY=""
  local _sm_line _sm_found="" _sm_trim _sm_val
  while IFS= read -r _sm_line; do
    [[ -z "${_sm_line//[[:space:]]/}" ]] && continue
    _sm_trim="${_sm_line#"${_sm_line%%[![:space:]]*}"}"
    if [[ "${_sm_trim:l}" != objective:* ]] \
       && [[ "$_sm_trim" =~ "^[A-Za-z]+:[[:space:]]*(.*)$" ]]; then
      _sm_val="${match[1]}"
      (( ${#_sm_val} <= 60 )) && continue
    fi
    _sm_found="$_sm_line"
    break
  done <<< "$_CC_PK_BODY"
  [[ -z "$_sm_found" ]] && return

  _sm_found="${_sm_found#"${_sm_found%%[![:space:]]*}"}"
  if [[ "${_sm_found:l}" == objective:* ]]; then
    _sm_found="${_sm_found#*:}"
    _sm_found="${_sm_found## }"
  fi
  if (( ${#_sm_found} > 72 )); then
    _sm_found="${_sm_found[1,72]}…"
  fi
  _CC_PK_SUMMARY="$_sm_found"
}

# _cc_pk_deliver <file>: prints a cyan confirmation, cd's to the stored
# path, marks the file consumed, and launches cco with the body as the
# positional prompt.
# $1 = pickup file. Remaining args ($2..) are flags typed before `pickup`
# on the command line (`cco -n "name" pickup <query>`) — forwarded to the
# launch as-is, before the positional prompt.
#
# A file already named *.consumed was delivered once before. Re-delivery is
# harmless (the alternative — hiding recoverable work — is not), so this is
# detected from the filename alone: the note is printed but the file is left
# named *.consumed (never re-consumed into *.consumed.consumed).
_cc_pk_deliver() {
  local _pk_f="$1"
  shift
  local -a _pk_fwd_flags=("$@")
  _cc_pk_parse "$_pk_f"

  if [[ -z "$_CC_PK_PATH" ]]; then
    printf '  \033[1;31m✗ pickup file has no stored path (missing or malformed frontmatter): %s\033[0m\n' "$_pk_f"
    return 1
  fi
  if [[ ! -d "$_CC_PK_PATH" ]]; then
    printf '  \033[1;31m✗ worktree no longer exists: %s\033[0m\n' "$_CC_PK_PATH"
    return 1
  fi

  local _pk_mtime _pk_age_s _pk_age
  _pk_mtime=$(_cc_mtime "$_pk_f")
  if [[ -n "$_pk_mtime" ]]; then
    _pk_age_s=$(( $(date +%s) - _pk_mtime ))
    if (( _pk_age_s < 86400 )); then
      _pk_age="$(( _pk_age_s / 3600 ))h"
    else
      _pk_age="$(( _pk_age_s / 86400 ))d"
    fi
  else
    _pk_age="?"
  fi

  local _pk_was_consumed=0
  [[ "$_pk_f" == *.consumed ]] && _pk_was_consumed=1
  (( _pk_was_consumed )) && printf '  \033[2m(already picked up %s ago — re-delivering)\033[0m\n' "$_pk_age"

  # Name precedence: an explicit -n/--name in the forwarded flags wins over
  # the stored thread: — never pass -n twice.
  local _pk_explicit_name="" _pk_fi
  for (( _pk_fi = 1; _pk_fi <= ${#_pk_fwd_flags[@]}; _pk_fi++ )); do
    if [[ "${_pk_fwd_flags[$_pk_fi]}" == "-n" || "${_pk_fwd_flags[$_pk_fi]}" == "--name" ]]; then
      _pk_explicit_name="${_pk_fwd_flags[$(( _pk_fi + 1 ))]}"
      break
    fi
  done

  local _pk_thread_disp="${_CC_PK_THREAD:-<unnamed>}"
  if [[ -n "$_pk_explicit_name" ]]; then
    printf '  \033[1;36m↻ delivering "%s" (%s/%s, %s ago) — using explicit name "%s" (overrides stored)\033[0m\n' "$_pk_thread_disp" "$_CC_PK_REPO" "$_CC_PK_WORKTREE" "$_pk_age" "$_pk_explicit_name"
  elif [[ -n "$_CC_PK_THREAD" ]]; then
    printf '  \033[1;36m↻ delivering "%s" (%s/%s, %s ago) — restoring name "%s"\033[0m\n' "$_pk_thread_disp" "$_CC_PK_REPO" "$_CC_PK_WORKTREE" "$_pk_age" "$_CC_PK_THREAD"
  else
    printf '  \033[1;36m↻ delivering "%s" (%s/%s, %s ago)\033[0m\n' "$_pk_thread_disp" "$_CC_PK_REPO" "$_CC_PK_WORKTREE" "$_pk_age"
  fi

  cd "$_CC_PK_PATH" || return 1
  # Flags precede the positional prompt: claude [options] [command] [prompt].
  # -n restores the stored thread name only when one was captured AND no
  # explicit -n/--name was already forwarded — never synthesize a name,
  # never pass -n twice.
  if [[ -z "$_pk_explicit_name" && -n "$_CC_PK_THREAD" ]]; then
    _pk_fwd_flags+=(-n "$_CC_PK_THREAD")
  fi
  # Launch first, consume only on success — a failed launch (e.g. cco not
  # sourced, orchestrator-prompt.md missing) must leave the pickup file
  # intact so the next `ccp` still finds it instead of reporting nothing
  # pending.
  cco "${_pk_fwd_flags[@]}" "$_CC_PK_BODY"
  local _pk_launch_status=$?
  if (( _pk_launch_status == 0 )); then
    (( _pk_was_consumed )) || mv -f "$_pk_f" "${_pk_f}.consumed"
  fi
  return $_pk_launch_status
}

# AND-matching, case-insensitive, literal (no glob/regex interpretation)
# against a haystack built from thread+repo+worktree+summary — shared by
# the query-path (`cco pickup <query>`) and the interactive selector's
# type-a-name fallback. $1 = query (whitespace-separated terms, order-
# independent, terms may span different fields), remaining args = candidate
# files. Empty query (no terms) matches everything.
# Sets _cc_pk_filter_result (array of matched file paths).
_cc_pk_filter() {
  local _f_query="$1"
  shift
  _cc_pk_filter_result=()

  # Split on whitespace, lowercase each term, drop empties. ${=...} does
  # IFS field-splitting only — not filename generation — so terms
  # containing glob-special characters (., *, [, ?, () stay literal.
  local -a _f_terms
  local _f_raw_term
  for _f_raw_term in ${=_f_query}; do
    [[ -n "$_f_raw_term" ]] && _f_terms+=("${_f_raw_term:l}")
  done

  local _f_file _f_haystack _f_term _f_ok
  for _f_file in "$@"; do
    _cc_pk_parse "$_f_file"
    _cc_pk_summary
    _f_haystack="${_CC_PK_THREAD:l} ${_CC_PK_REPO:l} ${_CC_PK_WORKTREE:l} ${_CC_PK_SUMMARY:l}"
    _f_ok=1
    for _f_term in "${_f_terms[@]}"; do
      if [[ "$_f_haystack" != *"$_f_term"* ]]; then
        _f_ok=0
        break
      fi
    done
    (( _f_ok )) && _cc_pk_filter_result+=("$_f_file")
  done
}

# Prints the numbered pickup list for the given files ($@). Shared by the
# initial listing and any re-display triggered from the interactive selector.
# Each row is followed by a dimmed, indented one-line summary (from the
# pickup body) when one is available.
_cc_pk_show_list() {
  local -a _s_files=("$@")
  local _s_i _s_f _s_mtime _s_age_s _s_age _s_thread_disp
  for (( _s_i = 1; _s_i <= ${#_s_files[@]}; _s_i++ )); do
    _s_f="${_s_files[$_s_i]}"
    _cc_pk_parse "$_s_f"
    _cc_pk_summary
    _s_mtime=$(_cc_mtime "$_s_f")
    if [[ -n "$_s_mtime" ]]; then
      _s_age_s=$(( $(date +%s) - _s_mtime ))
      if (( _s_age_s < 86400 )); then
        _s_age="$(( _s_age_s / 3600 ))h"
      else
        _s_age="$(( _s_age_s / 86400 ))d"
      fi
    else
      _s_age="?"
    fi
    if [[ -n "$_CC_PK_THREAD" ]]; then
      _s_thread_disp="$_CC_PK_THREAD"
    else
      _s_thread_disp=$'\033[2m<unnamed>\033[0m'
    fi
    printf '  %2d) %b  \033[2m%s/%s · %s\033[0m\n' "$_s_i" "$_s_thread_disp" "$_CC_PK_REPO" "$_CC_PK_WORKTREE" "$_s_age"
    [[ -n "$_CC_PK_SUMMARY" ]] && printf '      \033[2m%s\033[0m\n' "$_CC_PK_SUMMARY"
  done
}

# Given a list of candidate pickup files ($@), drops any whose recorded
# path: no longer exists (printing the existing skip note — applies to
# pending and *.consumed candidates alike), then sorts the rest newest
# first by mtime. Sets _cc_pk_scan_result (array).
_cc_pk_scan() {
  local -a _sc_in=("$@")
  local -a _sc_files _sc_mtimes
  local _sc_f _sc_mtime
  for _sc_f in "${_sc_in[@]}"; do
    _cc_pk_parse "$_sc_f"
    if [[ -n "$_CC_PK_PATH" && ! -d "$_CC_PK_PATH" ]]; then
      printf '  \033[2m(skipped — worktree gone: %s)\033[0m\n' "$_CC_PK_PATH"
      continue
    fi
    _sc_mtime=$(_cc_mtime "$_sc_f")
    [[ -z "$_sc_mtime" ]] && _sc_mtime=0
    _sc_files+=("$_sc_f")
    _sc_mtimes+=("$_sc_mtime")
  done

  _cc_pk_scan_result=()
  (( ${#_sc_files[@]} == 0 )) && return

  local -a _sc_pairs _sc_sorted
  local _sc_i
  for (( _sc_i = 1; _sc_i <= ${#_sc_files[@]}; _sc_i++ )); do
    _sc_pairs+=("${_sc_mtimes[$_sc_i]}"$'\t'"${_sc_files[$_sc_i]}")
  done
  _sc_sorted=("${(@f)$(printf '%s\n' "${_sc_pairs[@]}" | sort -t $'\t' -k1,1rn)}")
  local _sc_pair
  for _sc_pair in "${_sc_sorted[@]}"; do
    _cc_pk_scan_result+=("${_sc_pair#*$'\t'}")
  done
}

# `cco pickup` — list pending pickups (newest first), or with a query,
# match directly by thread/repo/worktree. No age gate, no confirmation —
# explicit invocation is the confirmation. Reads $_CC_PK_FWD_FLAGS (global,
# set by cco()) for any flags typed before `pickup` on the command line.
#
# Consume-on-use renames a delivered pickup to *.consumed and drops it out
# of the normal pending listing — that part is unchanged. But a *.consumed
# file is recoverable work, not gone: when nothing pending matches, this
# falls back to offering the matching *.consumed entries under a dimmed
# heading instead of reporting nothing found. Selecting one re-delivers it
# (see _cc_pk_deliver) without resurrecting it into the pending set.
_cc_pk_cmd() {
  local _pk_query="$1"
  local -a _pk_fwd_flags=("${_CC_PK_FWD_FLAGS[@]}")

  _cc_pk_scan "$HOME/.claude/pickup"/*.md(N)
  local -a _pk_files_all=("${_cc_pk_scan_result[@]}")

  _cc_pk_scan "$HOME/.claude/pickup"/*.md.consumed(N)
  local -a _pk_consumed_all=("${_cc_pk_scan_result[@]}")

  if (( ${#_pk_files_all[@]} == 0 && ${#_pk_consumed_all[@]} == 0 )); then
    printf 'no pending pickups.\n'
    return 0
  fi

  local -a _pk_files
  local _pk_consumed_mode=0
  local _pk_fallback_label="pending pickups"

  # Query filter — case-insensitive substring match against thread/repo/worktree.
  if [[ -n "$_pk_query" ]]; then
    _cc_pk_filter "$_pk_query" "${_pk_files_all[@]}"
    local -a _pk_matched=("${_cc_pk_filter_result[@]}")
    if (( ${#_pk_matched[@]} == 1 )); then
      _cc_pk_deliver "${_pk_matched[1]}" "${_pk_fwd_flags[@]}"
      return $?
    elif (( ${#_pk_matched[@]} > 1 )); then
      _pk_files=("${_pk_matched[@]}")
      printf '  multiple matches for "%s":\n' "$_pk_query"
    else
      _cc_pk_filter "$_pk_query" "${_pk_consumed_all[@]}"
      local -a _pk_consumed_matched=("${_cc_pk_filter_result[@]}")
      if (( ${#_pk_consumed_matched[@]} > 0 )); then
        _pk_consumed_mode=1
        _pk_files=("${_pk_consumed_matched[@]}")
        _pk_fallback_label="recently picked up"
        printf '  \033[2mno pending pickups — recently picked up:\033[0m\n'
      else
        printf '  no match for "%s" — showing all pending pickups:\n' "$_pk_query"
        _pk_files=("${_pk_files_all[@]}")
      fi
    fi
  else
    if (( ${#_pk_files_all[@]} > 0 )); then
      _pk_files=("${_pk_files_all[@]}")
    else
      _pk_consumed_mode=1
      _pk_files=("${_pk_consumed_all[@]}")
      _pk_fallback_label="recently picked up"
      printf '  \033[2mno pending pickups — recently picked up:\033[0m\n'
    fi
  fi

  # The selector's own no-match path re-displays this full list — pending
  # or consumed, matching whichever set is currently in play.
  (( _pk_consumed_mode )) && _pk_files_all=("${_pk_consumed_all[@]}")

  _cc_pk_show_list "${_pk_files[@]}"

  # Interactive selector — accepts a number (index into the currently
  # displayed list) or a name (fresh substring query, reusing _cc_pk_filter).
  # Unique name match selects it; multiple re-displays the filtered list and
  # re-prompts; no match re-displays the full pending-pickup list and
  # re-prompts. Empty input cancels. Capped at 3 attempts.
  local _pk_choice _pk_attempt
  for (( _pk_attempt = 1; _pk_attempt <= 3; _pk_attempt++ )); do
    read "_pk_choice?  select a pickup (number or name): "

    if [[ -z "$_pk_choice" ]]; then
      printf '  cancelled.\n'
      return 0
    fi

    if [[ "$_pk_choice" =~ ^[0-9]+$ ]]; then
      if (( _pk_choice >= 1 && _pk_choice <= ${#_pk_files[@]} )); then
        _cc_pk_deliver "${_pk_files[$_pk_choice]}" "${_pk_fwd_flags[@]}"
        return $?
      fi
      printf '  \033[1;31m✗ not a valid choice.\033[0m\n'
      continue
    fi

    _cc_pk_filter "$_pk_choice" "${_pk_files[@]}"
    if (( ${#_cc_pk_filter_result[@]} == 1 )); then
      _cc_pk_deliver "${_cc_pk_filter_result[1]}" "${_pk_fwd_flags[@]}"
      return $?
    elif (( ${#_cc_pk_filter_result[@]} > 1 )); then
      _pk_files=("${_cc_pk_filter_result[@]}")
      printf '  multiple matches for "%s":\n' "$_pk_choice"
      _cc_pk_show_list "${_pk_files[@]}"
    else
      printf '  \033[1;31m✗ no match for "%s"\033[0m — showing all %s:\n' "$_pk_choice" "$_pk_fallback_label"
      _pk_files=("${_pk_files_all[@]}")
      _cc_pk_show_list "${_pk_files[@]}"
    fi
  done

  printf '  \033[1;31m✗ giving up after 3 attempts.\033[0m\n'
  return 1
}

cco() {
  local base=(claude --append-system-prompt-file ~/.claude/orchestrator-prompt.md)
  [[ -n "$CCO_REMOTE_CONTROL" ]] && base+=(--remote-control)

  # Scan for a bare `pickup` token anywhere in the args, not just $1 —
  # flags may precede it (`cco -n "name" pickup <query>`). Everything
  # before the FIRST `pickup` token is forwarded to the launch as flags;
  # everything after is the query (joined with spaces, so unquoted
  # multi-word queries like `cco pickup ghostties website` match the
  # quoted form). A `pickup` appearing again after that is just query text.
  local -a _cc_pre_flags _cc_post_query
  local _cc_found_pickup=0
  local _cc_arg
  for _cc_arg in "$@"; do
    if [[ $_cc_found_pickup -eq 0 && "$_cc_arg" == "pickup" ]]; then
      _cc_found_pickup=1
      continue
    fi
    if [[ $_cc_found_pickup -eq 0 ]]; then
      _cc_pre_flags+=("$_cc_arg")
    else
      _cc_post_query+=("$_cc_arg")
    fi
  done
  if [[ $_cc_found_pickup -eq 1 ]]; then
    _CC_PK_FWD_FLAGS=("${_cc_pre_flags[@]}")
    _cc_pk_cmd "${(j: :)_cc_post_query}"
    unset _CC_PK_FWD_FLAGS
    return
  fi

  if [ $# -gt 0 ]; then
    echo "✦ Orchestrator mode loaded"
    "${base[@]}" "$@"
    return
  fi

  echo "✦ Orchestrator mode loaded"

  "${base[@]}"
}

# ccp = shorthand for `cco pickup`. Pure forwarder — inserts the `pickup`
# token at the right spot and calls cco, so cco's arg-scan (and the rest
# of the pickup machinery) runs exactly once, never duplicated here.
#   ccp                          → cco pickup
#   ccp ghostties website        → cco pickup ghostties website
#   ccp -n "Override" ghostties  → cco -n "Override" pickup ghostties
# Split at the first non-flag token — `-n`/`--name` also consume the
# value that follows them, since that value is not itself a flag.
ccp() {
  local -a _cp_args=("$@") _cp_pre _cp_post
  local _cp_i=1 _cp_n=$#
  while (( _cp_i <= _cp_n )); do
    local _cp_a="${_cp_args[$_cp_i]}"
    case "$_cp_a" in
      -n|--name)
        _cp_pre+=("$_cp_a")
        (( _cp_i++ ))
        if (( _cp_i <= _cp_n )); then
          _cp_pre+=("${_cp_args[$_cp_i]}")
          (( _cp_i++ ))
        fi
        ;;
      -*)
        _cp_pre+=("$_cp_a")
        (( _cp_i++ ))
        ;;
      *)
        break
        ;;
    esac
  done
  while (( _cp_i <= _cp_n )); do
    _cp_post+=("${_cp_args[$_cp_i]}")
    (( _cp_i++ ))
  done
  cco "${_cp_pre[@]}" pickup "${_cp_post[@]}"
}
