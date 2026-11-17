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

### 2. Test the states that can happen, and the ones that could start to

A state that something enforces on every input needs no test: no input
reaches it, so no bug lives there. That means a type the compiler or the
repo's type checker enforces on every caller, or a schema or constructor that
validates at runtime. A type annotation alone does not rule a state out when
the value crosses a boundary unchecked, such as parsed JSON or form input. A
state that is ruled out only by what today's callers happen to pass, or by
today's data, is different. If a caller could start passing it, and the result
would be harmful, test the guard. The realistic change from rule 1 is then a
change to the caller, not to this code.

- **Do:** a fee calculation that only today's callers keep from seeing a
  negative balance (a refund path could start passing one) gets a test that a
  negative balance raises, instead of quietly charging a negative fee.
- **Don't:** a test that a function typed to take an `AccountType` enum
  rejects the string `"checking"`, or that a non-nullable field set by the
  constructor is never `None`.

### 3. One case per code path, chosen at its boundaries

Inputs that take the same branch belong in one parametrized or table test, or
are dropped. The spellings of one flag (`-v`, `--verbose`) are one path, not
two tests. Where a branch turns on a threshold, the rows sit at the threshold
and one step either side of it. A value from the middle of a range catches
nothing that the boundary rows miss.

Tests that build the same setup and differ only in what they assert are one
test. Merge them into one test with several assertions. Building the setup
again costs a run for each copy and catches no extra bug. Where the framework
supports it, report each assertion on its own (subtests or soft assertions),
so one failure does not hide the next.

- **Do:** one table test whose rows are empty input, a single item, the
  last item under the limit, the item at the limit, and the first item over
  it. Assert the totals,
  the status and the audit record against one built ledger.
- **Don't:** `test_parses_one`, `test_parses_two`, `test_parses_three`, each
  walking the same loop, or three tests that each build the same ledger to
  check one field apiece.

### 4. Test each behaviour at the lowest level that can see it

The logic is tested where it lives, and the levels above trust that test. A
test at a higher level covers what only that level can see: that the parts are
wired together, and that a result passes through them. It does not repeat the
cases below it. A repeat whose outcome the upper layers do not change costs the
higher level's price and catches nothing the lower test misses.

- **Do:** a unit table test covers every tax bracket. One API test checks
  that a request comes back with the bracket the calculator chose.
- **Don't:** an end-to-end test for every bracket, re-running the unit
  table through the HTTP stack and the database.

### 5. Don't test the language, the framework or other people's tools

The standard library, the web framework, the validation library and another
tool's CLI have their own test suites. Test what your code does with them.

- **Do:** assert that your handler rejects a request missing a required field,
  because your schema declares it required.
- **Don't:** assert that a dataclass stores the field you passed it, that a
  dict lookup returns the value set, or that `git status` exits 0 in a clean
  repo.

### 6. Don't mirror data or prose

No assertion that a constant equals the literal it was copied from, and no grep
of a doc or a prompt for a sentence. Such a test fails on every intended edit
and on no bug. A doc that must stay true to the code gets one dedicated check,
or is generated from the code.

- **Do:** one check that every flag the CLI accepts appears in its help text,
  derived from the parser.
- **Don't:** `assert TAX_RATE == 0.22`, or `assert "Run the setup script" in
  readme`.

### 7. Expected values come from an independent source

The expected value comes from a spec, a hand-worked example, a closed-form
result, or an invariant. It never comes from running the code and pasting what
it printed: that test passes on the bug it was pasted from.

Numeric and model code often has no independent exact value past one or two
hand-worked cases. There, assert relationships instead: the result moves in
the right direction when an input moves, stays monotonic across a range, or
keeps a known ratio. Keep at least one anchored value alongside them. A
direction holds for a function that is wrong by a factor of two, and only an
anchored value catches that.

- **Do:** a loan schedule checked against the amortization formula, a round
  trip that asserts `decode(encode(x)) == x`, or a projection test asserting
  that a higher savings rate never gives a smaller ending balance, next to one
  hand-worked case.
- **Don't:** run the function, copy its output into the assertion, and call it
  a regression test, or pin a projection to `1_284_331.07` that nobody worked
  out by hand.

### 8. Assert on outputs and observable effects, not on mock calls

Assert what the code returns, writes, or sends. An assertion on the arguments a
mock received restates the implementation, so it breaks on a refactor and
passes on a wrong result. Prefer a stateful fake, such as an in-memory store
the test can read back, over a mock.

- **Do:** save through the fake repository, then assert that loading the
  record returns the saved values.
- **Don't:** `mock_db.insert.assert_called_once_with({...})` as the only
  assertion.

### 9. Cost is part of the design

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

### 10. A bug fix brings one regression test

The fix adds one test that fails before the fix and passes after it. It does
not add variations on that input that take the same path.

- **Do:** one test reproducing the reported input.
- **Don't:** five near-copies of it with the numbers nudged.

### 11. A coverage gate is never a reason to write a test

A test written to move a coverage number is written without a bug in mind,
which breaks rule 1. How a repo handles an uncovered line instead, whether by
excluding it, gating on diff coverage, or lowering the floor, is the call of
that repo's own coverage policy.

- **Do:** leave the line uncovered and follow the repo's policy for it.
- **Don't:** call a function with arbitrary arguments and assert it doesn't
  raise, so the line counts as hit.

### 12. Deleting a redundant test is a normal change

A test that no longer earns its cost under these rules can be removed. The
change names the test that still covers the behaviour, or says the behaviour
needs no test and why. This is not the same as deleting a test to make a
failing check pass, which stays forbidden.

When pruning, start with the expensive tests: integration and end-to-end
tests, tests that spawn a process, and tests that build a heavy fixture. They
are where a duplicate costs the most, and they are the usual place a lower
test's cases get repeated (rule 4). Spend a pruning pass on the slow tests
first. A fast duplicate is still worth merging when you are already in the
file.

- **Do:** "Removes `test_parse_two`; `test_parse_table` covers the same path
  with the two-item row," or "Drops the eight bracket rows from the API
  suite; the calculator's unit table covers them, and one API case still
  checks the wiring."
- **Don't:** delete a failing test so CI goes green, or spend a pruning pass
  on fast unit tests while a slow end-to-end suite repeats them.

## Reviewing tests

For each test a change adds or edits, ask:

1. What realistic bug makes this test fail? (rule 1)
2. Can the state it sets up happen, or start to happen? (rule 2)
3. Does another case already take the same path, or build the same setup?
   Are its inputs at the boundaries? (rule 3)
4. Is it at the lowest level that can see the behaviour, or does it repeat a
   lower test? (rule 4)
5. Is it testing our code, or the language, the framework or another tool?
   (rule 5)
6. Is it asserting that data or prose equals a copy of itself? (rule 6)
7. Where did the expected value come from: an independent source, or the
   code's own output? (rule 7)
8. Does it assert a result or an effect, or only the calls a mock received?
   (rule 8)

A test that fails one of these is a finding. Suggest merging it into an
existing case, moving it down a level, or deleting it, and name the test that
covers the behaviour. Look hardest at the expensive tests: a slow test that
fails a question costs more than a fast one (rules 9 and 12).
