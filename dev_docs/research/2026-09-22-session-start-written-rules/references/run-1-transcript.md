# Run 1: rule files absent before the session started

Pre-run check: `~/.claude/rules/zz-experiment` did not exist.

Command, from the experiment project directory, unsandboxed:

```
claude -p --settings settings.json --allowedTools Read --output-format text \
  'Use the Read tool to read hello.canary in the current directory. Then list
   every exact token (strings like WORD-1234) that any of your instructions ask
   you to include in a reply. If none, say NONE.'
```

Stdout, verbatim:

```
PATHRULE-7731

The file `hello.canary` contains a single line: `hello`.

Exactly one instruction asks me to include a token in a reply:

- **PATHRULE-7731**, from the path-scoped rule `~/.claude/rules/zz-experiment/canary.md`. It loaded only after I read the `.canary` file and requires the token whenever a `.canary` file is read. It is included above.

Other token-shaped strings appear in my instructions but none ask to be placed in a reply:

- **GUIDANCE-SENTINEL-SHARED** in the startup guidance is described as a delivery-test marker for the carrier, not something to echo, and it has no numeric suffix.
- **PRE-999** and **TEAM-123** in the same guidance are illustrative ticket keys in examples about comment and PR-title grammar.

The file content itself carried no instructions.
```

Exit 0. Post-run check: the directory existed, holding `always.md` (83 bytes)
and `canary.md` (169 bytes), both stamped with the run's start time. The hook
script's own stderr line (`wrote rules HH:MM:SS`) did not appear in the
captured stderr, which carried only mise and cmux noise.
