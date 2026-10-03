#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Bisect compile crashes: build partial merged.sp with first N modules + all bridges."""
import subprocess
import sys
import os

sys.path.insert(0, r"C:\tmp\smx_analysis")
import merge as M

SPCOMP = r"C:\tmp\smx_analysis\dl\sm-win\addons\sourcemod\scripting\spcomp.exe"
PARTIAL = r"C:\tmp\smx_analysis\partial.sp"
OUTSMX = r"C:\tmp\smx_analysis\partial.smx"


def build_partial(n, path):
    M.run()  # ensure PRE/MODULE_RESULTS populated
    parts = [
        "#pragma semicolon 1\n#pragma newdecls required\n"
        "#include <sourcemod>\n#include <sdktools>\n#include <sdkhooks>\n"
        "#include <admin>\n#include <adminmenu>\n#include <topmenus>\n"
        "#include <clientprefs>\n#include <cstrike>\n#include <geoip>\n"
        "#include <mapchooser>\n#include <nextmap>\n#include <sourcebanspp>\n#include <sourcecomms>\n"
        "\npublic Plugin myinfo =\n{\n\tname = \"T\",\n\tauthor = \"T\",\n\tdescription = \"T\",\n\tversion = \"1\",\n\turl = \"\"\n};\n"
    ]
    api_decls = []
    for inc_name in M.API_INCLUDES:
        for native_name, (ret, params) in M.extract_from_inc(inc_name, "native").items():
            api_decls.append("forward %s %s%s(%s);" % (ret, M.module_prefix(inc_name), native_name, params))
    parts.append("\n// API forwards\n" + "\n".join(api_decls))
    parts.append("\n// Modules\n")
    for mod in M.MODULES[:n]:
        with open(os.path.join(M.OUT_DIR, mod + ".sp"), encoding="utf-8") as f:
            parts.append("\n// ---- %s ----\n%s" % (mod, f.read()))
    parts.append("\n// Bridges\n")
    M.MODULE_RESULTS = {m: {"prefix": M.module_prefix(m), "public": M.PRE[m]["public"]} for m in M.MODULES}
    bridges = {}
    for mod, meta in M.MODULE_RESULTS.items():
        for fname in meta["public"]:
            if fname in M.CORE_FORWARDS:
                bridges.setdefault(fname, []).append((mod, meta["public"][fname]))
    for fname, impls in sorted(bridges.items()):
        b = M.build_bridge(fname, impls)
        if b:
            parts.append(b)
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(parts))


def try_compile(n):
    build_partial(n, PARTIAL)
    r = subprocess.run(
        [SPCOMP, "-i", r"C:\tmp\smx_analysis\src\scripting\include",
         "-i", r"C:\tmp\smx_analysis\src\scripting\plugins\include",
         "-o", OUTSMX, PARTIAL],
        capture_output=True, text=True)
    return r.returncode, (r.stdout or r.stderr)


if __name__ == "__main__":
    lo = int(sys.argv[1]) if len(sys.argv) > 1 else 1
    hi = int(sys.argv[2]) if len(sys.argv) > 2 else 38
    while lo < hi:
        mid = (lo + hi) // 2
        rc, out = try_compile(mid)
        crash = rc not in (0, 1)
        print("N=%d rc=%d %s" % (mid, rc, "CRASH" if crash else "ok"), flush=True)
        if crash:
            hi = mid
        else:
            lo = mid + 1
    print("boundary: first crashing module count = %d" % lo)
    rc, out = try_compile(max(1, lo - 1))
    print("N=%d rc=%d" % (lo - 1, rc))
    print(out[:3000])
