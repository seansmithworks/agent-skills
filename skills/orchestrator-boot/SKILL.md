---
name: orchestrator-boot
description: DEPRECATED, do not invoke. State now arrives automatically via the state-inject.sh SessionStart hook; pending-updates and scaffolding checks live in /catching-up. Kept only until the cleanup lane deletes it.
---

# Orchestrator Boot

Session-start sequence for an orchestrator thread. Run once, at first activation.

## 1. Task assignment

If the `TASK_FILE` env var points at a task file, read it. It is markdown with YAML frontmatter (title, status, goal, notes). Treat it as this session's work order: present the title and goal in one line, then continue through the steps below with that as the focus.

## 2. Pending updates

**Never read `PENDING-UPDATES.md` in full at boot** — it is ~4.6k chars to produce a number. Count with grep:

```bash
grep -ci '^- \*\*Status:\*\* *pending$' ~/.claude/PENDING-UPDATES.md
```

Surface only — apply nothing. Read the file itself only when the count is non-zero AND Sean wants to act on it.

- 0 → silent
- 1–2 → one line: "Orchestrator has N pending updates."
- 3–4 → same, plus "Run `/orchestrator-update` to review."
- 5+ → "Orchestrator has N pending updates. Backlog is building — recommend `/orchestrator-update` this session."

## 3. Project scaffolding

**Never read `SCAFFOLDING.md` in full at boot** — it is ~10k chars and you need one row. `ls` the project root, then grep only this project's row:

```bash
grep -i '<project-name>' ~/.claude/projects/SCAFFOLDING.md
```

Check for `CLAUDE.md` (required); `DESIGN.md` (required when `*.tsx`, `*.jsx`, `*.swift`, `*.html`, or `apps/*` are present); and the v2.2 grounding set `mission.md`, `brand.md`, `principles.md`. A project absent from the registry is v0 — stay silent unless `DESIGN.md` is missing on a UI project.

- 0 missing → silent
- 1 missing → one line naming the file and why it matters
- 2+ missing, or `DESIGN.md` missing on a UI project → name the inferred version and the gap, and point at `/orchestrator-scaffold`

## 4. Read existing context

**First, read this session's scope file at `~/.claude/scope/$CLAUDE_CODE_SESSION_ID.md`.** It is written automatically at SessionStart by the `scope-init.sh` hook, so it is normally present; if it is absent, say nothing and do not create one. Surface the Objective line and any unchecked Done-when boxes as part of step 7.

**If `Objective:` reads `unset`, fill it in.** The line carries a `│ ` rail prefix (`│ Objective:  unset …`) — match on it and preserve the rail when rewriting. Boot is where the thread's objective becomes known, so boot is what writes it — a scope file left at `unset` records nothing and guards nothing. Replace the `unset` text with the objective in one sentence, and replace the `- [ ] unset` placeholder under `## Done when` with the observable conditions that would make this thread finished. If the objective genuinely is not yet known at boot, leave it and say so in step 7 rather than inventing one.

**Rehydration short-circuit — check this BEFORE reading anything.** The point of the short-circuit is to avoid expensive work; do not pay a large read to evaluate it.

```bash
F=<memory-dir>/ORCHESTRATOR.md
[ -f "$F" ] && find "$F" -mtime -7 | grep -q . && grep -qi 'architecture summary' "$F" && echo SHORTCIRCUIT
```

If `SHORTCIRCUIT`: read `ORCHESTRATOR.md` and `MEMORY.md` only, then go straight to step 7. Skip steps 5 and 6.

Otherwise read the fuller set: `MEMORY.md`, `mission.md`, all `agent-*.md`, `general-agent-context.md`, `ORCHESTRATOR.md`.

**Never read at boot in either case:** `ORCHESTRATOR-log.md` (decision-log archive), `INDEX.md`, `tease-capture.md`, `tier_overrides.md`, or any `ORCHESTRATOR-*.md` sibling. These are on-demand.

**If `ORCHESTRATOR.md` exceeds 15,000 chars, say so in step 7** — it has drifted past its 10,000–15,000-char target range (20,000 hard max) and needs a prune. Measure with `wc -c`, never in lines: the lines are paragraphs, so a line count hides real growth.

## 5. Scaffold if bare

If no agent files exist: ask "What are you building and who is it for?" → write `mission.md`. Copy the matching `DESIGN.md` template for UI projects. Map the codebase with parallel `explore` agents. Scaffold agent files by lifecycle role — product, experience, craft, build, data, quality as the core set; marketing, content, growth, finance, support, ops added as those stages activate.

## 6. Build the mental model

Architecture (layers, data flow, key abstractions) · conventions · fragile areas and known coupling · test coverage and patterns · build and deploy pipeline.

## 7. Present

Present the state in one screen. If the session already has an objective (a task file, a pickup body, or the first message), begin it without waiting for a confirmation.
