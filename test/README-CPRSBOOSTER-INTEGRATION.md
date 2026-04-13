# CPRSBooster + NursingBooster Integration Proposal

## Overview

NursingBooster is an opt-in module that adds nursing-specific automation to CPRSBooster:
- One-click template apply for CPRS reminder dialog checkboxes (e.g. VAAES Shift Assessment — 292 checkboxes in seconds)
- CP Flowsheets template support (save/load observation data)
- Quick Action buttons for frequently used templates
- Floating panel with Ctrl+Shift+B toggle

**NursingBooster is entirely opt-in.** When disabled, zero NursingBooster code runs. CPRSBooster behaves exactly as it does today.

## How It Works

1. User enables NursingBooster via a checkbox on the Ctrl+H settings screen
2. CPRSBooster downloads the module from GitHub to the OneDrive\CPRSBooster folder
3. CPRSBooster reloads to parse the module via `#Include`
4. On subsequent startups, the module loads automatically (already cached on disk)
5. A background check 30 seconds after startup downloads updates if available

When the user disables NursingBooster, the panel hides and timers stop. No reload needed to disable.

## What Changes in CPRSBooster

The integration requires changes in **6 locations** in the CPRSBooster script. The file `CPRSBooster_TEST_with_nb.ahk` is a working copy of the active production script with all changes applied. Here's exactly what was added:

### 1. Auto-execute section (before `Return ; End of auto-execute`)

```ahk
; NB_Enabled and NB_Channel loaded by refreshdata from CPRSData.txt slots 83/84
if (NB_Enabled = "")
    NB_Enabled := 0
if (NB_Channel = "")
    NB_Channel := "stable"

; First-time download if module file missing
if (NB_Enabled) {
    nbModulePath := onedrivelocal . "\nursingbooster_module.ahk"
    if (!FileExist(nbModulePath)) {
        gosub NB_FetchModuleIfNeeded
        Reload
        Sleep 1000
    }
}

; Initialize the module
if (NB_Enabled && IsLabel("NB_ModuleInit")) {
    nbInitLbl := "NB_ModuleInit"
    Gosub, %nbInitLbl%
}

; Background update check (fires once, 30 seconds after startup)
if (NB_Enabled)
    SetTimer, NB_BackgroundUpdateCheck, -30000
```

**Also:** `SetTimer, CheckToolbars` was moved from line 200 to after `gosub refreshdata` (line 582+) to fix a race condition where the function bar built with empty F-key labels during drive-check sleep. This is a latent bug in production CPRSBooster that only manifests on `Reload` (when CPRS is already maximized).

### 2. Download/update labels (after auto-execute Return)

`NB_FetchModuleIfNeeded` — downloads the module from GitHub, caches per-channel, copies to active path.

`NB_BackgroundUpdateCheck` — one-shot timer, checks for updates 30 seconds after startup.

### 3. `#Include` directive (after the download labels)

```ahk
#Include %A_ScriptDir%\..
#Include *i nursingbooster_module.ahk
```

The script runs from `CPRSBooster\Engine\`, the module is cached in `CPRSBooster\`. `*i` = silent if file missing.

### 4. Ctrl+H settings UI

Checkbox and channel dropdown added to the settings form:

```ahk
Gui, Add, Checkbox, ..., Enable Nursing Booster (downloads from GitHub)
Gui, Add, DropDownList, ..., Stable|Beta/Dev
```

Window height increased from 700 to 770 to fit.

### 5. ButtonOK handler

Detects enable/channel changes, downloads module if enabling, reloads if needed:

```ahk
NB_Enabled := NB_EnabledChk ? 1 : 0
NB_Channel := (NB_ChannelDDL = "Beta/Dev") ? "master" : "stable"
; If enabling for first time or changing channel: download + reload
; If disabling: just hide panel and stop timers (no reload)
```

### 6. refreshdata / writeit

Two lines each to read/write `NB_Enabled` (slot 83) and `NB_Channel` (slot 84) from CPRSData.txt.

## What CPRSBooster Does NOT Need

- No NursingBooster-specific logic in any hotkey handler
- No changes to the function bar (`!+h`) build code
- No changes to the sign flow
- No new GUI definitions
- No new hotkey registrations

The module manages all of that itself:
- It creates its own GUIs (80-85, no conflicts with CPRSBooster's 1-72)
- It registers its own hotkeys (Ctrl+Shift+B, Ctrl+Shift+D)
- It detects the function bar and places a companion dropdown next to it via a timer
- It hides its panel when F-keys are pressed and restores after 6 seconds
- It pauses its own timers during template apply to avoid interference

## Security

- The module is downloaded over HTTPS from GitHub (`raw.githubusercontent.com`)
- No patient data is transmitted — all template data stays in OneDrive\CPRSBooster
- The module only reads/writes to its own template folders and INI file
- When disabled, no NursingBooster code executes (hotkeys gated behind `#If NB_Enabled`)
- The module file is cached locally in OneDrive\CPRSBooster — works offline after first download

## GitHub Repository

- **Stable channel**: `https://raw.githubusercontent.com/kingpanther13/NursingBooster/stable/nursingbooster_module.ahk`
- **Dev channel**: `https://raw.githubusercontent.com/kingpanther13/NursingBooster/master/nursingbooster_module.ahk`

## Files in This Branch

- `CPRSBooster_TEST_with_nb.ahk` — the modified CPRSBooster script (compare with `dumps/CPRSBooster_ACTIVE_PRODUCTION_SCRIPT.ahk` for exact diff)
- `README-CPRSBOOSTER-INTEGRATION.md` — this file

## To Test

1. Copy `CPRSBooster_TEST_with_nb.ahk` to replace the active production script
2. Launch CPRSBooster
3. Press Ctrl+H to open settings
4. Scroll to bottom — check "Enable Nursing Booster"
5. Click OK — CPRSBooster downloads the module and reloads
6. Press Ctrl+Shift+B to toggle the NursingBooster panel
