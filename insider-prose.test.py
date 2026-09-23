#!/usr/bin/env python3
"""Fixtures for scripts/insider_prose.py. Run by insider-prose.test.sh.

Reads the repo root from ROOT, set by the wrapper.

The good cases are the load-bearing half. A detector that fires on a correct
rewrite is worse than one that misses, because a false positive teaches its
reader to stop reading it, and the design's rule is that a signal firing on a
good case is dropped rather than tuned. So a good case failing here is not a
prompt to loosen the regex; it is the signal's obituary.

The bad cases are not symmetrical with them, and that asymmetry is deliberate.
Only one of the four is reachable by the one signal that survived design: the
mechanical tier detects a dangling `the same N <noun>` and nothing else. Shape
1, historical narrative, has no mechanical tier at all and rests on the
once-per-session pointer. Those cases are still carried, as an executable
statement of where the boundary sits, but a miss on them is reported rather
than asserted -- a future signal that catches one is an improvement, and a
suite that failed on it would be arguing against its own design.
"""

import os
import sys

root = os.environ["ROOT"]
sys.path.insert(0, os.path.join(root, "scripts"))

import insider_prose  # noqa: E402  (path set above)

fails = 0


def check(name, text, *, expect_hit):
    """Assert whether the detector fires. Returns the findings either way."""
    global fails
    findings = insider_prose.scan(text)
    hit = bool(findings)
    if hit == expect_hit:
        print(f"ok   {name}")
    else:
        fails += 1
        want = "a finding" if expect_hit else "no finding"
        print(f"FAIL {name}: expected {want}, got {findings!r}")
    return findings


def report(name, text):
    """Record where the mechanical tier does not reach, without asserting it."""
    findings = insider_prose.scan(text)
    reach = "reaches" if findings else "does not reach"
    print(f"note {name}: the detector {reach} this ({len(findings)} findings)")


# --- bad-1: issue #62's first example, verbatim. Shape 1. -------------------
# Historical narrative: it orients the reader in the history of the work rather
# than in the change, and opens on a section number they cannot resolve.
BAD_1 = (
    "Section 1 of the 2026-09-17 Jev record was the best-rated of its seven "
    "candidates and the only one left with no decision either way. It proposed "
    "replacing scripts/eval.sh with one typed Choice over the skill "
    "descriptions, on evidence that was never the comparison "
    "typed-model-calls.md rule 1 asks for."
)

# --- bad-2: issue #62's second example, verbatim. Shape 2. -----------------
# Every clause is a lookup. "The same 14 rows" as what; which two rows it won.
BAD_2 = (
    "On the same 14 rows the typed call scored 14/14 in four passes against "
    "the harness's 10/14 then 12/14 -- but two of the rows it \"won\" are "
    "skills that invoked nothing at all."
)

# --- bad-3: a SKILL.md opener recounting its own design history. Shape 1. ---
BAD_3 = (
    "This skill began as three separate commands that shared a config loader. "
    "The loader was extracted first, then the commands were merged one at a "
    "time as their flags converged."
)

# --- bad-4: a decision record pointing at "the other two". Shape 2. --------
# A dangling reference the surviving regex does not match: the form is "the
# other two", not "the same N <noun>".
BAD_4 = (
    "The other two were rejected for the same reason, so this record covers "
    "all three."
)

# --- good-1: bad-1 rewritten. States what the change does. ----------------
GOOD_1 = (
    "Replace scripts/eval.sh with a typed call over the skill descriptions. "
    "The comparison against the current harness is in "
    "references/eval-comparison.md: the typed call named the right skill for "
    "all 14 prompts, the harness for 10 and then 12."
)

# --- good-2: bad-2 rewritten. Every reference resolves in the text. -------
GOOD_2 = (
    "Over the 14 prompts in references/prompts.md, the typed call named the "
    "right skill every time across four passes. The harness named it for 10 "
    "and then 12. Two of the prompts the typed call won are skills that "
    "invoked nothing at all: summarise-thread and rank-candidates."
)

# --- good-3: bad-3 rewritten. States what the skill is now. ---------------
GOOD_3 = (
    "This skill loads its config once and dispatches on the subcommand. The "
    "flags are shared, so a flag added to one subcommand is available to all "
    "of them."
)

# --- good-4: a resolved `the same N <noun>`, which the regex cannot see. --
# The antecedent is named in the previous sentence, so this is correct prose.
# The detector fires on it anyway -- it reports "go check the antecedent", not
# "there is none" -- which is why the check reports and never fails the build.
GOOD_4 = (
    "The baseline covered 14 rows. The candidate covered the same 14 rows."
)

print("-- good cases: a firing here kills the signal --")
check("good-1 (bad-1 rewritten)", GOOD_1, expect_hit=False)
check("good-2 (bad-2 rewritten)", GOOD_2, expect_hit=False)
check("good-3 (bad-3 rewritten)", GOOD_3, expect_hit=False)

print()
print("-- bad case the mechanical tier reaches --")
check("bad-2 (dangling 'the same 14 rows')", BAD_2, expect_hit=True)

print()
print("-- where the mechanical tier stops, reported not asserted --")
report("bad-1 (historical narrative)", BAD_1)
report("bad-3 (historical narrative)", BAD_3)
report("bad-4 (dangling, different form)", BAD_4)
report("good-4 (resolved antecedent)", GOOD_4)

print()
if fails:
    print(f"FAIL: {fails} case(s)")
    sys.exit(1)
print("ok: fixtures pass")
