# Writing and Reviewing Tests

What makes a test worth writing, and what makes one worth deleting. A test
costs CI time on every run for as long as it exists, and a suite full of
duplicates hides the few tests that catch bugs. Each rule below comes with a
case to follow and a case to avoid, because a concrete rule changes what gets
written and "write good tests" does not.

A repo's own testing docs win where they disagree with this file, per the
`## Precedence` section of `portable.md`.

## The rules

### 1. Every test names the bug it would catch

Before writing a test, describe a realistic change to the code that would make
it fail. If you can't, don't write it.

- **Do:** "If someone drops the `<=` to `<`, a balance exactly at the limit
  stops qualifying." Then test the boundary value.
- **Don't:** a test that builds an object and asserts it is not `None`. No
  plausible edit to the code makes it fail.

### 2. One case per code path

Inputs that take the same branch belong in one parametrized or table test, or
are dropped. The spellings of one flag (`-v`, `--verbose`) are one path, not
two tests.

- **Do:** one table test with a row for each branch: empty input, a single
  item, the item that trips the limit.
- **Don't:** `test_parses_one`, `test_parses_two`, `test_parses_three`, each
  walking the same loop.

### 3. Don't test the language, the framework or other people's tools

The standard library, the web framework, the validation library and another
tool's CLI have their own test suites. Test what your code does with them.

- **Do:** assert that your handler rejects a request missing a required field,
  because your schema declares it required.
- **Don't:** assert that a dataclass stores the field you passed it, that a
  dict lookup returns the value set, or that `git status` exits 0 in a clean
  repo.

### 4. Don't mirror data or prose

No assertion that a constant equals the literal it was copied from, and no grep
of a doc or a prompt for a sentence. Such a test fails on every intended edit
and on no bug. A doc that must stay true to the code gets one dedicated check,
or is generated from the code.

- **Do:** one check that every flag the CLI accepts appears in its help text,
  derived from the parser.
- **Don't:** `assert TAX_RATE == 0.22`, or `assert "Run the setup script" in
  readme`.

### 5. Expected values come from an independent source

The expected value comes from a spec, a hand-worked example, a closed-form
result, or an invariant. It never comes from running the code and pasting what
it printed: that test passes on the bug it was pasted from.

- **Do:** a loan schedule checked against the amortization formula, or a
  round trip that asserts `decode(encode(x)) == x`.
- **Don't:** run the function, copy its output into the assertion, and call it
  a regression test.

### 6. Assert on outputs and observable effects, not on mock calls

Assert what the code returns, writes, or sends. An assertion on the arguments a
mock received restates the implementation, so it breaks on a refactor and
passes on a wrong result. Prefer a stateful fake, such as an in-memory store
the test can read back, over a mock.

- **Do:** save through the fake repository, then assert that loading the
  record returns the saved values.
- **Don't:** `mock_db.insert.assert_called_once_with({...})` as the only
  assertion.

### 7. Cost is part of the design

- No real sleeps. Inject a clock and advance it.
- Run a suite's cases in one interpreter or process, not one per case. Spawn
  the real binary only for the few cases where the real invocation is what's
  under test: argument parsing, exit codes, the environment.
- Build expensive fixtures once per file, not once per test.
- Mark a test over the repo's time budget as slow, as the repo defines it, so
  the fast tier stays fast.

- **Do:** a retry test that advances a fake clock by 30 seconds and runs
  instantly.
- **Don't:** `time.sleep(2)` to let a background job finish, or a shell suite
  that starts a fresh interpreter for each of 200 table rows.

### 8. A bug fix brings one regression test

The fix adds one test that fails before the fix and passes after it. It does
not add variations on that input that take the same path.

- **Do:** one test reproducing the reported input.
- **Don't:** five near-copies of it with the numbers nudged.

### 9. A coverage gate is never a reason to write a test

A test written to move a coverage number is written without a bug in mind,
which breaks rule 1. How a repo handles an uncovered line instead, whether by
excluding it, gating on diff coverage, or lowering the floor, is the call of
that repo's own coverage policy.

- **Do:** leave the line uncovered and follow the repo's policy for it.
- **Don't:** call a function with arbitrary arguments and assert it doesn't
  raise, so the line counts as hit.

### 10. Deleting a redundant test is a normal change

A test that no longer earns its cost under these rules can be removed. The
change names the test that still covers the behaviour, or says the behaviour
needs no test and why. This is not the same as deleting a test to make a
failing check pass, which stays forbidden.

- **Do:** "Removes `test_parse_two`; `test_parse_table` covers the same path
  with the two-item row."
- **Don't:** delete a failing test so CI goes green.

## Reviewing tests

For each test a change adds or edits, ask:

1. What realistic bug makes this test fail? (rule 1)
2. Does another case already take the same path? (rule 2)
3. Is it testing our code, or the language, the framework or another tool?
   (rule 3)
4. Is it asserting that data or prose equals a copy of itself? (rule 4)
5. Where did the expected value come from: an independent source, or the
   code's own output? (rule 5)
6. Does it assert a result or an effect, or only the calls a mock received?
   (rule 6)

A test that fails one of these is a finding. Suggest merging it into an
existing case or deleting it, and name the test that covers the behaviour.
