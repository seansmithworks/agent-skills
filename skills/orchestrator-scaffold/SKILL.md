---
name: orchestrator-scaffold
description: Scaffold missing project files via three modes. Use when the user says "/orchestrator-scaffold", "scaffold this project", "set up agent files", "create grounding files", "add mission brand principles", or when Phase 1 boot check surfaces missing scaffolding. Three modes — default (auto-detect), lifecycle (v2.1 agent files), grounding (v2.2 mission/brand/principles interview).
allowed-tools: Read, Write, Edit, Bash, Glob, Agent, Skill
version: 0.3.0
---

# /orchestrator-scaffold — Project Scaffolding

Closes the gap between Phase 1 boot reporting what's missing and the scaffolding actually existing. Handles both scaffolding tiers: the v2.1 lifecycle agent files (six domain specialists) and the v2.2 grounding files (mission.md, brand.md, principles.md — the identity layer that survives compaction). A bare `/orchestrator-scaffold` reads SCAFFOLDING.md, checks what's actually on disk, and presents gaps. The two explicit modes (`lifecycle` and `grounding`) let you skip straight to a specific goal.

Sibling to `/orchestrator-update`, which handles config evolution. This skill handles initial setup and gap-filling, not config changes.

---

## Modes

### default — auto-detect what's missing

Triggered by: bare `/orchestrator-scaffold`

#### Steps

1. Read `~/.claude/projects/SCAFFOLDING.md` to find the project's recorded version.
2. Identify the current project from cwd — derive the project name from the directory name. Match against the registry table. If not found, treat as v0.
3. Derive the memory dir path: replace every non-alphanumeric character in the full path with `-`, prepend nothing. Example: `~/Code/my-app/` → `~/.claude/projects/-Users-yourname-Code-my-app/memory/`.
4. Run the presence check (see Detection Logic section):
   - Check project root for: `CLAUDE.md`, `DESIGN.md`, `mission.md`, `brand.md`, `principles.md`, `BACKLOG.md`
   - Check memory dir for: `agent-product.md`, `agent-experience.md`, `agent-craft.md`, `agent-build.md`, `agent-data.md`, `agent-quality.md`, `general-agent-context.md`

   `BACKLOG.md` doesn't gate version or need the interview: create an empty stub silently if missing, never overwrite an existing one. It starts with a bare top heading.

   **Scope files are never scaffolded.** Each session's scope lives at `~/.claude/scope/$CLAUDE_CODE_SESSION_ID.md`, written automatically at SessionStart by the `scope-init.sh` hook. Don't check for one, don't create one, don't report it as a gap.
5. Present gap report:

```
[Project Name] — [version in registry] recorded, checked on disk:

  Grounding files (v2.2):   ✓/✗ [mission.md, brand.md, principles.md status]
  Lifecycle agents (v2.1):  ✓/✗ [agent count / missing list]

  What do you want to scaffold?
  1. grounding — draft mission.md, brand.md, principles.md (interview flow, ~15 min)
  2. lifecycle — scaffold the 6 agent files (~5 min)
  3. both — grounding first, then lifecycle (grounding output feeds lifecycle)

  (skip with "cancel")
```

6. Wait for the user's selection, then run the corresponding mode.
7. If the project is not in SCAFFOLDING.md: treat as v0. Before doing anything, ask: "Is this an active project with continuity, or an experiment / scratch work? Grounding files only pay off on projects you'll be compacting for weeks." Wait for the user's answer before proceeding.

> **In "both" mode, run grounding first, then lifecycle.** Lifecycle agent files need mission.md to produce non-generic content.

---

### lifecycle — v2.1 agent files

Triggered by: `/orchestrator-scaffold lifecycle`

Mechanical scaffold of the six core lifecycle agent files using project-specific content from a codebase explore pass.

#### Steps

1. **Check for mission.md.** Look at project root and memory dir. If missing: halt with — _"Lifecycle agents need a mission to be useful. Run `/orchestrator-scaffold grounding` first, or tell me: what are you building and who is it for? I'll draft a mission.md from your answer."_ Do not proceed without a mission.

2. **Check for existing agent files.** If any of the six agent files already exist in the memory dir: read each one, report which exist, and ask — "These files already exist. Overwrite, skip individual files, or cancel?" Never overwrite without explicit confirmation.

3. **Check for legacy v1 files.** If `agent-frontend.md`, `agent-backend.md`, `agent-api.md`, `agent-design.md`, or `agent-mobile.md` exist in the memory dir: read each one and propose which of the six v2.1 roles (product, experience, craft, build, data, quality — see step 5 below) its content maps to, then wait for the user's confirmation before folding it in. Do not auto-rename or delete old files — surface the migration plan and wait for the user's go-ahead.

4. **Explore the codebase.** Dispatch an `explore` subagent to map the project:
   - File inventory with one-line purposes
   - Data flows and key abstractions
   - Conventions (naming, file organization, patterns)
   - Known fragile areas or coupling
   - Test structure and coverage patterns
   - Skip the explore pass if fewer than ~20 source files — use the user's description of the codebase instead.

5. **Dispatch 6 parallel `implementer` subagents**, one per role: product, experience, craft, build, data, quality. Each subagent receives:
   - mission.md content
   - Explore report scoped to its domain
   - Its role's scope: product (why/who/what to build), experience (UX/UI/interaction), craft (design tokens, visual system), build (architecture, code conventions), data (schema, storage, sync), quality (testing, review, release gates)
   - Target: 80–150 lines per file, mandatory Gotchas section, cross-references instead of duplicated content
   - No token tables outside agent-craft.md — build references craft

6. **Write `general-agent-context.md`** to the memory dir. This file covers architecture summary, build commands, conventions — context every subagent needs regardless of role.

7. **Write files to:** `~/.claude/projects/<path>/memory/agent-<role>.md`. Private memory only. No `--team` flag. No repo placement question.

8. **Update SCAFFOLDING.md.** Set version to v2.1 (or v2.2 if grounding files already present at project root). Update Last touch date.

9. **Present summary:**

   ```
   Lifecycle agent files created:
   - agent-product.md    (N lines)
   - agent-experience.md (N lines)
   - agent-craft.md      (N lines)
   - agent-build.md      (N lines)
   - agent-data.md       (N lines)
   - agent-quality.md    (N lines)
   - general-agent-context.md (N lines)

   [Any files that landed thin (< 60 lines): flag with reason]

   Memory dir: ~/.claude/projects/<path>/memory/
   Note: Agent files are outside the git repo — note their creation in ORCHESTRATOR.md.
   ```

---

### grounding — v2.2 mission/brand/principles

Triggered by: `/orchestrator-scaffold grounding`

Interview-driven flow. The three files capture the user's voice and product thinking — not boilerplate. Interview first, draft, confirm, then write. The sequence is one-file-at-a-time.

#### Steps

1. **Explain what the three files are** (say this once at the start, concisely):
   - mission.md — anchors every feature decision; read at every scope-creep fork
   - brand.md — governs every surface with a voice; microcopy, error messages, marketing
   - principles.md — always/never/when-in-doubt tiebreaker for subagents at decision forks

2. **Check for existing grounding files.** If mission.md, brand.md, or principles.md already exist at project root: read each one first. For each that exists, ask — "mission.md already exists. Do you want to (1) review and iterate on it, (2) replace from scratch, or (3) skip it?" Never overwrite without explicit per-file confirmation; do not start a file's interview until its overwrite question is answered.

3. **Run the interview file-by-file** (see Interview Flow section). For each file:
   a. Ask the interview questions for that file
   b. Draft the file from the user's answers
   c. Show the draft to Sean
   d. Iterate once if needed — one revision round, not a negotiation loop
   e. Confirm ("Does this look right? I'll write it to disk on your go-ahead.")
   f. **Wait for explicit confirmation before writing.** If the user abandons mid-interview, write nothing to disk.

4. **Write files to project root** (not the memory dir — grounding files travel with the code):
   - `<project-root>/mission.md`
   - `<project-root>/brand.md`
   - `<project-root>/principles.md`

5. **Update SCAFFOLDING.md.** Set version to v2.2 (if all three grounding files present + lifecycle agents present) or note partial grounding-only state. Update Last touch date.

6. **Present summary and commit reminder:**

   ```
   Grounding files written:
   - mission.md   (N words) — <project-root>/
   - brand.md     (N words) — <project-root>/
   - principles.md (N words) — <project-root>/

   COMMIT THESE FILES before switching branches or compacting this session.
   They are the identity layer — losing them to an uncommitted branch is a real risk.

   git add mission.md brand.md principles.md
   git commit -m "add v2.2 grounding layer (mission, brand, principles)"
   ```

> **Tone during interview:** Direct questions, not forms. Lead with moments and concrete examples — users think in situations and use-cases, not demographic segments or frameworks. Do not use jargon: "persona," "value proposition," "positioning statement," "north star metric."

---

## What a scaffolded project looks like

```
project-root/
  CLAUDE.md
  DESIGN.md          (UI projects)
  mission.md
  brand.md
  principles.md
  BACKLOG.md         (open/deferred items, resurfaces at wrap)

~/.claude/projects/<path>/memory/
  ORCHESTRATOR.md
  MEMORY.md
  agent-product.md
  agent-experience.md
  agent-craft.md
  agent-build.md
  agent-data.md
  agent-quality.md
  general-agent-context.md
```

Project-root files travel with the code and are committed. Memory-dir files are private, uncommitted, and grow over months (`ORCHESTRATOR.md`).

## Detection Logic

Source of truth for what should exist is SCAFFOLDING.md. Always verify on disk — the registry tells you what was intended; disk tells you what exists. Surface any drift explicitly, never silently.

```
read ~/.claude/projects/SCAFFOLDING.md
  → find row for current project by directory name
  → if not found: treat as v0

recorded_version = row["version"]  # e.g. "v2.2", "v2.1", "v0"

derive memory_dir:
  import re
  full_path = expand(cwd)           # e.g. /Users/yourname/Code/my-app
  slug = re.sub(r'[^A-Za-z0-9]', '-', full_path)  # -Users-yourname-Code-my-app
  memory_dir = "~/.claude/projects/" + slug + "/memory/"

check disk:
  lifecycle_present = all of [
    agent-product.md, agent-experience.md, agent-craft.md,
    agent-build.md, agent-data.md, agent-quality.md, general-agent-context.md
  ] exist in memory_dir

  grounding_present = all of [mission.md, brand.md, principles.md]
    exist at project root

derive target_state:
  if grounding_present and lifecycle_present:   → v2.2 (complete)
  elif lifecycle_present only:                  → v2.1
  elif grounding_present only:                  → v2.2 (partial — grounding without agents)
  elif mission.md only (no agents):             → v2-stub
  else:                                         → v0

gaps = what's missing vs. v2.2:
  - v2.2 target: needs both lifecycle + grounding
  - v2.1 target: needs lifecycle files only
  - v2-stub:    mission.md exists, agents missing → suggest lifecycle mode
  - v0:         nothing → either mode or both

tiered surfacing (match Phase 1 boot rules):
  0 gaps and recorded_version == v2.2 → report "already at v2.2 — nothing to do"
  1 gap    → single-line note, offer to fix
  2+ gaps  → explicit advisory with mode recommendation

if recorded_version and disk_version differ → surface drift explicitly:
  "Registry shows v2.1 but I only found N of 6 agent files on disk. Proceeding based on what's on disk."
```

---

## Interview Flow (grounding mode)

One file at a time. Questions feel like a conversation, not a form. After each file's questions, draft and confirm before moving to the next file.

### mission.md — 4-5 questions

Quality bar: specific enough to be a filter, honest about what it's not, short enough to be read at every scope fork. Target: 175–250 words, 5 sections (why, who, promise, anti-goals, how to apply). Closing "How to apply" section is MANDATORY — without it the file is documentation, not a decision tool.

Questions to ask (in order, conversationally):

1. "Who opens this — what's the situation they're in when they reach for it?" Push toward a moment, not a demographic. "A developer who's been procrastinating for an hour" beats "25–40-year-old knowledge worker."
2. "What's the one thing it does that makes the difference?" Looking for the core mechanism, not the category.
3. "What would someone say or do differently after using this for a month — in concrete terms?" Measurable outcome, not feature coverage.
4. "What is this definitely not — what have you already ruled out?" Anti-goals are often more useful than goals.
5. "Where is it right now — exploring, building, shipping, or maintaining?" Stage shapes what agent files prioritize.

### brand.md — 5-6 questions

Quality bar: concrete enough to govern a single line of microcopy. Target: 250–350 words, covers voice + character + tone per state + what it's not + how to apply. "How to apply" section is MANDATORY.

Questions to ask:

1. "If this product were a person, what's the one-sentence personality — and what are they definitely not?" The barista framing in Brukas came from exactly this kind of question.
2. "Give me a line it would say in its best moment, and a line it would never say." Concrete examples beat adjective lists.
3. "What's the tone at the emptiest, most inviting moment — before the user has done anything?" Empty states reveal personality more than any other surface.
4. "What's the tone when something goes wrong — error, couldn't connect, failure?" Error tone reveals how the product treats people under pressure.
5. "What's the single biggest thing this product should never sound like?" Anti-tones — the "no" is usually sharper than the "yes."
6. (Optional) "Are there surfaces where the tone shifts significantly — like active use vs. setup?" Brukas example: "Timer running → gone. The app recedes."

### principles.md — 5-6 questions

Quality bar: structured as Always/Never/When-in-doubt, actionable enough that a subagent reading it knows which of two valid paths to take. Target: 275–375 words. "How to apply" section is MANDATORY.

Questions to ask:

1. "What are 2-3 things this product always does — non-negotiable, even when it's inconvenient?" System dark mode, touch targets, no guilt for missed sessions — constraints that stay even when skipping would be faster.
2. "What has it never done and must never do — even if a user asks?" Streaks, leaderboards, social features — you probably have strong opinions here.
3. "When a subagent has two valid paths and no obvious winner — what's the tiebreaker?" The "when in doubt" rules. Brukas: "less UI. Defer to iOS muscle memory. Slower is wrong."
4. "Is there a specific technical or UX decision that's been made and should never be reopened?" Named-and-closed decisions prevent zombie debates.
5. "Are there any a11y or platform-native behaviors that are non-negotiable?" Honor Dynamic Type, 44pt minimums — these don't make it into principles without being said explicitly.
6. (Optional) "Is there anything the product did in a past version that you've removed and want to keep removed?" Good for projects with history. Prevents regression of deliberate cuts.

---

## File Templates

- **mission.md:** ~200 words, sections: why / who / promise / anti-goals / how to apply
- **brand.md:** ~300 words, sections: voice / character / tone calibration per state / what it's not / how to apply
- **principles.md:** ~330 words, sections: always / never / when in doubt / how to apply

Each file closes with a "How to apply" section that tells a subagent when to pull this file in. Files without this section are documentation, not decision tools.

For lifecycle agent files: use the six role scopes and 80–150 line target given in the lifecycle mode's step 5 above as the structural template.

---

## Behavior Choices

Three tunable decisions deferred to first-run. Sensible defaults are below — refine after real use.

**Quick interview mode:** NOT included. Full interview only (4-6 questions per file). If you want a "quick" mode (2-3 questions, shorter drafts) for early-stage projects, add it on request. The full interview is the right investment for any project you'll be compacting for weeks.

**Refresh granularity:** Full-file refresh only. When a file already exists and you want to update it, the skill re-runs the full interview for that file and produces a new draft. Section-level edits (e.g., "just update the anti-goals section") are handled via direct user request, not via this skill. Simpler to implement; edge cases for partial rewrites are subtle.

**Commit reminder:** Prominent reminder in output, but no hard stop. The skill ends with an explicit "commit these N files when ready" block with copy-pasteable git commands. Does not gate on confirmation that Sean will commit — that would be annoying for experienced sessions. The reminder is the responsibility transfer.

---

## Edge Cases

**Project not in SCAFFOLDING.md:** Treat as v0. Ask before doing anything: "Is this an active project with weeks of continuity, or an experiment / scratch work? Grounding files only pay off when you're compacting sessions and relying on subagents for judgment calls over time." For confirmed experiments, offer only lifecycle scaffolding (lower overhead, useful short-term) or exit cleanly. Do not silently scaffold without this pre-flight question.

**Project already at target version (idempotency):** Report "already at v2.2 — nothing to generate." Offer: "Want to refresh a specific file? (mission / brand / principles / agent-[role])" — re-runs the interview for that file alone, overwrites with confirmation.

**User abandons interview mid-flow:** write nothing to disk; nothing lands until the user confirms each file's draft. If the user says "pause" or "save where we are," write a `draft-<filename>.md` in the project root clearly labeled `DRAFT — NOT FINAL`, only if explicitly asked.

**Files already exist with content:** read first, then ask per file before overwriting. The question: "mission.md already exists — review and iterate, replace from scratch, or skip?" Applies to all three grounding files and all six lifecycle agent files.

**Project at v0, scratch, or \_experiments/:** ask before doing anything. "This looks like a new or experimental project. Grounding files are designed for projects with at least a few weeks of continuity. Worth it here, or skip?" For confirmed experiments, offer lifecycle-only scaffolding (useful even short-term) or exit cleanly.

**Legacy v1 projects (old-style agent files present):** Detect ad-hoc filenames: `agent-frontend.md`, `agent-backend.md`, `agent-api.md`, `agent-design.md`, `agent-mobile.md`, `agent-testing.md`, `agent-qa.md`. Read each and propose which v2.1 role it maps to (per the mapping step in lifecycle mode, step 3) before generating new lifecycle files. Do NOT auto-rename or delete old files — surface the migration plan and wait for the user's go-ahead. Never silently remove v1 files.

**Git repo not detected at project root:** Note that grounding files will be written but are not yet tracked by git. Tell Sean: "No .git found — these files won't be version-controlled until you initialize a repo or move them into one."

---

## After Completion

The skill handles these steps before closing:

1. **Update SCAFFOLDING.md** with the new version, scaffolding pattern, agents present, and today's date. Match the existing table shape exactly — no new columns, no format drift.

2. **Print a summary** of what was created: file paths, line/word counts, any files that landed thin with a note on why.

3. **Commit reminder block** — explicit, copy-pasteable:
   - Grounding files: `git add mission.md brand.md principles.md && git commit -m "add v2.2 grounding layer"`
   - Lifecycle files: note that the memory dir is outside the git repo for solo projects; suggest noting creation in ORCHESTRATOR.md instead.

4. **Suggest re-running orchestrator boot** to confirm Phase 1 check now passes: "Run the boot check — Phase 1 should now report 0 missing files for [version]."

---

## Notes on Path Derivation

The memory dir path formula: take the absolute path (e.g., `/Users/yourname/Code/my-app`), replace every non-alphanumeric character with `-`. Do NOT strip the leading `/` — it becomes the leading `-`. Result: `-Users-yourname-Code-my-app`. Memory dir: `~/.claude/projects/-Users-yourname-Code-my-app/memory/`.

**Verify before writing.** Always run `ls ~/.claude/projects/ | grep <project-name-fragment>` before writing to confirm the actual dir name on disk. Path derivation is deterministic but dirs created by different Claude Code versions may have edge-case variants. Disk is truth; derivation is a starting guess.

**SCAFFOLDING.md lives at** `~/.claude/projects/SCAFFOLDING.md` — one level above any project memory dir, not inside one. Read it from this fixed path regardless of cwd.
