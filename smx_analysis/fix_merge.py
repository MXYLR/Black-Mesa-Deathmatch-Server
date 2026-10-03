#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Fix merge.py: replace everything from 'def run():' to EOF with clean body."""
src = open("merge.py", encoding="utf-8").read()
idx = src.index("def run():")
head = src[:idx]

run_body = '''def run():
    global API_NATIVES, CORE_FORWARDS, PRE, MODULE_RESULTS
    API_NATIVES = get_api_natives()
    CORE_FORWARDS, _ = get_core_forwards()

    # phase 1: preprocess all modules (expand, strip myinfo, collect original symbols)
    PRE = {}
    for mod in MODULES:
        text = read_text(main_file(mod))
        text = expand_local_includes(text, os.path.dirname(main_file(mod)))
        text = remove_myinfo(text)
        public_funcs = collect_public_funcs(text)
        funcs, vars_, macros, types, em, mn = collect_symbols(text)
        syms = (funcs | vars_ | macros | types | em | mn)
        syms.discard(None)
        PRE[mod] = {"text": text, "public": public_funcs, "syms": syms}

    # phase 2: determine direct-call implementors for plugin forwards
    impls_by_fwd = {}
    for fwd_name in PLUGIN_FORWARDS:
        impls = [m for m in MODULES if fwd_name in PRE[m]["public"]]
        if impls:
            impls_by_fwd[fwd_name] = impls
            print("bridge %s -> %s" % (fwd_name, impls))

    # phase 3: rename and emit module files
    MODULE_RESULTS = {}
    for mod in MODULES:
        prefix = module_prefix(mod)
        text = bridge_plugin_forwards(mod, PRE[mod]["text"], impls_by_fwd)
        renamer = Renamer(PRE[mod]["syms"], prefix, API_NATIVES)
        text = renamer.rename(text)
        MODULE_RESULTS[mod] = {"prefix": prefix, "public": PRE[mod]["public"]}
        with open(os.path.join(OUT_DIR, mod + ".sp"), "w", encoding="utf-8") as f:
            f.write(text)
        print("processed %s (%d syms)" % (mod, len(PRE[mod]["syms"])))

    # phase 4: assemble BMAG.sp
    parts = [
        "#pragma semicolon 1\\n"
        "#pragma newdecls required\\n"
        "#include <sourcemod>\\n"
        "#include <sdktools>\\n"
        "#include <sdkhooks>\\n"
        "#include <admin>\\n"
        "#include <adminmenu>\\n"
        "#include <topmenus>\\n"
        "#include <clientprefs>\\n"
        "#include <cstrike>\\n"
        "#include <geoip>\\n"
        "#include <mapchooser>\\n"
        "#include <nextmap>\\n"
        "#include <sourcebanspp>\\n"
        "#include <sourcecomms>\\n"
        "\\n"
        "public Plugin myinfo =\\n"
        "{\\n"
        '\\tname = "Black Mesa All-in-One",\\n'
        '\\tauthor = "Merged",\\n'
        '\\tdescription = "Merged server plugins",\\n'
        '\\tversion = "1.0.0",\\n'
        '\\turl = ""\\n'
        "};\\n"
    ]

    api_decls = []
    for inc_name in API_INCLUDES:
        for native_name, (ret, params) in extract_from_inc(inc_name, "native").items():
            api_decls.append("forward %s %s%s(%s);" % (ret, module_prefix(inc_name), native_name, params))
    if api_decls:
        parts.append("\\n// Cross-module API forward declarations\\n" + "\\n".join(api_decls) + "\\n")

    parts.append("\\n// ================= Modules =================")
    for mod in MODULES:
        parts.append("\\n// ---- Module: %s ----\\n" % mod)
        with open(os.path.join(OUT_DIR, mod + ".sp"), encoding="utf-8") as f:
            parts.append(f.read())

    bridges = {}
    for mod, meta in MODULE_RESULTS.items():
        for fname in meta["public"]:
            if fname in CORE_FORWARDS:
                bridges.setdefault(fname, []).append((mod, meta["public"][fname]))

    bridge_parts = []
    for fname in ["OnPluginStart", "AskPluginLoad2", "OnAllPluginsLoaded", "OnConfigsExecuted"]:
        if fname in bridges:
            impls = sorted(
                bridges[fname],
                key=lambda t: SPECIAL_ORDER.index(t[0]) if t[0] in SPECIAL_ORDER else 99,
            )
            b = build_bridge(fname, impls)
            if b:
                bridge_parts.append(b)
    for fname, impls in bridges.items():
        if fname in ("OnPluginStart", "AskPluginLoad2", "OnAllPluginsLoaded", "OnConfigsExecuted"):
            continue
        b = build_bridge(fname, impls)
        if b:
            bridge_parts.append(b)

    if bridge_parts:
        parts.append("\\n// ================= Lifecycle bridges =================")
        parts.extend(bridge_parts)
        parts.append("")

    main_text = "\\n".join(parts)
    with open(os.path.join(OUT_DIR, "BMAG.sp"), "w", encoding="utf-8") as f:
        f.write(main_text)
    print("wrote BMAG.sp (%d lines)" % main_text.count("\\n"))
    print("bridges:", sorted(bridges.keys()))


if __name__ == "__main__":
    run()
'''

open("merge.py", "w", encoding="utf-8").write(head + run_body)

import ast
ast.parse(open("merge.py", encoding="utf-8").read())
print("syntax OK")
