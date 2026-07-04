#!/usr/bin/env python3
"""Self-test for ci_lint.py: seeds one known bug per check into throwaway
copies of the REAL module/host and asserts the right check fires; also
asserts the clean tree stays clean. Runs in the CI lint job, so a regex
tweak that silently neuters a check turns the build red instead of giving
false confidence.

Usage: python3 tools/test_ci_lint.py   (from the repo root)
Exit code = number of failed cases.
"""

import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
LINT = REPO / "tools" / "ci_lint.py"
MODULE = "nursingbooster_module.ahk"
HOST = "CPRSBooster_with_NursingBooster.ahk"

failures = 0


def run_lint(tree, branch="master"):
    proc = subprocess.run(
        [sys.executable, str(LINT), "--repo", str(tree), "--channel-branch", branch],
        capture_output=True, text=True)
    return proc.returncode, proc.stdout + proc.stderr


def seed_tree(tmp):
    tree = Path(tmp) / "tree"
    tree.mkdir()
    shutil.copy(REPO / MODULE, tree / MODULE)
    shutil.copy(REPO / HOST, tree / HOST)
    return tree


def case(name, check_tag, mutate, branch="master", expect_clean=False):
    global failures
    with tempfile.TemporaryDirectory() as tmp:
        tree = seed_tree(tmp)
        if mutate:
            mutate(tree)
        code, out = run_lint(tree, branch)
        hits = out.count(f"[{check_tag}]") if check_tag else 0
        ok = (code == 0 and "clean" in out) if expect_clean else (code != 0 and hits > 0)
        status = "PASS" if ok else "FAIL"
        if not ok:
            failures += 1
        print(f"{status}: {name}"
              + ("" if expect_clean else f" ({hits} x [{check_tag}], exit {code})"))
        if not ok:
            print(out.strip()[:800])


def sub(tree, fname, old, new, count=1):
    p = tree / fname
    text = p.read_text(encoding="utf-8")
    assert old in text, f"seed anchor missing in {fname}: {old[:60]!r}"
    p.write_text(text.replace(old, new, count), encoding="utf-8")


def append(tree, fname, extra):
    p = tree / fname
    p.write_text(p.read_text(encoding="utf-8") + extra, encoding="utf-8")


def main():
    # 0. the real tree must be clean (master channel rules)
    case("clean tree stays clean", None, None, expect_clean=True)

    # 1a. version-label disagreement between the two label lines
    def m_version(tree):
        text = (tree / MODULE).read_text(encoding="utf-8")
        m = re.search(r"vNB_VersionLine, (\S+)", text)
        sub(tree, MODULE, f"vNB_VersionLine, {m.group(1)}", "vNB_VersionLine, dev999")
    case("version label mismatch", "version-labels", m_version)

    # 1b. dev label forbidden on the stable channel
    case("dev label on stable channel", "version-labels", None, branch="stable")

    # 2. function reads module state without declaring it
    case("missing global declaration", "missing-globals", lambda t: sub(
        t, MODULE,
        "    global NB_BoosterGuiVisible, NB_PanelHwnd, NB_DebugLogging",
        "    global NB_DebugLogging"))

    # 2b. module state assigned ONLY in a sub-label (not init) still guarded
    case("missing global for label-assigned state", "missing-globals", lambda t: append(
        t, MODULE,
        "\nNB_SeedLabel:\n    NB_SeedVar := 1\nreturn\n\n"
        "NB_SeedFunc() {\n    x := NB_SeedVar\n    return x\n}\n"))

    # 3. NOACTIVATE-family Gui shown without NA
    case("Gui 80 Show without NA", "show-noactivate", lambda t: sub(
        t, MODULE, "Gui, 80:Show, NA", "Gui, 80:Show"))

    # 4. executable statement stranded between labels
    case("dead top-level statement", "dead-toplevel", lambda t: sub(
        t, MODULE, "\nNB_CheckGui14Dropdown:",
        "\nNB_OrphanVar := 1\nNB_CheckGui14Dropdown:"))

    # 5a. host references a label the module does not define
    case("host references missing label", "host-congruence", lambda t: sub(
        t, HOST, "gosub NB_FetchModuleIfNeeded", "gosub NB_FetchModuleWrongName"))

    # 5b. host creates a Gui inside the module's reserved range
    case("host creates reserved Gui", "host-congruence", lambda t: sub(
        t, HOST, "ButtonOK: ; Execute the following actions when the button from the GUI OK is pressed",
        "ButtonOK:\nGui, 82:Add, Text,, oops"))

    # 5c. panel-showing timer with no host teardown
    case("panel-show timer never turned Off", "host-congruence", lambda t: sub(
        t, HOST, "SetTimer, NB_RestorePanelAfterFKey, Off", "; seed: teardown removed"))

    # 6. unbalanced #If context at EOF
    def m_ifbal(tree):
        p = tree / MODULE
        lines = p.read_text(encoding="utf-8").splitlines()
        assert lines[-1].startswith("#If"), lines[-1]
        p.write_text("\n".join(lines[:-1]) + "\n", encoding="utf-8")
    case("open #If context at EOF", "if-balance", m_ifbal)

    print(f"\nci_lint self-test: {failures} failure(s)")
    sys.exit(failures)


if __name__ == "__main__":
    main()
