---
name: wrap
description: End-of-session close-out — secure uncommitted work, run the scope audit, put every open item in a durable home, refresh shared project state, and report honestly what was captured and what was skipped. Use when Sean is done for the day or longer ("wrap", "wrap it up", "done for now", "that's it for today", "end session", /wrap), including when the session contained almost nothing — it then correctly does almost nothing rather than not running. Retrospective only — never emits a resume/pickup prompt. Do NOT use for mid-task context recycling where the same work continues in a fresh thread (that is /wrap-continue), for answering questions about what wrapping does, or when a single narrower capture was asked for (just commit this, save one note).
license: MIT
metadata:
  version: 1.0.0
  category: workflow
  domain: session-management
---

# Wrap

Close out a session so nothing valuable dies with it, and so the last thing Sean reads is true.

**Route first.** Stopping → wrap. Continuing the same work in a fresh thread → `/wrap-continue`, stop here. The signal is stopping vs. continuing, not how much context was burned.

---

## Hard rules

These are the failure modes. Everything else is judgment.

1. **Freeze, then re-check.** Before anything is captured or claimed, stop background agents and background shells this session started (`TaskStop`; `TaskList` to find them). Leave dev servers and anything Sean wants running up — record port and PID so tomorrow doesn't start a second one. Then re-run `git status` in *every* worktree those processes touched. A killed process routinely leaves half-written files; that work is either committed on a clearly-labelled branch or named in the close-out as unverified. Never silent.

2. **Push is the default.** Commit freely — commits are cheap and reversible. Decide, never ask:

   | Case | Action |
   |---|---|
   | Nothing to push | say nothing at all |
   | Remote named `upstream`, or `main`/`master`/`develop` on a remote other than the user's own default | skip, one-line note: `Push skipped — upstream/protected remote, push manually if intended` |
   | Everything else — including `main` when it tracks `origin`, and deploy/staging remotes pushed to routinely | push |

   Refusing an `origin` push on your own safety reasoning is a failure, not caution. The narrow skips exist for one reason: never create an outward-facing effect resembling an upstream contribution (prior Ghostty incident — an unintended PR opened upstream). Never force-push unless asked for by name.

   Same asked-not-assumed posture as before for anything else irreversible or subjective — deleting entries, promoting a parked idea into active work, changing someone else's branch. One decision at a time, each with enough context to answer; not one batched "cut all eight?".

3. **Verify delegated work against the filesystem, not against the report.** Only applies if this thread delegated. A subagent's "done" is a claim: check that the file exists, the commit landed, the scope was met. A gap is either closed now or written into the durable open-item records — never softened, never reported resolved. This check runs *before* anything downstream is written on the strength of it.

4. **Dependency order.** freeze → verify delegations → commit code → tickets → scope audit → reconcile open items → learnings → shared state → session record → docs commit → push. Artifacts cite identifiers that already exist. A session note cannot cite the SHA of the commit that contains it. Reconcile the backlog before writing shared state, so the two records don't contradict each other about what's open.

5. **One home per fact.** A learning lives in exactly one durable file and is referenced elsewhere by name — never restated in full inside `ORCHESTRATOR.md`, a session note, and a memory file. Same for the session's narrative: one long-term store, not two.

6. **Never invent.** If it isn't observable in the repo, the files, or this thread, you don't know it. No inferred prior incidents, no assumed delegation outcomes, no reconstructed history to make a sentence land harder.

7. **Retrospective only — no pickup prompt.** No "next session starts here", "picks up at", "next step is to…". Naming an item as open is required; instructions for resuming it belong to `/wrap-continue`. Asking Sean for a decision is not a pickup prompt and is welcome.

---

## Where things go

Match what's already in each file: edit the existing entry rather than appending a second one, keep its headings and schema, don't invent new sections to hold your output.

| Content | Home |
|---|---|
| Open / deferred / unfinished items | project-root `BACKLOG.md` (create if absent) |
| Scope card's unchecked Done-when boxes and "Noticed, not pursued" entries | fold into `BACKLOG.md`, then stamp the scope card closed (see step 4). The scope card is `~/.claude/scope/$CLAUDE_CODE_SESSION_ID.md` — one per session, never reused |
| Current project state and pointers to it | `.claude/projects/<escaped-path>/memory/ORCHESTRATOR.md` — state and links only, never the durable fact itself |
| Durable decisions, learnings, corrections, gotchas, in-flight-work detail | a named file in the same `memory/` dir (`agent-*.md`, `reference_*`, `feedback_*`), indexed in its `MEMORY.md`, linked from `ORCHESTRATOR.md` by `[[wikilink]]` |
| Superseded `ORCHESTRATOR.md` content (prior PICKUP block, closed items) | `.claude/projects/<escaped-path>/memory/ORCHESTRATOR-log.md` |
| Cross-project status | `~/.claude/projects/project-facts.md` — edit the existing block; new blocks follow the schema at the top of that file, including default flags (a freshly shipped milestone is `promoted: no`) |
| Deferred-intent log | `~/.claude/projects/<escaped-path>/memory/tease-capture.md` — its own 30-day prune rule is documented inside it |
| Session narrative | the repo's existing notes location for code projects, **or** the project's Second Brain thread for cross-domain/life projects — one, never both |
| Tickets | Linear via `mcp__claude_ai_Linear__save_issue` (the exact tool ID depends on what you named your Linear MCP server), if the project tracks tickets |

Session-scoped facts never enter a cross-session file at all — not `ORCHESTRATOR.md`, not a memory file. Test before writing a line into either: would a fresh thread that never reads this line do something wrong because of it? A PID, a port, "the MCP was down this session" — none of these are evaluable later, so none of them get written, even as a status update.

Stage by explicit path. `git add -A` sweeps another session's edits when two threads share a tree.

---

## The pass

The session record and close-out below both target 150–350 words with the structure rules given in each section.

Run what the session earned. Steps 0 and 4 are the load-bearing ones.

0. **Freeze.** Rule 1. One line if nothing was running.
1. **Verify delegations.** Rule 3. Nothing to do if this thread delegated nothing — say that rather than omitting it.
2. **Commit code.** If the tree is clean or the diff is noise, skip and say so.
3. **Tickets.** Only if tracked tickets moved. Link the real SHAs from step 2.
3a. **Scope audit.** Runs once per session, here, after the commit so the diff is complete and before reconciling, because dropouts feed it. Run `python3 ~/.claude/hooks/scope-check.py wrap "$CLAUDE_CODE_SESSION_ID"` (~20s, Haiku, always exits 0) and act on each line:
   - `DROPOUT — …`: an ask Sean made with no matching change. Show it was actually done (evidence), or append it to `BACKLOG.md` like any other open item. Never silently drop it.
   - `DRIFT — …`: state it in one line in the close-out, without re-litigating it.
   - `CLEAN`, `NO SCOPE CARD`, `NO ASKS`: no action; one line in the close-out.
   - `AUDIT FAILED: …`: say so in the close-out and carry on.
4. **Reconcile open items.** If the scope card (`~/.claude/scope/$CLAUDE_CODE_SESSION_ID.md`) exists, state its locked Objective (the `│ Objective:` line, inside the frame) and a verdict (met, partly met, or not met) before folding anything into `BACKLOG.md`; if the thread's actual work diverged from that Objective, say so plainly rather than reporting success against a substituted goal. An Objective still reading `unset` is itself the finding — report it as unlocked rather than substituting what the thread happened to do. Walk the thread's task list item by item: finished → marked finished, not carried forward as noise; still open → into `BACKLOG.md`, no duplicate of an item already there. Fold the scope card's unchecked Done-when boxes and Noticed-not-pursued entries into `BACKLOG.md` the same way. **This runs whether or not the session produced any learnings** — it is not gated on step 5. It is the mechanism that makes "deferred is not dropped" true.

   Then, once the fold is done, stamp the scope card closed: tick any Done-when box that was actually met this session (leave genuinely unmet ones unticked — they're the honest record, already folded into `BACKLOG.md`), refresh `Updated:` to today (preserving its `│ ` rail), and add a `Closed: <date> — wrapped, open items in BACKLOG.md` line inside the frame, same `│ ` rail and label alignment as the other fields. Fold first, stamp second — stamping first risks marking closed something that never landed. If the scope card doesn't exist, say nothing and don't create one.
5. **Learnings.** Only non-obvious ones — corrections, decisions, conventions, gotchas that cost real time. Nothing re-derivable from the code or the git log. Write once, index it. A learning about tooling or Claude config, rather than this project, routes to `~/.claude/PENDING-UPDATES.md` when it satisfies that registry's admission rule (`skills/orchestrator-update/SKILL.md`).
6. **Deferred-intent review.** Show what has accumulated in `tease-capture.md` since it was last reviewed, with each entry's age. Only raise archiving for entries 6+ months old (name them) — archiving means moving them to `tease-capture-log.md`, never deleting. Don't ask about entries younger than 6 months; that silence is the rule. Separately, offer promoting any entry that is a genuine actionable spike, at any age, one at a time. Nothing archived or promoted automatically. Skip if empty or already reviewed.
7. **Shared state.** Where the project has `ORCHESTRATOR.md`, updating it is **mandatory** if *any* of these are true: a subagent was delegated (success or failure), an architectural decision was made, in-flight work was added or completed, step 1 deferred a gap, the session produced commits, or project state changed in a way another thread would need. Skippable only when the file doesn't exist, or when *none* of those hold. Being an implementation thread rather than the orchestrator is not an excuse; neither is a clean ending.

   The update is not complete until something has been evicted, or you've confirmed nothing is stale and said so. Eviction, not addition, is the point of touching this file:
   - **PICKUP holds one block — the current one.** Writing a new block means the prior block moves to `ORCHESTRATOR-log.md` in the same edit, not alongside it.
   - **In-Flight holds genuinely open work only,** each item compressed to status + next action + pointer — not restated prose.
   - **Fragile Areas is the target shape for anything trap-like:** one line, a `[[wikilink]]` to the file that owns the full text, nothing restated in `ORCHESTRATOR.md` itself.
   - **Durable traps route to the file that owns them, never to `-log.md`.** Archiving a permanently-true fact is how it stops protecting anyone; `-log.md` is for what has actually closed or been superseded, not for things that are still true but merely old.
8. **Session record.** Ties the session to its real artifacts: commits made, tickets touched, memory files saved, gaps deferred and where they went. Skip for a session that produced none of those — an empty note committed to look thorough is worse than no note.
9. **Docs commit.** Everything steps 4–8 wrote gets its own commit, separate from the code commit, so documentation and code history stay distinguishable. Then push (rule 2). Documentation left uncommitted is the wrap failing at its own job.

---

## Flagging open items

- An item carrying only a question, "needs input", "TBD", or a phase label — no concrete proposal to react to — gets flagged inline **decide or kill**, with a strawman attached when you can form one. A passive placeholder is how requested work silently becomes never-done.
- An item that has been carried before gets `(carried N×)` where N is the true count read from the record and incremented by one — not restated, not reset, not guessed.

## Size ceilings

Files that load automatically into every future session (`MEMORY.md`, `ORCHESTRATOR.md`, `CLAUDE.md`) are measured with `wc -c` — never in lines. A line count hides real growth here: these files are written in paragraphs, so a file that blows the char cap 5x over can still read as "a few hundred lines." `MEMORY.md` and `CLAUDE.md` size per `~/.claude/CONTEXT-RIGHTSIZING.md`. `ORCHESTRATOR.md` targets **10,000–15,000 characters, hard max 20,000**, sub-allocated by section so no single section absorbs the whole range:

| Section | Budget |
|---|---|
| Header / frontmatter | ~800 |
| Architecture Summary + Active Conventions + Fragile Areas + Relevant Paths | ~5,500 |
| Decision Log (3 entries, ≤1,300 chars each) | ~4,000 |
| In-Flight Work (live items only) | ~4,500 |

Keeping one current means cutting what has gone stale, not only appending what is new. If one is over its cap (or `ORCHESTRATOR.md` is over its target range), say so in the close-out and offer a specific prune naming the sections — never delete on your own authority. Leaving an oversized always-read file unmentioned is a miss.

## Proportion

- **Nothing happened** — a line or two, maybe a single saved note. The flow still ran; it just found nothing. Do not manufacture capture to fill it.
- **In a hurry** — secure the code, name what's open, stop. Then say which steps you skipped for time.
- **Big session** — run the steps its content triggered, not all of them by default.

A skipped step is a correct outcome. A skipped step that vanishes from the close-out is not.

---

## The close-out

```
                                               _____
                                              |     |
  ╭───────────────────────────────────────────[_____]───────────────────────────────────────────╮
  │                             ┌────────────────────────────────────────────────────────────┐  │
  │                             │                                                            │  │
  │   · · · · · · · · · · · ·   │                                                            │  │
  │   · · · · · · · · · · · ·   │               ________ ______ _______ ______               │  │
  │  · ◉ ◉ ◉ ◉ ◉ ◉ ◉ ◉ ◉ ◉ ◉ ·  │              |  |  |  |   __ \   _   |   __ \              │  │
  │  ·◉ ○ ○ ○ ○ ○ ○ ○ ○ ○ ○ ◉·  │              |  |  |  |      <       |    __/              │  │
  │  ·◉ ○ ○ ○ ○ ○ ○ ○ ○ ○ ○ ◉·  │              |________|___|__|___|___|___|                 │  │
  │  ·◉ ○ ○ ○ ○ ○ ○ ○ ○ ○ ○ ◉·  │                                                            │  │
  │  ·◉ ○ ○ ○ ○ ○ ○ ○ ○ ○ ○ ◉·  │                      _______ _______                       │  │
  │  ·◉ ○ ○ ○ ○ ○ ● ○ ○ ○ ○ ◉·  │                     |_     _|_     _|                      │  │
  │  ·◉ ○ ○ ○ ○ ○ ○ ○ ○ ○ ○ ◉·  │                      _|   |_  |   |                        │  │
  │  ·◉ ○ ○ ○ ○ ○ ○ ○ ○ ○ ○ ◉·  │                     |_______| |___|                        │  │
  │  ·◉ ○ ○ ○ ○ ○ ○ ○ ○ ○ ○ ◉·  │                                                            │  │
  │  ·◉ ○ ○ ○ ○ ○ ○ ○ ○ ○ ○ ◉·  │                       _______ ______                       │  │
  │  · ◉ ◉ ◉ ◉ ◉ ◉ ◉ ◉ ◉ ◉ ◉ ·  │                      |   |   |   __ \                      │  │
  │   · · · · · · · · · · · ·   │                      |   |   |    __/                      │  │
  │   · · · · · · · · · · · ·   │                      |_______|___|                         │  │
  │                             │                                                            │  │
  │                             │                                                            │  │
  │                             └────────────────────────────────────────────────────────────┘  │
  ╰─────────────────────────────────────────────────────────────────────────────────────────────╯
```

Default to bullets, not paragraphs. **The banner above always leads the close-out** — it is a marker, not content, and does not count against the word target below. **No boxed status table, no per-step checklist** — those restate the close-out itself, and that repetition costs the read. Length scales with the session: two to five lines when little happened; for a heavy session, a short labelled list, one line per area, ~15 lines at the outside. 150–350 words is the target range — over range means reorder, deduplicate, or demote, never cut something load-bearing.

Lead with the thing Sean most needs to know — a gap, a broken state, a decision waiting on him — not a chronology.

Cover, in whatever form fits:

- commits, with SHAs, and whether they landed on origin or were skipped (and why)
- anything left running or left broken, stated plainly (a branch that doesn't compile says so here, not only three files deep)
- where each open item landed
- `Scope audit:` the audit's result, one line
- what was skipped, and why
- what needs his decision

Every claim is something you checked *this turn*. "Unverified" is a perfectly good word. "Clean tree" is a claim — re-check it after your last write, or don't make it.

Shape, for a light session:

> Two commits, pushed to origin — `<sha>` (the fix) and `<sha>` (docs).
> Nothing was running. The one unresolved question went to `BACKLOG.md`, flagged decide-or-kill.
> Skipped notes, memory and the idea log — nothing new to put in them.
