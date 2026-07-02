# Running the CPRS harness on your own Windows PC

You can run the fake-CPRS test locally, watch it drive the real module, and
even use the NursingBooster panel against the fake dialog by hand — to
satisfy yourself that it behaves the way a real CPRS reminder dialog does.

## 1. Install prerequisites (one time)

1. **Windows.** The harness is Win32; it cannot run on Mac/Linux/Android.
2. **AutoHotkey v1.1, 64-bit Unicode.** Download the v1.1 installer from
   <https://www.autohotkey.com/download/1.1/> and install it. During install
   pick the default (Unicode 64-bit); the resulting `AutoHotkeyU64.exe` is
   what the harness needs. The stub builds windows with 64-bit `WNDCLASSEXW`
   layouts, so the **U64** build is required — the 32-bit `AutoHotkeyA32.exe`
   will not work.
3. **Get this repo onto the PC.** Either:
   - `git clone` it and `git checkout fix/dev21-focus-review`, or
   - on the GitHub PR, use **Code -> Download ZIP** and unzip it.

## 2. Run it (one command)

Open **PowerShell**, `cd` into the repo folder, and run one of:

```powershell
# Automated e2e - same as CI: prints PASS/FAIL, exit code = failures
powershell -ExecutionPolicy Bypass -File tests\run_cprs_local.ps1

# WATCH - slow narrated apply you can watch, dialog left open
powershell -ExecutionPolicy Bypass -File tests\run_cprs_local.ps1 -Watch

# INTERACTIVE - click the dialog + use the NursingBooster panel by hand
powershell -ExecutionPolicy Bypass -File tests\run_cprs_local.ps1 -Interactive
```

If AutoHotkey installed somewhere unusual, point at it:

```powershell
... -File tests\run_cprs_local.ps1 -Interactive -AhkExe "C:\Tools\AutoHotkey\AutoHotkeyU64.exe"
```

### What each mode does

- **default** reproduces CI exactly: the stub and driver run, assertions
  print, and the exit code is the number of failures. This is the thing that
  gates the PR.
- **-Watch** opens the fake dialog with readable captions and runs the real
  `NB_ApplyTemplate` slowly with on-screen narration, so you can see each box
  get checked and each deferred section appear, then leaves the dialog up.
- **-Interactive** opens the fake dialog AND the real NursingBooster module.
  Press **Ctrl+Shift+B** to show the floating panel, then:
  1. Click checkboxes in the fake dialog.
  2. Panel -> **Save Tpl**, name it — it scans the dialog and saves your
     pattern (to `Documents\NursingBooster-Playground\NursingTemplates`).
  3. Uncheck things, then **Load Tpl** -> pick it -> **Apply**, and watch it
     re-check exactly what you saved.
  This is the full module, driven by hand, against a stand-in dialog — the
  same code path it runs against real CPRS.

To run the pieces manually instead of via the script: copy
`AutoHotkeyU64.exe` to `CPRSChart.exe`, rename the `.ahk.txt` files to
`.ahk`, launch `CPRSChart.exe e2e_cprs_stub.ahk`, then launch
`AutoHotkeyU64.exe e2e_cprs.ahk` (or `playground_host.ahk`, or
`demo_cprs_apply.ahk`). For readable captions in the watch/playground
scripts, set the environment variable `NB_E2E_VISUAL=1` before launching the
stub (`set NB_E2E_VISUAL=1`). The runner script just automates all of this.

## 3. What is faithful, and what is not (read this)

The harness reproduces the **window structure and behavior** the module
actually interacts with — verified against the real CPRS Delphi source and
against real dialog dumps in `logs/CPRS Booster logs (not cpfs)/`:

- window class names (`TfrmRemDlg`, two `TScrollBox` with one hidden,
  `TGroupBox` nested in `TGroupBox`, `TCPRSDialogParentCheckBox`,
  `TCPRSDialogCheckBox`, `TDlgFieldPanel`, and prompt-control "noise")
- the parent-checkbox + panel sibling pairing, checkbox check state,
  groupbox nesting depth (including a level with no checkboxes), deferred
  child creation when a parent is checked, and z-order

It is deliberately **not** a visual replica of CPRS:

- Real CPRS draws each item's label with a **non-windowed** control (a Delphi
  `TLabel`) that has no window handle, so Win32/AutoHotkey cannot read it at
  all. The stub therefore leaves labels blank by default — "blank to Win32"
  is exactly what the module sees in real CPRS. `-Watch` and `-Interactive`
  paint readable captions **only** so a human can follow along; the automated
  test never does, and no assertion depends on a caption.
- Checkboxes are plain Win32 auto-checkboxes, not Delphi owner-drawn
  `TORCheckBox`, so they will not look themed. Check state via
  `BM_GETCHECK`/`BM_SETCHECK` is identical, which is what matters.
- It is scaled to roughly a quarter of the real VAAES assessment's size.

So confirm fidelity **structurally**, not by "does it look like CPRS."

## 4. Confirming it matches real CPRS structurally

1. On your CPRS box with NursingBooster loaded, open a real reminder dialog
   and dump its control tree: hover a control and press **Ctrl+Shift+I** to
   inspect one live, or **Ctrl+Shift+D** to dump the whole tree to a file.
   (Real dumps are already committed in `logs/CPRS Booster logs (not cpfs)/`.)
2. Run this harness in **-Interactive** mode and inspect the fake dialog the
   same way — Ctrl+Shift+I / Ctrl+Shift+D work on it too, since the module
   is loaded.
3. Compare: class names, parent/child nesting, the two-scrollbox layout, and
   the deferred-children-on-check behavior should line up. The automated e2e
   asserts the machine-checkable parts of that correspondence (exact toggle
   counts, position-by-position class/checked/depth equality, the depth
   histogram) on every push.

## Files

- `tests/e2e_cprs_stub.ahk.txt` — the fake dialog (runs as `CPRSChart.exe`).
- `tests/e2e_cprs.ahk.txt` — the automated driver (asserts).
- `tests/demo_cprs_apply.ahk.txt` — the slow, narrated `-Watch` driver.
- `tests/playground_host.ahk.txt` — loads the real module for `-Interactive`.
- `tests/run_cprs_local.ps1` — the runner that wires it all up.
- `nursingbooster_module.ahk` — the module under test (unchanged by any of this).
