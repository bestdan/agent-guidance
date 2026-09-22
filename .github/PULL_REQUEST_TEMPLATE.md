<!-- Title: imperative, under 70 characters, grammar per the `Git:` bullet in portable.md.
     Body: about 200 words, 400 at the hard ceiling. Delete any heading you leave empty.
     `authoring_pull_requests.md` governs how to write inside this shape. -->

## Summary

<!-- One to three sentences: the problem this solves or the capability it adds, and the approach.
     This is the only required section. -->

## Why this way

<!-- The non-obvious: a trade-off, a workaround, a decision a reviewer would reasonably question.
     If a rule moved between files, say which carrier delivers it now and why that file. -->

## Notes for the reviewer

<!-- Verification CI cannot produce, what you want scrutinized, links to the decision record or
     prior discussion. Never "tests pass" or "lint is clean": the tests, fmt, lint and shellcheck
     jobs report that already. -->

## Delivery

<!-- These are the checks CI cannot run. Delete every line that does not apply to this change. -->

- [ ] A rule added or reworded sits in the file its delivery requires: `portable.md` when a session
      must hold it mid-task, `portable-claude.md` when it names Claude Code machinery that
      `sync_codex.sh` must leave out, `writing_about_code.md` when it is register read on demand.
- [ ] A rule moving out of `bestdan/dotfiles` lands here first; the deletion there waits until the
      plugin update is installed.
- [ ] A choice a later reader would question has a record under `dev_docs/decisions/`.
- [ ] A new convention ships with whatever enforces it, and a new enforcement says which rule it serves.
