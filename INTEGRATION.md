# NursingBooster Module Integration Guide

This document describes how to integrate the NursingBooster module into CPRSBooster (or any AHK v1 host script). The module is designed to be loaded on demand and updated independently of the host.

## What the module provides

- **Gui 67** — Floating Nursing Booster panel
- **Gui 73** — Settings panel
- **Ctrl+Shift+B hotkey** — toggles the panel
- Save/Load/Apply/Delete templates for CPRS reminder dialogs (checkbox-heavy ones like VAAES Shift Assessment)
- CP Flowsheets template support (separate save/load/apply for the grid view input dialogs)
- Quick Action buttons + dropdown
- Settings persistence in `OneDrive\CPRSBooster\NursingTemplates\booster_settings.ini`
- Templates stored in `OneDrive\CPRSBooster\NursingTemplates` and `OneDrive\CPRSBooster\CPFSTemplates`

## What the host script needs to provide

1. The global `onedrivelocal` variable (path to `OneDrive\CPRSBooster` folder) — defined before the module is loaded
2. A global `NB_Enabled` variable (1 or 0) — controls whether the module activates
3. An `#Include *i` directive that points to the cached module file
4. A `gosub NB_ModuleInit` call inside the host's auto-execute section (gated on `NB_Enabled` and `IsLabel`)

That's the whole interface. The module is otherwise self-contained.

## Channel structure

The module is published on two GitHub branches:

| Channel | URL                                                                                                            |
|---------|----------------------------------------------------------------------------------------------------------------|
| Stable  | `https://raw.githubusercontent.com/kingpanther13/NursingBooster/stable/nursingbooster_module.ahk`              |
| Dev     | `https://raw.githubusercontent.com/kingpanther13/NursingBooster/master/nursingbooster_module.ahk`              |

The host script picks one of these URLs based on user preference and downloads to the cache.

## Recommended cache location

`%A_OneDrive%\CPRSBooster\nursingbooster_module.ahk`

## Update strategy

Two approaches, pick whichever fits CPRSBooster's existing patterns:

### Option A: Always download on startup (simple)

```ahk
NB_FetchModule:
    nbChannel := NB_Channel ? NB_Channel : "stable"
    nbModuleUrl := "https://raw.githubusercontent.com/kingpanther13/NursingBooster/" . nbChannel . "/nursingbooster_module.ahk"
    nbModulePath := onedrivelocal . "\nursingbooster_module.ahk"
    nbTempPath := A_Temp . "\nursingbooster_module_dl.ahk"

    UrlDownloadToFile, %nbModuleUrl%, %nbTempPath%
    if (ErrorLevel)
        return  ; offline — keep using cached

    FileRead, newContent, %nbTempPath%
    cachedContent := ""
    if (FileExist(nbModulePath))
        FileRead, cachedContent, %nbModulePath%

    if (newContent != cachedContent) {
        FileDelete, %nbModulePath%
        FileMove, %nbTempPath%, %nbModulePath%
        nbWasUpdated := true
    } else {
        FileDelete, %nbTempPath%
    }
return
```

### Option B: Network share + FileGetTime (matches CPRSBooster's BstHelper pattern)

If VA prefers a network share over GitHub for some users, the module file can be hosted on a UNC path and copied with `FileCopy` based on `FileGetTime` comparison — same pattern as `BstHelper.ahk` already uses in CPRSBooster.

## Auto-execute integration

Place this in CPRSBooster's auto-execute section, near the end (just before the auto-execute `Return`):

```ahk
;######################## NURSING BOOSTER MODULE ###########################

; If enabled, fetch latest module then reload if updated.
; (AHK v1 #Include is parse-time, so updates only take effect after reload.)
if (NB_Enabled) {
    nbWasUpdated := false
    gosub NB_FetchModule
    if (nbWasUpdated) {
        Reload
        Sleep 1000
    }
}

; Initialize the module (if loaded and enabled)
if (NB_Enabled && IsLabel("NB_ModuleInit"))
    gosub NB_ModuleInit
```

And the `#Include` directive (place anywhere in the script — `#Include` is parse-time):

```ahk
#Include *i %A_OneDrive%\CPRSBooster\nursingbooster_module.ahk
```

The `*i` flag makes the include silently do nothing if the file doesn't exist yet (first run before download, or if the user has NB disabled and never downloaded).

## Settings persistence

The host should store two values in its existing settings file (CPRSData.txt array slots, or wherever):

- `NB_Enabled` — 1 if user enabled the module, 0 otherwise
- `NB_Channel` — "stable" or "master"

Suggested array slots: 83 (NB_Enabled), 84 (NB_Channel). Use whatever's free.

## Settings UI

Add to CPRSBooster's Ctrl+H settings dialog:

```ahk
nbEnabledChkOpt := NB_Enabled ? "Checked" : ""
Gui, Add, Checkbox, x100 y620 w250 h30 vNB_EnabledChk %nbEnabledChkOpt%, Enable Nursing Booster (downloads from GitHub)
nbCurrentChannel := NB_Channel ? NB_Channel : "stable"
nbDevSel := (nbCurrentChannel = "master") ? "|stable|master||" : "|stable||master|"
Gui, Add, DropDownList, x360 y620 w120 vNB_ChannelDDL, %nbDevSel%
```

In ButtonOK (after Gui, Submit):

```ahk
nbPrevEnabled := NB_Enabled
nbPrevChannel := NB_Channel
NB_Enabled := NB_EnabledChk ? 1 : 0
NB_Channel := NB_ChannelDDL ? NB_ChannelDDL : "stable"
nbNeedsReload := (nbPrevEnabled != NB_Enabled) || (nbPrevChannel != NB_Channel)
```

After writeit:

```ahk
if (nbNeedsReload) {
    if (NB_Enabled)
        gosub NB_FetchModule
    Reload
    Sleep 1000
}
```

## Optional integration hooks

These enhance the integration but aren't required for the module to work:

### 1. Suppress hotkey conflicts

Add to any host hotkey context check:

```ahk
if (winactive("NursingBoosterPanel"))  ; don't interfere with NB panel
    return
```

### 2. NursingBooster dropdown on host's function bar (Gui 14)

The module exposes a helper label `NB_AddDropdownToGui14`. Call it from inside CPRSBooster's Gui 14 build code:

```ahk
if (NB_Enabled && IsLabel("NB_AddDropdownToGui14"))
    gosub NB_AddDropdownToGui14
```

### 3. Hide panel during sign

The module exposes `NB_SignWrapper` which hides the panel, calls the host's sign hotkey, then restores the panel. Wrap CPRSBooster's sign hotkey:

```ahk
^!s::
if (NB_Enabled && IsLabel("NB_SignWrapper")) {
    gosub NB_SignWrapper
    return
}
; ... existing sign code ...
return
```

The module's `NB_SignWrapper` will call back into the host's `^!s` hotkey to do the actual signing.

## Reference test integration

A working test version of CPRSBooster with all of the above integrated is at `test/CPRSBooster_TEST_with_nb.ahk` in the NursingBooster repo. Compare it against `dumps/CPRSBooster_ACTIVE_PRODUCTION_SCRIPT.ahk` (the unmodified production script) to see exactly what was added.

## File checklist

In the CPRSBooster fork:

- [ ] Add `NB_Enabled` and `NB_Channel` globals (loaded from settings file)
- [ ] Add the `NB_FetchModule` label
- [ ] Add the auto-execute integration block (fetch + reload check + ModuleInit call)
- [ ] Add the `#Include *i` directive
- [ ] Add the Ctrl+H settings UI elements
- [ ] Add the ButtonOK reload-detection logic
- [ ] Add NB_Enabled and NB_Channel to the settings array read/write
- [ ] (Optional) Add the three integration hooks
