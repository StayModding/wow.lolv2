#!/usr/bin/env python3
"""Cheap sanity check: balanced braces/parens/brackets outside strings and comments.

This is not a parser and it does not replace xcodebuild; it just catches the
kind of structural slip that is painful to find in a CI log.

    python tools/check_swift_balance.py
"""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def strip_code(text: str) -> str:
    out: list[str] = []
    i = 0
    in_string = in_line_comment = in_block_comment = False
    while i < len(text):
        ch = text[i]
        nxt = text[i + 1] if i + 1 < len(text) else ""
        if in_line_comment:
            if ch == "\n":
                in_line_comment = False
                out.append(ch)
            i += 1
            continue
        if in_block_comment:
            if ch == "*" and nxt == "/":
                in_block_comment = False
                i += 2
                continue
            i += 1
            continue
        if in_string:
            if ch == "\\":
                i += 2
                continue
            if ch == '"':
                in_string = False
            i += 1
            continue
        if ch == "/" and nxt == "/":
            in_line_comment = True
            i += 2
            continue
        if ch == "/" and nxt == "*":
            in_block_comment = True
            i += 2
            continue
        if ch == '"':
            in_string = True
            i += 1
            continue
        out.append(ch)
        i += 1
    return "".join(out)


def main() -> int:
    files = sorted((ROOT / "WowTok").rglob("*.swift"))
    if not files:
        print("no Swift files found")
        return 1

    failures = 0
    for path in files:
        code = strip_code(path.read_text(encoding="utf-8"))
        problems = []
        for opener, closer in (("{", "}"), ("(", ")"), ("[", "]")):
            if code.count(opener) != code.count(closer):
                problems.append(f"{opener}{closer} {code.count(opener)}/{code.count(closer)}")
        if problems:
            failures += 1
            print(f"FAIL {path.relative_to(ROOT)} :: {', '.join(problems)}")

    print(f"{len(files)} files checked, {failures} unbalanced")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
