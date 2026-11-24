#!/usr/bin/env python3
"""Rewrite an APEX page export so it installs in another environment.

Usage:
    shift_page_export.py SOURCE_EXPORT TARGET_NATIVE_EXPORT OUTPUT

SOURCE_EXPORT         page export taken from the environment that has the change
TARGET_NATIVE_EXPORT  export of the same page taken from the target environment
                      (it carries the target's real IDs; it also is the rollback)
OUTPUT                file to write; install it with the Install Page wizard

What it does:
  1. Reads the raw ID of the user interface in both files and computes the
     constant shift D between them.
  2. Checks that the same D holds for every other shared component both
     files reference (templates, menus, LOVs, authorization schemes ...).
     Stops with an error if it does not: a single shift cannot fix that case.
  3. Adds D to EVERY wwv_flow_api.id(N) of the source export.
  4. Sets p_default_id_offset and p_default_workspace_id to the target's values.
"""
import re
import sys

ID_RE = re.compile(r"wwv_flow_api\.id\((\d+)\)")
REF_RE = re.compile(r"(p_\w+)=>wwv_flow_api\.id\((\d+)\)")
# Keys whose value points at a component of the page itself, not a shared one.
OWN_KEYS = {
    "p_id", "p_event_id", "p_parent_plug_id", "p_item_plug_id",
    "p_button_plug_id", "p_affected_region_id", "p_triggering_button_id",
    "p_triggering_region_id", "p_worksheet_id", "p_report_id",
    "p_flow_step_id", "p_when_button_pressed", "p_process_id",
}


def read(path):
    with open(path, encoding="utf8", newline="") as f:
        return f.read()


def header_value(text, key):
    m = re.search(r",%s=>(\d+)" % key, text)
    if not m:
        sys.exit("Header value %s not found" % key)
    return int(m.group(1))


def shared_refs(text):
    """First raw ID seen per shared-component key (templates, UI, LOV, ...)."""
    refs = {}
    for key, value in REF_RE.findall(text):
        if key not in OWN_KEYS:
            refs.setdefault(key, set()).add(int(value))
    return refs


def main():
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    source = read(sys.argv[1])
    target = read(sys.argv[2])

    src_refs = shared_refs(source)
    tgt_refs = shared_refs(target)
    d = min(tgt_refs["p_user_interface_id"]) - min(src_refs["p_user_interface_id"])
    print("shift D = %d" % d)

    # Every shared key present in both files must agree on the same D.
    bad = []
    for key in sorted(set(src_refs) & set(tgt_refs)):
        for value in tgt_refs[key]:
            if value - d not in src_refs[key]:
                bad.append(key)
    if bad:
        sys.exit("Shift is not uniform for: %s -- do not install." % ", ".join(bad))
    print("uniform shift confirmed for: %s" % ", ".join(sorted(set(src_refs) & set(tgt_refs))))

    out = ID_RE.sub(lambda m: "wwv_flow_api.id(%d)" % (int(m.group(1)) + d), source)
    for key in ("p_default_id_offset", "p_default_workspace_id"):
        out = out.replace(
            ",%s=>%d" % (key, header_value(source, key)),
            ",%s=>%d" % (key, header_value(target, key)),
        )
    print("ids shifted: %d" % len(ID_RE.findall(source)))
    with open(sys.argv[3], "w", encoding="utf8", newline="") as f:
        f.write(out)


if __name__ == "__main__":
    main()
