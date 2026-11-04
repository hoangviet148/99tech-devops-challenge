import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PROBLEMS = ["problem1", "problem2", "problem3", "problem4", "problem5"]
REQ_RE = re.compile(r"(?<![\w-])REQ-(?:G\d+|P\d-\d+A?)(?![\w-])")
DP_RE = re.compile(r"(?<![\w-])(?:GEN|OPS|SEC|REL|PERF|COST|SUS|FSI)-DP\d+(?![\w-])")
ADR_RE = re.compile(r"(?<![\w-])ADR-(?:P\d-)?\d{4}(?![\w-])")
LOCAL_RE = re.compile(r"(?<![\w./-])([A-Z]{1,3}(?:-P\d)?-?)(\d{1,3})(?![\w-])")
SKIP_FAMILIES = ("REQ-", "ADR-")
SECTIONS = ["Context", "Decision", "Alternatives considered", "Trade-offs", "Consequences", "Verification", "Reopen when"]
FIELDS = ["Status", "Date", "Deciders", "Requirements", "Principles", "Supersedes"]

errors = []


def fail(message):
    errors.append(message)


def rel(path):
    return path.relative_to(ROOT).as_posix()


def strip_code(text):
    text = re.sub(r"```.*?```", "", text, flags=re.S)
    return re.sub(r"`[^`\n]*`", "", text)


def first_cells(text):
    cells = []
    for line in text.splitlines():
        if line.startswith("|") and not re.match(r"^\|[\s:|-]+\|$", line):
            cells.append(line.split("|")[1].strip())
    return cells


def register(path, pattern):
    if not path.exists():
        fail(f"{rel(path)} is missing")
        return set()
    found = {cell for cell in first_cells(path.read_text()) if pattern.fullmatch(cell)}
    if not found:
        fail(f"{rel(path)} defines no ID")
    return found


def sections(text):
    parts = {}
    current = None
    for line in text.splitlines():
        heading = re.match(r"^## (.+)$", line)
        if heading:
            current = heading.group(1).strip()
            parts[current] = []
        elif current:
            parts[current].append(line)
    return {name: "\n".join(body).strip() for name, body in parts.items()}


def metadata(text):
    values = {}
    for line in text.splitlines():
        cells = [cell.strip() for cell in line.split("|")[1:-1]]
        if len(cells) == 2 and cells[0] in FIELDS:
            values[cells[0]] = cells[1]
    return values


def adr_files():
    folders = [(ROOT / "docs" / "adr", "ADR-")]
    folders += [(ROOT / "src" / p / "docs" / "adr", f"ADR-P{p[-1]}-") for p in PROBLEMS]
    records = {}
    for folder, prefix in folders:
        if not folder.exists():
            fail(f"{rel(folder)} is missing")
            continue
        files = sorted(folder.glob("[0-9][0-9][0-9][0-9]-*.md"))
        index = (folder / "README.md").read_text() if (folder / "README.md").exists() else ""
        if not index:
            fail(f"{rel(folder)}/README.md is missing")
        for path in files:
            adr_id = prefix + path.name[:4]
            records[adr_id] = path
            if f"({path.name})" not in index:
                fail(f"{rel(folder)}/README.md does not link {path.name}")
        for link in re.findall(r"\((\d{4}-[^)]+\.md)\)", index):
            if not (folder / link).exists():
                fail(f"{rel(folder)}/README.md links {link}, which does not exist")
    return records


def check_adr(adr_id, path, reqs, dps):
    text = path.read_text()
    title = text.splitlines()[0] if text else ""
    if not title.startswith(f"# {adr_id}: "):
        fail(f"{rel(path)}: the title must start with '# {adr_id}: '")
    meta = metadata(text)
    for field in FIELDS:
        if not meta.get(field):
            fail(f"{rel(path)}: metadata field {field} is missing or empty")
    cited_reqs = set(REQ_RE.findall(meta.get("Requirements", "")))
    cited_dps = set(DP_RE.findall(meta.get("Principles", "")))
    if not cited_reqs:
        fail(f"{rel(path)}: cites no requirement")
    if not cited_dps:
        fail(f"{rel(path)}: cites no principle")
    for unknown in sorted(cited_reqs - reqs):
        fail(f"{rel(path)}: requirement {unknown} is not in docs/requirements.md")
    for unknown in sorted(cited_dps - dps):
        fail(f"{rel(path)}: principle {unknown} is not in docs/principles.md")
    body = sections(text)
    for name in SECTIONS:
        if not body.get(name):
            fail(f"{rel(path)}: section '{name}' is missing or empty")
    alternatives = [c for c in first_cells(body.get("Alternatives considered", "")) if c and c != "Option"]
    if len(alternatives) < 2:
        fail(f"{rel(path)}: needs at least two alternatives, found {len(alternatives)}")
    return cited_reqs


def local_ids(text):
    found = {}
    for family, number in LOCAL_RE.findall(strip_code(text)):
        if not family.startswith(SKIP_FAMILIES):
            found.setdefault(family, set()).add(number)
    return found


def defined_ids(text):
    found = {}
    for cell in first_cells(text):
        match = re.fullmatch(r"([A-Z]{1,3}(?:-P\d)?-?)(\d{1,3})", cell.split(" ")[0])
        if match and not match.group(1).startswith(SKIP_FAMILIES):
            found.setdefault(match.group(1), set()).add(match.group(2))
    return found


def main():
    reqs = register(ROOT / "docs" / "requirements.md", REQ_RE)
    dps = register(ROOT / "docs" / "principles.md", DP_RE)
    records = adr_files()
    decided = set()
    for adr_id, path in sorted(records.items()):
        decided |= check_adr(adr_id, path, reqs, dps)

    documents = [ROOT / "README.md", *sorted((ROOT / "docs").glob("*.md"))]
    solutions = {}
    for problem in PROBLEMS:
        path = ROOT / "src" / problem / "SOLUTION.md"
        if not path.exists():
            fail(f"{rel(path)} is missing")
            continue
        solutions[problem] = path
        text = path.read_text()
        if not re.search(r"^#{2,3} .*[Aa]ssumption", text, flags=re.M):
            fail(f"{rel(path)} has no assumptions section")
        documents.append(path)

    traced = set()
    for path in documents + list(records.values()):
        text = strip_code(path.read_text())
        for unknown in sorted(set(REQ_RE.findall(text)) - reqs):
            fail(f"{rel(path)}: requirement {unknown} is not in docs/requirements.md")
        for unknown in sorted(set(DP_RE.findall(text)) - dps):
            fail(f"{rel(path)}: principle {unknown} is not in docs/principles.md")
        for unknown in sorted(set(ADR_RE.findall(text)) - set(records)):
            fail(f"{rel(path)}: {unknown} has no decision record")
        if path.name == "SOLUTION.md" or path.parent == ROOT / "docs" or path.name == "README.md":
            traced |= set(REQ_RE.findall(text))

    for req in sorted(reqs - decided):
        fail(f"{req} is cited by no decision record")
    for req in sorted(reqs - traced):
        fail(f"{req} appears in no SOLUTION.md, root README or register document")

    for adr_id, path in sorted(records.items()):
        problem = path.parts[-4] if path.parts[-4].startswith("problem") else None
        sources = [solutions[problem]] if problem in solutions else [ROOT / "README.md", *documents]
        if not any(adr_id in strip_code(p.read_text()) for p in sources if p.exists() and p != path):
            where = rel(solutions[problem]) if problem in solutions else "the root documents"
            fail(f"{adr_id} is not cited by {where}")

    families = {}
    for problem, path in solutions.items():
        texts = [path.read_text()] + [p.read_text() for a, p in records.items() if p.parts[-4] == problem]
        defined = {}
        for text in texts:
            for family, numbers in defined_ids(text).items():
                defined.setdefault(family, set()).update(numbers)
        families[problem] = defined
        for text, source in zip(texts, [path] + [p for a, p in records.items() if p.parts[-4] == problem]):
            for family, numbers in local_ids(text).items():
                if family not in defined:
                    continue
                for number in sorted(numbers - defined[family]):
                    fail(f"{rel(source)}: {family}{number} is not defined in a table of {rel(path)} or its decision records")

    print(f"requirements {len(reqs)}, principles {len(dps)}, decision records {len(records)}")
    for problem, defined in sorted(families.items()):
        listing = ", ".join(f"{family}* ({len(numbers)})" for family, numbers in sorted(defined.items()))
        print(f"{problem}: {listing}")
    for message in errors:
        print(f"FAIL {message}")
    print(f"{len(errors)} failures")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
