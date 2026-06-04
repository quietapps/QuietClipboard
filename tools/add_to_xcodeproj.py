#!/usr/bin/env python3
"""Add Swift source files to QuietClipboard.xcodeproj (non-synchronized project).

Adds a PBXFileReference (SOURCE_ROOT-relative so it resolves regardless of group),
a PBXBuildFile, and inserts the build file into the app target's PBXSourcesBuildPhase.
Idempotent: skips files already referenced. Usage:

    python3 tools/add_to_xcodeproj.py QuietClipboard/Services/Foo.swift [more...]
"""
import os
import re
import sys
import secrets

PROJ = os.path.join(os.path.dirname(__file__), "..", "QuietClipboard.xcodeproj", "project.pbxproj")
PROJ = os.path.abspath(PROJ)


def gen_id(existing):
    while True:
        i = secrets.token_hex(12).upper()
        if i not in existing:
            existing.add(i)
            return i


def main(paths):
    with open(PROJ) as f:
        text = f.read()

    existing_ids = set(re.findall(r"\b[0-9A-F]{24}\b", text))
    build_lines = []
    ref_lines = []
    sources_entries = []

    for path in paths:
        path = path.lstrip("./")
        base = os.path.basename(path)
        if f"/* {base} */" in text or f"path = {path};" in text:
            print(f"SKIP (already present): {path}")
            continue
        ref_id = gen_id(existing_ids)
        bf_id = gen_id(existing_ids)
        ref_lines.append(
            f'\t\t{ref_id} /* {base} */ = {{isa = PBXFileReference; '
            f'lastKnownFileType = sourcecode.swift; name = {base}; path = "{path}"; '
            f'sourceTree = SOURCE_ROOT; }};'
        )
        build_lines.append(
            f'\t\t{bf_id} /* {base} in Sources */ = {{isa = PBXBuildFile; '
            f'fileRef = {ref_id} /* {base} */; }};'
        )
        sources_entries.append(f'\t\t\t\t{bf_id} /* {base} in Sources */,')
        print(f"ADD: {path}  ref={ref_id} build={bf_id}")

    if not build_lines:
        print("Nothing to add.")
        return

    text = text.replace(
        "/* Begin PBXBuildFile section */",
        "/* Begin PBXBuildFile section */\n" + "\n".join(build_lines), 1)
    text = text.replace(
        "/* Begin PBXFileReference section */",
        "/* Begin PBXFileReference section */\n" + "\n".join(ref_lines), 1)

    # Insert into the app target's Sources build phase files list.
    m = re.search(r"(isa = PBXSourcesBuildPhase;.*?files = \(\n)", text, re.DOTALL)
    if not m:
        sys.exit("ERROR: could not find PBXSourcesBuildPhase files list")
    insert_at = m.end()
    text = text[:insert_at] + "\n".join(sources_entries) + "\n" + text[insert_at:]

    with open(PROJ, "w") as f:
        f.write(text)
    print(f"Patched {PROJ}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit("usage: add_to_xcodeproj.py <file.swift> [more...]")
    main(sys.argv[1:])
