#!/usr/bin/env python3
"""Checks a repo's dev_docs/ against the layout in dev_docs_layout.md.

Run: scripts/dev-docs-layout.py [ROOT]

ROOT is the repository root and defaults to the current directory. A ROOT with
no dev_docs/ has nothing to check and passes. Every violation is one line on
stdout, `path: what is wrong`, and the exit status is 1 when there is any.

The checks, each one the Enforcement section of dev_docs_layout.md names:

1. dev_docs/tasks/ holds only .task-config*.yml files, <name>_plan/
   directories, and flat <slug>.md cards. A dot-prefixed entry belongs to a
   tool rather than to an agent, so it is skipped; .task-config* is matched
   ahead of that skip, so a near miss like .task-config.yaml is still
   reported.
2. No unchecked `- [ ]` under dev_docs/ outside dev_docs/tasks/*_plan/. Lines
   inside a fenced code block are not counted, so a README's template can
   show the syntax.
3. Every entry in a record or design directory, which is every directory under
   dev_docs/ other than tasks/, is YYYY-MM-DD-<slug>.md, a YYYY-MM-DD-<slug>/
   bundle directory, or README.md. Slugs are kebab-case, lowercase, ASCII.
4. A bundle directory holds README.md, which is the record, and references/,
   which holds its artifacts and is not inspected further. No flat
   YYYY-MM-DD-<slug>.md sits beside a bundle of the same name: the directory
   replaces the file, so both together are one date and slug naming two
   records. The converse is not checked — a bundle whose artifacts are all
   gitignored, or not added yet, is indistinguishable from one with none.
5. A record's `created` front-matter field equals the date in its filename, or
   in its bundle directory's name.
6. A decision record has a `## Revisit when` section.

Undated subdirectories of research/ are skipped by checks 2 and 3: the
research-spike skill owns those trees, keeps a question ledger with checkboxes
in it, and validates them itself. A dated one is a record bundle and is
checked, which is what the date distinguishes.

Nothing under a references/ tree is checked at all. Its contents are evidence
frozen with the record that cites them -- a probe script, a capture, a result
table -- in whatever shape and nesting the evidence came in.

Which files count. Inside a git repository the checks read what git sees:
tracked files plus untracked files that .gitignore does not exclude, so a
skill's ignored config directory and a locally ignored plan never fail a check
that CI would pass. Outside a repository, or when git is not on PATH, the
directory is walked as is. Check 1 always walks the filesystem: an ignored
plan directory is legitimate content there, and a stray file is stray whether
or not anyone committed it. Neither reader descends into a dot-prefixed entry
under tasks/: that entry belongs to a tool, so its contents are no check's to
judge, and outside a repository nothing else would filter them out.
"""

import datetime
import os
import pathlib
import re
import subprocess
import sys

CONVENTION = "dev_docs_layout.md in the agent-guidance plugin"

SLUG = r"(\d{4}-\d{2}-\d{2})-(?:[a-z0-9]+(?:-[a-z0-9]+)*)"
RECORD_NAME = re.compile(rf"^{SLUG}\.md$")
# A record that carries artifacts is a directory with the same name, minus the
# .md: README.md is the record and references/ holds the artifacts.
BUNDLE_NAME = re.compile(rf"^{SLUG}$")
REFERENCES = "references"
CHECKBOX = re.compile(r"^\s*[-*+] \[ \]")
FENCE = re.compile(r"^\s*(`{3,}|~{3,})")
CREATED = re.compile(r"^created:\s*(.*?)\s*$")
REVISIT = re.compile(r"^## Revisit when\s*$")

# macOS Finder writes this into any directory it displays, so it appears on a
# clean checkout without anyone committing anything. Skipped by name.
FINDER_NOISE = {".DS_Store"}


def git_files(root: pathlib.Path):
    """Paths under dev_docs/ that git sees, relative to root, or None if not a repo."""
    try:
        top = subprocess.run(
            ["git", "-C", str(root), "rev-parse", "--show-toplevel"],
            capture_output=True,
            text=True,
            check=True,
        ).stdout.strip()
        if not top:
            return None
        out = subprocess.run(
            ["git", "-C", str(root), "ls-files", "-z", "--cached", "--others",
             "--exclude-standard", "--", "dev_docs"],
            capture_output=True,
            check=True,
        ).stdout
    except (OSError, subprocess.CalledProcessError):
        return None
    files = []
    for raw in out.split(b"\0"):
        if not raw:
            continue
        rel = pathlib.Path(os.fsdecode(raw))
        # A tracked file deleted in the working tree is still listed.
        if (root / rel).is_file() and rel.name not in FINDER_NOISE \
                and not in_tool_entry(rel):
            files.append(rel)
    return files


def walked_files(root: pathlib.Path):
    files = []
    for dirpath, _, names in os.walk(root / "dev_docs"):
        for name in names:
            if name in FINDER_NOISE:
                continue
            rel = pathlib.Path(dirpath, name).relative_to(root)
            if in_tool_entry(rel):
                continue
            files.append(rel)
    return files


def front_matter(text: str):
    """The lines between the opening and closing --- fences, or None."""
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return None
    for i in range(1, len(lines)):
        if lines[i].strip() == "---":
            return lines[1:i]
    return None


def created_value(text: str):
    fm = front_matter(text)
    if fm is None:
        return None
    for line in fm:
        m = CREATED.match(line)
        if m:
            return m.group(1).strip("\"'")
    return None


def in_tool_entry(rel: pathlib.Path) -> bool:
    """A file under a dot-prefixed entry in dev_docs/tasks/, which check_tasks
    skips for the same reason: the entry belongs to a tool, not to an agent,
    so its contents are no check's to judge. It is filtered where the file
    list is built rather than inside one check, because the checks that read
    that list inherit whatever it admits — check_checkboxes is the only one
    that reaches in today, and the next one would be silent about it.

    Scoped to tasks/ deliberately. A .claude/ under a record directory is a
    genuine violation and check 3 should keep reporting it."""
    parts = rel.parts
    return len(parts) > 2 and parts[1] == "tasks" and parts[2].startswith(".")


def in_plan_dir(rel: pathlib.Path) -> bool:
    parts = rel.parts
    return len(parts) > 3 and parts[1] == "tasks" and parts[2].endswith("_plan")


def in_research_spike(rel: pathlib.Path) -> bool:
    """A file inside an undated subdirectory of dev_docs/research/, which the
    research-spike skill owns and validates itself. A dated subdirectory is a
    record bundle, which this checker owns."""
    parts = rel.parts
    return (
        len(parts) > 3
        and parts[1] == "research"
        and not BUNDLE_NAME.match(parts[2])
    )


def in_references(rel: pathlib.Path) -> bool:
    """A file inside a record bundle's references/ tree: evidence frozen with
    the record, in whatever shape it came in, at any depth."""
    parts = rel.parts
    return (
        len(parts) > 4
        and parts[1] != "tasks"
        and bool(BUNDLE_NAME.match(parts[2]))
        and parts[3] == REFERENCES
    )


def check_tasks(root: pathlib.Path, report):
    tasks = root / "dev_docs" / "tasks"
    if not tasks.is_dir():
        return
    for entry in sorted(tasks.iterdir()):
        name = entry.name
        rel = entry.relative_to(root)
        # A leading dot means the entry belongs to a tool, and this check is
        # about what an agent authors here. Harness and editor directories
        # (.claude/, .codex/, .idea/) land in whatever cwd they were launched
        # from, and that set is open, so naming them one at a time accumulates
        # an arm per tool forever. Asking git instead is worse: under every
        # handler but repo-pr this convention has .gitignore carry
        # dev_docs/tasks/*, so "skip what git ignores" would check nothing at
        # all in the one directory this rule is for — which is why check 1
        # walks the filesystem, and why the suite pins that with a fixture.
        #
        # .task-config*.yml is the one dot-entry the checker RECOGNISES rather
        # than merely tolerates, so it is matched ahead of the skip: a near
        # miss like .task-config.yaml is reported, not swallowed as tooling.
        if name.startswith(".task-config"):
            if entry.is_dir() or not name.endswith(".yml"):
                report(rel, "only .task-config*.yml and <slug>.md cards belong loose under dev_docs/tasks/")
            continue
        if name.startswith("."):
            continue
        if entry.is_dir():
            if not name.endswith("_plan"):
                report(rel, "only <name>_plan/ directories belong under dev_docs/tasks/")
        elif name.endswith(".md"):
            continue
        else:
            report(rel, "only .task-config*.yml and <slug>.md cards belong loose under dev_docs/tasks/")


def check_checkboxes(root: pathlib.Path, files, report):
    for rel in files:
        if (rel.suffix != ".md" or in_plan_dir(rel) or in_research_spike(rel)
                or in_references(rel)):
            continue
        fence = None
        try:
            lines = (root / rel).read_text(encoding="utf-8", errors="replace").splitlines()
        except OSError as e:
            report(rel, f"unreadable: {e}")
            continue
        for n, line in enumerate(lines, 1):
            m = FENCE.match(line)
            if m:
                marker = m.group(1)
                if fence is None:
                    fence = marker
                elif marker[0] == fence[0] and len(marker) >= len(fence):
                    fence = None
                continue
            if fence is None and CHECKBOX.match(line):
                report(rel, f"line {n}: unchecked checkbox outside dev_docs/tasks/*_plan/; a backlog is not a dev_doc")


def check_record_body(root: pathlib.Path, rel: pathlib.Path, date: str,
                      directory: str, report):
    """The front matter and section rules, for a flat record or a bundle's
    README.md. DATE is the date the filename or the bundle name carries."""
    try:
        datetime.date.fromisoformat(date)
    except ValueError:
        report(rel, f"{date} is not a calendar date")
        return
    try:
        text = (root / rel).read_text(encoding="utf-8", errors="replace")
    except OSError as e:
        report(rel, f"unreadable: {e}")
        return
    created = created_value(text)
    if created is None:
        report(rel, "no `created:` in the front matter; every record carries one")
    elif created != date:
        report(rel, f"created: {created} does not match the record's date {date}")
    if directory == "decisions" and not any(REVISIT.match(l) for l in text.splitlines()):
        report(rel, "no `## Revisit when` section; a decision says what would reopen it")


def check_records(root: pathlib.Path, files, report):
    # Bundle directories seen, and whether each one's README.md turned up: a
    # bundle without its record is artifacts nothing explains.
    bundles = {}
    # Flat records, keyed by the path minus the .md, which is byte-identical to
    # the key a bundle of the same name gets. Compared at the end rather than on
    # encounter, because the flat file and the bundle's files interleave in the
    # listing and the verdict must not depend on which came first.
    flats = set()
    for rel in files:
        parts = rel.parts
        if len(parts) < 3 or parts[1] == "tasks":
            continue
        directory = parts[1]
        name = parts[2]
        bundle = BUNDLE_NAME.match(name)
        if len(parts) > 3:
            if bundle:
                bundle_dir = pathlib.Path(*parts[:3])
                bundles.setdefault(bundle_dir, False)
                if in_references(rel):
                    continue
                if len(parts) == 4 and parts[3] == "README.md":
                    bundles[bundle_dir] = True
                    check_record_body(root, rel, bundle.group(1), directory, report)
                    continue
                report(rel, f"a record bundle holds README.md and references/, nothing else; see {CONVENTION}")
                continue
            if in_research_spike(rel):
                continue
            report(rel, f"a subdirectory is not allowed under dev_docs/{directory}/")
            continue
        if name == "README.md":
            continue
        m = RECORD_NAME.match(name)
        if not m:
            report(rel, f"not YYYY-MM-DD-<slug>.md (kebab-case, lowercase) or README.md; dev_docs/{directory}/ holds records")
            continue
        flats.add(rel.with_suffix(""))
        check_record_body(root, rel, m.group(1), directory, report)
    for bundle, has_readme in sorted(bundles.items()):
        if not has_readme:
            report(bundle, "a record bundle's README.md is the record; this one has artifacts and no record")
        if bundle in flats:
            report(bundle, f"also exists as {bundle.name}.md; a record is a flat file or a bundle, never both; see {CONVENTION}")


def main(argv):
    if len(argv) > 2 or argv[1:] in (["-h"], ["--help"]):
        print(__doc__.strip().splitlines()[0])
        print("Run: scripts/dev-docs-layout.py [ROOT]")
        return 0 if argv[1:] in (["-h"], ["--help"]) else 2
    root = pathlib.Path(argv[1] if len(argv) == 2 else ".").resolve()
    if not (root / "dev_docs").is_dir():
        print(f"{root}: no dev_docs/, nothing to check")
        return 0

    violations = []

    def report(rel, message):
        violations.append(f"{rel.as_posix()}: {message}")

    files = git_files(root)
    if files is None:
        files = walked_files(root)
    files.sort()

    check_tasks(root, report)
    check_checkboxes(root, files, report)
    check_records(root, files, report)

    for v in violations:
        print(v)
    if violations:
        print(f"{len(violations)} layout violation(s); see {CONVENTION}")
        return 1
    print(f"dev_docs/ layout ok ({len(files)} files)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
