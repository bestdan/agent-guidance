# Portable guidance, Claude-only

The portable rules that name Claude Code machinery — `AskUserQuestion`, the
`Agent` and `Workflow` tools, the model tiers, permission matching, plugins and
skills. Codex cannot act on any of it, so this file reaches Claude Code alone:
the `SessionStart` hook injects it, and `sync_codex.sh` deliberately does not
concatenate it. Everything that holds under both harnesses is in `portable.md`.

Marker for the delivery tests: `GUIDANCE-SENTINEL-CLAUDE`. It stays as a
permanent delivery canary — its presence in a Claude session and its absence
from `~/.codex/AGENTS.md` are the two things the delivery tests assert.

## Communication

- **`AskUserQuestion` is for decisions that belong to the user.** Use it when the decision turns on preference, scope, values, or appetite for risk. Use it only when the options are real and mutually exclusive. State your recommendation and the tradeoff first. Four corollaries follow:
  - **Technical-correctness questions go to agent review, not to the user.** A finding that needs expertise the user does not have goes back to a reviewer with the evidence. Do not pose it as a yes/no.
  - **Risky proceed-or-not decisions go in prose.** A button forces a binary answer. The user usually wants to redirect the work or add a condition instead.
  - **Exploratory and design questions get a recommendation plus the main tradeoff.** State the recommendation in prose and let the user redirect. Do not structure the choice as a multi-option prompt.
  - **Never proceed past an unanswered question.** After the user answers a binary choice, restate the resolved answer before you implement against it.

## Output Formats

- **Plans:** For any multi-step plan that spans more than ~3 steps or multiple PRs, use the `/plan-with-docs` skill (ships with the `workflow-skills` plugin: `bestdan/workflow-skills`).

## Delegation & subagents

- **How:** on `Agent`/`Task` calls pass `model: "haiku"` (or `"sonnet"`); in a `Workflow` script **you author**, set `model:`/`effort:` per stage — cheap on the fan-out, the strong model on synthesize/verify.
- **Reach — be honest about it.** This only bites where the model actually chooses the tier: live Agent-tool fan-outs and workflows you write. It does **not** reach a pre-packaged skill's _fixed_ workflow (e.g. `/deep-research`) — those inherit the session model uniformly with no per-stage knob. For a sealed, retrieval-heavy skill, control cost by running it from a cheaper session instead.

## Rules

- **To learn what a skill does, invoke it — don't read the plugin cache.** When you need a skill's behaviour or interface, call `/<plugin>:<skill>` (e.g. `/workflow-skills:promote-tasks`) or ask me. Don't go searching `~/.claude/plugins/cache/` with Bash: that layout is an installation detail that moves, and a failed search there reads as "the skill doesn't exist" rather than "I looked in the wrong place".
- **"Papercut" is a term of art → the `/papercuts:papercut` skill.** Any request to record, capture, write up, or flush a "papercut" (or "paper cut") routes to `/papercuts:papercut` (from the `bestdan/papercuts-plugin` plugin), which gates capture and spools to the `bestdan/papercuts-ledger` ledger. Never satisfy it by filing an ad-hoc Linear issue or tracker task instead — the tracker is downstream of papercut triage, not the capture vehicle. If `/papercuts:papercut` genuinely doesn't fit the request, say so and ask rather than silently substituting a tracker.
- **Never env-prefix `git` to configure it; use `git -c`.** Permission rules anchor on the command word, so a segment like `GIT_EDITOR=true git rebase --continue` can never match `Bash(git rebase:*)` (or its `rtk git` twin) and always prompts, no matter how complete the allowlist is. Write `git -c core.editor=true rebase --continue` instead — same effect, stays git-anchored and matchable. The `agents/guard_env_prefix_git.py` PreToolUse hook denies the env-prefixed git form with this feedback. The principle generalizes: an env-var prefix on any command defeats command-anchored allow rules for that segment.
- **Run network git (`git push` especially) as its own Bash call, never in a `&&` chain.** Permission rules match per `&&`/`;` segment and one uncovered segment (a `cd`, a test run) prompts the whole call — and because push needs the sandbox escape, the entire chain runs unsandboxed instead of just the push. Do the local work (tests, rebase) in sandboxed calls first, then push alone.
- **No `cd "$(git rev-parse --show-toplevel)"`:** Don't wrap git (or any) commands in a `cd "$(...)"` to the repo root. The command substitution forces a permission prompt even for allowlisted commands. Run git directly from cwd. `git -C <path>` is for reads, or for a repo other than this one; it is never how you write into another worktree of this repo, which you enter with `EnterWorktree` (`path`) instead. See "Stand in the tree you write" in `portable.md` for why. A `Shell cwd was reset to <path>` notice on a Bash result is that rule being broken live: the run is writing to a tree it is not in, so stop rather than re-prefixing the next command.
- **`gh api`:** Always put the method flag (`--method`/`-X`, or any `-f`/`-F`/`--input` that implies a write) **before** the endpoint path — e.g. `gh api --method POST repos/owner/repo/pulls/1/comments`, never `gh api repos/owner/repo/pulls/1/comments --method POST`. The read-only `gh api repos/*/pulls/*/...` allowlist entries are anchored on the endpoint path, so a mutating call that leads with the path would slip past their GET-only scope. Leading with the method keeps writes out of those patterns.
