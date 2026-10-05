---
name: model-census
description: "Report which Claude model actually ran, per main thread, per subagent type, and per repo, from local transcripts. Use to verify tier routing works and to see where Fable/Opus tokens go. Trigger: 'model census', 'model usage', 'which models are we using', '/model-census'."
license: MIT
metadata:
  version: 1.0.0
  category: workflow
  domain: cost-observability
---

# Model census

Neither the API console nor `ccusage` can see subagent type or repo — they see API keys and token counts, not which agent definition ran or what it was working on. This skill reads the transcripts directly.

## What it reads

`~/.claude/projects/**/*.jsonl` (main-thread transcripts) and `~/.claude/projects/**/subagents/agent-*.jsonl` (subagent transcripts). Subagent type is recovered by joining the parent transcript's `Agent` tool_use (`input.subagent_type`) to the matching tool_result's `agentId: <id>` line, then matching that id to its subagent transcript. Token counts are raw counts, not dollars — this is a routing check, not a billing report.

## Command

```bash
python3 <skill dir>/scripts/model-census.py --brief --since <date>
```

Global install (`npx skills add ... -g`): `~/.claude/skills/model-census/scripts/model-census.py`. Project-local install (the default): `./.claude/skills/model-census/scripts/model-census.py`. `--since` takes `YYYY-MM-DD` (default: 30 days back). Drop `--brief` for the full report broken out by project.

## Always flag

- Any Fable row in the **MAIN THREAD** table, or any model other than the declared `~/.claude/settings.json` default (Sean's is `opus`; Opus matching it is not a flag) — the main thread pays to read every tool output, so an undeclared top-tier default there is the expensive place for it to leak, not a per-task subagent.
- A top-level `model` key in `~/.claude/settings.json` only when it is `fable`, a pinned version (anything that isn't a bare alias like `opus`, `sonnet` or `haiku`), or absent while the main thread runs Fable — that's a silent global default, usually written by `/model <x>` + Enter instead of the session-only flag. A bare `opus` is expected.
