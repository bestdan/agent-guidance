# Review and authoring conventions: one home, three carriers

> Dated design record. The live description of this system is [`dev_docs/conventions.md`](../conventions.md); where the two disagree, that file is current and this one is history.

The reviewing and PR-authoring conventions move out of `bestdan/dotfiles` and into this plugin, where two skills expose them by verb. Three carriers deliver them — the skills, co-review's assembled `<INPUT>`, and the Codex pointer — and a precedence rule in `portable.md` says what happens when a repo disagrees.

**Nothing is committed to any consumer repo.** Every carrier is plugin-delivered and already reaches every machine and harness today. That is the property that makes this safe to carry into a repo you do not own.

## What is true today

Nothing enforces reviewing conventions anywhere.

- **This plugin carries none.** `rg -i review portable.md portable-claude.md` returns five lines at `87e76fd`; four are coding rules mentioning review in passing, one routes technical-correctness questions to agent review. None says how to review or how to write a finding.
- **The conventions exist, in the wrong place.** `dotfiles/agents/writing_about_code.md` holds "One point per comment", "Say whether it blocks", "Comment on the code, not the author", plus the verified-versus-inferred and absence-claim rules. That file is private and machine-local. It reaches a Claude Code session on a synced machine and nothing else.
- **Four of five co-review reviewers get nothing.** Each is dispatched with rubric plus diff and cut off from repo context by design: `crush` pins `--cwd <NEUTRAL>` specifically to take the repo's context files off the discovery path, `agy`'s `--add-dir` trusts only the input directory, `devin` uses a neutral cwd, `copilot` runs in GitHub's cloud. The rubric names "Project conventions" as a focus area with no conventions behind it.
- **No precedence rule exists.** Grepped `portable.md`, `portable-claude.md`, `dotfiles/agents/AGENTS.md`, and `writing_about_code.md`: the only precedence language in the corpus is the owner table for draft-versus-ready, and `authoring_pull_requests.md`'s rule about PR _body_ templates. Nothing says what happens when a repo's conventions disagree with these. The default leans the wrong way — user-level `CLAUDE.md` arrives flagged as overriding, repo `AGENTS.md` arrives as ordinary context.

`codex` is the partial exception on the first three points: `codex exec` runs in the repo, and `~/.codex/AGENTS.md` carries `portable.md`. Verified that the file exists and contains the portable guidance; **not** verified that a co-review dispatch loads it. Either way its pointer says "Do NOT explore the filesystem" and `writing_about_code.md` is referenced there only as a link, so the review-comment rules do not arrive.

## Decisions

### 1. Content home — this plugin

```
agent-guidance/
  portable.md                   # gains two pointer lines, a precedence rule, the title grammar
  writing_about_code.md         # shared    — moved verbatim from dotfiles/agents/
  authoring_pull_requests.md    # authoring — moved from dotfiles/agents/, one gate deleted
  reviewing.md                  # reviewing — new
  skills/authoring/SKILL.md     # verb: write a PR
  skills/reviewing/SKILL.md     # verb: review a change
```

**Authoring and reviewing are different verbs drawing on one body of source material.** The three files are the content layer, not the interface: `writing_about_code.md` is shared — it governs any prose about code, which both verbs produce — while `authoring_pull_requests.md` and `reviewing.md` each serve one. Two skills sit on top with different triggers: `agent-guidance:authoring` fires at PR time, `agent-guidance:reviewing` when reviewing a change.

`writing_about_code.md` moves rather than being copied. It is already portable — it names no machine, path, or repo.

`authoring_pull_requests.md` moves with it, absorbed from issue #10's step 2. The two are a pair in `dotfiles/agents/AGENTS.md`, which routes prose about code to the first and adds the second at PR time; splitting them across a public plugin and a private repo is a worse resting state than moving either alone. It is portable on the same test — verified 2026-09-12 by grep: 116 lines with no mention of any owner, repo, machine, path, or platform, and the owner table that decides draft-versus-ready stays behind in `dotfiles`. The move deletes one gate: "With no template, put the key in brackets at the end of the title" (line 83) becomes unconditional, and templates govern the body only. That gate is the gap issue #10 measured — `finplan`'s template says nothing about titles, so every PR there falls through it into whatever the opening path improvises.

Both moves are a publication decision: this repo is public, `dotfiles` is private. Made once, here.

`reviewing.md` is new writing: what a review checks (correctness, contradictions, conventions, test gaps), blocking versus non-blocking, the conventional-comment label, and the pattern rule — _a review checks the change against the repo's documented patterns, not only against itself._

Neither skill is injected by the `SessionStart` hook, and splitting by verb is what keeps that affordable: a session reviewing a change pays for `writing_about_code.md` plus `reviewing.md` and never for the 116 lines of PR-title grammar, while a session opening a PR pays the reverse. A single combined skill would charge every session the full ~250 lines for whichever half it is not doing. This is the same reasoning `dotfiles/agents/AGENTS.md` already applies to both files — "applies without being read" for the first, "read it at PR time, not at session start" for the second. The split preserves a distinction that file already makes.

Whether a skill fires reliably enough is the risk here, and it doubles with two skills. It stays bounded: the co-review carrier in decision 3 reads the files directly, so the reviewer path does not depend on a skill triggering. The authoring path does, which is why the title grammar also lands in `portable.md` as a line every session sees.

### 2. Precedence — the repo wins on its own conventions

`portable.md` gains a rule, because there is none today and the guidance now travels into repos the author does not own.

- **Conventions about the work product** — commit format, PR title and body shape, review style, code style, test layout → **the repo's documented conventions win.** These rules describe one developer's defaults, and a repo with its own stated convention is not asking.
- **Rules about the session's own environment and workflow** — worktree isolation, the Bash sandbox, `dli`, `op`, which CLI tools to reach for → **these hold regardless.** A repo has no standing to say how someone else's machine works, and a repo that appears to is describing its own CI rather than the reader's session.

The split is what makes the rule safe. "The repo wins" applied without it would let any `AGENTS.md` override the sandbox and worktree rules, which are safety machinery, not preferences.

This is a prose rule with no mechanism behind it — both sets of instructions land in the same context window and the model arbitrates. Stating the direction is the whole intervention; there is no harness feature that enforces it, and none is assumed.

### 3. The sandboxed local reviewers

co-review assembles `<INPUT>` as rubric plus requests plus diff. It gains one segment: the shared conventions, read from the installed plugin through a resolver modelled on `papercuts-plugin-dir.sh` (env override, then the `installPath` in `installed_plugins.json`, then the version scan, then the marketplace clone).

The assembled `<INPUT>` file — **not stdin** — is the one artifact all five reviewers receive regardless of cwd, sandbox, or repo. The distinction is load-bearing: `codex`, `copilot` and `crush` read `<INPUT>` piped on stdin, but `agy` does not read stdin at all (its pointer names the file by path) and `devin` is handed it via `--prompt-file`. An implementer who takes "stdin" literally wires the new segment into the pipe and misses two of the five. Appending to `<INPUT>` is the one edit that covers all of them, and it is a `workflow-skills` change.

This is the only enforcement path that does not depend on a skill firing, which makes it the load-bearing carrier for reviewing.

## What reaches whom, after

| Consumer                                        | Verb      | Carrier                                            | Needs anything from the repo? |
| ----------------------------------------------- | --------- | -------------------------------------------------- | ----------------------------- |
| Claude Code, reviewing a change                 | reviewing | `agent-guidance:reviewing` skill                   | no — plugin install           |
| Claude Code, opening a PR                       | authoring | `agent-guidance:authoring` skill                   | no — plugin install           |
| `codex`, `crush`, `copilot` CLI, `devin`, `agy` | reviewing | co-review's assembled `<INPUT>`                    | no — `workflow-skills` change |
| Codex sessions generally                        | both      | one pointer line per skill in `~/.codex/AGENTS.md` | no — `sync_codex.sh`          |

All four **routes** already reach every machine and harness today, including a repo owned by someone else — what each must still gain is the content, per the fourth column. Verified: `sync_codex.sh:61` resolves the **installed plugin** through `agent-guidance-dir.sh` and concatenates its `portable.md` with `dotfiles/agents/AGENTS.md` at shell startup; the Claude Code side comes from this plugin's own `SessionStart` hook. Neither asks the repo for anything.

## Considered and dropped — the GitHub Copilot review path

An earlier version of this design generated a delimited block into each consumer's `.github/copilot-instructions.md`, synced by a scheduled reusable workflow, so GitHub Copilot code review would enforce the same conventions. **Dropped: it was the only piece requiring write access to consumer repos, and it bought exactly one consumer.**

What it would have cost, and why that is more than it looks:

- A block generator, marker ownership, and a `rev=<sha>` staleness marker.
- A reusable workflow here plus a caller workflow in every consumer.
- `permissions: contents: write, pull-requests: write` in each caller — and separately the repo/org setting **"Allow GitHub Actions to create and approve pull requests,"** which is off by default and **cannot be set from a workflow file**. That is a manual, out-of-band toggle in every consumer, and when it is missed the scheduled job produces no PR and no signal.
- On `$WORK` repos, both gates are org-controlled rather than the author's to clear — and a committed `.github/copilot-instructions.md` changes how Copilot reviews _everyone's_ PRs in a shared repo. That is a team decision, not a personal config change.

The research is kept because it is the expensive part to redo. Copilot code review reads `.github/copilot-instructions.md`, `.github/instructions/**/*.instructions.md` with an `applyTo` glob, `AGENTS.md`, and legacy `CLAUDE.md`/`GEMINI.md`/`REVIEW.md` — from the **head branch**, so a change is testable in its own PR. It sees only committed files, and per `workflow-skills/scripts/build-copilot-instructions.py` it **does not follow links**, so a link-first guidance file gives a reviewer a map and no territory. (Source: GitHub documentation, fetched 2026-09-12.)

Dropping this also dropped the per-repo pattern map — a `<!-- agent-guidance:patterns -->` span mapping path globs to `dev_docs` files. Its only consumer was the generator. The rule it served survives in `reviewing.md`: check the change against the repo's documented patterns, not only against itself. A reviewer that can read the repo finds those docs without a hand-authored index.

`finplan` leaves scope with this section — it was only ever a block consumer.

## Cost

Two costs, both ongoing:

- **Every co-review dispatch grows** by the size of the conventions, against each of five reviewers' context and bill. This is the price of the one carrier that does not depend on a skill firing.
- **Two skills instead of one** doubles the chance that the right one fails to fire. Mitigated for reviewing by the co-review carrier, and for authoring by putting the title grammar in `portable.md` where every session sees it.

No line budget is needed now that nothing is generated into a size-capped file.

## Sequencing against issue #10

Issue #10 is a contradiction problem — `portable.md`, `dotfiles`, and `workflow-skills` each state a different PR-title rule, and the one that actually writes the titles is not the SOT. This design is a distribution problem — the rules exist and reach nobody. They share one step, the file move in decision 1, which this design owns. Issue #10's remaining steps stay there: the four `workflow-skills` handler templates and the `guard_pr_body.py` title check. The `portable.md` title grammar is the exception — it comes here, as issue #11, because `skills/authoring/SKILL.md` cites it.

One ordering constraint runs inside that scope. **The title grammar must land in `portable.md` before `skills/authoring/SKILL.md` cites it.** The skill points at the conventions; if it ships while `portable.md` is still silent on the ticket key, it points at a rule set missing the most-violated convention in issue #10's measured data. One line, no shared code, no merged PR — but a real dependency edge.

## Scope

`agent-guidance`, `dotfiles`, and `workflow-skills`.

- **`agent-guidance`** — the moves, the two skills, `reviewing.md`, and the `portable.md` additions.
- **`dotfiles`** — one migration commit: delete the two moved files, repoint their two rules in `agents/AGENTS.md` at the plugin. Not recurring.
- **`workflow-skills`** — one co-review edit, decision 3.

`$WORK` repos are in scope as _consumers_ and out of scope as _targets_: they receive everything through the plugin carriers and have nothing committed to them.

## Open questions

- Whether the `authoring` and `reviewing` skills fire often enough, or whether either path eventually wants `SessionStart` injection after all. Measurable after the fact, and reversible.
- ~~Whether `crush` reliably consumes `<INPUT>` on stdin at all.~~ **Answered 2026-09-12 (issue #20): yes, verified.** `crush run` v0.92.0 reads stdin when it is a named pipe or a regular file and prepends the bytes plus `"\n\n"` to the prompt argument (`MaybePrependStdin`, `internal/cmd/root.go:918` at tag v0.92.0); when stdin is a TTY, a socket, or a character device it sends the prompt alone, silently. The documented co-review dispatch (`cat "<INPUT>" | crush run --cwd … -q -m … "<POINTER>"`) is the pipe case and delivered the input in every variant tested: with and without `--cwd`, `-q`, `-m`; via `<` redirect; at 44KB; two dispatches in parallel; from a backgrounded shell. Verified by the model echoing a canary present only in the stdin file, and by crush's own `prompt_len` log line, which equals input bytes + 2 + pointer length for every run. So the `NO INPUT` observed during this document's review did not reproduce, crush is **not** an `agy`-class no-stdin exception, and decision 3 reaches all five reviewers. The likely cause of the original observation, inferred not verified: zero bytes reached the pipe — `<INPUT>` empty when `cat` ran, or a dispatch without its `cat |` prefix so stdin was the harness socket. Not excluded: the model emitting `NO INPUT` despite a full prompt at review size, which could not be exercised at 44KB because the Hyper account ran out of credits mid-spike. Diagnostic for next time is in `workflow-skills/skills/co-review/reviewers/crush.md`: read `prompt_len` in `crush --cwd "<NEUTRAL>" logs` — pointer length alone means no pipe, pointer + 2 means an empty pipe, a full-sized value means a model-side failure.
- Whether the precedence rule in decision 2 changes behaviour at all, given it has no mechanism behind it. Worth checking against a real `$WORK` repo whose `AGENTS.md` states a conflicting convention.
