# NursingBooster — agent notes

## Versioning (IMPORTANT — do not get this wrong)

Two release channels, **different label styles**:

| Channel  | Branch   | Label style | Current |
|----------|----------|-------------|---------|
| Dev/Beta | `master` | `devXX`     | `dev21` |
| Stable   | `stable` | `X.Y`       | `1.0`   |

The label appears in **two** lines of `nursingbooster_module.ahk`: the `vNB_PanelTitle`
line and the `vNB_VersionLine` line.

**When promoting dev → stable: copy the CODE from master, but RE-LABEL to stable's
next `X.Y` — never let the `devXX` label land on `stable`.** The stable module must
differ from master only in those two label lines. Full steps: `PROMOTE_TO_STABLE.md`.
(History: stable's label was wrongly carried as `dev6`/`dev18` from verbatim copies
before it was reset to `1.0`.)

## What ships

- `nursingbooster_module.ahk` is the live module users fetch (dev → `master` raw URL,
  stable → `stable` raw URL). It is `#Include`d into CPRSBooster on the user's machine.
- The big `CPRSBooster_*.ahk*` files are host/combined snapshots, not what users pull.

## Testing reality

- AHK v1 (CI pins 1.1.37.02, the final v1.1 release) / Windows / CPRS — the module
  can't be run on this dev box. CI (`.github/workflows/ahk-ci.yml`) now covers:
  - **lint** (ubuntu): `tools/ci_lint.py` — version-label agreement + channel rule
    (devNN on master, X.Y on stable), missing-`global` reads of module variables in
    functions, `Gui 80/84/85:Show` without NA, dead top-level statements between
    labels, host↔module label/Gui-number congruence, `#If` balance. Runs locally:
    `python3 tools/ci_lint.py --repo . --channel-branch master`.
  - **syntax** (windows): real AHK v1/v2 load-validation of every script.
  - **unit tests** (windows): `tests/test_module.ahk.txt` — Yunit against the REAL
    module (`#Include`d with `NB_Enabled=0`): JSON escape/parse round-trips, the
    CPFS matcher (`CF_FindBestMatch`), quick-action helpers, speed file I/O.
    Yunit alone always exits 0 — the runner counts failures and exits nonzero.
  - **GUI smoke + e2e** (windows, interactive desktop): `tests/smoke_gui.ahk.txt`
    (panel toggles without stealing focus, F-key hide/restore, Ctrl+Shift+B,
    drop-up follows fxnbar and is left alone while open); `tests/e2e_cpfs*.ahk.txt`
    (apply engine against a stub Add Data form run as CPFlowsheets.exe);
    `tests/e2e_cprs*.ahk.txt` (apply engine against a fake TfrmRemDlg built from
    superclassed Button classes with CPRS's real VCL class names, including
    deferred child creation). Always run AHK with `/ErrorStdOut` in CI — a modal
    error dialog otherwise hangs the runner.
- The fake TfrmRemDlg e2e IS the "pared-down CPRS": real Win32 checkbox
  semantics under CPRS's real VCL class names, one-off reminder-dialog layouts
  per test, no VistA/login. A modified real CPRS client is not an option — CPRS
  only builds under proprietary Delphi 2007 — and a live VistA (WorldVistA VEHU
  docker + CPRSChart.exe under Wine) was prototyped but dropped as too slow and
  flaky for CI (and still can't reach a reminder dialog without deep login +
  patient + reminder automation).
- Behavior changes to the apply path should still get a quick smoke test on the
  Windows/CPRS box (the version label in the panel confirms which build is live).
