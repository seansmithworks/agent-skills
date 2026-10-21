---
name: mild2wild
description: "Design ladder: fan out N design variants from mild to wilder (mild, medium, bold, wild, wilder) in Pencil, HTML, or Zoah, with a tiered banner, a gallery, and carry-forward rounds. Invoke on \"mild2wild\", \"mild to wild\", \"mild to wilder\", \"wild and wilder\", \"go wilder\", \"even wilder\", \"design pass\", \"paper/pen.dev variants\". Routing: single-element tweaks (bolder, quieter, one-off generate) go to `impeccable`, not here. Screen- or flow-level exploration only."
argument-hint: "[count] [clean|full|extreme] <what to design>"
user-invocable: true
---

# mild2wild

Divergence tool: many variants of one subject, spread across a ladder from safe to structurally different. It ends in a pick, then a build. Boundaries below are load-bearing; the order of work is yours.

## No args or `help`

Print the menu card from [banner.md](banner.md) and stop. Do nothing else.

## The ladder

| Tier | What moves |
|---|---|
| mild | Same system and layout. One treatment axis moves. |
| medium | Same tokens. Layout reworked. |
| bold | Tokens pushed to their edge. |
| wild | Breaks one system rule, named on the card. |
| wilder | Breaks structure (IA, metaphor). |

- DESIGN.md is source of truth for mild, medium, bold. Wild and wilder may break it and must say which rule (`breaks` field).
- Wilder guard: "different layouts but not overly themed". Wilder changes structure, not costume. A radar skin on the same layout is a failed wilder.
- Mild/medium axes: pick from [axes.md](axes.md).

## Modifiers (args, any order)

- **count**: integer, default 10. If none given and the subject's shape is ambiguous, ask once: flows or multi-screen lean fewer (e.g. 6), single static things lean more (e.g. 20). If clearly one or the other, pick and state it in the banner; do not ask.
- **preset**: `full` (default; all 5 tiers), `clean` (mild/medium/bold; nothing breaks DESIGN.md), `extreme` (bold/wild/wilder).
- Split count evenly across the preset's tiers; remainder goes to the wildest tiers (`extreme 6` = 2/2/2; `full 10` = 2 each; `full 12` = 2/2/2/3/3).

## Banner and recap

Before generating, print the banner from [banner.md](banner.md) (plain monospace, no emoji). Reprint the same strip at the end of every round as the recap: the user's pick marked `★`, each card's one-line idea under its tier.

## Card

One line per variant, appended to `<run>/rN/manifest.jsonl`:

`{id, round, tier, breaks, name, idea, src, png}`

`breaks` is empty for mild/medium/bold and names the rule for wild/wilder. `idea` is one sentence: what this layout believes matters most. Every card has a source (`src`) and a PNG (`png`) or it does not count. Variety beats polish; one render pass plus at most one fix pass.

## Media

Pick the medium from the project and say so in the banner.

- **Pencil.** The user creates new .pen files in the app; MCP does not. `mcp__pencil__execute` given a path that does not exist writes into whatever canvas is active. So: first confirm the Pencil app is running and its MCP server is active (a `get_app_state` error means stop and tell the user to open Pencil). Ask the user once for the dedicated .pen path, record it in `<run>/index.md`, and pass it to every subagent. Never write to any other .pen file. The guard binds the orchestrator AND every subagent: immediately before EVERY write (each `execute` batch, each browser import-to-canvas), call `mcp__pencil__get_app_state` and assert the active canvas path equals that file. Every write, not once per run, because a tab switch mid-run silently redirects the write. Mismatch or no canvas: stop, write nothing, and print a short hard-stop message naming the active canvas path and the intended file (for example "mild2wild writes only to <intended .pen>. active canvas: <path>. Make it the active tab, then re-run."). Variant subagents spawn as `senior-implementer` (it carries the Pencil MCP tools; pass no `model` param). Each owns one top-level frame and touches only it. Export PNG into its card folder.
- **HTML.** One static page per card (`src`), screenshotted to PNG. No shared mutable files between cards. Parallel screenshots: every card shoots with `agent-browser --session <card-id> <cmd>` (flag before the command); the default session is shared, and r2 cards 23/24 got one screenshot. After each wave, md5 the PNGs and re-shoot any duplicates.
- **Zoah.** One Zoah branch per variant; `src` is the branch ref. Never writes local code.
- **Figma.** Not supported until a real pass uses it.

## Output location

`<repo>/.mild2wild/<YYYY-MM-DD>-<slug>/rN/`, one subfolder per card. Parallel agents write only inside their own card folder. Never /tmp (a /tmp brief lost a whole round once). Never committed: if `.mild2wild/` is missing from the repo's .gitignore, add it and tell the user. Public repos plus binaries is a one-way door.

## Rounds

Two carry-forward modes, the user picks:

- **Push all forward (+ N wilder):** every card from the last round gets another iteration, plus N new cards from the wildest tiers.
- **Ladder from #id:** a fresh ladder starting from one picked card.

The round N+1 brief opens with `Endorsed, must keep:` listing picks by id, before anything else. Corrections from the user carry forward as constraints; endorsed structure is not rediscovered.

## Gallery and ending

One gallery per run (Artifact or local HTML), republished to the same URL each round. Build it with `python3 -I ~/.claude/skills/mild2wild/gallery.py <run> <outdir> rN` (sibling-page links don't open in the Artifact viewer, so it loads cards in-page via fetch + iframe srcdoc). End every run with one of: "choose the best and build" (build the pick), or hand-off to `/impeccable craft`. Neither is automatic; the user chooses.

Log in `<run>/index.md`: rounds-to-pick and the picked card's tier. That is the success measure for this skill; if a run ends without a pick, log that.
