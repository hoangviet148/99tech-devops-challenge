import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PROBLEMS = ["problem1", "problem2", "problem3", "problem4", "problem5"]
SETS = ["GEN", "OPS", "SEC", "REL", "PERF", "COST", "SUS", "FSI"]
SET_NAMES = "|".join(SETS)
REQ_RE = re.compile(r"(?<![\w-])REQ-(?:G\d+|P\d-\d+A?)(?![\w-])")
DP_RE = re.compile(rf"(?<![\w-])(?:{SET_NAMES})-DP\d+(?![\w-])")
ADR_RE = re.compile(r"(?<![\w-])ADR-(?:P\d-)?\d{4}(?![\w-])")
SHAPED_RE = re.compile(rf"(?<![\w-])(?:REQ-(?:G|P\d+-?)\d[\w-]*|ADR-(?:P\d+-)?\d[\w-]*|(?:{SET_NAMES})-DP\d[\w-]*)")
LOCAL_RE = re.compile(r"(?<![\w./-])([A-Z]{1,3}(?:-P\d)?-?)(\d{1,3})(?![\w-])")
DEFINED_RE = re.compile(r"([A-Z]{1,3}(?:-P\d)?-?)(\d{1,3})")
PINNED_RE = re.compile(r"-P(\d)-$")
SEPARATOR_RE = re.compile(r"^\|[\s:|-]+\|$")
SOLUTION_TRACE = re.compile(r"(?:\d+\.\s+)?Traceability")
README_TRACE = re.compile(r"Traceability of the instructions")
SKIP_FAMILIES = ("REQ-", "ADR-")
EXTERNAL = {"AES-", "BIP-", "CWE-", "EIP-", "ERC-", "P-", "RFC-", "SHA-", "SOC-", "TLS-", "UTF-"}
SECTIONS = ["Context", "Decision", "Alternatives considered", "Trade-offs", "Consequences", "Verification", "Reopen when"]
SUBSECTIONS = ["Positive", "Negative", "Risks"]
FIELDS = ["Status", "Date", "Deciders", "Requirements", "Principles", "Supersedes"]

errors = []
texts = {}


def fail(message):
    errors.append(message)


def rel(path):
    return path.relative_to(ROOT).as_posix()


def natural(text):
    return [int(part) if part.isdigit() else part for part in re.split(r"(\d+)", text)]


def squash(text):
    return " ".join(text.split())


def read(path):
    if path not in texts:
        try:
            texts[path] = path.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError) as error:
            fail(f"{rel(path)} cannot be read: {getattr(error, 'strerror', None) or type(error).__name__}")
            texts[path] = ""
    return texts[path]


def strip_fences(text):
    return re.sub(r"```.*?```", "", text, flags=re.S)


def strip_code(text):
    return re.sub(r"`[^`\n]*`", "", strip_fences(text))


def cells(line):
    body = line.strip()[1:]
    if body.endswith("|") and not body.endswith("\\|"):
        body = body[:-1]
    return [cell.strip() for cell in re.split(r"(?<!\\)\|", body)]


def tables(text):
    found = []
    rows = None
    for line in strip_fences(text).splitlines():
        if not line.startswith("|"):
            rows = None
        elif not SEPARATOR_RE.match(line.rstrip()):
            if rows is None:
                rows = []
                found.append((cells(line), rows))
            else:
                rows.append(cells(line))
    return found


def id_rows(text):
    return [row for header, rows in tables(text) if header[0] == "ID" for row in rows]


def sections(text, marker="##"):
    parts = {}
    current = None
    for line in text.splitlines():
        heading = re.match(rf"^{marker} (.+)$", line)
        if heading:
            current = heading.group(1).strip()
            parts[current] = []
        elif current is not None:
            parts[current].append(line)
    return {name: "\n".join(body).strip() for name, body in parts.items()}


def metadata(text):
    values = {}
    for header, rows in tables(text):
        for row in [header, *rows]:
            if len(row) == 2 and row[0] in FIELDS and row[0] not in values:
                values[row[0]] = row[1]
    return values


def register(path, pattern):
    if not path.is_file():
        fail(f"{rel(path)} is missing")
        return {}
    found = {}
    for row in id_rows(read(path)):
        if pattern.fullmatch(row[0]):
            found.setdefault(row[0], row[1] if len(row) > 1 else "")
    if not found:
        fail(f"{rel(path)} defines no ID")
    return found


def adr_files():
    folders = [(ROOT / "docs" / "adr", "ADR-", None)]
    folders += [(ROOT / "src" / p / "docs" / "adr", f"ADR-P{p[-1]}-", p) for p in PROBLEMS]
    records = {}
    for folder, prefix, problem in folders:
        if not folder.is_dir():
            fail(f"{rel(folder)} is missing")
            continue
        index_path = folder / "README.md"
        index = read(index_path) if index_path.is_file() else ""
        if not index:
            fail(f"{rel(index_path)} is missing")
        for path in sorted(folder.glob("[0-9][0-9][0-9][0-9]-*.md")):
            records[prefix + path.name[:4]] = (problem, path)
            if index and f"({path.name})" not in index:
                fail(f"{rel(index_path)} does not link {path.name}")
        for link in re.findall(r"\((\d{4}-[^)]+\.md)\)", index):
            if not (folder / link).is_file():
                fail(f"{rel(index_path)} links {link}, which does not exist")
    return records


def check_adr(adr_id, path, reqs, dps):
    text = read(path)
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
    for unknown in sorted(cited_reqs - set(reqs), key=natural):
        fail(f"{rel(path)}: requirement {unknown} is not in docs/requirements.md")
    for unknown in sorted(cited_dps - set(dps), key=natural):
        fail(f"{rel(path)}: principle {unknown} is not in docs/principles.md")
    body = sections(text)
    for name in SECTIONS:
        if not body.get(name):
            fail(f"{rel(path)}: section '{name}' is missing or empty")
    if body.get("Consequences"):
        consequences = sections(body["Consequences"], "###")
        for name in SUBSECTIONS:
            if not consequences.get(name):
                fail(f"{rel(path)}: subsection '{name}' of Consequences is missing or empty")
    alternatives = [row for header, rows in tables(body.get("Alternatives considered", "")) for row in rows if row[0]]
    if len(alternatives) < 2:
        fail(f"{rel(path)}: needs at least two alternatives, found {len(alternatives)}")
    return cited_reqs


def kind(token):
    if token.startswith("REQ-"):
        return "requirement"
    return "decision record" if token.startswith("ADR-") else "principle"


def check_ids(path, reqs, dps, records):
    text = strip_code(read(path))
    for unknown in sorted(set(REQ_RE.findall(text)) - set(reqs), key=natural):
        fail(f"{rel(path)}: requirement {unknown} is not in docs/requirements.md")
    for unknown in sorted(set(DP_RE.findall(text)) - set(dps), key=natural):
        fail(f"{rel(path)}: principle {unknown} is not in docs/principles.md")
    for unknown in sorted(set(ADR_RE.findall(text)) - set(records), key=natural):
        fail(f"{rel(path)}: {unknown} has no decision record")
    for token in sorted(set(SHAPED_RE.findall(text)), key=natural):
        if not any(pattern.fullmatch(token) for pattern in (REQ_RE, ADR_RE, DP_RE)):
            fail(f"{rel(path)}: {token} is not a well-formed {kind(token)} ID")


def trace_lines(path, heading):
    for name, body in sections(strip_code(read(path))).items():
        if heading.fullmatch(name):
            return [line for line in body.splitlines() if line.startswith("|")]
    return None


def check_traceability(reqs, readme, solutions):
    owners = {"G": (readme, README_TRACE)} if readme.is_file() else {}
    owners.update({f"P{problem[-1]}": (path, SOLUTION_TRACE) for problem, path in solutions.items()})
    rows = {}
    for key, (path, heading) in owners.items():
        lines = trace_lines(path, heading)
        if lines is None:
            fail(f"{rel(path)} has no traceability section")
        else:
            rows[key] = (path, {req for line in lines for req in REQ_RE.findall(line)})
    for req in sorted(reqs, key=natural):
        key = "G" if req.startswith("REQ-G") else req[4:6]
        if key in rows and req not in rows[key][1]:
            fail(f"{req} has no row in the traceability table of {rel(rows[key][0])}")


def check_citations(records, readme, solutions):
    for adr_id, (problem, path) in sorted(records.items()):
        source = solutions.get(problem) if problem else readme
        if source and source.is_file() and adr_id not in ADR_RE.findall(strip_code(read(source))):
            fail(f"{adr_id} is not cited by {rel(source)}")


def check_restated(reqs, solutions):
    for path in solutions.values():
        for header, rows in tables(read(path)):
            if header[:2] != ["ID", "Requirement"]:
                continue
            for row in rows:
                if row[0] in reqs and squash(row[1] if len(row) > 1 else "") != squash(reqs[row[0]]):
                    fail(f"{rel(path)}: {row[0]} restates the requirement in other words than docs/requirements.md")


def check_sets(principles, applied):
    table = next((rows for header, rows in tables(read(principles)) if header[0] == "Problem"), None)
    if table is None:
        fail(f"{rel(principles)} has no table headed Problem")
        return
    listed = {}
    for row in table:
        number = re.fullmatch(r"(?:Problem\s+)?(\d+)", row[0])
        if number:
            cell = row[1] if len(row) > 1 else ""
            names = SETS if cell == "All sets" else re.findall(rf"\b(?:{SET_NAMES})\b", cell)
            listed.setdefault(f"problem{number.group(1)}", set(names))
    for problem in PROBLEMS:
        if not (ROOT / "src" / problem / "docs" / "adr").is_dir():
            continue
        number = problem[-1]
        if problem not in listed:
            fail(f"{rel(principles)} has no row for problem {number}")
            continue
        sets = applied.get(problem, {})
        for name in SETS:
            if name in listed[problem] and name not in sets:
                fail(f"{rel(principles)}: {name} listed for problem {number}, which neither its decision records nor its traceability table cites")
            elif name in sets and name not in listed[problem]:
                fail(f"{rel(principles)} does not list {name} for problem {number}, which {sets[name]} cites")


def defined_ids(text):
    found = {}
    for row in id_rows(text):
        match = DEFINED_RE.fullmatch(row[0].split(" ")[0])
        if match and not match.group(1).startswith(SKIP_FAMILIES):
            found.setdefault(match.group(1), set()).add(match.group(2))
    return found


def local_ids(text):
    found = {}
    for family, number in LOCAL_RE.findall(strip_code(text)):
        if not family.startswith(SKIP_FAMILIES):
            found.setdefault(family, set()).add(number)
    return found


def owners_of(problem, family, families):
    if not family.endswith("-"):
        return [problem] if family in families[problem] else None
    pinned = PINNED_RE.search(family)
    candidates = [f"problem{pinned.group(1)}"] if pinned else PROBLEMS
    owners = [p for p in candidates if family in families[p]]
    if not owners and family in EXTERNAL:
        return None
    return owners


def where(owners):
    paths = ", ".join(rel(ROOT / "src" / owner / "SOLUTION.md") for owner in owners)
    return f"{paths} or {'its' if len(owners) == 1 else 'their'} decision records"


def check_local(records, solutions):
    sources = {}
    families = {}
    for problem in PROBLEMS:
        paths = [solutions[problem]] if problem in solutions else []
        paths += [path for adr_id, (owner, path) in sorted(records.items()) if owner == problem]
        sources[problem] = paths
        defined = {}
        for path in paths:
            for family, numbers in defined_ids(read(path)).items():
                defined.setdefault(family, set()).update(numbers)
        families[problem] = defined
    unchecked = {problem: set() for problem in PROBLEMS}
    for problem in PROBLEMS:
        for path in sources[problem]:
            for family, numbers in sorted(local_ids(read(path)).items()):
                owners = owners_of(problem, family, families)
                if owners is None:
                    unchecked[problem].update(family + number for number in numbers)
                elif not owners:
                    for number in sorted(numbers, key=int):
                        fail(f"{rel(path)}: {family}{number} belongs to a family that no problem defines in an ID table")
                else:
                    known = set().union(*(families[owner][family] for owner in owners))
                    for number in sorted(numbers - known, key=int):
                        fail(f"{rel(path)}: {family}{number} is not defined in an ID table of {where(owners)}")
    return families, unchecked


def main():
    reqs = register(ROOT / "docs" / "requirements.md", REQ_RE)
    principles = ROOT / "docs" / "principles.md"
    dps = register(principles, DP_RE)
    records = adr_files()
    decided = set()
    applied = {}
    for adr_id, (problem, path) in sorted(records.items()):
        decided |= check_adr(adr_id, path, reqs, dps)
        for dp in sorted(set(DP_RE.findall(strip_code(read(path)))), key=natural):
            applied.setdefault(problem, {}).setdefault(dp.split("-")[0], adr_id)

    readme = ROOT / "README.md"
    if not readme.is_file():
        fail(f"{rel(readme)} is missing")
    solutions = {}
    for problem in PROBLEMS:
        path = ROOT / "src" / problem / "SOLUTION.md"
        if not path.is_file():
            fail(f"{rel(path)} is missing")
            continue
        solutions[problem] = path
        if not re.search(r"^#{2,3} .*[Aa]ssumption", read(path), flags=re.M):
            fail(f"{rel(path)} has no assumptions section")
        for line in trace_lines(path, SOLUTION_TRACE) or []:
            for dp in DP_RE.findall(line):
                applied.setdefault(problem, {}).setdefault(dp.split("-")[0], f"the traceability table of {rel(path)}")

    documents = [p for p in [readme, *sorted((ROOT / "docs").glob("*.md"))] if p.is_file()]
    documents += [*solutions.values(), *(path for adr_id, (problem, path) in sorted(records.items()))]
    for path in documents:
        check_ids(path, reqs, dps, records)

    for req in sorted(set(reqs) - decided, key=natural):
        fail(f"{req} is cited by no decision record")
    check_traceability(reqs, readme, solutions)
    check_citations(records, readme, solutions)
    check_restated(reqs, solutions)
    if principles.is_file():
        check_sets(principles, applied)
    families, unchecked = check_local(records, solutions)

    print(f"requirements {len(reqs)}, principles {len(dps)}, decision records {len(records)}")
    for problem in PROBLEMS:
        listing = ", ".join(f"{family}* ({len(numbers)})" for family, numbers in sorted(families[problem].items()))
        tokens = ", ".join(sorted(unchecked[problem], key=natural))
        sets = ", ".join(name for name in SETS if name in applied.get(problem, {}))
        print(f"{problem}: {listing or 'none'}")
        print(f"{problem} not checked: {tokens or 'none'}")
        print(f"{problem} principle sets: {sets or 'none'}")
    failures = list(dict.fromkeys(errors))
    for message in failures:
        print(f"FAIL {message}")
    print(f"{len(failures)} failures")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
