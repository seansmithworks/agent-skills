---
name: wrap-continue
description: Checkpoint a long-lived thread mid-task so it can be thrown away and resumed in a fresh one — stop background writers, commit, smart-push, run the scope audit, reconcile open items into BACKLOG.md, and render a copyable pickup prompt inline. Use when the work is NOT finished and continues immediately in a new thread ("wrap and continue", "checkpoint", "context reset", "trim and keep going", "recycle this thread"). Do NOT use when the session is actually over — done for the day, work complete, or switching to unrelated work; that is /wrap's heavy retrospective. The distinguishing test is whether the task is finished, not whether the thread is ending.
license: MIT
metadata:
  version: 1.0.0
  category: workflow
  domain: session-management
---

# Wrap + Continue

A checkpoint, not a retrospective. It exists because the heavy end-of-session flow burns the exact context the user is trying to reclaim — so proportion is a requirement, not a preference.

## Misroute check (one line, then move)

If the signal is "done for the day" / "work is complete" / "switching to something else", this is the wrong flow. Say which flow applies and **then run that flow in the same turn** — do not stop and hand the user back a command to type; they already asked to wrap. A wrongly-run heavy flow costs context; a wrongly-run light flow loses capture. Name the signal that decided it in one sentence and get on with it. No pickup prompt in that case.

Everything below assumes the task continues.

Section 3 and Section 5 below both target 150–350 words with the structure rules given in each section.

## 1. Stop background writers first — ordering is load-bearing

Nothing may be observed about repository state until everything that could still be writing has stopped.

- List and stop background agents/shells (`TaskList` / `TaskStop`, plus background Bash this session launched).
- **Exception: leave long-running processes the next thread will want** — dev servers, booted simulators, watchers. Note the PID, port/UDID and the command so the next thread reuses it instead of starting a second one.
- **Then re-check `git status` in every location a stopped writer could have touched** — main tree *and* every worktree (`git worktree list`; worktrees live under `<repo>/.claude/worktrees/`), plus any other directory it wrote to. A clean root proves nothing about the trees.
- For each stopped agent, state: what it was doing, what it committed, what it left behind unfinished. Partial work is committed on a clearly labelled WIP commit (message names the breakage) **and** named in the pickup prompt as unverified — never left silent, never left to look finished.

> Reversing this order caused a real incident: a wrap reported a clean tree, the agents were killed after, and a half-built route died uncommitted under a false "nothing uncommitted anywhere" claim. A status read taken before the stop is not citable.

If nothing is running, one line and move on.

## 2. Commit, then push

**Committing is mandatory whenever anything is uncommitted. Never ask, never invent an exception** ("it's only a context reset" is not one — the thread's disk state is exactly what is at risk).

- Stage by explicit path, never `git add -A` — a concurrent session in the same tree gets swept in otherwise.
- If `git status` reports an ahead/behind count, `git fetch` before trusting it; a stale remote-tracking ref that disagrees with `git log` is a real and common trap. Re-check after pushing.

**Push is the default. Decide, never ask:**

| Case | Action |
|---|---|
| Nothing to push | say nothing at all |
| Remote named `upstream`, or `main`/`master`/`develop` on a remote other than the user's own default | skip, one-line note: `Push skipped — upstream/protected remote, push manually if intended` |
| Everything else — including `main` when it tracks `origin`, and deploy/staging remotes pushed to routinely | push |

Refusing an `origin` push on your own safety reasoning ("this deploys production", "want me to push?") is a failure, not caution. The narrow skips exist for one reason: never create an outward-facing effect resembling an upstream contribution (prior Ghostty incident — an unintended PR opened upstream).

## 2a. Scope audit

Runs once per session, here: after the commit so the diff is complete, before the ledger, because dropouts feed it. Run `python3 ~/.claude/hooks/scope-check.py wrap "$CLAUDE_CODE_SESSION_ID"` (~20s, Haiku, always exits 0) and act on each line:

- `DROPOUT — …`: an ask Sean made with no matching change. Show it was actually done (evidence), or append it to `BACKLOG.md` like any other open item. Never silently drop it.
- `DRIFT — …`: state it in one line in the report, without re-litigating it.
- `CLEAN`, `NO SCOPE CARD`, `NO ASKS`: no action; one line in the report.
- `AUDIT FAILED: …`: say so in the report and carry on.

## 3. Light capture — only what the code cannot tell you

Bar: *would this be unrecoverable if context cleared right now?* Corrections, decisions, constraints, gotchas. Skip freely; do not pad, do not restate rules that already live in `DESIGN.md` or an existing memory file.

- New correction → `.claude/projects/<path>/memory/feedback_*.md`; new durable reference → `reference_*.md`. One or two lines of genuine signal, in the file's existing format. If `MEMORY.md` is an index, add the pointer — an unindexed file is invisible.
- Project has an `ORCHESTRATOR.md`? Update its Decision Log and rebuild its In-Flight section — **regardless of thread type**. Implementation threads change project state too, and that state must be written back before context clears. The In-Flight section is generated, not hand-written: run `~/.claude/hooks/lib/inflight.sh <repo-root> --merged-since <date of the file's last update>` (branches and worktrees with commits in the last 14 days, open PRs, PRs merged since), add the open items from the repo-root `BACKLOG.md`, and replace the whole section — rewritten, never appended. Hand-written prose stays only for decisions, Fragile Areas, and blocked-on-Sean items (see `/wrap` step 7). If `inflight.sh` prints nothing (non-git root), keep the section with `no git state`.
- `~/.claude/projects/project-facts.md` (cross-project status index) — if the file exists and this session changed something it tracks, update the project's block in place, matching the existing entry format. A shipped milestone gets a `Shipped: <date> — <what>. Promoted: no.` line; without the promotion state, downstream promotion/content workflows cannot find it. If the file does not exist, say nothing about it.

Under time pressure this section is the *only* thing that gets cut. Never the commit, the push, the ledger, or the pickup prompt.

## 4. Reconcile the ledger — always runs, even when capture is skipped

State the thread's **locked objective** in one line, but first check it still describes what the thread is actually doing; if it has drifted, say so at the handoff and carry the corrected objective forward instead of the stale one. If `~/.claude/scope/$CLAUDE_CODE_SESSION_ID.md` exists, refresh its `Updated:` date, tick any Done-when box that's now met, and add anything newly out of scope under "Noticed, not pursued." Scope is capped at one screen; once it exceeds that it has become a plan, and the overflow moves to `BACKLOG.md`, not the scope file. Then walk every item in the task ledger:

- Done → marked complete, not carried.
- Open → recorded in the project-root `BACKLOG.md` (create if absent; append under a dated heading in the file's existing style; never duplicate an item already listed). Label each as *carried* or *parked* so a carried item does not read as duplicate parking. BACKLOG.md is the durable record that survives the wipe — the pickup prompt is lossy by design and must never be an item's only record.
- **Objective filter:** classify each open item as serving the locked objective or not. Off-objective items are parked and **excluded from "What's next"** — at most a one-line "parked in BACKLOG.md" pointer. Finished-but-off-objective work is closed out, not promoted into the next thread as a live decision. When in doubt, park: a wrongly parked item costs one line to restore; a wrongly carried one derails the restart.
- **Form check on carried items.** An item phrased as a question, "needs Sean's input", "TBD", or "awaiting a decision" is a defect signal, not a normal item. Either build the concrete first-pass strawman **now** (and tell the next thread to apply or redline it rather than re-ask), or surface it in the prompt as `DECIDE OR KILL:`. Producing the strawman is the stronger answer nearly every time.
- An item carried across a previous reset gets stamped inline in the prompt text: `carried 2× since 2026-08-01`. No separate tracking file for this — the stamp is the mechanism.

## 5. Pickup prompt

Always produced — it is the point of the exercise. Nothing uncommitted and nothing to capture is still a hit: the run is just short.

Compact — sized for a fast re-read, not a report. 150–350 words is the target range — over range means reorder, deduplicate, or demote, never cut something load-bearing. Default to bullets. It carries only:

- What is being built (one sentence). If the session's scope file exists, its Objective line and unchecked Done-when boxes go here verbatim — the next thread gets a fresh scope file of its own, so the prompt is the only thing that carries the lock across.
- Where it stands, with the exact committed state (branch + SHA).
- The specific immediate next action — actionable, on-objective. "Continue the work" is a failure.
- Non-obvious context the codebase cannot supply: constraints, decisions, gotchas, conclusions already reached (say *don't re-derive X* — that carries the answer without the tokens that caused the reset).
- Anything a stopped agent left behind, named as **unverified**. Anything left running, with how to reuse it.
- `Working directory:` as an **absolute path** (`/Users/seansmith/Code/...`), not a tilde. If the session is in a worktree, this is the worktree's path, not the main tree's.
- **Worktree carry-forward.** Detect with `git rev-parse --git-dir` vs `git rev-parse --git-common-dir` — if they differ, the session is in a worktree. Get its name with `basename "$(git rev-parse --show-toplevel)"`. When in a worktree, name it inline in the block (e.g. `Worktree: <name>`) so the next thread has it as context. When not in a worktree, say nothing — no "not in a worktree" line.

Below the block, outside it, tell Sean to **quit this session before opening the new one** — a predecessor left running holds the tree's lock, so the zsh collision guard reads it as concurrent and strands the successor in a fresh throwaway worktree instead of continuing in this one. This does not conflict with keeping the block scrollable for re-copying: the clipboard copy below already carries the block past the quit, so nothing is lost by closing the tab. Relaunching via `cco pickup` (or `cco pickup <name>`) delivers this prompt automatically as the new thread's opening message — no manual paste needed. `cco`, and its shorthand `ccp` (= `cco pickup`), come from `shell/orchestrator.zsh` in this repo. Bare `cco` is the clean-slate path and will **not** deliver it. The inline block is the fallback for any other launch path (a fresh `claude`, a different machine, or the clipboard/pickup file being unavailable).

**Render it inline in the response, in a single fenced block, and put every heading, label and instruction to the user *outside* the fence.** Anything inside the fence gets pasted into the next thread; a stray `## Pickup prompt` heading or a slash command inside it lands as garbage there. That block is the primary deliverable — the user must be able to see it, scroll back, and re-copy it.

**Delimit the block.** Immediately after the opening fence, and again immediately before the closing fence, place a line of 60 `─` (U+2500) characters:

```
────────────────────────────────────────────────────────────
```

A full box would need every line padded to a fixed width, which breaks on long paths and wraps badly in narrow terminals — a bare rule is the ceiling. These delimiter lines are inside the fence and get pasted into the next thread along with everything else; that is intended, not noise, and they must not be stripped as cleanup.

**Lead the block with the wordmark below.** It is a marker, not content, and is exempt from the 150–350 word target the same way `/wrap`'s banner is exempt from its close-out's word target. Its first line *is* the top delimiter and its last line *is* the bottom delimiter — do not add a second top delimiter above it. Reproduce it exactly, including trailing spaces on the frame lines; they are load-bearing for alignment. It reads WRAP / CONT / INUE — CONTINUE deliberately breaks across two rows because the mark does what the skill does, so do not "fix" the break:

```
────────────────────────────────────────────────────────────
             ╭────────────────────────────────╮             
             │  __  __  ____      _    ____   │             
             │ | |  | ||  _ \    / \  |  _ \  │             
             │ | |/\| || |_) |  / _ \ | |_) | │             
             │ |  /\  ||  _ <  / ___ \|  __/  │             
             │ |_/  \_||_| \_\/_/   \_\_|     │             
             │   ____ ___  _   _ _____        │             
             │  / ___/ _ \| \ | |_   _|       │             
             │ | |  | | | |  \| | | |         │             
             │ | |__| |_| | |\  | | |         │             
             │  \____\___/|_| \_| |_|         │             
             │  ___ _   _ _   _ _____         │             
             │ |_ _| \ | | | | | ____|        │             
             │  | ||  \| | | | |  _|          │             
             │  | || |\  | |_| | |___         │             
             │ |___|_| \_|\___/|_____|        │             
             ╰────────────────────────────────╯             
────────────────────────────────────────────────────────────
```

**Order inside the fence is fixed:** opening fence → wordmark (whose first line is the top delimiter) → `Thread:` line (when present) → body → recap instruction (below) → bottom delimiter → closing fence.

**End the block with a recap gate, addressed to the next thread, not to Sean.** The last line inside the fence, before the bottom delimiter, instructs the next thread: reading files, grepping, checking git state, and pulling memory or scaffolding context is fine without asking — gather that first, since it's what makes the recap accurate instead of a guess. But before the first change — writing or editing a file, running a build or migration, dispatching a subagent that will change something, or any other irreversible or outward-facing action — state back in a few lines what it understands the objective to be and what it is about to do first, then wait for confirmation — not a full plan, an alignment check sized so Sean can confirm or correct in one reply. This is a gate the next thread waits on, not a recap it narrates while already working. It stays inside the fence, as the final line of the block, so it survives the paste — moving it outside the fence defeats the point.

**Thread name.** `jq -r '.name // empty' ~/.claude/sessions/$CLAUDE_PID.json 2>/dev/null`. This is a **shape heuristic, not a provenance field** — session files carry no field marking a name as user-set vs. auto-generated (checked against Claude Code 2.1.235: the only name-related keys present are `name` and `nameSince`), so do not go looking for one to "restore." Carry the name forward unless it matches the auto-generated-slug shape — lowercase alphanumeric words joined by dashes and ending in a dash plus digits, regex `^[a-z0-9]+(-[a-z0-9]+)*-[0-9]+$` (e.g. `code-55`, `agent-skills-12`). If it matches that shape, or the value is empty, or the file or `jq` is missing, skip in silence — an auto slug carries no signal and must never be surfaced as though it did. When a real name exists: put `Thread: <name>` as the line inside the block immediately following the top delimiter (see ordering above; prose, not a command), and below the block, outside it, give the working mechanism — `type /rename "<name>" in the new thread (or launch it as claude -n "<name>")`. `/rename` only fires as an entire message, so it cannot live in the paste.

**Worktree relaunch command.** When the session is in a worktree (detected above), give the exact relaunch command below the block, outside it, alongside the `/rename` guidance — it is an instruction to Sean about how to launch, not text for the next agent: `cco pickup` (or `cco pickup <name>` to skip straight to this entry). `cco pickup` restores the worktree + delivers the pickup prompt in one step, matched by the `worktree:`/`repo:`/`thread:` fields in the pickup file's frontmatter — no manual `cd` needed. Skip in silence when not in a worktree. Note for Sean: bare `cco` is the clean-slate path and will not deliver this prompt — `cco pickup` is required to resume.

**Clipboard** (convenience, best-effort, never a blocker):

```bash
cat <<'EOF' | pbcopy
[prompt content]
EOF
```

Unavailable (non-macOS, no clipboard)? One footnote in the status table. Not an error, not repeated in prose.

**Pickup file** (sibling to the clipboard step, same best-effort contract — the clipboard copy is the only carrier today, and anything copied over it before relaunch loses the handoff). Write frontmatter followed by the identical prompt body — no fence delimiters, no headings, no surrounding prose in the body, exactly what goes inside the fence — to disk so `cco pickup` can deliver it automatically on the next launch. The filename key is a lossy mangling of the toplevel path (every non-alphanumeric char becomes a dash) and cannot be reversed, so the frontmatter stores the real values directly — `path:` is the absolute toplevel, never derived from the key:

```bash
key="$(git rev-parse --show-toplevel | sed -E 's/[^a-zA-Z0-9]/-/g')"
mkdir -p "$HOME/.claude/pickup"

toplevel="$(git rev-parse --show-toplevel)"
git_dir="$(cd "$(git rev-parse --git-dir)" && pwd)"
git_common_dir="$(cd "$(git rev-parse --git-common-dir)" && pwd)"
if [[ "$git_dir" == "$git_common_dir" ]]; then
  worktree="main"
else
  worktree="$(basename "$toplevel")"
fi
repo="$(basename "$(dirname "$git_common_dir")")"
# thread: same shape heuristic as the Thread name section above — never a derived/auto slug.
thread="$(jq -r '.name // empty' ~/.claude/sessions/$CLAUDE_PID.json 2>/dev/null)"
if [[ "$thread" =~ ^[a-z0-9]+(-[a-z0-9]+)*-[0-9]+$ ]]; then
  thread=""
fi

{
  printf '%s\n' "---"
  printf 'thread: %s\n' "$thread"
  printf 'repo: %s\n' "$repo"
  printf 'worktree: %s\n' "$worktree"
  printf 'path: %s\n' "$toplevel"
  printf '%s\n' "---"
  cat <<'EOF'
[prompt content]
EOF
} > "$HOME/.claude/pickup/${key}.md"
```

Keyed on the repo's toplevel, so a worktree gets its own pickup file (its toplevel is itself). Fails silently, no retry — one footnote in the status table if it fails, never a blocker.

## 6. Output shape

A status table so the run can be confirmed at a glance, then the pickup prompt. Row vocabulary: Agents · Git · Scope audit · Capture · Backlog · Repo · Clipboard · Pickup · Thread.

**Omit any row that does not apply this run** — no `None running`, no `No change`, no empty Thread row. A row that says nothing is noise.

```
  ┌──────────┬──────────────────────────────────────────────┐
  │ Agents   │ 2 stopped — settings-form left it broken     │
  │ Git      │ 3 commits — pushed to origin (abc1234)       │
  │ Repo     │ main clean · session-2 clean, WIP pushed     │
  └──────────┴──────────────────────────────────────────────┘
```

When more than one working tree was involved, report repo state **location by location**. A single "all clean" row reads at a glance as "everything is fine" and hides the tree that is broken.

**Proportion is scored.** Outside the fenced prompt, the response is the table plus at most a couple of lines the table cannot carry. Do not re-narrate the table in prose. Do not add ASCII art, gift-box graphics, banners, or scissor rules — unrequested decoration is a defect in a flow whose entire purpose is saving tokens. When there is genuinely nothing to do, a long response is itself the failure.

Whole flow: a handful of exchanges. No new *tracking* files, no cleanup, no scope beyond the one continuing task — `BACKLOG.md` is the single sanctioned addition to the repo, and the pickup file under `~/.claude/pickup/` is a one-shot handoff carrier (consumed and renamed on delivery), not a tracking file.
