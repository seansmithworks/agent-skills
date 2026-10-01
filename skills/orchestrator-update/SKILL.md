---
name: orchestrator-update
description: Review and apply pending orchestrator config updates. Use when the user says "/orchestrator-update", "check pending updates", or on session start if the registry has pending entries. Surfaces improvements from `~/.claude/PENDING-UPDATES.md`, applies selected ones via subagents, and validates with the eval suite.
allowed-tools: Read, Write, Edit, Bash, Glob, Agent, Skill
version: 0.2.0
---

# /orchestrator-update

Manage the orchestrator's config evolution. Opt-in: nothing auto-applies.

## When to use

- You run `/orchestrator-update` explicitly
- Session-start check found entries in `~/.claude/PENDING-UPDATES.md` with `- **Status:** pending` and you want to review
- After any significant model or config change, to catch regressions early

## Workflow

### Step 1 — Load registry

Read `~/.claude/PENDING-UPDATES.md`. Parse the entries into a list. For each pending entry, capture: ID, title, change type, blast radius, expected eval delta, effort.

### Step 2 — Present options

Show a numbered list of pending entries with ID, title, change type, effort, and expected eval delta. Format:

```
Pending orchestrator updates (N):

1. UPD-001 (efficiency, ~30min) — MEMORY.md tier structure
   Expected: -300 tokens per session boot, no behavioral regression

2. UPD-002 (efficiency, ~15min) — ORCHESTRATOR.md rehydration short-circuit
   Expected: -2-3 min per boot on known projects, no token change

3. UPD-003 (quality, ~10min) — Fanout ceiling heuristic
   Expected: better behavior on 8+ unit tasks, no regression

Options:
- Pick one or more numbers to apply (e.g., "1" or "1,3")
- "prune" to dismiss stale entries (60+ days pending)
- "all" to apply all pending (not recommended without review)
- "cancel" to exit
```

### Step 3 — Baseline eval

Before applying anything:

- If `~/.claude/evals/` exists: run the tokenize script `python3 ~/.claude/evals/tokenize.py` — save output as baseline. This measures token counts for the auto-loaded context layers (global CLAUDE.md, global MEMORY.md, orchestrator-prompt.md, project CLAUDE.md). Then run the 8-test behavioral suite from `~/.claude/evals/orchestrator-smoke-test.md` (spawn a subagent that reads the config + predicts outcomes for all 8 tests) — save as baseline. Without a baseline there is no regression signal.
- If `~/.claude/evals/` does not exist: fall back. Baseline becomes `wc -c` on every file named in the selected entries' blast radius, taken now. The behavioral suite is skipped. The Step 7 report must say explicitly that the eval suite was unavailable and this fallback ran instead.

### Step 4 — Apply

For each selected entry:

- Dispatch a subagent with the entry's rationale, blast radius, and files to touch
- Subagent applies changes, returns a summary
- Do NOT parallelize multiple entries unless they touch disjoint files

### Step 5 — Post-apply eval

After all selected entries applied:

- If `~/.claude/evals/` exists: re-run `python3 ~/.claude/evals/tokenize.py` — save output as post-apply result. Re-run the 8-test behavioral suite from `~/.claude/evals/orchestrator-smoke-test.md` — save as post-apply result. Compare to baselines and produce a delta report. Format: `MEMORY.md: 1,652 → N tokens (±delta). Behavioral: N/8 PASS.` **If behavioral suite shows regressions:** surface them with HIGH visibility (e.g., `⚠ REGRESSION: Test 3 DESIGN.md awareness — was PASS, now FAIL`). Do NOT silently apply. The user retains override authority — if they confirm, proceed. If unconfirmed, hold and explain what regressed.
- If `~/.claude/evals/` does not exist: re-run `wc -c` on the same files from the Step 3 fallback baseline and produce a byte-delta report. State plainly that the behavioral suite was skipped and regressions cannot be detected this run.

### Step 6 — Update registry

For each applied entry:

- Change `- **Status:** pending` to `- **Status:** applied-YYYY-MM-DD`
- Append a `**Actual eval delta:** [numbers]` line
- If delta is worse than expected, add a `**Caveat:**` line
- If the entry's `Eval test to run:` names a test not yet in `~/.claude/evals/orchestrator-smoke-test.md`, write that test into the suite before marking the entry `applied-`

### Step 7 — Report to Sean

Summary:

- Which entries were applied
- Token delta actual vs expected
- Behavioral delta actual vs expected
- Any regressions (if any, flag prominently)
- Next suggested action

## Admission rule (for adding NEW entries to the registry)

When adding a new pending entry during a session:

1. It must tie to output quality OR token/context cost
2. It must specify an `Expected eval delta` in measurable terms
3. It must name the eval test that validates it, existing or to-be-added
4. If any of these is missing, it doesn't belong in the registry — file as a Linear issue instead

## Prune mode

`/orchestrator-update prune` reviews all entries with age >60 days:

- Shows title, age, why it hasn't been applied yet
- Offers to mark each as `dismissed-YYYY-MM-DD` with a short reason

## Constraints

- Never auto-apply entries. Always require explicit user selection.
- Run baseline and post-apply evals; without both there's no regression signal.
- Commit nothing on behalf of the user — this skill edits personal config files (`~/.claude/`). Manage its backup separately.

## Files touched

- Read: `~/.claude/PENDING-UPDATES.md`, `~/.claude/evals/*` (baseline + running evals)
- Write: `~/.claude/PENDING-UPDATES.md` (status updates), `~/.claude/evals/*-<date>-*.md` (new eval results)
- Edit via subagent dispatch: whichever files the selected entries name in their "Blast radius"
