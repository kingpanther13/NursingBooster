#!/usr/bin/env python3
"""NursingBooster CI lint / congruence gate.

Static checks that encode this repo's recurring bug classes so they fail CI
instead of shipping:

  1. version-labels   - the two version label lines in the module agree, use a
                        valid channel format, and match the branch's channel
                        (devNN on master, X.Y on stable).
  2. missing-globals  - a module function reads a module-level variable
                        (assigned in NB_ModuleInit) without declaring it in a
                        `global` line and without a super-global declaration
                        elsewhere. In AHK v1 that read silently returns a blank
                        local (the dead-AlwaysOnTop bug class).
  3. show-noactivate  - Gui 80/84/85 (the NOACTIVATE panel family) must never
                        `Show` without `NA` or `Hide` (the focus-stealing bug
                        class).
  4. dead-toplevel    - executable statements stranded at top level between a
                        label's `return` and the next label/function never run
                        in an #Include'd module (the dead mini-bar-init class).
  5. host-congruence  - every NB_* label the host gosubs / SetTimers / IsLabels
                        exists in the module, and the host does not CREATE any
                        Gui in the module's reserved 80-85 range.
  6. if-balance       - every `#If <expr>` in the module is closed by a bare
                        `#If` before EOF (an open context leaks onto host
                        hotkeys included later).

Usage:
  python3 tools/ci_lint.py [--repo DIR] [--channel-branch NAME]

Exit code = number of findings (0 = clean).
"""

import argparse
import re
import sys
from pathlib import Path

MODULE = "nursingbooster_module.ahk"
HOST = "CPRSBooster_with_NursingBooster.ahk"

# Gui numbers the module owns; the host must not create these.
MODULE_GUI_RANGE = set(range(80, 86))

# Commands whose first argument is a label, not a variable (skip when scanning
# for variable reads).
LABEL_COMMANDS = re.compile(
    r"^\s*(?:SetTimer|Gosub|GoTo|Hotkey)\s*,?\s+", re.IGNORECASE
)

findings = []


def finding(check, path, lineno, message):
    findings.append((check, path, lineno, message))


def strip_comment_and_strings(line):
    """Remove ; comments (not inside quotes) and "quoted" string contents.

    Emits balanced "" for each string so the output can safely be re-scanned
    (an unbalanced quote would swallow the rest of the line on a second pass).
    """
    out = []
    in_str = False
    i = 0
    while i < len(line):
        ch = line[i]
        if in_str:
            if ch == '"':
                # "" is an escaped quote inside an AHK string
                if i + 1 < len(line) and line[i + 1] == '"':
                    i += 2
                    continue
                in_str = False
                out.append('"')
            i += 1
            continue
        if ch == '"':
            in_str = True
            out.append('"')
            i += 1
            continue
        if ch == ";" and (i == 0 or line[i - 1] in " \t"):
            break
        out.append(ch)
        i += 1
    return "".join(out)


LABEL_RE = re.compile(r"^([A-Za-z0-9_][A-Za-z0-9_]*):\s*(?:;.*)?$")
HOTKEY_RE = re.compile(r"^\S+::")
FUNC_RE = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)\(([^)]*)\)\s*\{\s*(?:;.*)?$")
RETURN_RE = re.compile(r"^\s*return\b", re.IGNORECASE)
GLOBAL_DECL_RE = re.compile(r"^\s*global\s+(.+)$", re.IGNORECASE)


def parse_global_names(decl):
    names = []
    for part in decl.split(","):
        name = part.split(":=")[0].strip()
        if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", name):
            names.append(name)
    return names


def segment_module(lines):
    """Classify each line of the module.

    Returns (functions, superglobals, init_assigns, toplevel_dead)
      functions: list of dicts {name, start, end, body_lines, globals}
      superglobals: set of names declared `global` outside any function
      init_assigns: set of variable names assigned in NB_ModuleInit's body
      toplevel_dead: list of (lineno, text) executable lines in no context
    """
    functions = []
    superglobals = set()
    init_assigns = set()
    toplevel_dead = []

    ctx = "none"          # none | label | hotkey | function
    cur_func = None
    in_init = False
    brace_depth = 0       # inside function bodies
    in_block_comment = False
    if_context_open = False

    for idx, raw in enumerate(lines, 1):
        stripped = raw.strip()

        if in_block_comment:
            if stripped.startswith("*/"):
                in_block_comment = False
            continue
        if stripped.startswith("/*"):
            in_block_comment = True
            continue

        code = strip_comment_and_strings(raw).rstrip()
        scode = code.strip()

        if ctx == "function":
            cur_func["body"].append((idx, code))
            m = GLOBAL_DECL_RE.match(code)
            if m:
                cur_func["globals"].update(parse_global_names(m.group(1)))
            brace_depth += code.count("{") - code.count("}")
            if brace_depth <= 0:
                cur_func["end"] = idx
                functions.append(cur_func)
                cur_func = None
                ctx = "none"
            continue

        m = FUNC_RE.match(code)
        if m and not re.match(r"^(if|while|for|loop|else|return)\b", m.group(1), re.IGNORECASE):
            cur_func = {
                "name": m.group(1),
                "start": idx,
                "end": None,
                "body": [],
                "globals": set(p.strip() for p in m.group(2).split(",") if p.strip()),
            }
            brace_depth = 1
            ctx = "function"
            continue

        lm = LABEL_RE.match(scode)
        if lm:
            ctx = "label"
            in_init = lm.group(1) == "NB_ModuleInit"
            continue
        if HOTKEY_RE.match(scode):
            ctx = "hotkey"
            continue

        if not scode:
            continue

        # Directives are fine anywhere; track #If context for check 6.
        if scode.startswith("#"):
            if re.match(r"^#If\b", scode, re.IGNORECASE):
                if_context_open = bool(re.match(r"^#If\s+\S", scode, re.IGNORECASE))
            continue

        mgl = GLOBAL_DECL_RE.match(code)
        if ctx in ("label", "hotkey", "none") and mgl:
            superglobals.update(parse_global_names(mgl.group(1)))

        if ctx == "label":
            if in_init:
                am = re.match(r"^\s*([A-Za-z_][A-Za-z0-9_]*)\s*:=", code)
                if am:
                    init_assigns.add(am.group(1))
                hm = re.search(r"\+?Hwnd([A-Za-z_][A-Za-z0-9_]*)", code)
                if hm:
                    init_assigns.add(hm.group(1))
            continue

        if ctx == "hotkey":
            continue

        # ctx == none: executable statement outside any context -> dead code
        toplevel_dead.append((idx, scode))

    return functions, superglobals, init_assigns, toplevel_dead, if_context_open


CONDITIONAL_PREFIX_RE = re.compile(
    r"^(if\b|else\b|while\b|for\b|loop\b|Loop,|IfMsgBox|IfWin|IfNot|IfExist|Ifexist|try\b)",
    re.IGNORECASE,
)


def label_body_tracking(lines):
    """Second pass purely for label/hotkey body 'return' end-tracking so
    statements after a label's closing return (still before the next label)
    are reported as dead. Handles brace blocks inside label bodies, and does
    not treat a conditional single-statement return (`if (x)` newline
    `return`) as the end of the label."""
    dead = []
    ctx = "none"
    depth = 0
    prev_code = ""
    in_block_comment = False
    for idx, raw in enumerate(lines, 1):
        stripped = raw.strip()
        if in_block_comment:
            if stripped.startswith("*/"):
                in_block_comment = False
            continue
        if stripped.startswith("/*"):
            in_block_comment = True
            continue
        code = strip_comment_and_strings(raw).strip()
        if not code:
            continue
        if LABEL_RE.match(code) or HOTKEY_RE.match(code):
            ctx = "body"
            depth = 0
            prev_code = ""
            continue
        m = FUNC_RE.match(code)
        if m and not re.match(r"^(if|while|for|loop|else|return)\b", m.group(1), re.IGNORECASE):
            ctx = "function"
            depth = 1
            prev_code = ""
            continue
        if ctx == "function":
            depth += code.count("{") - code.count("}")
            if depth <= 0:
                ctx = "closed"
                prev_code = ""
            continue
        if code.startswith("#"):
            prev_code = code
            continue
        if ctx == "body":
            conditional_return = (
                CONDITIONAL_PREFIX_RE.match(prev_code)
                and not prev_code.rstrip().endswith("{")
            )
            depth += code.count("{") - code.count("}")
            if depth <= 0 and RETURN_RE.match(code) and not conditional_return:
                ctx = "closed"
            prev_code = code
            continue
        if ctx == "closed":
            if GLOBAL_DECL_RE.match(code):
                # load-time declaration, legal (though discouraged) here
                continue
            dead.append((idx, code))
        prev_code = code
    return dead


def check_version_labels(repo, channel_branch):
    module = repo / MODULE
    text = module.read_text(encoding="utf-8", errors="replace")
    m1 = re.search(r"vNB_PanelTitle[^\n]*?,\s*Nursing Booster\s+(\S+)", text)
    m2 = re.search(r"vNB_VersionLine,\s*(\S+)\s*$", text, re.MULTILINE)
    if not m1 or not m2:
        finding("version-labels", MODULE, 0, "could not locate one or both version label lines")
        return
    v1, v2 = m1.group(1), m2.group(1)
    if v1 != v2:
        finding("version-labels", MODULE, 0,
                f"panel title says '{v1}' but settings version line says '{v2}'")
    for v in {v1, v2}:
        if not (re.fullmatch(r"dev\d+", v) or re.fullmatch(r"\d+\.\d+", v)):
            finding("version-labels", MODULE, 0,
                    f"label '{v}' is neither devNN (master) nor X.Y (stable)")
    if channel_branch == "master" and not re.fullmatch(r"dev\d+", v1):
        finding("version-labels", MODULE, 0,
                f"master/dev channel requires a devNN label, found '{v1}'")
    if channel_branch == "stable" and not re.fullmatch(r"\d+\.\d+", v1):
        finding("version-labels", MODULE, 0,
                f"stable channel requires an X.Y label, found '{v1}' "
                "(see PROMOTE_TO_STABLE.md - never carry devNN onto stable)")


def check_module(repo):
    module = repo / MODULE
    lines = module.read_text(encoding="utf-8", errors="replace").splitlines()

    functions, superglobals, init_assigns, _, if_open = segment_module(lines)

    # ---- check 2: missing globals ------------------------------------------
    # Anything NB_ModuleInit assigns is module state a function may only touch
    # after declaring it (or via a super-global declaration somewhere).
    module_vars = {v for v in init_assigns if not v.startswith("nb")}
    for fn in functions:
        allowed = fn["globals"] | superglobals
        for lineno, code in fn["body"]:
            if LABEL_COMMANDS.match(code):
                continue
            # fn body lines were already comment/string-stripped in segment_module
            for name in re.findall(r"\b(?:NB|CF)_[A-Za-z0-9_]+\b", code):
                if name in module_vars and name not in allowed:
                    finding("missing-globals", MODULE, lineno,
                            f"{fn['name']}() uses module variable {name} without "
                            "a global declaration (reads a blank local in AHK v1)")

    # ---- check 3: Show without NA on the NOACTIVATE family ------------------
    for idx, raw in enumerate(lines, 1):
        code = strip_comment_and_strings(raw)
        m = re.search(r"Gui,\s*(8[045])\s*:\s*Show\b([^;]*)", code)
        if m and not re.search(r"\b(NA|Hide)\b", m.group(2)):
            finding("show-noactivate", MODULE, idx,
                    f"Gui {m.group(1)}:Show without NA/Hide steals focus from CPRS "
                    "(WS_EX_NOACTIVATE does not block programmatic activation)")

    # ---- check 4: dead top-level statements ---------------------------------
    for lineno, code in label_body_tracking(lines):
        finding("dead-toplevel", MODULE, lineno,
                f"statement between labels never executes in an #Include'd module: '{code[:60]}'")

    # ---- check 6: #If balance ----------------------------------------------
    if if_open:
        finding("if-balance", MODULE, len(lines),
                "#If <expr> context still open at EOF - add a bare #If to close it")

    return lines


def check_host_congruence(repo, module_lines):
    host = repo / HOST
    if not host.exists():
        return
    module_text = "\n".join(module_lines)
    module_labels = set(re.findall(r"^([A-Za-z0-9_][A-Za-z0-9_]*):\s*(?:;.*)?$",
                                   module_text, re.MULTILINE))

    host_lines = host.read_text(encoding="utf-8", errors="replace").splitlines()
    in_block_comment = False
    for idx, raw in enumerate(host_lines, 1):
        stripped = raw.strip()
        if in_block_comment:
            if stripped.startswith("*/"):
                in_block_comment = False
            continue
        if stripped.startswith("/*"):
            in_block_comment = True
            continue
        code = strip_comment_and_strings(raw)

        # NB_* labels the host expects the module to provide
        for m in re.finditer(
                r"(?:Gosub\s*,?\s*|SetTimer\s*,\s*|IsLabel\(\")\s*(NB_[A-Za-z0-9_]+)",
                code, re.IGNORECASE):
            name = m.group(1)
            if name not in module_labels and not host_defines_label(host_lines, name):
                finding("host-congruence", HOST, idx,
                        f"host references label {name} which exists in neither "
                        "the module nor the host")

        # Host must not CREATE a Gui in the module's range (Destroy is fine)
        m = re.search(r"Gui[,\s]+(\d+)\s*:\s*(Add|New|Show|Color|Font|Margin|Menu)\b",
                      code, re.IGNORECASE)
        if m and int(m.group(1)) in MODULE_GUI_RANGE:
            finding("host-congruence", HOST, idx,
                    f"host creates Gui {m.group(1)} inside the module's reserved "
                    "range 80-85")


def host_defines_label(host_lines, name):
    pat = re.compile(rf"^{re.escape(name)}:\s*(?:;.*)?$")
    return any(pat.match(strip_comment_and_strings(l).strip()) for l in host_lines)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", default=".", help="repo root")
    ap.add_argument("--channel-branch", default="",
                    help="branch whose channel rules apply (master/stable); "
                    "empty = only label agreement + format are enforced")
    args = ap.parse_args()
    repo = Path(args.repo)

    check_version_labels(repo, args.channel_branch)
    module_lines = check_module(repo)
    check_host_congruence(repo, module_lines)

    if findings:
        print(f"ci_lint: {len(findings)} finding(s)")
        for check, path, lineno, message in findings:
            loc = f"{path}:{lineno}" if lineno else path
            print(f"::error file={path},line={lineno}::[{check}] {loc}: {message}")
    else:
        print("ci_lint: clean")
    sys.exit(min(len(findings), 100))


if __name__ == "__main__":
    main()
