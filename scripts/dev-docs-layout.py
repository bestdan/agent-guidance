#!/usr/bin/env python3
"""Checks a repo's dev_docs/ against the layout in dev_docs_layout.md.

Run: scripts/dev-docs-layout.py [--write-index] [ROOT]

With --write-index it checks nothing: it writes INDEX.md in every record
directory (check 9), creating it where it is absent, and names each file it
wrote. INDEX.md is the only file it writes. It exits 0 unless it cannot read
or write an INDEX.md: a record it could not index (its date is not a calendar
date, or it is unreadable) is named on stderr, and the plain check is what
fails on it.

ROOT is the repository root and defaults to the current directory. A ROOT with
no dev_docs/ anywhere under it has nothing to check and passes. Every violation
is one line on stdout, `path: what is wrong` with the path relative to ROOT,
and the exit status is 1 when there is any.

A monorepo package's dev_docs/ (`<package>/dev_docs/`) is found without being
named and gets every check below except the first; in its place, a package's
dev_docs/ holding tasks/ or .handoffs/ fails, because the tooling that owns
each resolves one location. A dev_docs/ inside another dev_docs/ is not a
package: it is content of the outer tree, and the outer tree's checks judge it.

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
   bundle directory, README.md, or the generated INDEX.md. Slugs are
   kebab-case, lowercase, ASCII.
4. A bundle directory holds README.md, which is the record, and references/,
   which holds its artifacts and is not inspected further. No flat
   YYYY-MM-DD-<slug>.md sits beside a bundle of the same name: the directory
   replaces the file, so both together are one date and slug naming two
   records. The converse is not checked — a bundle whose artifacts are all
   gitignored, or not added yet, is indistinguishable from one with none.
5. A record's `created` front-matter field equals the date in its filename, or
   in its bundle directory's name.
6. A decision record has a `## Revisit when` section. Every record has exactly
   one `# ` heading outside code blocks, which the index lists as its title. A
   decision's `status` is accepted, superseded or deprecated, and a design's
   is proposed. A front-matter field that names a file (a decision's
   `convention`, `supersedes` and `superseded_by`; research's `feeds`)
   resolves from the record's own directory, unless it is a URL.
7. A decision's `supersedes` and `superseded_by` name each other, a record
   with `superseded_by` is `status: superseded`, and one that is superseded
   names its replacement.
8. Every relative link in a dev_docs/ markdown file, inline or a reference
   definition, resolves to a file; the anchor is not checked. Links in code
   spans and fenced blocks are not links. A filename quoted in backticks is
   not a link and is not checked: records cite deleted designs and other
   repos' records that way, and a record cannot be rewritten to drop one.
9. A record directory's INDEX.md is exactly what --write-index would write
   there: the directory's records, newest first, each linked by its title. A
   directory without an INDEX.md has no index and is not checked; running
   --write-index once is how a repo opts in. The header comment names the
   command that regenerates the index, and is the one line allowed to differ:
   a repo that vendors its own generator names that, and both this check and
   --write-index keep the command an existing index names.

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
that CI would pass. That includes discovery: a package's dev_docs/ is found by
the files in it git sees, so one whose every file is ignored is not checked.
Outside a repository, or when git is not on PATH, the directory is walked as
is, without entering dot-prefixed directories. Check 1 always walks the
filesystem: an ignored plan directory is legitimate content there, and a stray
file is stray whether or not anyone committed it; the package check for tasks/
and .handoffs/ reads the filesystem for the same reason. Neither reader
descends into a dot-prefixed entry under tasks/: that entry belongs to a tool,
so its contents are no check's to judge, and outside a repository nothing else
would filter them out.
"""

import dataclasses
import datetime
import os
import pathlib
import re
import subprocess
import sys
import unicodedata
import urllib.parse

CONVENTION = "dev_docs_layout.md in the agent-guidance plugin"
USAGE = "Run: scripts/dev-docs-layout.py [--write-index] [ROOT]"

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
FIELD = re.compile(r"^([A-Za-z_][A-Za-z0-9_-]*):\s*(.*?)\s*$")
H1 = re.compile(r"^# (.+?)(?:\s+#+)?\s*$")
CODE_SPAN = re.compile(r"(`+).*?\1")
# The target is <...> (which may hold spaces and parentheses) or a bare run
# allowing one level of balanced parentheses; the title is any of CommonMark's
# three forms. Group 1 or 2 is the target.
INLINE_LINK = re.compile(
    r"!?\[[^\]]*\]\(\s*(?:<([^>\n]+)>|((?:[^()\s<>]|\([^()\s]*\))+))"
    r"(?:\s+(?:\"[^\"]*\"|'[^']*'|\([^)]*\)))?\s*\)")
# A reference definition, but not a footnote (`[^1]: text`), whose text is
# prose rather than a target. Group 1 or 2 is the target.
REF_LINK = re.compile(r"^\s{0,3}\[(?!\^)[^\]]+\]:\s*(?:<([^>\n]+)>|(\S+))")
SCHEME = re.compile(r"^[A-Za-z][A-Za-z0-9+.-]*:")
DECISION_STATUSES = ("accepted", "superseded", "deprecated")
DESIGN_STATUSES = ("proposed",)
# Front-matter fields that name another file, relative to the record's own
# directory, per directory.
PATH_FIELDS = {
    "decisions": ("convention", "supersedes", "superseded_by"),
    "research": ("feeds",),
}
INDEX = "INDEX.md"
# The INDEX.md header names the command that regenerates the file. This
# script's own is the default; a repo that vendors its own generator names that
# one instead, and both check 9 and --write-index keep whatever command an
# existing index names, so the header is the only part of the file they allow
# to differ.
INDEX_COMMAND = "scripts/dev-docs-layout.py --write-index"
INDEX_NOTE_TAIL = " from each record's front matter and title. Edit the records, not this file. -->"
INDEX_NOTE_LINE = re.compile(r"^<!-- Generated by (.+?)" + re.escape(INDEX_NOTE_TAIL) + "$")
# Entries only the repository root's dev_docs/ may hold.
ROOT_ONLY = ("tasks", ".handoffs")

# macOS Finder writes this into any directory it displays, so it appears on a
# clean checkout without anyone committing anything. Skipped by name.
FINDER_NOISE = {".DS_Store"}


def git_listing(root: pathlib.Path):
    """The dev_docs/ files git sees under root, grouped by the directory that
    holds their dev_docs/, or None if root is not in a repository.

    Returns {package: [path relative to package]}, where package is relative
    to root and is `.` for the root's own dev_docs/. The first dev_docs
    component of a path decides its package, so a dev_docs/ nested inside
    another one is content of the outer tree rather than a package."""
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
             "--exclude-standard", "--", ":(glob)**/dev_docs/**"],
            capture_output=True,
            check=True,
        ).stdout
    except (OSError, subprocess.CalledProcessError):
        return None
    groups = {}
    for raw in out.split(b"\0"):
        if not raw:
            continue
        rel = pathlib.Path(os.fsdecode(raw))
        # The pathspec only matches a dev_docs that has something below it, so
        # its first occurrence is always a directory.
        i = rel.parts.index("dev_docs")
        package = pathlib.Path(*rel.parts[:i])
        inner = pathlib.Path(*rel.parts[i:])
        # Registered before the filter: a package whose only file is its
        # tasks/.task-config.yml still has to reach check_root_only.
        files = groups.setdefault(package, [])
        # A tracked file deleted in the working tree is still listed.
        if (root / rel).is_file() and rel.name not in FINDER_NOISE \
                and not in_tool_entry(inner):
            files.append(inner)
    return groups


def walked_listing(root: pathlib.Path):
    """git_listing's shape, read from the filesystem. Dot-prefixed directories
    are not entered: they belong to tools, and a harness's worktree under
    .claude/ carries a whole second copy of the repository."""
    groups = {}
    for dirpath, dirnames, _ in os.walk(root):
        if "dev_docs" in dirnames:
            package = pathlib.Path(dirpath).relative_to(root)
            groups[package] = walked_files(root / package)
        # Not descending into dev_docs/ is what keeps a nested one from
        # counting as a package; walked_files reads its whole tree.
        dirnames[:] = [d for d in dirnames
                       if d != "dev_docs" and not d.startswith(".")]
    return groups


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


def fields(text: str) -> dict:
    """Top-level `key: value` pairs of the front matter, with a trailing YAML
    comment and surrounding quotes removed. Enough for the flat fields records
    carry; not a YAML parser. YAML escapes are not interpreted, so `'it''s'`
    reads as `it''s` and `"a \\"b\\""` keeps its backslashes. Only an index
    cell shows such a value, and the check reads it the same way."""
    out = {}
    for line in front_matter(text) or []:
        m = FIELD.match(line)
        if not m:
            continue
        value = m.group(2)
        quote = value[:1]
        close = value.find(quote, 1) if quote in ("\"", "'") else -1
        rest = value[close + 1:].strip() if close > 0 else None
        if rest is not None and (rest == "" or rest.startswith("#")):
            value = value[1:close]
        else:
            value = re.sub(r"\s+#.*$", "", value).strip()
            if len(value) > 1 and value[0] in ("\"", "'") and value[-1] == value[0]:
                value = value[1:-1]
        out[m.group(1)] = value
    return out


def prose_lines(text: str):
    """(line number, line) for each line outside the front matter and outside
    fenced code blocks, so a README's template is not read as content."""
    lines = text.splitlines()
    start = 0
    fm = front_matter(text)
    if fm is not None:
        start = len(fm) + 2
    fence = None
    for n in range(start, len(lines)):
        line = lines[n]
        m = FENCE.match(line)
        if m:
            marker = m.group(1)
            if fence is None:
                fence = marker
            elif marker[0] == fence[0] and len(marker) >= len(fence):
                fence = None
            continue
        if fence is None:
            yield n + 1, line


def titles(text: str):
    return [m.group(1) for _, ln in prose_lines(text) if (m := H1.match(ln))]


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


def check_root_only(root: pathlib.Path, report):
    """A package's dev_docs/ has no tasks/ and no .handoffs/: the tooling that
    owns each resolves one location, the repository root's. Read from the
    filesystem, like check 1, because both are usually gitignored."""
    for name in ROOT_ONLY:
        entry = root / "dev_docs" / name
        if entry.exists():
            report(entry.relative_to(root),
                   f"{name}/ belongs only in the repository root's dev_docs/; see {CONVENTION}")


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
    if directory == "decisions" and not any(REVISIT.match(ln) for ln in text.splitlines()):
        report(rel, "no `## Revisit when` section; a decision says what would reopen it")
    heads = titles(text)
    if len(heads) != 1:
        report(rel, f"{len(heads)} `# ` headings outside code blocks; a record has exactly one, its title, which the index lists")
    meta = fields(text)
    allowed = {"decisions": DECISION_STATUSES, "designs": DESIGN_STATUSES}.get(directory)
    status = meta.get("status", "")
    if allowed and status not in allowed:
        shown = f"status: {status}" if status else "no `status:`"
        report(rel, f"{shown}; a record in {directory}/ is one of {', '.join(allowed)}")
    for key in PATH_FIELDS.get(directory, ()):
        value = meta.get(key, "")
        if value and not SCHEME.match(value) and not (root / rel).parent.joinpath(value).exists():
            report(rel, f"{key}: {value} does not exist, relative to this record")
    return Record(rel, date, directory, heads[0] if heads else rel.stem, meta)


@dataclasses.dataclass
class Record:
    rel: pathlib.Path
    date: str
    directory: str
    title: str
    meta: dict

    @property
    def link(self) -> str:
        """The link a README in the record's directory uses for it."""
        if self.rel.name == "README.md":
            return f"{self.rel.parent.name}/"
        return self.rel.name


def record_key(path: pathlib.Path) -> str:
    """The identity of the record PATH names, so a bundle directory, its
    README.md, and a trailing slash all compare equal. Compare only keys built
    from paths of the same kind, all absolute or all relative to one base."""
    path = pathlib.Path(os.path.normpath(path))
    if path.name == "README.md":
        path = path.parent
    elif path.suffix == ".md":
        path = path.with_suffix("")
    return path.as_posix()


def check_supersession(root: pathlib.Path, records, report):
    """Check 7: supersedes and superseded_by name each other, and status agrees
    with superseded_by. A dangling target is check_record_body's to report."""
    by_key = {record_key(root / r.rel): r for r in records if r.directory == "decisions"}
    for key, r in sorted(by_key.items()):
        status = r.meta.get("status", "")
        newer = r.meta.get("superseded_by", "")
        older = r.meta.get("supersedes", "")
        if status == "superseded" and not newer:
            report(r.rel, "status: superseded with no `superseded_by:`; name the record that replaced it")
        if newer and status != "superseded":
            report(r.rel, f"superseded_by: {newer} but status: {status or '(none)'}; a replaced record is status: superseded")
        for field, back, value in (("superseded_by", "supersedes", newer),
                                   ("supersedes", "superseded_by", older)):
            if not value:
                continue
            other = by_key.get(record_key((root / r.rel).parent / value))
            if other is None:
                continue
            target = other.meta.get(back, "")
            if not target or record_key((root / other.rel).parent / target) != key:
                report(r.rel, f"{field}: {value}, but that record's `{back}:` does not name this one")


def link_targets(text: str):
    """(line number, target) for each link in prose: inline, image and
    reference-definition links, with code spans removed first so a link shown
    as code is not read as one."""
    for n, line in prose_lines(text):
        bare = CODE_SPAN.sub("", line)
        for m in INLINE_LINK.finditer(bare):
            yield n, m.group(1) or m.group(2)
        m = REF_LINK.match(bare)
        if m:
            yield n, m.group(1) or m.group(2)


def check_links(root: pathlib.Path, files, report):
    """Check 8: every relative link in a dev_docs/ markdown file resolves. The
    anchor is not checked, only the file. Plans, spikes and references/ are
    other owners' content and are skipped as the other checks skip them."""
    for rel in files:
        if (rel.suffix != ".md" or in_plan_dir(rel) or in_research_spike(rel)
                or in_references(rel) or rel.parts[1:2] == ("tasks",)):
            continue
        try:
            text = (root / rel).read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        for n, target in link_targets(text):
            # A root-relative target resolves against the repository on GitHub,
            # which a package's base cannot stand in for, so it is not checked.
            if target.startswith(("#", "/")) or SCHEME.match(target):
                continue
            path = urllib.parse.unquote(target.split("#", 1)[0].split("?", 1)[0])
            if path and not (root / rel).parent.joinpath(path).exists():
                report(rel, f"line {n}: link to {target}, which does not exist")


def cell(text: str) -> str:
    return text.replace("|", "\\|")


def label(text: str) -> str:
    """TEXT as a table cell's link text: a backslash, `[` or `]` is escaped
    too, so an unbalanced bracket in a title cannot end the link early."""
    return cell(text.replace("\\", "\\\\").replace("[", "\\[").replace("]", "\\]"))


def display_width(text: str) -> int:
    """Terminal columns TEXT takes, which is what dprint pads a table cell to:
    a wide or full-width character counts two; a nonspacing or enclosing mark,
    a Hangul medial or final jamo, a zero-width space, joiner, word joiner or
    byte-order mark, or a variation selector counts none. Each rule was checked
    against dprint's markdown plugin 0.22.1; a soft hyphen, which it counts as
    one, stays one."""
    total = 0
    for c in text:
        o = ord(c)
        if (unicodedata.category(c) in ("Mn", "Me") or unicodedata.combining(c)
                or 0x1160 <= o <= 0x11FF or 0xD7B0 <= o <= 0xD7FF
                or 0x200B <= o <= 0x200F or 0x2060 <= o <= 0x2064 or o == 0xFEFF
                or 0xFE00 <= o <= 0xFE0F):
            continue
        total += 2 if unicodedata.east_asian_width(c) in ("W", "F") else 1
    return total


def table(header, rows):
    """A markdown table padded the way dprint pads one, so the generated file
    is already in the form the formatter would leave it."""
    widths = [max(3, display_width(h), *(display_width(r[i]) for r in rows))
              for i, h in enumerate(header)]

    def line(cells):
        return "| " + " | ".join(c + " " * (w - display_width(c))
                                 for c, w in zip(cells, widths)) + " |"

    return [line(header), line(["-" * w for w in widths]), *(line(r) for r in rows)]


def index_note(command: str) -> str:
    """The INDEX.md header comment naming COMMAND as what regenerates it."""
    return f"<!-- Generated by {command}{INDEX_NOTE_TAIL}"


def index_command(text: str) -> str:
    """The regenerating command an existing INDEX.md's header names, or this
    script's own when TEXT has no such header."""
    for line in text.splitlines():
        m = INDEX_NOTE_LINE.match(line)
        if m:
            return m.group(1)
    return INDEX_COMMAND


def render_index(directory: str, records, spikes, command: str = INDEX_COMMAND) -> str:
    """The INDEX.md for DIRECTORY, newest record first, its header naming
    COMMAND as what regenerates it."""
    records = sorted(records, key=lambda r: (r.date, r.rel.as_posix()), reverse=True)
    out = [f"# {directory.capitalize()} index", "", index_note(command), ""]
    if directory == "decisions":
        live = [r for r in records if r.meta.get("status") not in ("superseded", "deprecated")]
        gone = [r for r in records if r not in live]
        by_key = {record_key(r.rel): r for r in records}
        out += table(["Date", "Decision"],
                     [[r.date, f"[{label(r.title)}]({r.link})"] for r in live]) if live else ["No decisions yet."]
        if gone:
            rows = []
            for r in gone:
                newer = by_key.get(record_key(r.rel.parent / r.meta.get("superseded_by", "")))
                if r.meta.get("status") == "deprecated":
                    fate = "deprecated"
                elif newer:
                    fate = f"superseded by [{label(newer.title)}]({newer.link})"
                else:
                    fate = "superseded"
                rows.append([r.date, f"[{label(r.title)}]({r.link})", fate])
            out += ["", "## Superseded and deprecated", ""]
            out += table(["Date", "Decision", "Status"], rows)
    elif directory == "research":
        out += table(["Date", "Research", "Question"],
                     [[r.date, f"[{label(r.title)}]({r.link})", cell(r.meta.get("question", ""))]
                      for r in records]) if records else ["No research records yet."]
        if spikes:
            out += ["", "## Research spikes", "", "Each keeps its own ledger.", ""]
            out += [f"- [`{s}/`]({s}/)" for s in sorted(spikes)]
    elif directory == "designs":
        rows = []
        for r in records:
            tracks = r.meta.get("tracks", "")
            rows.append([r.date, f"[{label(r.title)}]({r.link})",
                         f"<{tracks}>" if SCHEME.match(tracks) else cell(tracks)])
        out += table(["Date", "Design", "Tracks"], rows) if rows else ["No designs are open."]
    else:
        out += table(["Date", "Record"],
                     [[r.date, f"[{label(r.title)}]({r.link})"] for r in records]) if records else ["No records yet."]
    return "\n".join(out) + "\n"


def record_directories(files):
    """The record directories under dev_docs/ that hold any listed file:
    every directory but tasks/ and a dot-prefixed one, which belong to tools."""
    return sorted({rel.parts[1] for rel in files
                   if len(rel.parts) >= 3 and rel.parts[1] != "tasks"
                   and not rel.parts[1].startswith(".")})


def indexes(files, records, current=None):
    """(INDEX.md path, its text as generated, the command its header names)
    for every record directory. CURRENT, when given, maps an INDEX.md path to
    the text already there, whose header command the generated text keeps."""
    current = current or {}
    spikes = {}
    for rel in files:
        if in_research_spike(rel):
            spikes.setdefault(rel.parts[1], set()).add(rel.parts[2])
    out = []
    for d in record_directories(files):
        rel = pathlib.Path("dev_docs", d, INDEX)
        command = index_command(current.get(rel, ""))
        text = render_index(d, [r for r in records if r.directory == d], spikes.get(d, set()), command)
        out.append((rel, text, command))
    return out


def check_index(root: pathlib.Path, files, records, report):
    """Check 9: a record directory's INDEX.md is exactly what the records
    generate, apart from the regenerating command its header names. A
    directory without one has no index and is not checked."""
    present = set(files)
    current = {}
    for rel, _, _ in indexes(files, records):
        if rel not in present:
            continue
        try:
            current[rel] = (root / rel).read_text(encoding="utf-8")
        except OSError as e:
            report(rel, f"unreadable: {e}")
    for rel, text, command in indexes(files, records, current):
        if rel in current and current[rel] != text:
            report(rel, f"out of date; it is generated, so run {command} rather than editing it")


def check_records(root: pathlib.Path, files, report, on_skip=None):
    """Checks 3 to 6, and returns the records an index can list. ON_SKIP, when
    given, is called with the path of each record left out because its date
    is not a calendar date or it could not be read."""
    # Bundle directories seen, and whether each one's README.md turned up: a
    # bundle without its record is artifacts nothing explains.
    bundles = {}
    # Flat records, keyed by the path minus the .md, which is byte-identical to
    # the key a bundle of the same name gets. Compared at the end rather than on
    # encounter, because the flat file and the bundle's files interleave in the
    # listing and the verdict must not depend on which came first.
    flats = set()
    records = []

    def body(rel, date, directory):
        r = check_record_body(root, rel, date, directory, report)
        if r is not None:
            records.append(r)
        elif on_skip is not None:
            on_skip(rel)

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
                    body(rel, bundle.group(1), directory)
                    continue
                report(rel, f"a record bundle holds README.md and references/, nothing else; see {CONVENTION}")
                continue
            if in_research_spike(rel):
                continue
            report(rel, f"a subdirectory is not allowed under dev_docs/{directory}/")
            continue
        if name in ("README.md", INDEX):
            continue
        m = RECORD_NAME.match(name)
        if not m:
            report(rel, f"not YYYY-MM-DD-<slug>.md (kebab-case, lowercase), README.md or {INDEX}; dev_docs/{directory}/ holds records")
            continue
        flats.add(rel.with_suffix(""))
        body(rel, m.group(1), directory)
    for bundle, has_readme in sorted(bundles.items()):
        if not has_readme:
            report(bundle, "a record bundle's README.md is the record; this one has artifacts and no record")
        if bundle in flats:
            report(bundle, f"also exists as {bundle.name}.md; a record is a flat file or a bundle, never both; see {CONVENTION}")
    return records


def write_index(root: pathlib.Path, files, records) -> list:
    """Writes INDEX.md in every record directory under root's dev_docs/ whose
    generated text differs from what is there, creating it where it is absent.
    Returns the paths it wrote. An existing index keeps the regenerating
    command its header names."""
    current = {}
    for rel, _, _ in indexes(files, records):
        if (root / rel).is_file():
            current[rel] = (root / rel).read_text(encoding="utf-8")
    changed = []
    for rel, text, _ in indexes(files, records, current):
        path = root / rel
        if current.get(rel) != text:
            path.write_text(text, encoding="utf-8")
            changed.append(rel)
    return changed


def main(argv):
    args = argv[1:]
    if args in (["-h"], ["--help"]):
        print(__doc__.strip().splitlines()[0])
        print(USAGE)
        return 0
    write = "--write-index" in args
    args = [a for a in args if a != "--write-index"]
    if len(args) > 1 or any(a.startswith("-") for a in args):
        print(USAGE)
        return 2
    root = pathlib.Path(args[0] if args else ".").resolve()

    listing = git_listing(root)
    if listing is None:
        listing = walked_listing(root)
    # The root's dev_docs/ is checked even when git sees nothing in it: check 1
    # reads the filesystem, and an ignored tasks/ is exactly where it looks.
    if (root / "dev_docs").is_dir():
        listing.setdefault(pathlib.Path("."), [])
    if not listing:
        print(f"{root}: no dev_docs/, nothing to check")
        return 0

    if write:
        for package in sorted(listing):
            base = root / package
            files = sorted(listing[package])
            # Write mode checks nothing, but a record left out of the index is
            # said out loud, with the reason the check would give.
            seen = {}

            def note(rel, message, seen=seen):
                seen.setdefault(rel, []).append(message)

            def skipped(rel, seen=seen, package=package):
                why = "; ".join(seen.get(rel, [])) or "unreadable"
                print(f"skipped {(package / rel).as_posix()}: not indexed, {why}", file=sys.stderr)

            records = check_records(base, files, note, skipped)
            for rel in write_index(base, files, records):
                print(f"wrote {(package / rel).as_posix()}")
        return 0

    violations = []
    count = 0
    for package in sorted(listing):
        files = sorted(listing[package])
        count += len(files)
        base = root / package

        def report(rel, message, package=package):
            violations.append(f"{(package / rel).as_posix()}: {message}")

        if package == pathlib.Path("."):
            check_tasks(base, report)
        else:
            check_root_only(base, report)
        check_checkboxes(base, files, report)
        records = check_records(base, files, report)
        check_supersession(base, records, report)
        check_links(base, files, report)
        check_index(base, files, records, report)

    for v in violations:
        print(v)
    if violations:
        print(f"{len(violations)} layout violation(s); see {CONVENTION}")
        return 1
    where = "" if len(listing) == 1 else f" across {len(listing)} dev_docs/ directories"
    print(f"dev_docs/ layout ok ({count} files{where})")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
