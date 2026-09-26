# Backlog

Open items for the skills repo. Greppable, no ticket overhead.

## 2026-08-27 (thread "MD Probe") — config-evolution loop, planned and gated

Plan plus the unedited refutation live at `~/.claude/plans/config-evolution/`
(`draft-plan.md`, `refutation.md`). Verdict was **revise**; the revised order is below.
Nothing has been built yet.

- [x] **Fix the pending-updates counter.** Done, `b2cda14`. Reader (`orchestrator-boot/SKILL.md:19`),
  writer instruction (`orchestrator-update/SKILL.md:15,73`), and `templates/orchestrator-prompt.md:13`
  now all use the registry's real `- **Status:** pending` format. Verified by execution: synthetic
  pending entry → 1, real registry (3 applied entries) → 0.
- [ ] ~~Fix the pending-updates counter (do this FIRST, everything else is downstream).~~
  `skills/orchestrator-boot/SKILL.md:19` counts with `grep -c 'status: pending'`, but the registry
  and `templates/PENDING-UPDATES.md:28` both write `- **Status:** pending`. Case-sensitive substring
  mismatch, so the counter returns 0 for a correctly-formatted entry and boot has been silent since
  April. Verified by execution, not by reading. Fix the reader AND
  `skills/orchestrator-update/SKILL.md:73`, which instructs the applier to write the non-matching
  format, in the same commit so reader and writer agree. Verify against a synthetic pending entry.
- [ ] **Re-baseline the claude-config versioning gap against a real `git status`.**
  `~/.claude` shows ~399 dirty lines: 72 modified, 12 deleted, 314 untracked. The load-bearing ones
  are `agents/explore.md`, `agents/implementer.md`, `agents/planner.md` (the tier-routing files
  global CLAUDE.md calls load-bearing), uncommitted since `c94f929`, 2026-07-06; plus a deleted
  `policy-limits.json` and a deleted Annotie memory tree. Commit by explicit path.
  **Pushing `~/.claude` is reserved for Sean** (`ORCHESTRATOR.md:35`).
- [x] **Admission path resolved: KILLED, no fourth path needed.** Done, `f966aec`. The premise was
  wrong. `Discovered:` records provenance, not validation; the field that matters is `Eval test to
  run:`, and 2 of 3 live entries already name *prospective* tests — UPD-003 literally says "add a 9th
  test prompt to the suite," which IS the proposed fourth path, shipped in April. Field 3 was always
  satisfiable by a wrap. The separate-staging-list alternative is also killed: `pending` already means
  "recorded, not yet validated," and a second staging concept is redundant. Field 3 reworded to
  "name the eval test that validates it, existing or to-be-added" — clarifying de facto practice,
  not widening the rule. The wrap rule is unblocked.
- [ ] ~~Resolve the admission path before writing any wrap rule.~~ DECIDE OR KILL. All three
  registry entries record `Discovered: from post-slim behavioral eval` and each names a test that was
  already run, so field 3 of the admission rule (`skills/orchestrator-update/SKILL.md:93`) is
  retrospectively unproducible by a wrap that ran no eval. Strawman: admit a fourth path, "names the
  eval test that would need to be added." Alternative: entries stage in a separate list, not the
  registry itself.
- [x] **The wire, last.** Done, `f4a269a`. One sentence added to `skills/wrap/SKILL.md` step 5
  (Learnings) routing tooling/config learnings to `~/.claude/PENDING-UPDATES.md` when they satisfy the
  admission rule, referencing that rule by name rather than restating it. `README.md:266` corrected in
  the same commit so the registry row no longer implies `/orchestrator:update` is its only consumer.
  Per `CONTEXT-RIGHTSIZING.md`: intent stated once, no table row, no restated clause.
- [ ] ~~Then the wire, last.~~ One sentence in `skills/wrap/SKILL.md` step 5 routing tooling and
  config learnings to `~/.claude/PENDING-UPDATES.md` when they clear the admission rule, plus the
  matching `README.md:227` correction in the same commit (that line currently scopes the registry to
  the orchestrator family only, which the new rule would contradict). One sentence, no table row, no
  restated "one home per fact" clause. Read `~/.claude/CONTEXT-RIGHTSIZING.md` first, as global
  CLAUDE.md requires before adding to an instruction file.
- [ ] **Three untracked skills in claude-config** — `brukas-queue` (1 file), `genomics-viz`
  (4 files), `snippost` (1 file). Read them, then recommend track-or-ignore rather than asking.
  `jefe` is correctly gitignored: its own repo, 943 MB.
- [ ] **`.gitignore` inconsistency in claude-config.** `.gitignore:68` is
  `skills/workflow/brand-naming/`, not `skills/brand-naming`, which is tracked and not ignored.
  Six symlinks point into this repo but only four are ignored; `skills/orchestrator-boot` and
  `skills/orchestrator-route` are tracked as mode-120000 blobs. Decide the intended rule, then make
  the file match it.
- [ ] **Four `gh-*` skills are published here but not installed locally** — `gh-clean-branches`,
  `gh-fork-sync`, `gh-pr-triage`, `gh-stale-issues` have no symlink in `~/.claude/skills/`.
  Parked, off-objective, discovered incidentally.
- [ ] **Not doing, deliberately:** redesigning the four-channel model, moving skills from the private
  `claude-config` into this public repo, adding `## Learnings` sections to skills generally, or
  touching `ce-compound` / `docs/solutions/` routing.

- [~] **`templates/orchestrator-prompt.md` — partially reconciled by a sibling session (`4fbaff2`).**
  The Cardinal Rule is now present in the template. The two files still diverge substantially
  (`diff` against the installed `~/.claude/orchestrator-prompt.md` is 367 lines), so a cold installer
  still does not get the prompt Sean runs. Reassess whether full parity is the goal or whether the
  template is deliberately a different artifact.
- [ ] ~~`templates/orchestrator-prompt.md` is stale against the prompt Sean actually runs.~~ Discovered
  while verifying the counter fix. The installed `~/.claude/orchestrator-prompt.md` is a slimmer,
  newer design that delegates session start to the `/orchestrator-boot` skill; the repo template still
  inlines a "Phase 1: Codebase Exploration" flow with the counting logic written out, and is missing
  the Cardinal Rule, the scope-card rule, and the non-boot session guidance. A cold installer from
  this public repo inherits the old prompt. Decide whether the template should be regenerated from the
  installed file or is deliberately a different artifact.

- [x] **Prospective eval-test leak: gated.** Done, `b1dc551`. Step 6 of `orchestrator-update` now
  requires that a named-but-nonexistent test be written into `~/.claude/evals/orchestrator-smoke-test.md`
  before an entry can be marked `applied-`. Closes the leak going forward, including for the
  wrap-authored entries the new wire will produce.
- [ ] **Backfill eval tests 9 and 10** — now tracked as UPD-004 in `~/.claude/PENDING-UPDATES.md`
  (`1afa5e6`), routed there by `/wrap` under the new step-5 rule. Run `/orchestrator:update` to apply.
- [ ] ~~Backfill eval tests 9 and 10 — still missing, still uncovered.~~ The gate above stops NEW
  leaks; it does not retroactively create the two tests already lost. The suite is still 8 tests, and
  the rehydration short-circuit (UPD-002) and fanout ceiling (UPD-003) remain live behaviors with zero
  standing coverage. Writing them means editing `~/.claude/evals/`, which is Sean's call.
- [ ] ~~Prospective eval tests leak — they are never written back into the suite.~~ Discovered while
  resolving the admission path. `~/.claude/evals/orchestrator-smoke-test.md` still contains exactly 8
  tests (`grep -cE '^### [0-9]+\.'` → 8; no test 9 or 10 anywhere in the file). But UPD-002 and
  UPD-003 both record their named tests as run and passing — `Synthetic Test 9 (rehydration
  short-circuit): PASS HIGH`, `Synthetic Test 10 (10-unit audit): PASS HIGH`. Those tests were run
  once synthetically and evaporated. Two shipped behaviors therefore have zero standing coverage, and
  the validation that justified applying them cannot be re-run. This matters more once the wrap rule
  lands, because wrap-authored entries will name prospective tests too and leak identically.
  Fix: gate Step 6 of `skills/orchestrator-update/SKILL.md` — an entry cannot move to `applied-` until
  its named test actually exists in the suite. Touches `~/.claude/evals/`, so the backfill of tests
  9 and 10 is Sean's call.
- [ ] **`orchestrator-smoke-test.md:7` cites the stale Ghostty "Orchestrator" template.** Global
  CLAUDE.md records that template as non-existent; launch is `cco` / `ccob` now. One-line fix, in
  `~/.claude`, noticed incidentally.

- [x] **`policy-limits.json` untracking — skipped by decision (2026-08-28).** Commit was blocked by the
  auto-mode classifier; Sean elected to skip rather than spend a permission. The tree keeps one
  standing `D policy-limits.json`. Not a defect, a choice.

- [ ] **The zsh working-tree collision guard did not fire on two concurrent sessions (2026-08-28).**
  Global CLAUDE.md says the `claude()` guard in `~/.claude/shell/zshrc` locks on the tree and isolates
  a second live session automatically. On 2026-08-28 this thread and a sibling "tiers" thread both
  wrote `~/.claude` and `~/Code/agent-skills` directly, all session, with no isolation. Nothing was
  lost — the sibling committed only its own new files and this thread staged by explicit path every
  time — but `git add -A` from either side would have crossed them. Observed, not inferred: sibling
  commits `d93dab7`/`1253439`/`e76fe02`/`5c52066` in claude-config and `094cade`/`4fbaff2` here,
  interleaved with this thread's. Determine whether the guard only covers zsh launches (this session
  may not have come through it) or whether it is genuinely broken. Off-objective, discovered
  incidentally.


## Recovered from old Mac — uncommitted as of 2026-09-24 (merged 2026-09-25, review and fold in)

### 2026-09-02 (thread "Gooseworks take-home") — project-bootstrap scaffolding, scoped not built
`orchestrator-scaffold` covers **knowledge** files only (v2.1 lifecycle agents, v2.2
grounding). It has no lane for bootstrapping the actual project and its infrastructure.
A full web bootstrap was run by hand this session and documented at
`~/Code/docs/solutions/web-project-bootstrap-github-vercel.md` — that doc is the source
material if this gets built.

**Recommendation: sibling skill, not a fourth mode.** Three reasons:
- `skills/orchestrator-scaffold/SKILL.md` is already 21.5K; platform lanes would balloon it.
- Different trigger moment — scaffold runs on an existing project missing knowledge files,
  bootstrap runs on an empty directory.
- Different permission profile — bootstrap creates outward-facing resources (a repo, a
  public URL) and needs approval gates that the markdown-only scaffold modes never hit.

**Only the web/Vercel lane is evidence-backed.** iOS and macOS lanes were deliberately
NOT written: no Xcode/TestFlight bootstrap has actually been run, and inventing those
steps is how a skill becomes a wrong-ground-truth bug. Stub them; fill each one the
first time it is genuinely executed.

If built, it goes through `skill-forge` — the arm-gate applies, so it is not done until
it test-fires on a throwaway repo with pasted evidence.
