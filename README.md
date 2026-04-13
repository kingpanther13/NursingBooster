# CPRSBooster + NursingBooster Integration Proposal

## What is NursingBooster?

An opt-in AHK v1 module that adds nursing-specific automation to CPRSBooster:
- One-click template apply for CPRS reminder dialog checkboxes (e.g. VAAES Shift Assessment — 292 checkboxes in seconds)
- CP Flowsheets template support (save/load observation data)
- Quick Action buttons for frequently used templates
- Floating panel toggled with Ctrl+Shift+B

**Entirely opt-in.** When disabled, zero NursingBooster code runs. CPRSBooster behaves exactly as it does today.

## How It Works

1. User checks "Enable Nursing Booster" on the Ctrl+H settings screen
2. CPRSBooster downloads the module (~150KB) from GitHub over HTTPS to the OneDrive\CPRSBooster folder
3. CPRSBooster reloads to parse the module
4. On subsequent startups, the cached module loads automatically (no download delay)
5. A background check 30 seconds after startup downloads updates if available
6. When disabled, panel hides and timers stop — no reload needed

### Alternative to GitHub

The download mechanism can easily be swapped to pull from a network share instead of GitHub. One line change:

```ahk
; Current (GitHub):
UrlDownloadToFile, %nbModuleUrl%, %nbTempPath%

; Alternative (network share like S: or UNC path):
FileCopy, \\server\share\nursingbooster_module.ahk, %nbTempPath%, 1
```

Same pattern CPRSBooster already uses for `BstHelper.ahk`.

## What the Module Contains

The module (`nursingbooster_module.ahk`) is a self-contained AHK v1 script that provides:
- **Gui 80** — Floating Nursing Booster panel (Save/Load/Delete templates, Quick Actions, CP Flowsheets buttons)
- **Gui 82** — Template load picker
- **Gui 83** — Quick Action setup dialog
- **Gui 84** — Settings panel (speed sliders, advanced mode, debug logging)
- **Gui 85** — Companion dropdown that auto-positions next to the function bar
- **Ctrl+Shift+B hotkey** — toggles the panel
- **Ctrl+Shift+D hotkey** — dialog dump (debug tool, advanced mode only)
- Template save/load/apply for CPRS reminder dialogs using synchronous Win32 messaging
- Template save/load/apply for CP Flowsheets
- Auto-hides panel when F-keys are pressed (sign flow) and restores after 6 seconds
- CPRS/CPFS detection timer (shows status on panel)
- All settings persisted in `OneDrive\CPRSBooster\NursingTemplates\booster_settings.ini`
- Templates stored in `OneDrive\CPRSBooster\NursingTemplates\` and `OneDrive\CPRSBooster\CPFSTemplates\`
- GUI numbers 80-85 chosen to avoid conflicts with CPRSBooster's existing GUIs (1-72)
- All hotkeys gated behind `#If (NB_Enabled)` — inactive when module is disabled
- Panel uses `WS_EX_NOACTIVATE` — never steals focus from CPRS

## Exact Changes to CPRSBooster — Every Single Line

The file `CPRSBooster_TEST_with_nb.ahk` in this branch is a working copy of the active production script with all changes applied. Below is every line added or modified.

---

### Change 1: Move CheckToolbars timer (line 200)

**Why:** `SetTimer, CheckToolbars` at line 200 fires before `refreshdata` loads saved F-key labels at line 580. During drive-check sleep (line 488), the timer builds Gui 14 with empty labels. This is a latent bug that only manifests on `Reload` (when CPRS is already maximized). Moving the timer after refreshdata ensures data is loaded first.

**Original line 200:**
```ahk
	SetTimer, CheckToolbars, 1000, On
```

**Replaced with:**
```ahk
	; CheckToolbars timer moved to after refreshdata (line 580+) to prevent
	; race condition where timer builds Gui 14 before fxn vars are loaded.
	; SetTimer, CheckToolbars, 1000, On  ; MOVED — see below
```

---

### Change 2: CheckToolbars timer new location (after line 582, after `gosub refreshdata`)

**2 lines added:**
```ahk
; Start CheckToolbars AFTER refreshdata so fxn vars are populated before
; the timer can build Gui 14. Prevents blank F-key labels on Reload.
SetTimer, CheckToolbars, 1000, On
```

---

### Change 3: NursingBooster auto-execute block (inserted before the original `Return ; End of auto-execute section`)

**30 lines added:**
```ahk
;############################################################################################
;################## NURSING BOOSTER MODULE INTEGRATION ######################################
;############################################################################################
; Pulls NursingBooster from GitHub if enabled.
; The user toggles this in Ctrl+H settings.

; NB_Enabled and NB_Channel are loaded by refreshdata from CPRSData.txt
; (slots 83 and 84). Default to 0/stable if undefined.
if (NB_Enabled = "")
    NB_Enabled := 0
if (NB_Channel = "")
    NB_Channel := "stable"

; If enabled but module file missing, download it now (first-time setup).
; Otherwise skip the download — update check happens on a background timer.
if (NB_Enabled) {
    nbModulePath := onedrivelocal . "\nursingbooster_module.ahk"
    if (!FileExist(nbModulePath)) {
        gosub NB_FetchModuleIfNeeded
        Reload
        Sleep 1000
    }
}

; Initialize the module (if loaded and enabled)
if (NB_Enabled && IsLabel("NB_ModuleInit")) {
    nbInitLbl := "NB_ModuleInit"
    Gosub, %nbInitLbl%
}

; Start background update check (non-blocking, fires once after 30 seconds)
if (NB_Enabled)
    SetTimer, NB_BackgroundUpdateCheck, -30000

Return  ; End of auto-execute section
;---------------------ANY INITIALIZING CODE (autoexecute) MUST BE ABOVE HERE
```

---

### Change 4: Download/update labels (placed after auto-execute Return)

**NB_FetchModuleIfNeeded** — downloads the module from GitHub (or network share), caches per-channel (stable vs beta-dev), copies active version for `#Include` to load.

**NB_BackgroundUpdateCheck** — one-shot timer that fires 30 seconds after startup to check for updates without blocking startup.

**53 lines added:**
```ahk
;############################################################################################
;################## NURSING BOOSTER MODULE DOWNLOAD/UPDATE ##################################
;############################################################################################

NB_FetchModuleIfNeeded:
    ; Channel: "stable" or "master" (stored internally, shown as Beta/Dev in UI)
    nbChannel := NB_Channel ? NB_Channel : "stable"
    nbModuleUrl := "https://raw.githubusercontent.com/kingpanther13/NursingBooster/" . nbChannel . "/nursingbooster_module.ahk"
    ; Separate cache per channel + active copy that #Include loads
    nbChannelCache := onedrivelocal . "\nursingbooster_module_" . nbChannel . ".ahk"
    nbActivePath := onedrivelocal . "\nursingbooster_module.ahk"
    nbTempPath := A_Temp . "\nursingbooster_module_dl.ahk"

    ; Download to temp
    UrlDownloadToFile, %nbModuleUrl%, %nbTempPath%
    if (ErrorLevel) {
        ; Network error — use cached version if available
        if (FileExist(nbChannelCache))
            FileCopy, %nbChannelCache%, %nbActivePath%, 1
        return
    }

    ; Compare with channel cache. If different, update channel cache.
    FileRead, newContent, %nbTempPath%
    cachedContent := ""
    if (FileExist(nbChannelCache))
        FileRead, cachedContent, %nbChannelCache%

    if (newContent != cachedContent) {
        FileDelete, %nbChannelCache%
        FileMove, %nbTempPath%, %nbChannelCache%
    } else {
        FileDelete, %nbTempPath%
    }

    ; Copy channel cache to active path (what #Include loads)
    activeContent := ""
    if (FileExist(nbActivePath))
        FileRead, activeContent, %nbActivePath%
    FileRead, channelContent, %nbChannelCache%
    if (channelContent != activeContent) {
        FileCopy, %nbChannelCache%, %nbActivePath%, 1
        nbWasUpdated := true
    }
return

NB_BackgroundUpdateCheck:
    ; Non-blocking update check — runs once 30 seconds after startup
    nbWasUpdated := false
    gosub NB_FetchModuleIfNeeded
    if (nbWasUpdated) {
        ToolTip, NursingBooster updated — reloading...
        Sleep 1500
        Reload
    }
return
```

---

### Change 5: #Include directive (placed after download labels)

**5 lines added:**
```ahk
;############################################################################################
;################## NURSING BOOSTER MODULE INCLUDE ##########################################
;############################################################################################
; Include the cached module file. *i = silent if missing.
; Script is in CPRSBooster\Engine\, module is cached in CPRSBooster\
#Include %A_ScriptDir%\..
#Include *i nursingbooster_module.ahk
```

`*i` means AHK silently skips the include if the file doesn't exist (first run before download, or NB disabled and never downloaded). `%A_ScriptDir%\..` navigates from Engine\ to CPRSBooster\ where the module is cached.

---

### Change 6: Ctrl+H settings UI (added before OK button in the settings form)

**10 lines added:**
```ahk
; --- NursingBooster enable checkbox + channel selector ---
Gui, Font, s10 Bold, Verdana
Gui, Add, Text, x200 y710 w600 h25 cBlue, Nursing Booster Module
Gui, Font, s9 Norm, Verdana
nbEnabledChkOpt := NB_Enabled ? "Checked" : ""
Gui, Add, Checkbox, x200 y738 w350 h22 vNB_EnabledChk %nbEnabledChkOpt%, Enable Nursing Booster (downloads from GitHub)
Gui, Add, Text, x600 y740 w60 h20, Channel:
nbCurrentChannel := Array[84] ? Array[84] : "stable"
nbDevSel := (nbCurrentChannel = "master") ? "|Stable|Beta/Dev||" : "|Stable||Beta/Dev|"
Gui, Add, DropDownList, x665 y738 w100 vNB_ChannelDDL, %nbDevSel%
```

---

### Change 7: Ctrl+H window height (1 line changed)

**Original:**
```ahk
Gui, Show, x10 y0 w1200 h700, Minneapolis VA Informatics
```

**Changed to:**
```ahk
Gui, Show, x10 y0 w1200 h770, Minneapolis VA Informatics
```

---

### Change 8: ButtonOK handler — detect changes (added after `Gui, Submit`)

**7 lines added:**
```ahk
; --- NursingBooster: detect enable/channel changes ---
nbPrevEnabled := NB_Enabled
nbPrevChannel := NB_Channel
NB_Enabled := NB_EnabledChk ? 1 : 0
; Map display label back to branch name
NB_Channel := (NB_ChannelDDL = "Beta/Dev") ? "master" : "stable"
nbNeedsReload := (nbPrevEnabled != NB_Enabled) || (nbPrevChannel != NB_Channel)
```

---

### Change 9: ButtonOK handler — act on changes (added after writeit/refreshdata, before Return)

**25 lines added:**
```ahk
; --- NursingBooster: handle enable/channel changes ---
if (nbNeedsReload) {
    if (NB_Enabled && !nbPrevEnabled) {
        ; Enabling for the first time — need reload to parse #Include
        gosub NB_FetchModuleIfNeeded
        Reload
        Sleep 1000
    } else if (!NB_Enabled && nbPrevEnabled) {
        ; Disabling — just hide panel and stop timers, no reload
        if (IsLabel("NB_TogglePanel") && NB_BoosterGuiVisible) {
            nbToggle := "NB_TogglePanel"
            Gosub, %nbToggle%
        }
        if (IsLabel("NB_CheckCPRS"))
            SetTimer, NB_CheckCPRS, Off
        if (IsLabel("NB_CheckGui14Dropdown"))
            SetTimer, NB_CheckGui14Dropdown, Off
        if (IsLabel("NB_ClearToolTip")) {
            ToolTip, NursingBooster disabled
            SetTimer, NB_ClearToolTip, -2000
        } else {
            ToolTip, NursingBooster disabled
            Sleep 2000
            ToolTip
        }
    } else if (NB_Enabled && nbPrevChannel != NB_Channel) {
        ; Channel changed — download new channel and reload
        gosub NB_FetchModuleIfNeeded
        Reload
        Sleep 1000
    }
}
```

---

### Change 10: refreshdata — read NB settings (2 lines added after `Array[82]` assignment)

```ahk
NB_Enabled := Array[83]
NB_Channel := Array[84] ? Array[84] : "stable"
```

---

### Change 11: writeit — save NB settings (2 lines added after `WriteArray[82]` assignment)

```ahk
WriteArray[83] := NB_Enabled
WriteArray[84] := NB_Channel
```

---

## Total Lines Added/Changed

| Change | Lines | Type |
|--------|-------|------|
| 1. Move CheckToolbars | 3 | Modified |
| 2. CheckToolbars new location | 2 | Added |
| 3. Auto-execute integration | 30 | Added |
| 4. Download/update labels | 53 | Added |
| 5. #Include directive | 5 | Added |
| 6. Ctrl+H UI | 10 | Added |
| 7. Window height | 1 | Modified |
| 8. ButtonOK detect | 7 | Added |
| 9. ButtonOK act | 25 | Added |
| 10. refreshdata | 2 | Added |
| 11. writeit | 2 | Added |
| **Total** | **~140** | |

## Security

- Module downloaded over HTTPS from `raw.githubusercontent.com`
- No patient data transmitted — all template data stays in OneDrive\CPRSBooster
- Module only reads/writes its own template folders and INI file
- When disabled, no NursingBooster code executes (hotkeys gated behind `#If NB_Enabled`)
- Module cached locally — works offline after first download
- If GitHub is unreachable, falls back to cached version silently
- Can be swapped to network share (UNC path) if GitHub is not approved

## GitHub Repository

- **Stable**: `https://raw.githubusercontent.com/kingpanther13/NursingBooster/stable/nursingbooster_module.ahk`
- **Beta/Dev**: `https://raw.githubusercontent.com/kingpanther13/NursingBooster/master/nursingbooster_module.ahk`

## To Test

1. Copy `CPRSBooster_TEST_with_nb.ahk` to replace the active production script in Engine folder
2. Launch CPRSBooster
3. Press Ctrl+H to open settings
4. Scroll to bottom — check "Enable Nursing Booster", leave channel as "Stable"
5. Click OK — CPRSBooster downloads the module and reloads
6. Press Ctrl+Shift+B to toggle the NursingBooster panel
7. To disable: Ctrl+H → uncheck → OK (no reload needed, panel just hides)
