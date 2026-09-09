# Portable guidance, Claude-only

Sentinel payload. This file will hold the portable rules that name Claude Code
machinery — `AskUserQuestion`, the `Agent` and `Workflow` tools, the model
tiers — which Codex cannot act on. The plugin injects it; `sync_codex.sh` does
not concatenate it. The real rules arrive in plugin task 5.

Marker for the delivery tests: `GUIDANCE-SENTINEL-CLAUDE`.

- When you use `AskUserQuestion` and recommend an option, put that option first
  and append `(Recommended)` to its label.
