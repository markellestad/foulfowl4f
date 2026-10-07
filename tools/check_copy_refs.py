#!/usr/bin/env python3
"""Check that every 'add' key in docs/design/copy_revisions_fable_1006.json
is referenced by at least one .gd file in the codebase.
Exits 0 if all are referenced, 1 if any unreferenced keys remain.
"""
import json
import pathlib
import sys

def main() -> int:
    root = pathlib.Path(__file__).resolve().parent.parent
    revisions_path = root / "docs" / "design" / "copy_revisions_fable_1006.json"
    if not revisions_path.exists():
        print(f"Error: revisions file not found: {revisions_path}", file=sys.stderr)
        return 1

    with open(revisions_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    add_dict = data.get("add", {})
    if not add_dict:
        print("Warning: no 'add' section found in revisions file.", file=sys.stderr)
        return 1

    # Read all .gd files
    gd_files = list(root.glob("src/**/*.gd")) + list(root.glob("test/**/*.gd"))
    gd_texts = {}
    for p in gd_files:
        try:
            gd_texts[p] = p.read_text(encoding="utf-8", errors="replace")
        except Exception as e:
            print(f"Warning: could not read {p}: {e}", file=sys.stderr)

    unreferenced = []
    referenced_count = 0
    for key in sorted(add_dict.keys()):
        found = False
        for p, content in gd_texts.items():
            if key in content:
                found = True
                break
        if found:
            referenced_count += 1
        else:
            unreferenced.append(key)

    if unreferenced:
        print(f"check_copy_refs: FAIL ({len(unreferenced)} unreferenced keys out of {len(add_dict)}):")
        for k in unreferenced:
            print(f"  MISSING: {k}")
        return 1

    print(f"check_copy_refs: OK ({referenced_count}/{len(add_dict)} add keys referenced)")
    return 0

if __name__ == "__main__":
    sys.exit(main())
