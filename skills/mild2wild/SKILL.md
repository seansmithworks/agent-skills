---
name: mild2wild
description: "Design ladder: fan out N design variants from mild to wilder (mild, medium, bold, wild, wilder) in Pencil, HTML, or Zoah, with a tiered banner, a gallery, and carry-forward rounds. Invoke on \"mild2wild\", \"mild to wild\", \"mild to wilder\", \"wild and wilder\", \"go wilder\", \"even wilder\", \"design pass\", \"paper/pen.dev variants\". Routing: single-element tweaks (bolder, quieter, one-off generate) go to `impeccable`, not here. Screen- or flow-level exploration only."
argument-hint: "[count] [clean|full|extreme] <what to design>"
user-invocable: true
---

# mild2wild

Many variants of one subject, safe to structurally different. Ends in a pick, then a build.

## Ladder
- **mild:** same layout; one axis moves (axes.md).
- **medium:** layout reworked; same tokens.
- **bold:** tokens pushed to their edge.
- **wild:** breaks one DESIGN.md rule or category habit, named in `breaks`.
- **wilder:** breaks a structure the category assumes (IA, metaphor), not the costume; different layouts, not overly themed. A skin on the same layout is a failed wilder.

Mild to bold obey DESIGN.md. Each brief states **Intent** (what the subject must do for its user) and **Habit** (what its category does today). Wild is measured against Habit; a wild card that serves Intent worse than mild has failed.

## Args
`[count=10] [full|clean|extreme]`: all five tiers, mild to bold, or bold to wilder. Split evenly, remainder to the wildest. Count: when the shape is clear, pick it (flows ~6, single static things ~20) and state it in the banner; ask once only if it is truly ambiguous. Medium: HTML is the default. If the user names a tool (pen.dev/Pencil, a .pen file, Figma, Zoah), use it. If the project is native (Swift/SwiftUI/AppKit, etc.) and no preference is saved, ask once: "HTML, or a native design tool?" (the one allowed medium question; a .pen answer triggers the dedicated-.pen ask). Save the answer to `~/.claude/.mild2wild/prefs.md`, reuse it without asking next time, and state the medium in the banner. Infer Intent and Habit and state them; don't ask. No args or `help`: print banner.md's menu and stop.

## Card
`<run>/rN/<id>/` holds `card.png` and `index.html` (Pencil: export HTML). One line per card in `<run>/rN/manifest.jsonl`: `{id, round, tier, breaks, name, idea, src, png}`; `id` a zero-padded string, `breaks` "" below wild, `src` = `rN/<id>/index.html`. gallery.py reads these exactly. `idea`: one sentence on what matters most. Variety beats polish. One render pass, one fix pass.

## Slop gate
Per wave, a subagent that didn't build the cards checks each. Fail: wild still reads as Habit; a theme skin over the mild layout; an unasked stock move (gradient text, decorative glass, icon-card grids, hero-stat template, eyebrow labels, emoji icons, edge bars); invented claims; another card's idea. A fail gets one re-roll; wild and wilder (the hardest tiers) get one extra re-roll; a card that still fails is dropped, folder moved out of `rN/`. The recap names any tier missing a card and offers a re-roll; never silently deliver fewer cards than asked.

## Boundaries
- **Banner:** print banner.md's strip before generating; reprint as the recap each round, `★` on the pick.
- **Pencil:** MCP can't create .pen files; `execute` writes to whatever canvas is active. Confirm Pencil is running first; a get_app_state error means stop and tell the user to open it. Ask once for a dedicated .pen the user made for this run; never use whichever file is open. Record it in `<run>/index.md`. Before EVERY write, orchestrator and each subagent check `get_app_state`; active canvas isn't that file: stop, write nothing, name both paths. Subagents: a stronger model subagent (no `model` param), one frame each.
- **HTML:** `agent-browser --session <id> <cmd>` per card (flag first); md5 PNGs after each wave, re-shoot duplicates.
- **Zoah:** one branch per card, no local code. Figma: unsupported.
- **Output:** `<repo>/.mild2wild/<YYYY-MM-DD>-<slug>/`; agents write only their own card folder. Never /tmp. Not gitignored: add it, tell the user.

## Rounds
Next brief opens `Endorsed, must keep:` + pick ids; user corrections carry forward as constraints. User picks: push all forward (every card gets another iteration, plus N new cards in the wildest tiers (default 5)) or ladder from #id (a fresh ladder from one card).

## End
Gallery: `python3 -I ~/.claude/skills/mild2wild/gallery.py <run> <outdir> rN`, same URL each round. User picks; build it or hand off to `/impeccable craft`, never automatic. Log rounds-to-pick and pick tier (or "no pick") in `<run>/index.md`.
