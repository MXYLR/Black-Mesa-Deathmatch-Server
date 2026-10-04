#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Merge 35 enabled server plugins into a single .sp / .smx."""
import os
import re

SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)), "src", "scripting")
PLUGIN_DIR = os.path.join(SRC, "plugins")
INC_DIR = os.path.join(SRC, "include")
OUT_DIR = os.path.join(SRC, "BMAG")
os.makedirs(OUT_DIR, exist_ok=True)

MODULES = [
    "admincheats", "admin-flatfile", "adminhelp", "adminmenu", "advertisements",
    "adv-weapon_cleaner", "antiflood", "basechat", "basecomm", "basecommands",
    "basetriggers", "basevotes", "clientprefs", "connectmessage", "fast_spawn",
    "funcommands", "funvotes", "mapchooser", "missing_viewmodel_fix", "motd-fixer",
    "nominations", "pause", "playercommands", "reservedslots", "rockthevote",
    "showhealth", "sm_noearbleed", "sounds", "SpecDetails",
    "speclist", "sql-admin-manager", "teamjoinblocker",
    "bms_match", "textmsg_fix", "spawn_distribute",
]

API_INCLUDES = ["adminmenu", "topmenus", "mapchooser"]

# plugin-provided forwards whose in-merge implementors need direct-call bridging
PLUGIN_FORWARDS = {
    "OnAdminMenuReady": "adminmenu",
    "OnNominationRemoved": "mapchooser",
}

SPECIAL_ORDER = ["adminmenu", "topmenus", "mapchooser"]

# bms_match implements its SM lifecycle forwards with a Bms_ prefix (e.g.
# Bms_OnClientSayCommand).  collect_public_funcs only matches exact forward
# names, so these were silently never bridged in the merged build - the say
# hook (in-match !pause / rtv interception) and the PutInServer/Disconnect
# handlers were all dead code.  Map them back to the canonical SM names
# before collection so they are bridged like any other module's forwards.
FORWARD_ALIASES = {
    "Bms_OnClientPutInServer": "OnClientPutInServer",
    "Bms_OnClientDisconnect": "OnClientDisconnect",
    "Bms_OnClientSayCommand": "OnClientSayCommand",
}


def rename_forward_aliases(text):
    """Rename Bms_-prefixed forwards to their canonical SM names."""
    for old, new in FORWARD_ALIASES.items():
        text = re.sub(r"\b" + old + r"\b", new, text)
    return text


def read_text(path):
    with open(path, "rb") as f:
        raw = f.read()
    for enc in ("utf-8-sig", "gbk"):
        try:
            return raw.decode(enc)
        except UnicodeDecodeError:
            continue
    return raw.decode("utf-8", "replace")


def module_prefix(name):
    return "mod_" + name.replace("-", "_") + "_"


def main_file(name):
    if name == "admin-flatfile":
        return os.path.join(PLUGIN_DIR, "admin-flatfile", "admin-flatfile.sp")
    return os.path.join(PLUGIN_DIR, name + ".sp")


def extract_from_inc(inc_name, kind):
    """Extract 'kind' (native|forward) declarations from an include. -> {name: (ret, params)}"""
    path = os.path.join(INC_DIR, inc_name + ".inc")
    if not os.path.exists(path):
        return {}
    text = read_text(path)
    text = re.sub(r"/\*.*?\*/", " ", text, flags=re.S)
    text = re.sub(r"//[^\n]*", " ", text)
    out = {}
    for m in re.finditer(
        kind + r"\s+([\w:]+)\s+([A-Za-z_]\w*)\s*\((.*?)\)\s*;", text, flags=re.S
    ):
        out[m.group(2)] = (m.group(1), re.sub(r"\s+", " ", m.group(3)).strip())
    return out


def get_api_natives():
    """native name -> prefixed provider function name."""
    mapping = {}
    for inc_name in API_INCLUDES:
        for name in extract_from_inc(inc_name, "native"):
            mapping[name] = module_prefix(inc_name) + name
    return mapping


def get_core_forwards():
    """forward names provided by engine/extensions (need bridging), and
    plugin-API forwards (excluded)."""
    all_fwd, plugin_fwd = set(), set()
    for f in os.listdir(INC_DIR):
        if not f.endswith(".inc"):
            continue
        inc = f[:-4]
        fwds = extract_from_inc(inc, "forward")
        if inc in API_INCLUDES:
            plugin_fwd.update(fwds.keys())
        all_fwd.update(fwds.keys())
    return all_fwd - plugin_fwd, plugin_fwd


def expand_local_includes(text, base_dir, depth=0):
    if depth > 6:
        return text

    def repl(m):
        rel = m.group(1)
        path = os.path.join(base_dir, rel)
        if not os.path.exists(path):
            return m.group(0)
        sub = read_text(path)
        return "\n" + expand_local_includes(sub, os.path.dirname(path), depth + 1) + "\n"

    return re.sub(r'#include\s+"([^"]+\.sp)"', repl, text)


def remove_myinfo(text):
    # drop the myinfo block plus a wrapping #if/#else/#endif shell
    text = re.sub(
        r"(?:^#if[^\n]*\n)?public\s+Plugin:?myinfo\s*=.*?\n\s*};",
        "", text, flags=re.S | re.M,
    )
    return text


def remove_autoeexec(text):
    """Drop AutoExecConfig calls from modules.  In the merged plugin every
    module cvar belongs to the SAME plugin, so AutoExecConfig saves all of
    them under one file (last call wins) at map end - persisting mid-match
    values such as sm_fastspawn=0 (set by bms_match during matches) across
    map loads and silently changing the public defaults.  Cvar compiled
    defaults + server.cfg are the single source of truth instead."""
    out = []
    for ln in text.split("\n"):
        if re.search(r"^\s*AutoExecConfig\s*\(", ln):
            continue
        out.append(ln)
    return "\n".join(out)


def needs_olddecls(text):
    """True if module uses pre-1.7 syntax (new bool:, public Plugin:, tag: params,
    typeless public funcs, bare new decls).  False positives are harmless:
    new-style code compiles under `#pragma newdecls optional`."""
    return bool(
        re.search(
            r"public\s+Plugin:|"
            r"\(\s*(?:bool|String|Handle|Float|Plugin)\s*:|"
            r"\b(?:bool|String|Handle|Float)\s*:\s*\w+\s*\(|"
            r"public\s+[A-Za-z_]\w*\s*\(|"
            r"\bnew\s+",
            text,
        )
    )


def collect_public_funcs(text):
    """{name: ret} for top-level public functions (before renaming)."""
    out = {}
    for ln in text.split("\n"):
        if ln[:1] in (" ", "\t"):
            continue
        code = ln.rstrip()
        m = re.match(r"^public\s+([\w:]+(?::\w+)?\s+)?([A-Za-z_]\w*)\s*\(", code)
        if m:
            out[m.group(2)] = (m.group(1) or "void").strip()
    return out


def collect_symbols(text):
    """(funcs, vars_, macros, types, enum_members, method_names) top-level."""
    funcs, vars_, macros = set(), set(), set()
    types, enum_members, method_names = set(), set(), set()
    in_block = None   # (kind, brace_depth); kind: enum / struct / methodmap / typeset
    pending = None    # kind awaiting an opening brace on a later line

    for ln in text.split("\n"):
        code = ln.strip()
        if not code:
            continue
        if in_block:
            kind, depth = in_block
            depth += code.count("{") - code.count("}")
            if kind == "enum":
                if not (code.startswith("//") or code.startswith("*") or code.startswith("/*")):
                    for m in re.finditer(r"\b([A-Za-z_]\w*)\s*(?:=|,|\})", code):
                        enum_members.add(m.group(1))
            elif kind == "methodmap":
                for m in re.finditer(
                    r"(?:public\s+)?(?:[\w:]+(?::\w+)?\s+)*([A-Za-z_]\w*)\s*\(", code
                ):
                    method_names.add(m.group(1))
            in_block = (kind, depth) if depth > 0 else None
            continue
        if pending:
            if "{" in code:
                in_block = (pending, code.count("{") - code.count("}"))
                pending = None
                continue
            if ";" in code:
                pending = None
            continue
        if ln[:1] in (" ", "\t") or code.startswith("//"):
            continue
        m = re.match(r"^(enum\s+struct|enum|struct|methodmap|typeset|typedef)\b(.*)$", code)
        if m:
            kw_full, rest = m.group(1), m.group(2)
            kw = "enum_struct" if kw_full == "enum struct" else kw_full
            nm = re.match(r"\s*([A-Za-z_]\w*)", rest)
            if nm:
                types.add(nm.group(1))
            has_brace = "{" in rest
            if kw == "enum_struct":
                # fields do not occupy the global namespace
                if has_brace:
                    in_block = ("struct", rest.count("{") - rest.count("}"))
                else:
                    pending = "struct"
            elif kw == "enum":
                if has_brace:
                    in_block = ("enum", rest.count("{") - rest.count("}"))
                else:
                    pending = "enum"
            else:
                if has_brace:
                    in_block = (kw, 1)
                else:
                    pending = kw
            continue
        m = re.match(r"^#define\s+([A-Za-z_]\w*)", code)
        if m:
            macros.add(m.group(1))
            continue
        if code.startswith("#"):
            continue

        m = re.match(r"^(?:public|static|new)\s+", code)
        pre = bool(m)
        c = re.sub(r"^(?:public|static|new)\s+", "", code)
        m = re.match(r"^(\w+):([A-Za-z_]\w*)\s*(\()", c)
        if m:
            (funcs if pre else vars_).add(m.group(2))
            continue
        m = re.match(r"^(\w+):([A-Za-z_]\w*)\s*(;|=|\[|$)", c)
        if m:
            vars_.add(m.group(2))
            continue
        m = re.match(r"^(\w+)\s+([A-Za-z_]\w*)\s*(\()", c)
        if m:
            (funcs if pre else vars_).add(m.group(2))
            continue
        m = re.match(r"^([A-Za-z_]\w*)\s*(\()", c)
        if m:
            (funcs if pre else vars_).add(m.group(1))
            continue
        m = re.match(r"^(\w+)\s+([A-Za-z_]\w*)\s*(;|=|\[|$)", c)
        if m:
            vars_.add(m.group(2))
            continue
        m = re.match(r"^([A-Za-z_]\w*)\s*(;|=)", c)
        if m:
            vars_.add(m.group(1))
            continue
    return funcs, vars_, macros, types, enum_members, method_names


class Renamer:
    """Token-aware renamer protecting strings, comments and #include lines."""

    def __init__(self, syms, prefix):
        self.syms = syms
        self.prefix = prefix

    def rename(self, text):
        out = []
        i, n = 0, len(text)
        while i < n:
            c = text[i]
            if c == '"' or c == "'":
                j = i + 1
                while j < n:
                    if text[j] == "\\":
                        j += 2
                        continue
                    if text[j] == c:
                        break
                    j += 1
                out.append(text[i : j + 1])
                i = j + 1
            elif c == "/" and i + 1 < n and text[i + 1] == "/":
                j = text.find("\n", i)
                if j == -1:
                    j = n
                out.append(text[i:j])
                i = j
            elif c == "/" and i + 1 < n and text[i + 1] == "*":
                j = text.find("*/", i + 2)
                j = n if j == -1 else j + 2
                out.append(text[i:j])
                i = j
            elif c == "#":
                j = text.find("\n", i)
                if j == -1:
                    j = n
                line = text[i:j]
                if re.match(r"#\s*include\s*[<]", line):
                    out.append(line)
                else:
                    out.append(self._rename_identifiers(line))
                i = j
            elif c.isalpha() or c == "_":
                j = i
                while j < n and (text[j].isalnum() or text[j] == "_"):
                    j += 1
                tok = text[i:j]
                if tok in self.syms:
                    out.append(self.prefix + tok)
                else:
                    out.append(tok)
                i = j
            else:
                out.append(c)
                i += 1
        return "".join(out)

    def _rename_identifiers(self, text):
        """Rename identifiers in a preprocessor line without recursing on '#'."""
        out = []
        i, n = 0, len(text)
        while i < n:
            c = text[i]
            if c == '"' or c == "'":
                j = i + 1
                while j < n:
                    if text[j] == "\\":
                        j += 2
                        continue
                    if text[j] == c:
                        break
                    j += 1
                out.append(text[i : j + 1])
                i = j + 1
            elif c.isalpha() or c == "_":
                j = i
                while j < n and (text[j].isalnum() or text[j] == "_"):
                    j += 1
                tok = text[i:j]
                if tok in self.syms:
                    out.append(self.prefix + tok)
                else:
                    out.append(tok)
                i = j
            else:
                out.append(c)
                i += 1
        return "".join(out)


def find_forward_handles(text):
    handles = {}
    for m in re.finditer(
        r"(?:new\s+)?([A-Za-z_]\w*)\s*=\s*(?:new\s+)?(?:GlobalForward|CreateGlobalForward)\(\s*\"([A-Za-z_]\w*)\"",
        text,
    ):
        handles[m.group(1)] = m.group(2)
    return handles


def bridge_plugin_forwards(module, text, impls_by_fwd):
    """Rewrite Call_StartForward(handle) blocks into direct calls for forwards
    that have in-merge implementors."""
    handles = find_forward_handles(text)
    for handle, fwd_name in handles.items():
        impls = impls_by_fwd.get(fwd_name)
        if not impls:
            continue
        pattern = re.compile(
            r"Call_StartForward\(" + re.escape(handle) + r"\);\s*"
            r"(?P<push>(?:Call_Push(?:String|Cell|Float|Array|Any)\s*\([^;]+\);\s*)*)"
            r"Call_Finish\(\);",
            re.S,
        )

        def repl(m):
            pushes = re.findall(
                r"Call_Push(?:String|Cell|Float|Array|Any)\s*\(([^;]+)\);", m.group("push")
            )
            args = ", ".join(pushes)
            return "\n".join(
                "\t%s%s(%s);" % (module_prefix(imp), fwd_name, args)
                for imp in impls
            )

        text = pattern.sub(repl, text)
    return text


def build_bridge(fname, impls):
    sig = None
    for f in os.listdir(INC_DIR):
        if not f.endswith(".inc"):
            continue
        s = extract_from_inc(f[:-4], "forward").get(fname)
        if s:
            sig = s
            break
    if sig is None:
        return None
    ret, params = sig
    param_names = []
    for p in params.split(","):
        p = p.strip()
        if not p:
            continue
        nm = re.split(r"\s+", p)[-1]
        nm = re.sub(r"\[.*?\]", "", nm).replace("&", "").strip()
        param_names.append(nm)
    plist = ", ".join(param_names)
    calls = "\n".join(
        "\t%s%s(%s);" % (MODULE_RESULTS[mod]["prefix"], fname, plist) for mod, _ in impls
    )
    if ret == "void":
        return "public void %s(%s)\n{\n%s\n}" % (fname, params, calls)
    if ret == "APLRes":
        body = calls + "\n\treturn APLRes_Success;"
        return "public APLRes %s(%s)\n{\n%s\n}" % (fname, params, body)
    if ret == "bool":
        body = ""
        for mod, _ in impls:
            body += "\tif (!%s%s(%s))\n\t{\n\t\treturn false;\n\t}\n" % (
                MODULE_RESULTS[mod]["prefix"], fname, plist)
        body += "\treturn true;"
        return "public bool %s(%s)\n{\n%s\n}" % (fname, params, body)
    if ret == "Action":
        body = ""
        for i, (mod, _) in enumerate(impls):
            body += "\tAction _a%d_ = %s%s(%s);\n\tif (_a%d_ != Plugin_Continue)\n\t{\n\t\treturn _a%d_;\n\t}\n" % (
                i, MODULE_RESULTS[mod]["prefix"], fname, plist, i, i)
        body += "\treturn Plugin_Continue;"
        return "public Action %s(%s)\n{\n%s\n}" % (fname, params, body)
    return None


# ---------- main ----------
def run():
    global CORE_FORWARDS, PRE, MODULE_RESULTS
    CORE_FORWARDS, _ = get_core_forwards()

    # phase 1: preprocess all modules (expand, strip myinfo, collect original symbols)
    PRE = {}
    for mod in MODULES:
        text = read_text(main_file(mod))
        text = expand_local_includes(text, os.path.dirname(main_file(mod)))
        text = remove_myinfo(text)
        text = remove_autoeexec(text)
        text = rename_forward_aliases(text)
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
        renamer = Renamer(PRE[mod]["syms"], prefix)
        text = renamer.rename(text)
        MODULE_RESULTS[mod] = {"prefix": prefix, "public": PRE[mod]["public"]}
        with open(os.path.join(OUT_DIR, mod + ".sp"), "w", encoding="utf-8") as f:
            f.write(text)
        print("processed %s (%d syms)" % (mod, len(PRE[mod]["syms"])))

    # phase 4: assemble BMAG.sp
    parts = [
        "#pragma semicolon 1\n"
        "#pragma newdecls required\n"
        "#include <sourcemod>\n"
        "#include <sdktools>\n"
        "#include <sdkhooks>\n"
        "#include <admin>\n"
        "#include <adminmenu>\n"
        "#include <topmenus>\n"
        "#include <clientprefs>\n"
        "#include <geoip>\n"
        "#include <mapchooser>\n"
        "#include <nextmap>\n"
        "\n"
        "#define AUTOLOAD_EXTENSIONS\n"
        "#include <socket>\n"
        "\n"
        "public Plugin myinfo =\n"
        "{\n"
        '\tname = "BMAG",\n'
        '\tauthor = "MXYLR",\n'
        '\tdescription = "Merged server plugins",\n'
        '\tversion = "1.0.0",\n'
        '\turl = ""\n'
        "};\n"
    ]

    parts.append("\n// ================= Modules =================")
    for mod in MODULES:
        parts.append("\n// ---- Module: %s ----\n" % mod)
        with open(os.path.join(OUT_DIR, mod + ".sp"), encoding="utf-8") as f:
            mod_text = f.read()
        mod_text = "#undef REQUIRE_PLUGIN\n#undef REQUIRE_EXTENSIONS\n" + mod_text
        if needs_olddecls(mod_text):
            parts.append("#pragma newdecls optional")
            parts.append(mod_text)
            parts.append("#pragma newdecls required")
        else:
            parts.append(mod_text)

    bridges = {}
    for mod, meta in MODULE_RESULTS.items():
        for fname in meta["public"]:
            if fname == "AskPluginLoad" and "AskPluginLoad2" in meta["public"]:
                continue  # dead #else branch for SM < 1.3
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
        parts.append("\n// ================= Lifecycle bridges =================")
        parts.extend(bridge_parts)
        parts.append("")

    main_text = "\n".join(parts)
    with open(os.path.join(OUT_DIR, "BMAG.sp"), "w", encoding="utf-8") as f:
        f.write(main_text)
    print("wrote BMAG.sp (%d lines)" % main_text.count("\n"))
    print("bridges:", sorted(bridges.keys()))


if __name__ == "__main__":
    run()
