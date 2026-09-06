#!/usr/bin/env python3
import hashlib
import json
import re
import sys
from pathlib import Path


HEADINGS = {"완료 조건", "acceptance criteria", "검수 기준"}
HEADING = re.compile(r"^ {0,3}(#{1,6})[ \t]+(.+?)[ \t]*#*[ \t]*$")
BULLET = re.compile(r"^( *)([-*+])[ \t]+(?:(\[[ xX]\])[ \t]+)?(.*)$")
FENCE = re.compile(r"^ {0,3}(`{3,}|~{3,})")


def fail(message):
    raise ValueError(message)


def load(path):
    return json.loads(Path(path).read_text())


def body_hash(body):
    return hashlib.sha256(body.encode()).hexdigest()


def parse(body):
    lines = body.splitlines(keepends=True)
    visible = []
    fence = None
    for index, line in enumerate(lines):
        marker = FENCE.match(line)
        if fence:
            if marker and marker[1][0] == fence[0] and len(marker[1]) >= len(fence):
                fence = None
            continue
        if marker:
            fence = marker[1]
            continue
        visible.append(index)
    headings = [(i, HEADING.match(lines[i].rstrip("\r\n"))) for i in visible]
    headings = [(i, m) for i, m in headings if m]
    sections = [(i, m) for i, m in headings if m[2].strip().casefold() in HEADINGS]
    if len(sections) > 1:
        fail("multiple 완료 조건 sections; resolve the ambiguity before checking")
    if not sections:
        return None, [], lines
    start, heading = sections[0]
    end = next((i for i, m in headings if i > start and len(m[1]) <= len(heading[1])), len(lines))
    candidates = [(i, BULLET.match(lines[i].rstrip("\r\n"))) for i in visible if start < i < end]
    candidates = [(i, m) for i, m in candidates if m]
    if not candidates:
        return heading[2].strip(), [], lines
    indent = min(len(m[1]) for _, m in candidates)
    if any(len(m[1]) > indent and m[3] for _, m in candidates):
        fail("nested checkboxes in 완료 조건; flatten independently verifiable conditions first")
    top = [(i, m) for i, m in candidates if len(m[1]) == indent]
    items = []
    for position, (line, match) in enumerate(top):
        stop = top[position + 1][0] if position + 1 < len(top) else end
        text = match[4].strip()
        continuation = "".join(lines[line + 1:stop]).strip()
        if continuation:
            text += "\n" + continuation
        if not text:
            fail("empty condition")
        items.append({"index": position + 1, "text": text,
                      "checked": match[3] in ("[x]", "[X]"), "line": line})
    return heading[2].strip(), items, lines


def snapshot(raw):
    if not isinstance(raw, dict) or not isinstance(raw.get("body"), str):
        fail("issue response must contain a body string")
    issue = raw.get("number")
    updated = raw.get("updatedAt")
    if not isinstance(issue, (str, int)) or isinstance(issue, bool) or not str(issue):
        fail("issue response must contain an identifier")
    if not isinstance(updated, str) or not updated:
        fail("issue response must contain updatedAt")
    section, items, _ = parse(raw["body"])
    return {"issue": str(issue), "updatedAt": updated, "bodyHash": body_hash(raw["body"]),
            "section": section, "items": [{k: v for k, v in item.items() if k != "line"} for item in items]}


def guard(expected, raw):
    current = snapshot(raw)
    if current != expected:
        fail("issue changed since criteria was read; re-read and reassess before retrying")
    return current


def prepare(expected, checks, raw):
    guard(expected, raw)
    _, items, lines = parse(raw["body"])
    if not items:
        fail("no conditions to check; do not invent or silently add a section")
    if not isinstance(checks, list) or len(checks) != len(items):
        fail("check requires exactly one result for every condition")
    requested = {}
    for check in checks:
        if not isinstance(check, dict) or set(check) != {"index", "text", "checked"}:
            fail("each result must have index, text and checked only")
        index = check["index"]
        if type(index) is not int or index in requested or not 1 <= index <= len(items):
            fail("invalid or duplicate condition index")
        if type(check["checked"]) is not bool or not isinstance(check["text"], str):
            fail("checked must be boolean and text must be a string")
        requested[index] = check
    for item in items:
        check = requested[item["index"]]
        if check["text"] != item["text"]:
            fail("condition text does not match the reviewed snapshot")
        original = lines[item["line"]]
        match = BULLET.match(original.rstrip("\r\n"))
        mark = "[x]" if check["checked"] else "[ ]"
        if match[3]:
            if item["checked"] != check["checked"]:
                start, end = match.span(3)
                lines[item["line"]] = original[:start] + mark + original[end:]
        else:
            start = match.start(4)
            lines[item["line"]] = original[:start] + mark + " " + original[start:]
    body = "".join(lines)
    return {"issue": expected["issue"], "body": body, "changed": body != raw["body"]}


def verify(prepared, raw):
    current = snapshot(raw)
    if current["issue"] != prepared["issue"] or raw["body"] != prepared["body"]:
        fail("saved body differs from the planned checkbox-only edit; inspect concurrent edits or normalization; do not auto-retry")
    return dict(current, changed=prepared["changed"])


def main():
    command, *args = sys.argv[1:]
    if command == "read" and not args:
        result = snapshot(json.load(sys.stdin))
    elif command == "guard" and len(args) == 2:
        guard(load(args[0]), load(args[1]))
        return
    elif command == "prepare" and len(args) == 3:
        result = prepare(*(load(path) for path in args))
    elif command == "verify" and len(args) == 2:
        result = verify(*(load(path) for path in args))
    else:
        fail("usage: criteria.py read | guard <snapshot> <issue> | prepare <snapshot> <checks> <issue> | verify <prepared> <issue>")
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, TypeError, OSError) as error:
        print(f"criteria: {error}", file=sys.stderr)
        sys.exit(1)
