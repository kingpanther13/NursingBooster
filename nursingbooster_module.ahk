; ============================================================================================
; NursingBooster Module
; ============================================================================================
;
; Loadable module bundling NursingBooster + CP Flowsheets Booster.
;
; HOW THE HOST USES THIS MODULE:
;
;   1. Define `onedrivelocal` global (path to OneDrive\CPRSBooster folder) BEFORE loading.
;   2. Set `global NB_Enabled := 1` (or 0) BEFORE loading.
;   3. #Include this file with `#Include *i %A_OneDrive%\CPRSBooster\nursingbooster_module.ahk`
;   4. Call `gosub NB_ModuleInit` from within the host's auto-execute section.
;      Use `if (NB_Enabled && IsLabel("NB_ModuleInit"))` to make the call safe.
;
; WHAT THIS MODULE PROVIDES:
;   - Gui 67 (Nursing Booster floating panel)
;   - Gui 73 (Settings panel)
;   - Ctrl+Shift+B hotkey to toggle the panel
;   - Save/Load/Apply/Delete templates for CPRS reminder dialogs
;   - CP Flowsheets template support (separate save/load/apply)
;   - Quick Action buttons + dropdown
;
; OPTIONAL HOST INTEGRATION HOOKS (enhance behavior, not required):
;   - Add `winactive("NursingBoosterPanel")` to host's hotkey suppression checks
;   - Add NB dropdown to host's Gui 14 (function bar) — call gosub NB_AddDropdownToGui14
;   - Wrap host's sign hotkey with `Gosub NB_SignWrapper`
;
; ============================================================================================

; -------------------- GLOBAL VARIABLES --------------------
; Declared here so labels/functions can access them.
; All values are set in NB_ModuleInit — no defaults here to avoid
; interfering with host's variable loading order.

; -------------------- NB_ModuleInit: --------------------
; Called by host's auto-execute. Sets up directories, loads settings,
; builds GUIs, registers hotkey, starts detection timer.
NB_ModuleInit:
    if (!NB_Enabled)
        return

    ; Initialize all NB/CF globals
    NB_AppTitle := "Nursing Booster"
    NB_BoosterGuiVisible := 0
    NB_SignWasVisible := 0
    NB_ApplySpeed := 0
    NB_LeafSpeed := 0
    NB_AdvancedMode := 0
    NB_SpeedOverride := 0
    NB_SettingsTplPathMap := {}
    NB_DebugLogging := 0
    NB_CPRSDetected := 0
    NB_HK1_Label := "Quick 1"
    NB_HK1_Action := ""
    NB_HK2_Label := "Quick 2"
    NB_HK2_Action := ""
    NB_HK3_Label := "Quick 3"
    NB_HK3_Action := ""
    NB_HK4_Label := "Quick 4"
    NB_HK4_Action := ""
    NB_HK5_Label := "Quick 5"
    NB_HK5_Action := ""
    NB_SettingsVisible := 0
    NB_PanelHwnd := 0
    CF_AppTitle := "CP Flowsheets Booster"
    CF_Detected := 0
    CF_SpyResults := []
    CF_AutoSave := 0
    CF_ChainAddData := 0
    CF_AddDataDelay := 50
    CF_AutoSaveDelay := 500

    ; Resolve paths from host's `onedrivelocal`
    NB_TemplateDir       := onedrivelocal . "\NursingTemplates"
    NB_LogDir            := onedrivelocal . "\NursingTemplates\Logs"
    NB_SettingsIniPath   := onedrivelocal . "\NursingTemplates\booster_settings.ini"
    NB_HotkeyConfigPath  := onedrivelocal . "\NursingTemplates\hotkey_buttons.json"
    CF_TemplateDir       := onedrivelocal . "\CPFSTemplates"
    CF_LogDir            := onedrivelocal . "\CPFSTemplates\Logs"

    ; Make directories
    IfNotExist, %NB_TemplateDir%
        FileCreateDir, %NB_TemplateDir%
    IfNotExist, %NB_LogDir%
        FileCreateDir, %NB_LogDir%
    IfNotExist, %CF_TemplateDir%
        FileCreateDir, %CF_TemplateDir%
    IfNotExist, %CF_LogDir%
        FileCreateDir, %CF_LogDir%

    ; Load saved configs
    gosub NB_LoadHotkeyConfig
    gosub NB_LoadSettings

    ; -------------------- BUILD GUIS --------------------
    ; --- NursingBooster: Build floating panel (Gui 67) ---
    Gui, 80:Destroy
    Gui, 80:Color, 1a1a2e
    Gui, 80:Font, s9 cWhite, Segoe UI
    Gui, 80:Add, Text, x5 y4 w370 h20 Center BackgroundTrans vNB_PanelTitle gNB_DragPanel, Nursing Booster dev7  |  Ctrl+Shift+B to toggle
    Gui, 80:Font, s8 cBlack, Segoe UI
    Gui, 80:Add, Button, x5   y28 w70 h26 gNB_PanelSave, Save Tpl
    Gui, 80:Add, Button, x78  y28 w70 h26 gNB_PanelLoad, Load Tpl
    Gui, 80:Add, Button, x151 y28 w70 h26 gNB_PanelDelete, Del Tpl
    Gui, 80:Add, Button, x224 y28 w63 h26 gNB_PanelSettings, Settings
    Gui, 80:Add, Button, x290 y28 w90 h26 gNB_ShowBothBars, Show All Bars
    Gui, 80:Font, s7 c00BFFF, Segoe UI
    Gui, 80:Add, Text, x5 y58 w370 h16 Center BackgroundTrans, --- CP Flowsheets ---
    Gui, 80:Font, s8 cBlack, Segoe UI
    Gui, 80:Add, Button, x5   y76 w60 h26 gCF_PanelSave, Save
    Gui, 80:Add, Button, x68  y76 w60 h26 gCF_PanelLoad, Load
    Gui, 80:Add, Button, x131 y76 w50 h26 gCF_PanelDelete, Del
    Gui, 80:Add, Button, x184 y76 w70 h26 gCF_PanelAddData, Add Data
    Gui, 80:Font, s7 cRed, Segoe UI
    Gui, 80:Add, Checkbox, x320 y76 w60 h14 vCF_AutoAddChk gCF_ToggleAutoAdd, Auto-Add
    ; Advanced-only: AutoSave checkbox
    Gui, 80:Add, Checkbox, x320 y90 w60 h14 vCF_AutoSaveChk gCF_ToggleAutoSave +HwndCF_AdvAutoSaveHwnd, AutoSave
    Gui, 80:Font, s7 cFFD700, Segoe UI
    Gui, 80:Add, Text, x5 y106 w370 h16 Center BackgroundTrans, --- Quick Actions ---
    Gui, 80:Font, s7 cBlack, Segoe UI
    Gui, 80:Add, Button, x5   y123 w68 h24 gNB_HK1_Run vNB_HK1_Btn, %NB_HK1_Label%
    Gui, 80:Add, Button, x76  y123 w68 h24 gNB_HK2_Run vNB_HK2_Btn, %NB_HK2_Label%
    Gui, 80:Add, Button, x147 y123 w68 h24 gNB_HK3_Run vNB_HK3_Btn, %NB_HK3_Label%
    Gui, 80:Add, Button, x218 y123 w68 h24 gNB_HK4_Run vNB_HK4_Btn, %NB_HK4_Label%
    Gui, 80:Add, Button, x289 y123 w68 h24 gNB_HK5_Run vNB_HK5_Btn, %NB_HK5_Label%
    Gui, 80:Add, Button, x360 y123 w20 h24 gNB_HK_Setup, ...
    Gui, 80:Font, s8 cWhite, Segoe UI
    Gui, 80:Add, Text, x5 y151 w375 h16 Center BackgroundTrans vNB_PanelStatus, Ready | CPRS: Not detected | CPFS: Not detected
    ; Advanced-only controls: Override Speed + Leaf Speed
    Gui, 80:Font, s7 c00FF88, Segoe UI
    Gui, 80:Add, Checkbox, x5 y170 w100 h18 vNB_SpeedOverrideChk gNB_SpeedOverrideChanged BackgroundTrans +HwndNB_AdvOverrideHwnd, Override Speed
    Gui, 80:Add, Slider, x108 y168 w192 h22 vNB_MainSpeedSlider gNB_MainSpeedChanged Range0-600 TickInterval100 ToolTip +HwndNB_AdvParentSliderHwnd, %NB_ApplySpeed%
    Gui, 80:Add, Text, x305 y170 w75 h16 BackgroundTrans vNB_MainSpeedLabel +HwndNB_AdvParentLblHwnd, %NB_ApplySpeed% ms
    Gui, 80:Add, Text, x5 y192 w100 h16 BackgroundTrans vNB_LeafSpeedLbl +HwndNB_AdvLeafLblHwnd, Leaf Speed:
    Gui, 80:Add, Slider, x108 y190 w192 h22 vNB_LeafSpeedSlider gNB_LeafSpeedChanged Range0-600 TickInterval50 ToolTip +HwndNB_AdvLeafSliderHwnd, %NB_LeafSpeed%
    Gui, 80:Add, Text, x305 y192 w75 h16 BackgroundTrans vNB_LeafSpeedLabel +HwndNB_AdvLeafValHwnd, %NB_LeafSpeed% ms
    Gui, 80:+AlwaysOnTop -Caption +ToolWindow +HwndNB_PanelHwnd +E0x08000000  ; WS_EX_NOACTIVATE — panel never steals focus from CPRS
    Gui, 80:Show, x0 y0 w385 h218 Hide, NursingBoosterPanel
    GuiControl, 80:Disable, NB_MainSpeedSlider
    GuiControl, 80:Disable, NB_LeafSpeedSlider
    ; Apply advanced mode visibility (resize skipped at startup since panels not visible yet)
    gosub NB_ApplyAdvancedMode
    NB_BoosterGuiVisible := 0
    NB_SettingsVisible := 0

    ; Register Ctrl+Shift+B globally via Hotkey command — immune to #If context issues
    Hotkey, ^+b, NB_TogglePanel

    ; --- NursingBooster: Build Settings panel (Gui 73) ---
    Gui, 84:Destroy
    Gui, 84:Color, 1a1a2e
    Gui, 84:Font, s9 cWhite, Segoe UI
    Gui, 84:Add, Text, x5 y4 w280 h20 Center BackgroundTrans, Booster Settings
    Gui, 84:Font, s6 cSilver, Segoe UI
    Gui, 84:Add, Text, x10 y24 w270 h12 BackgroundTrans vNB_VersionLine, dev7
    Gui, 84:Font, s7 c00FF88, Segoe UI
    Gui, 84:Add, Text, x10 y40 w65 h16 BackgroundTrans, Template:
    Gui, 84:Add, DropDownList, x80 y37 w195 vNB_SettingsTplDDL gNB_SettingsTplChanged
    Gui, 84:Add, Text, x10 y68 w65 h16 BackgroundTrans, Parent Spd:
    Gui, 84:Add, Slider, x80 y66 w130 h22 vNB_TplSpeedSlider gNB_TplSpeedChanged Range0-600 TickInterval100 ToolTip, 600
    Gui, 84:Add, Text, x215 y68 w55 h16 BackgroundTrans vNB_TplSpeedLabel, 600 ms
    Gui, 84:Add, Text, x10 y92 w65 h16 BackgroundTrans, Leaf Spd:
    Gui, 84:Add, Slider, x80 y90 w130 h22 vNB_TplLeafSlider gNB_TplLeafChanged Range0-600 TickInterval50 ToolTip, 50
    Gui, 84:Add, Text, x215 y92 w55 h16 BackgroundTrans vNB_TplLeafLabel, 50 ms
    Gui, 84:Add, Button, x10 y118 w80 h24 gNB_SaveTplSpeed, Save Speed
    Gui, 84:Font, s6 cSilver, Segoe UI
    Gui, 84:Add, Text, x95 y122 w185 h14 BackgroundTrans vNB_TplSpeedStatus, Select a template to edit speed
    Gui, 84:Font, s7 c00FF88, Segoe UI
    nbAdvChkOpt := NB_AdvancedMode ? "Checked" : ""
    Gui, 84:Add, Checkbox, x10 y144 w200 h18 vNB_AdvancedModeChk gNB_AdvancedModeChanged %nbAdvChkOpt% BackgroundTrans, Advanced Mode
    ; Advanced-only: Add Data delay, Dump buttons, Debug Logging
    Gui, 84:Add, Text, x10 y166 w80 h16 BackgroundTrans vCF_AdvDelayLbl, Add Data Delay:
    Gui, 84:Add, Slider, x95 y164 w130 h22 vCF_AddDataDelaySlider gCF_AddDataDelayChanged Range50-2000 TickInterval250 ToolTip, %CF_AddDataDelay%
    Gui, 84:Add, Text, x230 y166 w55 h16 BackgroundTrans vCF_AddDataDelayLabel, %CF_AddDataDelay% ms
    Gui, 84:Add, Text, x10 y190 w80 h16 BackgroundTrans vCF_AdvSaveDelayLbl, AutoSave Delay:
    Gui, 84:Add, Slider, x95 y188 w130 h22 vCF_AutoSaveDelaySlider gCF_AutoSaveDelayChanged Range50-3000 TickInterval500 ToolTip, %CF_AutoSaveDelay%
    Gui, 84:Add, Text, x230 y190 w55 h16 BackgroundTrans vCF_AutoSaveDelayLabel, %CF_AutoSaveDelay% ms
    Gui, 84:Font, s8 cBlack, Segoe UI
    Gui, 84:Add, Button, x10 y214 w130 h24 gNB_PanelDump vNB_AdvDumpBtn, NB Dialog Dump
    Gui, 84:Add, Button, x145 y214 w130 h24 gCF_PanelSpy vCF_AdvSpyBtn, CPFS Dump
    Gui, 84:Font, s7 c00FF88, Segoe UI
    nbDbgChkOpt := NB_DebugLogging ? "Checked" : ""
    Gui, 84:Add, Checkbox, x10 y242 w200 h18 vNB_DebugLogChk gNB_DebugLogChanged %nbDbgChkOpt% BackgroundTrans, Debug Logging (NB + CPFS)
    Gui, 84:+AlwaysOnTop +ToolWindow -MinimizeBox
    Gui, 84:Show, x400 y0 w290 h268 Hide, NB Settings

    ; --- NursingBooster: Start CPRS detection timer ---
    SetTimer, NB_CheckCPRS, 3000

    ; --- Start Gui 14 dropdown injection timer ---
    SetTimer, NB_CheckGui14Dropdown, 2000

return


; -------------------- NB Gui 14 integration --------------------
; Periodically checks if the function bar (fxnbar) exists and adds
; the NB dropdown if it's missing. Handles the host rebuilding Gui 14
; via internal gosub calls that bypass any hotkey wrapper.
; NB_Gui14LastHwnd tracks the last seen fxnbar HWND to detect rebuilds.

NB_Gui14LastHwnd := 0
NB_MiniBarBuilt := false

NB_CheckGui14Dropdown:
    ; Check if fxnbar window exists — position our mini toolbar above it
    IfWinExist, fxnbar
    {
        nbFxnHwnd := WinExist("fxnbar")
        WinGetPos, nbFxnX, nbFxnY, nbFxnW,, ahk_id %nbFxnHwnd%
        if (!NB_MiniBarBuilt) {
            ; Build our own mini toolbar (Gui 85) — sits above the function bar
            Gui, 85:Destroy
            Gui, 85:Color, F0F0F0
            Gui, 85:Font, s8 cBlack, Verdana
            NB_MenuList := "Nursing Booster||" . NB_HK1_Label . "|" . NB_HK2_Label . "|" . NB_HK3_Label . "|" . NB_HK4_Label . "|" . NB_HK5_Label . "|Save Template|Load Template|Delete Template|Toggle Panel|Settings"
            Gui, 85:Add, DropdownList, gNB_DropdownAction y0 w140 -Tabstop altsubmit vNB_DropdownChoice, %NB_MenuList%
            Gui, 85:+AlwaysOnTop -Caption +ToolWindow +Owner +E0x08000000  ; WS_EX_NOACTIVATE
            nbMiniX := nbFxnX + nbFxnW + 2
            nbMiniY := nbFxnY
            Gui, 85:Show, x%nbMiniX% y%nbMiniY% h21 NA, NB_MiniBar
            NB_MiniBarBuilt := true
        } else {
            ; Keep mini bar positioned to the right of fxnbar
            IfWinExist, NB_MiniBar
            {
                nbMiniX := nbFxnX + nbFxnW + 2
                nbMiniY := nbFxnY
                WinMove, NB_MiniBar,, %nbMiniX%, %nbMiniY%
            }
            else
            {
                ; Mini bar was destroyed — rebuild next cycle
                NB_MiniBarBuilt := false
            }
        }
    }
    else
    {
        ; fxnbar gone — hide our mini bar too
        if (NB_MiniBarBuilt) {
            Gui, 85:Destroy
            NB_MiniBarBuilt := false
        }
    }
return


; ============================================================================================
; NURSING BOOSTER LABELS / FUNCTIONS
; ============================================================================================


;============================================================================================
; NURSING BOOSTER DROPDOWN HANDLER (on Gui 14 toolbar)
;============================================================================================

NB_DropdownAction:
    Gui, 85:Submit, NoHide
    if (NB_DropdownChoice = 1)  ; "Nursing Booster" header - do nothing
    {
        GuiControl, 85:Choose, NB_DropdownChoice, 1
        return
    }
    else if (NB_DropdownChoice >= 2 && NB_DropdownChoice <= 6)  ; Quick Actions 1-5
    {
        hkIdx := NB_DropdownChoice - 1
        if (hkIdx = 1)
            NB_RunHotkeyAction(NB_HK1_Action, NB_HK1_Label)
        else if (hkIdx = 2)
            NB_RunHotkeyAction(NB_HK2_Action, NB_HK2_Label)
        else if (hkIdx = 3)
            NB_RunHotkeyAction(NB_HK3_Action, NB_HK3_Label)
        else if (hkIdx = 4)
            NB_RunHotkeyAction(NB_HK4_Action, NB_HK4_Label)
        else if (hkIdx = 5)
            NB_RunHotkeyAction(NB_HK5_Action, NB_HK5_Label)
    }
    else if (NB_DropdownChoice = 7)   ; Save Template
        gosub NB_BtnSaveCurrentState
    else if (NB_DropdownChoice = 8)   ; Load Template
        gosub NB_BtnLoadSavedTemplate
    else if (NB_DropdownChoice = 9)   ; Delete Template
        gosub NB_BtnDeleteTemplate
    else if (NB_DropdownChoice = 10)  ; Toggle Panel
        gosub NB_TogglePanel
    else if (NB_DropdownChoice = 11)  ; Settings
        gosub NB_ToggleSettings
    ; Reset dropdown back to header
    GuiControl, 85:Choose, NB_DropdownChoice, 1
return

NB_RebuildDropdown() {
    global NB_HK1_Label, NB_HK2_Label, NB_HK3_Label, NB_HK4_Label, NB_HK5_Label
    newList := "Nursing Booster||" . NB_HK1_Label . "|" . NB_HK2_Label . "|" . NB_HK3_Label . "|" . NB_HK4_Label . "|" . NB_HK5_Label . "|Save Template|Load Template|Delete Template|Toggle Panel|Settings"
    GuiControl, 85:, NB_DropdownChoice, |%newList%
    GuiControl, 85:Choose, NB_DropdownChoice, 1
}


;============================================================================================
; NURSING BOOSTER TOGGLE PANEL (Gui 67)
;============================================================================================

NB_TogglePanel:
    if (NB_BoosterGuiVisible = 1)
    {
        Gui, 80:Hide
        NB_BoosterGuiVisible := 0
    }
    else
    {
        Gui, 80:Show, NA
        WinSet, AlwaysOnTop, On, ahk_id %NB_PanelHwnd%
        NB_BoosterGuiVisible := 1
    }
return


;============================================================================================
; NURSING BOOSTER PANEL BUTTON HANDLERS
;============================================================================================

NB_PanelSave:
    gosub NB_BtnSaveCurrentState
return

NB_PanelLoad:
    gosub NB_BtnLoadSavedTemplate
return

NB_PanelDelete:
    gosub NB_BtnDeleteTemplate
return

NB_PanelDump:
    gosub NB_DumpDialogControls
return

NB_PanelSettings:
NB_ToggleSettings:
    if (NB_SettingsVisible) {
        Gui, 84:Hide
        NB_SettingsVisible := 0
    } else {
        NB_RefreshSettingsTplList()
        ; Position settings panel below the booster panel
        settingsX := 0
        settingsY := 0
        if (NB_BoosterGuiVisible) {
            WinGetPos, nbPosX, nbPosY, nbPosW, nbPosH, ahk_id %NB_PanelHwnd%
            if (nbPosX != "" && nbPosY != "" && nbPosH != "") {
                settingsX := nbPosX
                settingsY := nbPosY + nbPosH + 2
            }
        }
        Gui, 84:Show, x%settingsX% y%settingsY%
        NB_SettingsVisible := 1
    }
return

NB_ShowBothBars:
    ; Force-show top Hyperdrive bar (!+z), bottom function bar (!+h), and NursingBooster panel
    ; Use SetTimer to avoid GUI thread context issues
    SetTimer, NB_ShowBarsDeferred, -10
return

NB_ShowBarsDeferred:
    ; Top bar (Hyperdrive, Gui 7/8)
    savedHBO := HBO
    HBO := 0
    gosub !+z
    HBO := savedHBO
    ; Bottom bar (Function keys, Gui 14)
    savedFBO := FBO
    FBO := 0
    gosub !+h
    FBO := savedFBO
return

NB_AdvancedModeChanged:
    GuiControlGet, NB_AdvancedMode, 73:, NB_AdvancedModeChk
    gosub NB_ApplyAdvancedMode
    gosub NB_SaveSettings
return

NB_ApplyAdvancedMode:
    ; Show or hide advanced-only controls based on NB_AdvancedMode
    showCmd := NB_AdvancedMode ? "Show" : "Hide"
    ; Gui 67 (main panel): speed sliders and autosave
    GuiControl, 80:%showCmd%, NB_SpeedOverrideChk
    GuiControl, 80:%showCmd%, NB_MainSpeedSlider
    GuiControl, 80:%showCmd%, NB_MainSpeedLabel
    GuiControl, 80:%showCmd%, NB_LeafSpeedLbl
    GuiControl, 80:%showCmd%, NB_LeafSpeedSlider
    GuiControl, 80:%showCmd%, NB_LeafSpeedLabel
    GuiControl, 80:%showCmd%, CF_AutoSaveChk
    ; Gui 73 (settings): add data delay, dump buttons, debug logging
    GuiControl, 84:%showCmd%, CF_AdvDelayLbl
    GuiControl, 84:%showCmd%, CF_AddDataDelaySlider
    GuiControl, 84:%showCmd%, CF_AddDataDelayLabel
    GuiControl, 84:%showCmd%, CF_AdvSaveDelayLbl
    GuiControl, 84:%showCmd%, CF_AutoSaveDelaySlider
    GuiControl, 84:%showCmd%, CF_AutoSaveDelayLabel
    GuiControl, 84:%showCmd%, NB_AdvDumpBtn
    GuiControl, 84:%showCmd%, CF_AdvSpyBtn
    GuiControl, 84:%showCmd%, NB_DebugLogChk
    ; Resize panels only if they are currently visible (avoid showing them at startup)
    if (NB_BoosterGuiVisible) {
        if (NB_AdvancedMode)
            Gui, 80:Show, w385 h218 NA
        else
            Gui, 80:Show, w385 h172 NA
    }
    if (NB_SettingsVisible) {
        if (NB_AdvancedMode)
            Gui, 84:Show, w290 h268 NA
        else
            Gui, 84:Show, w290 h170 NA
    }
return

NB_DragPanel:
    ; Allow dragging the panel by clicking the title bar text
    PostMessage, 0xA1, 2, 0,, NursingBoosterPanel
return

NB_SpeedOverrideChanged:
    GuiControlGet, NB_SpeedOverride, 67:, NB_SpeedOverrideChk
    if (NB_SpeedOverride) {
        GuiControl, 80:Enable, NB_MainSpeedSlider
        GuiControl, 80:Enable, NB_LeafSpeedSlider
    } else {
        GuiControl, 80:Disable, NB_MainSpeedSlider
        GuiControl, 80:Disable, NB_LeafSpeedSlider
    }
return

NB_MainSpeedChanged:
    GuiControlGet, NB_ApplySpeed, 67:, NB_MainSpeedSlider
    GuiControl, 80:, NB_MainSpeedLabel, %NB_ApplySpeed% ms
return

NB_LeafSpeedChanged:
    GuiControlGet, NB_LeafSpeed, 67:, NB_LeafSpeedSlider
    GuiControl, 80:, NB_LeafSpeedLabel, %NB_LeafSpeed% ms
return

NB_SettingsTplChanged:
    GuiControlGet, selectedTpl, 73:, NB_SettingsTplDDL
    if (selectedTpl = "")
        return
    tplPath := NB_SettingsTplPathMap[selectedTpl]
    if (tplPath = "")
        return
    tplSpeed := NB_ReadTemplateSpeed(tplPath)
    tplLeaf := NB_ReadTemplateLeafSpeed(tplPath)
    displayName := RegExReplace(selectedTpl, "\s*\[(NB|CF)\]$", "")
    GuiControl, 84:, NB_TplSpeedSlider, %tplSpeed%
    GuiControl, 84:, NB_TplSpeedLabel, %tplSpeed% ms
    GuiControl, 84:, NB_TplLeafSlider, %tplLeaf%
    GuiControl, 84:, NB_TplLeafLabel, %tplLeaf% ms
    GuiControl, 84:, NB_TplSpeedStatus, Speed for: %displayName%
return

NB_TplSpeedChanged:
    GuiControlGet, tplSpd, 73:, NB_TplSpeedSlider
    GuiControl, 84:, NB_TplSpeedLabel, %tplSpd% ms
return

NB_TplLeafChanged:
    GuiControlGet, tplLeafSpd, 73:, NB_TplLeafSlider
    GuiControl, 84:, NB_TplLeafLabel, %tplLeafSpd% ms
return

NB_SaveTplSpeed:
    GuiControlGet, selectedTpl, 73:, NB_SettingsTplDDL
    if (selectedTpl = "") {
        MsgBox, 48, %NB_AppTitle%, Select a template first.
        return
    }
    GuiControlGet, newSpeed, 73:, NB_TplSpeedSlider
    GuiControlGet, newLeaf, 73:, NB_TplLeafSlider
    tplPath := NB_SettingsTplPathMap[selectedTpl]
    if (tplPath = "") {
        MsgBox, 48, %NB_AppTitle%, Template path not found.
        return
    }
    displayName := RegExReplace(selectedTpl, "\s*\[(NB|CF)\]$", "")
    ok1 := NB_WriteTemplateSpeed(tplPath, newSpeed)
    ok2 := NB_WriteTemplateLeafSpeed(tplPath, newLeaf)
    if (ok1 && ok2) {
        GuiControl, 84:, NB_TplSpeedStatus, Saved: %newSpeed%/%newLeaf% ms for %displayName%
    } else {
        GuiControl, 84:, NB_TplSpeedStatus, Error saving speed!
    }
return

CF_AddDataDelayChanged:
    GuiControlGet, CF_AddDataDelay, 73:, CF_AddDataDelaySlider
    GuiControl, 84:, CF_AddDataDelayLabel, %CF_AddDataDelay% ms
    gosub NB_SaveSettings
return

CF_AutoSaveDelayChanged:
    GuiControlGet, CF_AutoSaveDelay, 73:, CF_AutoSaveDelaySlider
    GuiControl, 84:, CF_AutoSaveDelayLabel, %CF_AutoSaveDelay% ms
    gosub NB_SaveSettings
return

NB_DebugLogChanged:
    GuiControlGet, chkVal, 73:, NB_DebugLogChk
    NB_DebugLogging := chkVal
    gosub NB_SaveSettings
    gosub, writeit
return

84GuiClose:
    Gui, 84:Hide
    NB_SettingsVisible := 0
return


;============================================================================================
; CP FLOWSHEETS PANEL BUTTON HANDLERS
;============================================================================================

CF_PanelSpy:
    gosub CF_SpyDumpControls
return

CF_PanelSave:
    gosub CF_BtnSaveTemplate
return

CF_PanelLoad:
    gosub CF_BtnLoadTemplate
return

CF_PanelDelete:
    gosub CF_BtnDeleteTemplate
return

CF_PanelAddData:
    CF_ClickAddDataButton()
return

CF_ToggleAutoAdd:
    Gui, 80:Submit, NoHide
    global CF_ChainAddData
    CF_ChainAddData := CF_AutoAddChk
return

CF_ToggleAutoSave:
    Gui, 80:Submit, NoHide
    global CF_AutoSave
    if (CF_AutoSaveChk = 1) {
        MsgBox, 308, CP Flowsheets - AutoSave WARNING, WARNING: AutoSave will automatically click the SAVE button in CP Flowsheets after applying a template.`n`nThis saves the entry PERMANENTLY to the patient record.`n`nAre you sure you want to enable AutoSave?
        IfMsgBox, Yes
        {
            CF_AutoSave := 1
            ToolTip, CPFS AutoSave ENABLED - Save will be clicked automatically
            SetTimer, NB_ClearToolTip, -3000
        }
        else
        {
            CF_AutoSave := 0
            GuiControl, 80:, CF_AutoSaveChk, 0
        }
    } else {
        CF_AutoSave := 0
        ToolTip, CPFS AutoSave disabled
        SetTimer, NB_ClearToolTip, -2000
    }
return


;============================================================================================
; QUICK ACTION HOTKEY BUTTON HANDLERS
;============================================================================================

NB_HK1_Run:
    NB_RunHotkeyAction(NB_HK1_Action, "Quick 1")
return

NB_HK2_Run:
    NB_RunHotkeyAction(NB_HK2_Action, "Quick 2")
return

NB_HK3_Run:
    NB_RunHotkeyAction(NB_HK3_Action, "Quick 3")
return

NB_HK4_Run:
    NB_RunHotkeyAction(NB_HK4_Action, "Quick 4")
return

NB_HK5_Run:
    NB_RunHotkeyAction(NB_HK5_Action, "Quick 5")
return

NB_RunHotkeyAction(action, slotName) {
    global NB_TemplateDir, CF_TemplateDir, NB_AppTitle
    if (action = "") {
        ToolTip, %slotName% not configured - click [...] to set up
        SetTimer, NB_ClearToolTip, -2000
        return
    }
    ; Parse action type: "nb_template:Name", "cf_template:Name"
    if (RegExMatch(action, "^nb_template:(.+)$", m)) {
        NB_ApplyNamedTemplate(m1)
    }
    else if (RegExMatch(action, "^cf_template:(.+)$", m)) {
        templatePath := CF_TemplateDir . "\" . m1 . ".json"
        if (FileExist(templatePath)) {
            if (CF_ChainAddData) {
                CF_ClickAddDataButton()
                Loop, 20 {
                    Sleep, 250
                    if (CF_FindAddDataWindow())
                        break
                }
                Sleep, %CF_AddDataDelay%
            }
            CF_ApplyTemplate(templatePath)
        } else {
            MsgBox, 48, %NB_AppTitle%, CPFS template "%m1%" not found.`n`nSave a template with that name using CPFS Save first.
        }
    }
    else {
        ToolTip, Unknown action: %action%
        SetTimer, NB_ClearToolTip, -2000
    }
}

;============================================================================================
; QUICK ACTION SETUP DIALOG (Gui 71)
;============================================================================================

NB_HK_Setup:
    global NB_HK1_Action, NB_HK2_Action, NB_HK3_Action, NB_HK4_Action, NB_HK5_Action
    global NB_HK1_Label, NB_HK2_Label, NB_HK3_Label, NB_HK4_Label, NB_HK5_Label
    global NB_TemplateDir, CF_TemplateDir

    ; Build list of available actions
    actionList := "-- None --|"

    ; NB templates
    Loop, Files, %NB_TemplateDir%\*.json
    {
        fname := StrReplace(A_LoopFileName, ".json", "")
        actionList .= "NB Template: " . fname . "|"
    }

    ; CF templates
    Loop, Files, %CF_TemplateDir%\*.json
    {
        fname := StrReplace(A_LoopFileName, ".json", "")
        actionList .= "CPFS Template: " . fname . "|"
    }

    Gui, 83:Destroy
    Gui, 83:+AlwaysOnTop +ToolWindow
    Gui, 83:Color, F8F8F8
    Gui, 83:Font, s9 Bold, Segoe UI
    Gui, 83:Add, Text, x10 y10 w380, Quick Action Button Setup
    Gui, 83:Font, s8 Norm, Segoe UI

    ; Slot 1
    Gui, 83:Add, Text, x10 y40 w50, Slot 1:
    Gui, 83:Add, Edit, x65 y38 w100 h22 vNB_HKSetup_L1, %NB_HK1_Label%
    Gui, 83:Add, DropDownList, x170 y38 w220 vNB_HKSetup_A1, %actionList%
    NB_HKSetupSelectAction("NB_HKSetup_A1", NB_HK1_Action)

    ; Slot 2
    Gui, 83:Add, Text, x10 y68 w50, Slot 2:
    Gui, 83:Add, Edit, x65 y66 w100 h22 vNB_HKSetup_L2, %NB_HK2_Label%
    Gui, 83:Add, DropDownList, x170 y66 w220 vNB_HKSetup_A2, %actionList%
    NB_HKSetupSelectAction("NB_HKSetup_A2", NB_HK2_Action)

    ; Slot 3
    Gui, 83:Add, Text, x10 y96 w50, Slot 3:
    Gui, 83:Add, Edit, x65 y94 w100 h22 vNB_HKSetup_L3, %NB_HK3_Label%
    Gui, 83:Add, DropDownList, x170 y94 w220 vNB_HKSetup_A3, %actionList%
    NB_HKSetupSelectAction("NB_HKSetup_A3", NB_HK3_Action)

    ; Slot 4
    Gui, 83:Add, Text, x10 y124 w50, Slot 4:
    Gui, 83:Add, Edit, x65 y122 w100 h22 vNB_HKSetup_L4, %NB_HK4_Label%
    Gui, 83:Add, DropDownList, x170 y122 w220 vNB_HKSetup_A4, %actionList%
    NB_HKSetupSelectAction("NB_HKSetup_A4", NB_HK4_Action)

    ; Slot 5
    Gui, 83:Add, Text, x10 y152 w50, Slot 5:
    Gui, 83:Add, Edit, x65 y150 w100 h22 vNB_HKSetup_L5, %NB_HK5_Label%
    Gui, 83:Add, DropDownList, x170 y150 w220 vNB_HKSetup_A5, %actionList%
    NB_HKSetupSelectAction("NB_HKSetup_A5", NB_HK5_Action)

    Gui, 83:Add, Button, x110 y185 w90 h28 gNB_HKSetup_Save Default, Save
    Gui, 83:Add, Button, x210 y185 w90 h28 gNB_HKSetup_Cancel, Cancel
    Gui, 83:Show, w400 h225, Quick Action Setup
return

NB_HKSetupSelectAction(ctrlName, currentAction) {
    ; Convert stored action back to display text for dropdown selection
    displayText := "-- None --"
    if (RegExMatch(currentAction, "^nb_template:(.+)$", m))
        displayText := "NB Template: " . m1
    else if (RegExMatch(currentAction, "^cf_template:(.+)$", m))
        displayText := "CPFS Template: " . m1
    GuiControl, 83:ChooseString, %ctrlName%, %displayText%
}

NB_HKSetup_Save:
    Gui, 83:Submit
    global NB_HK1_Label, NB_HK1_Action, NB_HK2_Label, NB_HK2_Action
    global NB_HK3_Label, NB_HK3_Action, NB_HK4_Label, NB_HK4_Action
    global NB_HK5_Label, NB_HK5_Action

    ; Convert display text back to action strings
    NB_HK1_Label := NB_HKSetup_L1
    NB_HK1_Action := NB_HKParseActionChoice(NB_HKSetup_A1)
    NB_HK2_Label := NB_HKSetup_L2
    NB_HK2_Action := NB_HKParseActionChoice(NB_HKSetup_A2)
    NB_HK3_Label := NB_HKSetup_L3
    NB_HK3_Action := NB_HKParseActionChoice(NB_HKSetup_A3)
    NB_HK4_Label := NB_HKSetup_L4
    NB_HK4_Action := NB_HKParseActionChoice(NB_HKSetup_A4)
    NB_HK5_Label := NB_HKSetup_L5
    NB_HK5_Action := NB_HKParseActionChoice(NB_HKSetup_A5)

    ; Update button labels on panel
    GuiControl, 80:, NB_HK1_Btn, %NB_HK1_Label%
    GuiControl, 80:, NB_HK2_Btn, %NB_HK2_Label%
    GuiControl, 80:, NB_HK3_Btn, %NB_HK3_Label%
    GuiControl, 80:, NB_HK4_Btn, %NB_HK4_Label%
    GuiControl, 80:, NB_HK5_Btn, %NB_HK5_Label%

    ; Rebuild dropdown on bottom bar to reflect new quick action labels
    NB_RebuildDropdown()

    ; Save to file
    gosub NB_SaveHotkeyConfig
    Gui, 83:Destroy
    ToolTip, Quick actions saved
    SetTimer, NB_ClearToolTip, -2000
return

NB_HKSetup_Cancel:
    Gui, 83:Destroy
return

NB_HKParseActionChoice(displayText) {
    ; Convert dropdown display text to stored action string
    if (displayText = "-- None --" || displayText = "")
        return ""
    if (RegExMatch(displayText, "^NB Template: (.+)$", m))
        return "nb_template:" . m1
    if (RegExMatch(displayText, "^CPFS Template: (.+)$", m))
        return "cf_template:" . m1
    return ""
}

;============================================================================================
; QUICK ACTION CONFIG SAVE/LOAD
;============================================================================================

NB_LoadHotkeyConfig:
    global NB_HotkeyConfigPath
    global NB_HK1_Label, NB_HK1_Action, NB_HK2_Label, NB_HK2_Action
    global NB_HK3_Label, NB_HK3_Action, NB_HK4_Label, NB_HK4_Action
    global NB_HK5_Label, NB_HK5_Action

    if (!FileExist(NB_HotkeyConfigPath))
        return

    FileRead, hkJson, %NB_HotkeyConfigPath%
    if (hkJson = "")
        return

    ; Parse each slot with regex (guard against empty labels — they break dropdown indexing)
    if (RegExMatch(hkJson, """label1"":\s*""((?:[^""\\]|\\.)*)""", m) && m1 != "")
        NB_HK1_Label := m1
    if (RegExMatch(hkJson, """action1"":\s*""((?:[^""\\]|\\.)*)""", m))
        NB_HK1_Action := m1
    if (RegExMatch(hkJson, """label2"":\s*""((?:[^""\\]|\\.)*)""", m) && m1 != "")
        NB_HK2_Label := m1
    if (RegExMatch(hkJson, """action2"":\s*""((?:[^""\\]|\\.)*)""", m))
        NB_HK2_Action := m1
    if (RegExMatch(hkJson, """label3"":\s*""((?:[^""\\]|\\.)*)""", m) && m1 != "")
        NB_HK3_Label := m1
    if (RegExMatch(hkJson, """action3"":\s*""((?:[^""\\]|\\.)*)""", m))
        NB_HK3_Action := m1
    if (RegExMatch(hkJson, """label4"":\s*""((?:[^""\\]|\\.)*)""", m) && m1 != "")
        NB_HK4_Label := m1
    if (RegExMatch(hkJson, """action4"":\s*""((?:[^""\\]|\\.)*)""", m))
        NB_HK4_Action := m1
    if (RegExMatch(hkJson, """label5"":\s*""((?:[^""\\]|\\.)*)""", m) && m1 != "")
        NB_HK5_Label := m1
    if (RegExMatch(hkJson, """action5"":\s*""((?:[^""\\]|\\.)*)""", m))
        NB_HK5_Action := m1
return

NB_SaveHotkeyConfig:
    global NB_HotkeyConfigPath
    global NB_HK1_Label, NB_HK1_Action, NB_HK2_Label, NB_HK2_Action
    global NB_HK3_Label, NB_HK3_Action, NB_HK4_Label, NB_HK4_Action
    global NB_HK5_Label, NB_HK5_Action

    hkJson := "{`n"
    hkJson .= "  ""label1"": " . NB_EscJson(NB_HK1_Label) . ", ""action1"": " . NB_EscJson(NB_HK1_Action) . ",`n"
    hkJson .= "  ""label2"": " . NB_EscJson(NB_HK2_Label) . ", ""action2"": " . NB_EscJson(NB_HK2_Action) . ",`n"
    hkJson .= "  ""label3"": " . NB_EscJson(NB_HK3_Label) . ", ""action3"": " . NB_EscJson(NB_HK3_Action) . ",`n"
    hkJson .= "  ""label4"": " . NB_EscJson(NB_HK4_Label) . ", ""action4"": " . NB_EscJson(NB_HK4_Action) . ",`n"
    hkJson .= "  ""label5"": " . NB_EscJson(NB_HK5_Label) . ", ""action5"": " . NB_EscJson(NB_HK5_Action) . "`n"
    hkJson .= "}"

    FileDelete, %NB_HotkeyConfigPath%
    FileAppend, %hkJson%, %NB_HotkeyConfigPath%
return

NB_LoadSettings:
    global NB_SettingsIniPath, NB_AdvancedMode, NB_DebugLogging, CF_AddDataDelay, CF_AutoSaveDelay
    IniRead, NB_AdvancedMode, %NB_SettingsIniPath%, General, AdvancedMode, 0
    IniRead, NB_DebugLogging, %NB_SettingsIniPath%, General, DebugLogging, 0
    IniRead, CF_AddDataDelay, %NB_SettingsIniPath%, CPFS, AddDataDelay, 50
    IniRead, CF_AutoSaveDelay, %NB_SettingsIniPath%, CPFS, AutoSaveDelay, 500
return

NB_SaveSettings:
    global NB_SettingsIniPath, NB_AdvancedMode, NB_DebugLogging, CF_AddDataDelay, CF_AutoSaveDelay
    IniWrite, %NB_AdvancedMode%, %NB_SettingsIniPath%, General, AdvancedMode
    IniWrite, %NB_DebugLogging%, %NB_SettingsIniPath%, General, DebugLogging
    IniWrite, %CF_AddDataDelay%, %NB_SettingsIniPath%, CPFS, AddDataDelay
    IniWrite, %CF_AutoSaveDelay%, %NB_SettingsIniPath%, CPFS, AutoSaveDelay
return


;============================================================================================
; NURSING BOOSTER CPRS DETECTION TIMER
;============================================================================================

NB_CheckCPRS:
    Critical
    ; --- CPRS Detection ---
    cprsStatus := "CPRS: Not detected"
    IfWinExist, ahk_exe CPRSChart.exe
    {
        NB_CPRSDetected := 1
        dlgCheck := NB_FindActiveDialogWindow()
        if (dlgCheck) {
            cprsStatus := "Dialog detected"
        } else {
            cprsStatus := "CPRS: Detected"
        }
    }
    else
    {
        NB_CPRSDetected := 0
    }
    ; --- CP Flowsheets Detection ---
    cfStatus := "CPFS: Not detected"
    IfWinExist, ahk_exe CPFlowsheets.exe
    {
        CF_Detected := 1
        cfStatus := "CPFS: Detected"
        cfLastTime := CF_ReadLastEntryTime()
        if (cfLastTime != "")
            cfStatus .= ", last entry " . cfLastTime
    }
    else
    {
        CF_Detected := 0
    }
    GuiControl, 80:, NB_PanelStatus, Ready | %cprsStatus% | %cfStatus%

return

NB_ClearV6Warning:
    GuiControl, 80:, NB_PanelStatus, Ready
return

NB_RestorePanelAfterFKey:
    if (NB_SignWasVisible = 1) {
        Gui, 80:Show, NA
        WinSet, AlwaysOnTop, On, ahk_id %NB_PanelHwnd%
        NB_BoosterGuiVisible := 1
        NB_SignWasVisible := 0
    }
return


;============================================================================================
; NURSING BOOSTER - DIALOG WINDOW DETECTION
;============================================================================================

NB_FindActiveDialogWindow() {
    ; Try TfrmRemDlg first (reminder dialog)
    hwnd := WinExist("ahk_class TfrmRemDlg")
    if (hwnd)
        return hwnd

    ; Try TfrmTemplateDialog
    hwnd := WinExist("ahk_class TfrmTemplateDialog")
    if (hwnd)
        return hwnd

    ; Search all CPRS windows for one with checkbox controls
    WinGet, wndList, List, ahk_exe CPRSChart.exe
    Loop, %wndList%
    {
        wnd := wndList%A_Index%
        WinGetClass, cls, ahk_id %wnd%
        if (cls = "TCPRSChart" || cls = "TfrmFrame")
            continue
        if (NB_HasCheckboxControls(wnd))
            return wnd
    }

    ; Fallback: check main frame
    mainHwnd := WinExist("ahk_class TfrmFrame")
    if (!mainHwnd)
        mainHwnd := WinExist("ahk_exe CPRSChart.exe")
    if (mainHwnd && NB_HasCheckboxControls(mainHwnd))
        return mainHwnd

    return 0
}

NB_HasCheckboxControls(windowHwnd) {
    global NB__hasCheckboxes
    NB__hasCheckboxes := false
    enumCB := RegisterCallback("NB__CheckForCheckboxes", "Fast")
    DllCall("EnumChildWindows", "Ptr", windowHwnd, "Ptr", enumCB, "Ptr", 0)
    return NB__hasCheckboxes
}

NB__CheckForCheckboxes(hwnd, lParam) {
    global NB__hasCheckboxes
    VarSetCapacity(buf, 256, 0)
    DllCall("GetClassName", "Ptr", hwnd, "Str", buf, "Int", 256)
    if (buf = "TORCheckBox" || buf = "TCPRSDialogParentCheckBox" || buf = "TCPRSDialogCheckBox") {
        NB__hasCheckboxes := true
        return 0
    }
    return 1
}


;============================================================================================
; NURSING BOOSTER - NAMED TEMPLATE BUTTONS
;============================================================================================

NB_ApplyNamedTemplate(templateName) {
    global NB_TemplateDir, NB_AppTitle
    dlgHwnd := NB_FindActiveDialogWindow()
    if (!dlgHwnd) {
        ToolTip, Open a template or reminder dialogue in CPRS first
        SetTimer, NB_ClearToolTip, -2000
        return
    }
    templatePath := NB_TemplateDir . "\" . NB_SanitizeFilename(templateName) . ".json"
    if (FileExist(templatePath)) {
        WinActivate, ahk_id %dlgHwnd%
        Sleep, 200
        NB_ApplyTemplate(templatePath)
    } else {
        MsgBox, 64, %NB_AppTitle%, No '%templateName%' template saved yet.`n`nTo create one:`n1. Open the reminder dialogue in CPRS`n2. Manually check all the boxes the way you want them`n3. Select 'Save Template' from the Nursing Booster dropdown`n4. Name it exactly: %templateName%`n`nNext time you select this option it replays your selections.`nYou always review in CPRS before clicking Finish.
    }
}


;============================================================================================
; NURSING BOOSTER - SAVE TEMPLATE (format v7 - flat top-to-bottom)
;
; Captures ALL checkboxes in the scroll box as one flat Y-sorted list.
; Includes section toggles, group items, children, grandchildren — everything.
; No separate topLevelParents or groups — just one ordered list.
;============================================================================================

NB_BtnSaveCurrentState:
    dlgHwnd := NB_FindActiveDialogWindow()
    if (!dlgHwnd) {
        MsgBox, 48, %NB_AppTitle%, Open a template or reminder dialogue in CPRS first.
        return
    }

    InputBox, templateName, Save Template, Template name:`n`nUse a descriptive name like 'Negative Assessment' or 'Skin WNL'.`nNaming it the same as a toolbar option links it to that option.
    if (ErrorLevel || templateName = "")
        return

    ToolTip, Scanning dialog...
    NB_WaitForStableCheckboxCount(dlgHwnd)

    scrollBox := NB_FindVisibleScrollBox(dlgHwnd)
    if (!scrollBox) {
        MsgBox, 48, %NB_AppTitle%, Could not find dialog scroll area.
        return
    }

    ; Enumerate ALL checkboxes in the entire scroll box (flat, Y-sorted)
    allItems := NB_EnumDescendantCheckboxes(scrollBox)
    if (allItems.Length() = 0) {
        MsgBox, 48, %NB_AppTitle%, No checkboxes found in dialog.
        return
    }

    ; Build JSON — flat list
    json := "{"
    json .= "`n  ""name"": " . NB_EscJson(templateName) . ","
    json .= "`n  ""format"": 7,"
    json .= "`n  ""matching"": ""flat-sequential"","
    json .= "`n  ""speed"": " . NB_ApplySpeed . ","
    json .= "`n  ""leaf_speed"": " . NB_LeafSpeed . ","
    FormatTime, nowTime,, yyyy-MM-dd HH:mm
    json .= "`n  ""created"": """ . nowTime . ""","
    WinGetTitle, dlgTitle, ahk_id %dlgHwnd%
    json .= "`n  ""source_dialogue"": " . NB_EscJson(dlgTitle) . ","
    dlgVersion := NB_GetDialogVersion(dlgHwnd)
    if (dlgVersion != "")
        json .= "`n  ""source_version"": """ . dlgVersion . ""","

    totalChecked := 0
    totalControls := allItems.Length()
    json .= "`n  ""checkboxes"": ["
    for ci, cb in allItems {
        if (ci > 1)
            json .= ","
        json .= "`n    {""idx"": " . (ci - 1) . ", ""cls"": " . NB_EscJson(cb.className)
            . ", ""checked"": " . (cb.checked ? "true" : "false")
            . ", ""depth"": " . cb.depth
        if (cb.label != "")
            json .= ", ""label"": " . NB_EscJson(cb.label)
        json .= "}"
        if (cb.checked)
            totalChecked++
    }
    json .= "`n  ]"
    json .= "`n}"

    filePath := NB_TemplateDir . "\" . NB_SanitizeFilename(templateName) . ".json"
    f := FileOpen(filePath, "w", "UTF-8")
    f.Write(json)
    f.Close()

    ; Log using group-based view for readability
    if (NB_DebugLogging) {
        allGroupBoxes := NB_EnumScrollBoxGroupBoxes(scrollBox)
        NB__LogCheckboxStates("SAVE", allGroupBoxes, templateName, dlgTitle, totalChecked, totalControls)
    }

    ToolTip, Saved "%templateName%": %totalChecked%/%totalControls% checkboxes
    SetTimer, NB_ClearToolTip, -3000
return


;============================================================================================
; NURSING BOOSTER - APPLY TEMPLATE (format v7 - flat sequential)
;
; Treats the ENTIRE dialog as one flat top-to-bottom list.
; No separate phases for sections vs groups. Processes item by item:
; section toggle → its children → their grandchildren → next section.
; Re-enumerates the whole scroll box after every parent toggle so
; dynamically created children appear at the correct positions.
;============================================================================================

NB_ApplyTemplate(templatePath) {
    global NB_AppTitle, NB_TemplateDir, NB_ApplySpeed, NB_LeafSpeed, NB_SpeedOverride, NB_ApplyCancelled
    dlgHwnd := NB_FindActiveDialogWindow()
    if (!dlgHwnd)
        return

    FileRead, content, %templatePath%
    if (ErrorLevel) {
        MsgBox, 48, %NB_AppTitle%, Failed to read template: %templatePath%
        return
    }

    ; Accept format v7 or v6 (flat). Warn on v6 but allow it.
    isV7 := InStr(content, """format"": 7") || InStr(content, """format"":7")
    isV6 := InStr(content, """format"": 6") || InStr(content, """format"":6")
    if !(isV7 || isV6) {
        MsgBox, 262192, %NB_AppTitle%, This template must be re-saved with the updated Nursing Booster (v7).`n`n1. Open the reminder dialog in CPRS and fill it out`n2. Select 'Save Template' to create a new version
        return
    }
    if (isV6 && !isV7) {
        GuiControl, 80:, NB_PanelStatus, WARNING: Loading v6 template - re-save to upgrade to v7
        SetTimer, NB_ClearV6Warning, -5000
    }

    ; Check if template was saved from a different dialogue type
    dialogueMatched := true
    if (RegExMatch(content, """source_dialogue"":\s*""((?:[^""\\]|\\.)*)""", sdM)) {
        WinGetTitle, currentDlgTitle, ahk_id %dlgHwnd%
        if (sdM1 != "" && currentDlgTitle != "" && sdM1 != currentDlgTitle) {
            dialogueMatched := false
            MsgBox, 262452, %NB_AppTitle% - Dialogue Mismatch, This template was saved from:`n%sdM1%`n`nBut you are applying it to:`n%currentDlgTitle%`n`nAre you sure you want to continue?
            IfMsgBox, No
                return
        }
    }

    ; Check version mismatch (only if same dialogue — different dialogue already warned)
    if (dialogueMatched) {
        currentVersion := NB_GetDialogVersion(dlgHwnd)
        if (RegExMatch(content, """source_version"":\s*""([\d.]+)""", svM)) {
            if (currentVersion != "" && svM1 != "" && currentVersion != svM1) {
                MsgBox, 262452, %NB_AppTitle% - Version Mismatch, This template was saved on version %svM1% but this dialogue is now version %currentVersion%.`n`nCheckboxes may have changed. The template may not apply correctly.`n`nAre you sure you want to continue?
                IfMsgBox, No
                    return
            }
        } else if (currentVersion != "") {
            MsgBox, 262452, %NB_AppTitle% - Version Unknown, This template has no version info (saved before v8.2).`nThe current dialogue is version %currentVersion%.`n`nRe-save the template to enable version tracking.`nApply anyway?
            IfMsgBox, No
                return
        }
    }

    ; Parse flat checkbox list from template
    tplItems := NB_ParseFlatCheckboxes(content)
    if (tplItems.Length() = 0) {
        MsgBox, 48, %NB_AppTitle%, Template has no checkboxes.
        return
    }

    tplCount := tplItems.Length()

    ; Determine effective speed: override checkbox → main panel speed, else → template speed
    tplSpeed := 600
    if (RegExMatch(content, """speed"":\s*(\d+)", spdM))
        tplSpeed := spdM1 + 0
    tplLeafSpd := 50
    if (RegExMatch(content, """leaf_speed"":\s*(\d+)", lspdM))
        tplLeafSpd := lspdM1 + 0
    if (NB_SpeedOverride) {
        effectiveSpeed := NB_ApplySpeed
        effectiveLeafSpeed := NB_LeafSpeed
    } else {
        effectiveSpeed := tplSpeed
        effectiveLeafSpeed := tplLeafSpd
    }

    ; Wait for dialog to load
    ToolTip, Waiting for dialog to load...
    NB_WaitForStableCheckboxCount(dlgHwnd)

    scrollBox := NB_FindVisibleScrollBox(dlgHwnd)
    if (!scrollBox) {
        MsgBox, 48, %NB_AppTitle%, Could not find dialog scroll area.
        return
    }

    totalApplied := 0
    totalNotFound := 0

    ; Enumerate ALL checkboxes in the scroll box (flat, Y-sorted)
    liveItems := NB_EnumDescendantCheckboxes(scrollBox)

    ToolTip, Applying %tplCount% items... (Right-click to cancel)

    ; Pause timers during apply to prevent interference
    SetTimer, NB_CheckCPRS, Off
    SetTimer, NB_CheckGui14Dropdown, Off

    ; Register right-click hotkey to set cancel flag
    NB_ApplyCancelled := false
    Hotkey, ~RButton, NB_CancelApplyHotkey, On

    ; Walk the template top-to-bottom, one item at a time.
    ; Uses synchronous SendMessage BM_SETCHECK + WM_COMMAND instead of
    ; async PostMessage BM_CLICK to eliminate race conditions.
    ; Only re-enumerates when the checkbox count actually changes
    ; (real parent expansion/collapse), not after every toggle.
    tplPos := 1
    while (tplPos <= tplCount)
    {
        ; Cancel on right-click
        if (NB_ApplyCancelled) {
            Hotkey, ~RButton, NB_CancelApplyHotkey, Off
            ToolTip, Template apply cancelled at item %tplPos%/%tplCount%.
            SetTimer, NB_ClearToolTip, -3000
            return
        }

        liveCount := liveItems.Length()
        if (tplPos > liveCount) {
            totalNotFound++
            tplPos++
            continue
        }

        tplCb := tplItems[tplPos]
        liveCb := liveItems[tplPos]

        nb_tmpHwnd := liveCb.hwnd
        if (DllCall("IsWindow", "Ptr", nb_tmpHwnd)) {
            ; Fresh state read right before toggle decision
            SendMessage, 0x00F0, 0, 0,, ahk_id %nb_tmpHwnd%
            currentState := ErrorLevel ? true : false

            ; Only check unchecked boxes — never uncheck
            if (!currentState && tplCb.checked) {
                desiredState := 1

                ; Synchronous: set check state directly
                SendMessage, 0x00F1, %desiredState%, 0,, ahk_id %nb_tmpHwnd%  ; BM_SETCHECK

                ; Synchronous: notify parent that checkbox was clicked
                ; This triggers CPRS's child creation/destruction logic
                ; and does not return until CPRS finishes processing.
                nb_ctrlID := DllCall("GetDlgCtrlID", "Ptr", nb_tmpHwnd, "Int")
                nb_parentHwnd := DllCall("GetParent", "Ptr", nb_tmpHwnd, "Ptr")
                SendMessage, 0x0111, (nb_ctrlID & 0xFFFF), nb_tmpHwnd,, ahk_id %nb_parentHwnd%  ; WM_COMMAND + BN_CLICKED

                ; Verify the toggle took
                SendMessage, 0x00F0, 0, 0,, ahk_id %nb_tmpHwnd%
                if (!(ErrorLevel)) {
                    ; Retry once
                    SendMessage, 0x00F1, %desiredState%, 0,, ahk_id %nb_tmpHwnd%
                    SendMessage, 0x0111, (nb_ctrlID & 0xFFFF), nb_tmpHwnd,, ahk_id %nb_parentHwnd%
                }

                totalApplied++

                ; Check if structure changed (children created/destroyed)
                ; Only re-enumerate if count actually changed
                Sleep, %effectiveLeafSpeed%
                newItems := NB_EnumDescendantCheckboxes(scrollBox)
                if (newItems.Length() != liveCount) {
                    ; Structure changed — use new list
                    liveItems := newItems
                } else {
                    ; Count unchanged — this was a leaf toggle, no re-enum needed
                    ; But update liveItems to keep Y-sort fresh
                    liveItems := newItems
                }
            }
        }

        tplPos++

        ; Progress tooltip every 20 items
        if (Mod(tplPos, 20) = 0)
            ToolTip, Applying item %tplPos%/%tplCount%...

        ; Dismiss popups periodically
        if (Mod(totalApplied, 15) = 0)
            NB_DismissIntermediatePopups()
    }

    Hotkey, ~RButton, NB_CancelApplyHotkey, Off

    NB_DismissIntermediatePopups()

    ; Log every checkbox state after apply
    if (NB_DebugLogging) {
        WinGetTitle, applyDlgTitle, ahk_id %dlgHwnd%
        allGroupBoxes := NB_EnumScrollBoxGroupBoxes(scrollBox)
        NB__LogCheckboxStates("APPLY", allGroupBoxes, templatePath, applyDlgTitle, totalApplied, totalNotFound)
    }

    ToolTip, Done: %totalApplied% toggled - %totalNotFound% not found. Review before Finish.
    SetTimer, NB_ClearToolTip, -5000

    ; Resume timers
    SetTimer, NB_CheckCPRS, 3000
    SetTimer, NB_CheckGui14Dropdown, 2000

    ; Re-assert AlwaysOnTop on the panel — WinActivate on CPRS dialog strips it
    if (NB_BoosterGuiVisible = 1)
        WinSet, AlwaysOnTop, On, ahk_id %NB_PanelHwnd%
}

NB_CancelApplyHotkey:
    NB_ApplyCancelled := true
return


;============================================================================================
; NURSING BOOSTER - CHECKBOX STATE LOGGING
;============================================================================================

NB__LogCheckboxStates(action, groupBoxHwnds, templateNameOrPath := "", dialogTitle := "", statA := 0, statB := 0) {
    global NB_LogDir
    FormatTime, nowStamp,, yyyyMMddHHmmss
    FormatTime, nowDisp,, yyyy-MM-dd HH:mm:ss
    logPath := NB_LogDir . "\" . action . "_" . nowStamp . ".txt"
    FileDelete, %logPath%

    groupCount := groupBoxHwnds.Length()

    ; --- Header with summary info ---
    logText := "============================================================`n"
    logText .= "  NURSING BOOSTER " . action . " LOG`n"
    logText .= "============================================================`n"
    logText .= "Timestamp:    " . nowDisp . "`n"
    logText .= "Action:       " . action . "`n"
    logText .= "Template:     " . templateNameOrPath . "`n"
    logText .= "Dialog:       " . dialogTitle . "`n"
    logText .= "User:         " . A_UserName . "`n"
    logText .= "Groups found: " . groupCount . "`n"
    if (action = "SAVE")
        logText .= "Checked/Total: " . statA . "/" . statB . "`n"
    else if (action = "APPLY")
        logText .= "Toggled: " . statA . "  |  Not found: " . statB . "`n"
    logText .= "============================================================`n`n"
    FileAppend, %logText%, %logPath%, UTF-8

    ; --- Per-group checkbox detail ---
    totalCBs := 0
    totalChecked := 0
    for gi, gbHwnd in groupBoxHwnds {
        descendants := NB_EnumDescendantCheckboxes(gbHwnd)
        descCount := descendants.Length()
        groupLine := "--- Group " . gi . "/" . groupCount . " (" . descCount . " checkboxes) ---`n"
        FileAppend, %groupLine%, %logPath%, UTF-8
        for ci, cb in descendants {
            state := cb.checked ? "[X]" : "[ ]"
            cls := cb.className = "TCPRSDialogParentCheckBox" ? "PARENT" : "LEAF  "
            lbl := cb.label != "" ? cb.label : "(unlabeled)"
            cbLine := "  " . state . " depth=" . cb.depth . " " . cls . " " . lbl . "`n"
            FileAppend, %cbLine%, %logPath%, UTF-8
            totalCBs++
            if (cb.checked)
                totalChecked++
        }
        FileAppend, `n, %logPath%, UTF-8
    }

    ; --- Footer summary ---
    footerText := "============================================================`n"
    footerText .= "TOTALS: " . totalChecked . " checked out of " . totalCBs . " checkboxes in " . groupCount . " groups`n"
    footerText .= "============================================================`n"
    FileAppend, %footerText%, %logPath%, UTF-8
}


;============================================================================================
; NURSING BOOSTER - GROUP FINGERPRINTING
;============================================================================================

NB__GroupFingerprint(items) {
    labels := []
    depthCounts := {}
    for k, item in items {
        lbl := item.HasKey("label") ? item.label : ""
        if (lbl != "")
            labels.Push(lbl)
        d := item.HasKey("depth") ? item.depth : 0
        if (!depthCounts.HasKey(d))
            depthCounts[d] := 0
        depthCounts[d] := depthCounts[d] + 1
    }
    ; Sort labels alphabetically (insertion sort)
    if (labels.Length() > 1) {
        Loop, % labels.Length() - 1
        {
            i := A_Index + 1
            key := labels[i]
            j := i - 1
            while (j >= 1 && labels[j] > key) {
                labels[j + 1] := labels[j]
                j--
            }
            labels[j + 1] := key
        }
    }
    ; Sort depth keys
    depthKeys := []
    for k in depthCounts
        depthKeys.Push(k)
    if (depthKeys.Length() > 1) {
        Loop, % depthKeys.Length() - 1
        {
            i := A_Index + 1
            key := depthKeys[i]
            j := i - 1
            while (j >= 1 && depthKeys[j] > key) {
                depthKeys[j + 1] := depthKeys[j]
                j--
            }
            depthKeys[j + 1] := key
        }
    }
    fp := items.Length() . "|"
    for k, lbl in labels
        fp .= lbl . ","
    fp .= "|"
    for k, dk in depthKeys
        fp .= dk . ":" . depthCounts[dk] . ","
    return fp
}


;============================================================================================
; NURSING BOOSTER - CHECKBOX ENUMERATION
;============================================================================================

; Enumerate all TGroupBox direct children of the scrollbox, sorted by screen Y position
NB_EnumScrollBoxGroupBoxes(scrollBoxHwnd) {
    raw := []
    child := DllCall("GetWindow", "Ptr", scrollBoxHwnd, "UInt", 5, "Ptr")  ; GW_CHILD
    while (child) {
        VarSetCapacity(buf, 256, 0)
        DllCall("GetClassName", "Ptr", child, "Str", buf, "Int", 256)
        if (buf = "TGroupBox") {
            VarSetCapacity(rect, 16, 0)
            DllCall("GetWindowRect", "Ptr", child, "Ptr", &rect)
            y := NumGet(rect, 4, "Int")
            raw.Push({hwnd: child, y: y})
        }
        child := DllCall("GetWindow", "Ptr", child, "UInt", 2, "Ptr")  ; GW_HWNDNEXT
    }
    ; Sort by Y position (insertion sort)
    if (raw.Length() > 1) {
        Loop, % raw.Length() - 1
        {
            i := A_Index + 1
            key := raw[i]
            j := i - 1
            while (j >= 1 && raw[j].y > key.y) {
                raw[j + 1] := raw[j]
                j--
            }
            raw[j + 1] := key
        }
    }
    ; Return HWNDs in visual order
    sorted := []
    for k, item in raw
        sorted.Push(item.hwnd)
    return sorted
}

; Enumerate ALL descendant checkboxes within a container
NB_EnumDescendantCheckboxes(containerHwnd) {
    global NB__descCBResults, NB__descContainer
    NB__descCBResults := []
    NB__descContainer := containerHwnd
    enumCB := RegisterCallback("NB__EnumDescCBCallback", "Fast")
    DllCall("EnumChildWindows", "Ptr", containerHwnd, "Ptr", enumCB, "Ptr", 0)

    ; Compute nesting depth for each checkbox
    for k, item in NB__descCBResults {
        depth := 0
        p := DllCall("GetParent", "Ptr", item.hwnd, "Ptr")
        while (p && p != containerHwnd) {
            VarSetCapacity(pBuf, 256, 0)
            DllCall("GetClassName", "Ptr", p, "Str", pBuf, "Int", 256)
            if (pBuf = "TGroupBox")
                depth++
            p := DllCall("GetParent", "Ptr", p, "Ptr")
        }
        item.depth := depth
    }

    ; Resolve parent checkbox labels via sibling TDlgFieldPanel + MSAA
    for k, item in NB__descCBResults {
        if (item.label = "" && item.className = "TCPRSDialogParentCheckBox") {
            item.label := NB_ResolveParentCBLabel(item.hwnd)
        }
    }

    ; Sort by screen Y position (with X tiebreaker)
    results := NB__descCBResults
    if (results.Length() > 1) {
        Loop, % results.Length() - 1
        {
            i := A_Index + 1
            key := results[i]
            j := i - 1
            while (j >= 1 && (results[j].y > key.y || (results[j].y = key.y && results[j].x > key.x))) {
                results[j + 1] := results[j]
                j--
            }
            results[j + 1] := key
        }
    }

    return results
}

NB__EnumDescCBCallback(hwnd, lParam) {
    global NB__descCBResults
    VarSetCapacity(buf, 256, 0)
    DllCall("GetClassName", "Ptr", hwnd, "Str", buf, "Int", 256)
    if !(buf = "TCPRSDialogParentCheckBox" || buf = "TCPRSDialogCheckBox" || buf = "TORCheckBox")
        return 1

    SendMessage, 0x00F0, 0, 0,, ahk_id %hwnd%
    checked := ErrorLevel ? true : false

    ; Get screen position for Y-sorting
    VarSetCapacity(rect, 16, 0)
    DllCall("GetWindowRect", "Ptr", hwnd, "Ptr", &rect)
    y := NumGet(rect, 4, "Int")
    x := NumGet(rect, 0, "Int")

    ; Read label via simple DllCalls only (this is a Fast callback - no COM allowed)
    label := ""
    tLen := DllCall("GetWindowTextLengthW", "Ptr", hwnd, "Int")
    if (tLen > 0) {
        VarSetCapacity(tBuf, (tLen + 1) * 2, 0)
        DllCall("GetWindowTextW", "Ptr", hwnd, "Ptr", &tBuf, "Int", tLen + 1)
        label := Trim(StrGet(&tBuf, "UTF-16"))
    }

    NB__descCBResults.Push({hwnd: hwnd, className: buf, checked: checked, label: label, y: y, x: x})
    return 1
}

; Lightweight count-only enumeration for stability checks
NB_FindAllCheckboxes(dlgHwnd) {
    global NB__findCBResults
    NB__findCBResults := []
    enumCB := RegisterCallback("NB__EnumCBCallback", "Fast")
    DllCall("EnumChildWindows", "Ptr", dlgHwnd, "Ptr", enumCB, "Ptr", 0)
    return NB__findCBResults
}

NB__EnumCBCallback(hwnd, lParam) {
    global NB__findCBResults
    VarSetCapacity(buf, 256, 0)
    DllCall("GetClassName", "Ptr", hwnd, "Str", buf, "Int", 256)
    if !(buf = "TORCheckBox" || buf = "TCPRSDialogParentCheckBox" || buf = "TCPRSDialogCheckBox")
        return 1
    NB__findCBResults.Push({hwnd: hwnd, className: buf})
    return 1
}

; Wait until checkbox count stops changing
NB_WaitForStableCheckboxCount(dlgHwnd) {
    prevCount := 0
    stableRounds := 0
    Loop, 20
    {
        cbs := NB_FindAllCheckboxes(dlgHwnd)
        count := cbs.Length()
        if (count > 0 && count = prevCount) {
            stableRounds++
            if (stableRounds >= 3)
                return count
        } else {
            stableRounds := 0
        }
        prevCount := count
        Sleep, 500
    }
    return prevCount
}


;============================================================================================
; NURSING BOOSTER - DISMISS INTERMEDIATE POPUPS
;============================================================================================

NB_DismissIntermediatePopups() {
    Sleep, 150
    Loop, 3
    {
        found := false
        WinGet, wndList, List, ahk_exe CPRSChart.exe
        Loop, %wndList%
        {
            wnd := wndList%A_Index%
            WinGetClass, cls, ahk_id %wnd%
            if (cls = "TfrmRemDlg" || cls = "TCPRSChart" || cls = "TfrmFrame" || cls = "TfrmTemplateDialog")
                continue
            WinGetPos,,, w, h, ahk_id %wnd%
            if (w > 500 || h > 400)
                continue
            if (NB_HasDangerousButton(wnd))
                continue
            okHwnd := NB_FindOKButton(wnd)
            if (okHwnd) {
                PostMessage, 0x00F5, 0, 0,, ahk_id %okHwnd%
                Sleep, 200
                found := true
            }
        }
        if (!found)
            break
    }
}

NB_HasDangerousButton(windowHwnd) {
    global NB__hasDangerous
    NB__hasDangerous := false
    enumDangerous := RegisterCallback("NB__CheckDangerousCallback", "Fast")
    DllCall("EnumChildWindows", "Ptr", windowHwnd, "Ptr", enumDangerous, "Ptr", 0)
    return NB__hasDangerous
}

NB__CheckDangerousCallback(hwnd, lParam) {
    global NB__hasDangerous
    VarSetCapacity(buf, 256, 0)
    DllCall("GetClassName", "Ptr", hwnd, "Str", buf, "Int", 256)
    if (InStr(buf, "TEdit") || InStr(buf, "TMemo") || InStr(buf, "TRichEdit")) {
        NB__hasDangerous := true
        return 0
    }
    if (InStr(buf, "TButton") || InStr(buf, "TBitBtn")) {
        SendMessage, 0x000E, 0, 0,, ahk_id %hwnd%
        tLen := ErrorLevel
        if (tLen > 0) {
            VarSetCapacity(textBuf, (tLen + 1) * 2, 0)
            SendMessage, 0x000D, tLen + 1, &textBuf,, ahk_id %hwnd%
            textStr := StrGet(&textBuf)
            StringUpper, textUpper, textStr
            if (InStr(textUpper, "FINISH") || InStr(textUpper, "SUBMIT")
                || InStr(textUpper, "SIGN") || InStr(textUpper, "FILE")
                || InStr(textUpper, "COMPLETE") || InStr(textUpper, "SAVE")
                || InStr(textUpper, "DELETE") || InStr(textUpper, "REMOVE")) {
                NB__hasDangerous := true
                return 0
            }
        }
    }
    return 1
}

NB_FindOKButton(windowHwnd) {
    global NB__foundOKHwnd
    NB__foundOKHwnd := 0
    enumOK := RegisterCallback("NB__FindOKCallback", "Fast")
    DllCall("EnumChildWindows", "Ptr", windowHwnd, "Ptr", enumOK, "Ptr", 0)
    return NB__foundOKHwnd
}

NB__FindOKCallback(hwnd, lParam) {
    global NB__foundOKHwnd
    VarSetCapacity(buf, 256, 0)
    DllCall("GetClassName", "Ptr", hwnd, "Str", buf, "Int", 256)
    if !(InStr(buf, "TButton") || InStr(buf, "TBitBtn"))
        return 1
    SendMessage, 0x000E, 0, 0,, ahk_id %hwnd%
    tLen := ErrorLevel
    if (tLen > 0) {
        VarSetCapacity(textBuf, (tLen + 1) * 2, 0)
        SendMessage, 0x000D, tLen + 1, &textBuf,, ahk_id %hwnd%
        textStr := StrGet(&textBuf)
        StringUpper, textUpper, textStr
        if (textUpper = "OK" || textUpper = "&OK" || textUpper = "CONTINUE"
            || textUpper = "&CONTINUE" || textUpper = "YES" || textUpper = "&YES") {
            NB__foundOKHwnd := hwnd
            return 0
        }
    }
    return 1
}


;============================================================================================
; NURSING BOOSTER - LOAD / DELETE TEMPLATE
;============================================================================================

NB_BtnLoadSavedTemplate:
    dlgHwnd := NB_FindActiveDialogWindow()
    if (!dlgHwnd) {
        MsgBox, 48, %NB_AppTitle%, Open a template or reminder dialogue in CPRS first then load a template.
        return
    }
    NB_templates := []
    Loop, Files, %NB_TemplateDir%\*.json
    {
        NB_templates.Push(A_LoopFileFullPath)
    }
    if (NB_templates.Length() = 0) {
        MsgBox, 64, %NB_AppTitle%, No saved templates found.`n`nTo create one:`n1. Open a reminder dialogue in CPRS`n2. Check the boxes the way you want`n3. Select 'Save Template' from the Nursing Booster dropdown
        return
    }

    ; Build a list of template names
    NB_loadList := ""
    for k, path in NB_templates {
        RegExMatch(path, ".*\\(.*)\.json$", match)
        NB_loadList .= (NB_loadList != "" ? "|" : "") . match1
    }

    Gui, 81:Destroy
    Gui, 81:+AlwaysOnTop +ToolWindow
    Gui, 81:Font, s9, Segoe UI
    Gui, 81:Add, Text,, Select a template to apply:
    Gui, 81:Add, ListBox, w300 h200 vNB_LoadSelection, %NB_loadList%
    Gui, 81:Add, Button, y+5 w120 gNB_DoLoadTemplate Default, Apply
    Gui, 81:Add, Button, x+5 w120 gNB_CancelLoad, Cancel
    Gui, 81:Show,, Load Nursing Template
return

NB_DoLoadTemplate:
    Gui, 81:Submit
    if (NB_LoadSelection = "") {
        MsgBox, 48, %NB_AppTitle%, Select a template.
        return
    }
    Gui, 81:Destroy
    templatePath := NB_TemplateDir . "\" . NB_SanitizeFilename(NB_LoadSelection) . ".json"
    if (FileExist(templatePath)) {
        dlgWnd := NB_FindActiveDialogWindow()
        if (dlgWnd) {
            WinActivate, ahk_id %dlgWnd%
            Sleep, 200
            NB_ApplyTemplate(templatePath)
        }
    }
return

NB_CancelLoad:
    Gui, 81:Destroy
return


NB_BtnDeleteTemplate:
    NB_delTemplates := []
    Loop, Files, %NB_TemplateDir%\*.json
    {
        NB_delTemplates.Push(A_LoopFileName)
    }
    if (NB_delTemplates.Length() = 0) {
        MsgBox, 64, %NB_AppTitle%, No saved templates to delete.
        return
    }
    list := ""
    for i, f in NB_delTemplates
        list .= i . ": " . StrReplace(f, ".json", "") . "`n"
    InputBox, deleteIdx, Delete Template, Enter the number of the template to delete:`n`n%list%,, 300, 400
    if (ErrorLevel || deleteIdx = "")
        return
    if deleteIdx is not integer
    {
        MsgBox, 48, %NB_AppTitle%, Enter a number.
        return
    }
    if (deleteIdx < 1 || deleteIdx > NB_delTemplates.Length()) {
        MsgBox, 48, %NB_AppTitle%, Invalid selection.
        return
    }
    delName := StrReplace(NB_delTemplates[deleteIdx], ".json", "")
    MsgBox, 36, %NB_AppTitle%, Delete template "%delName%"?
    IfMsgBox, Yes
    {
        delPath := NB_TemplateDir . "\" . NB_delTemplates[deleteIdx]
        FileDelete, %delPath%
        ToolTip, Template "%delName%" deleted
        SetTimer, NB_ClearToolTip, -2000
    }
return


;============================================================================================
; NURSING BOOSTER - TOP-LEVEL PARENT DISCOVERY
;============================================================================================

NB_FindVisibleScrollBox(dlgHwnd) {
    child := DllCall("GetWindow", "Ptr", dlgHwnd, "UInt", 5, "Ptr")
    while (child) {
        VarSetCapacity(buf, 256, 0)
        DllCall("GetClassName", "Ptr", child, "Str", buf, "Int", 256)
        if (buf = "TScrollBox") {
            style := DllCall("GetWindowLong", "Ptr", child, "Int", -16, "Int")
            if (style & 0x10000000)
                return child
        }
        child := DllCall("GetWindow", "Ptr", child, "UInt", 2, "Ptr")
    }
    return 0
}

NB_EnumTopLevelParents(scrollBoxHwnd) {
    parents := []
    seenDirectParent := false
    child := DllCall("GetWindow", "Ptr", scrollBoxHwnd, "UInt", 5, "Ptr")
    while (child) {
        VarSetCapacity(buf, 256, 0)
        DllCall("GetClassName", "Ptr", child, "Str", buf, "Int", 256)
        if (buf = "TCPRSDialogParentCheckBox") {
            seenDirectParent := true
            SendMessage, 0x00F0, 0, 0,, ahk_id %child%
            checked := ErrorLevel ? true : false
            parents.Push({hwnd: child, checked: checked})
        } else if (buf = "TGroupBox" && seenDirectParent) {
            gbChild := DllCall("GetWindow", "Ptr", child, "UInt", 5, "Ptr")
            while (gbChild) {
                VarSetCapacity(gbBuf, 256, 0)
                DllCall("GetClassName", "Ptr", gbChild, "Str", gbBuf, "Int", 256)
                if (gbBuf = "TCPRSDialogParentCheckBox") {
                    SendMessage, 0x00F0, 0, 0,, ahk_id %gbChild%
                    checked := ErrorLevel ? true : false
                    parents.Push({hwnd: gbChild, checked: checked})
                }
                gbChild := DllCall("GetWindow", "Ptr", gbChild, "UInt", 2, "Ptr")
            }
        }
        child := DllCall("GetWindow", "Ptr", child, "UInt", 2, "Ptr")
    }
    return parents
}


;============================================================================================
; NURSING BOOSTER - TEMPLATE PARSING
;============================================================================================

NB_ParseFlatCheckboxes(jsonContent) {
    items := []

    ; Find the "checkboxes" array (top-level, format v7)
    cPos := InStr(jsonContent, """checkboxes""")
    if (!cPos)
        return items

    arrStart := InStr(jsonContent, "[",, cPos)
    if (!arrStart)
        return items

    ; Find matching ]
    depth := 1
    scanPos := arrStart + 1
    arrEnd := 0
    while (scanPos <= StrLen(jsonContent) && depth > 0) {
        ch := SubStr(jsonContent, scanPos, 1)
        if (ch = "[")
            depth++
        else if (ch = "]")
            depth--
        if (depth = 0)
            arrEnd := scanPos
        scanPos++
    }
    if (!arrEnd)
        return items

    ; Parse each checkbox object
    itemPos := arrStart
    while (itemPos := InStr(jsonContent, "{",, itemPos + 1)) {
        if (itemPos > arrEnd)
            break
        itemEnd := InStr(jsonContent, "}",, itemPos)
        if (!itemEnd)
            break
        itemStr := SubStr(jsonContent, itemPos, itemEnd - itemPos + 1)

        idx := 0
        if (RegExMatch(itemStr, """idx"":\s*(\d+)", idxM))
            idx := idxM1 + 0

        cls := ""
        if (RegExMatch(itemStr, """cls"":\s*""([^""]*)""", clsM))
            cls := clsM1

        checked := (InStr(itemStr, """checked"": true") || InStr(itemStr, """checked"":true"))
            ? true : false

        depthVal := 0
        if (RegExMatch(itemStr, """depth"":\s*(\d+)", depM))
            depthVal := depM1 + 0

        label := ""
        if (RegExMatch(itemStr, """label"":\s*""((?:[^""\\]|\\.)*)""", lblM))
            label := lblM1

        items.Push({idx: idx, cls: cls, checked: checked, label: label, depth: depthVal})
        itemPos := itemEnd
    }

    return items
}

NB_ParseTopLevelParents(jsonContent) {
    states := []
    pos := InStr(jsonContent, """topLevelParents""")
    if (!pos)
        return states
    arrStart := InStr(jsonContent, "[",, pos)
    arrEnd := InStr(jsonContent, "]",, arrStart)
    if (!arrStart || !arrEnd)
        return states
    arrStr := SubStr(jsonContent, arrStart + 1, arrEnd - arrStart - 1)
    searchPos := 1
    while (searchPos <= StrLen(arrStr)) {
        chunk := SubStr(arrStr, searchPos, 6)
        if (SubStr(chunk, 1, 4) = "true") {
            states.Push(true)
            searchPos += 4
        } else if (SubStr(chunk, 1, 5) = "false") {
            states.Push(false)
            searchPos += 5
        } else {
            searchPos++
        }
    }
    return states
}

; ---------------------------------------------------------------------------
; TEMPLATE SPEED HELPERS (per-template speed settings)
; ---------------------------------------------------------------------------

NB_RefreshSettingsTplList() {
    global NB_TemplateDir, CF_TemplateDir, NB_SettingsTplPathMap
    list := ""
    NB_SettingsTplPathMap := {}

    ; NB templates
    Loop, Files, %NB_TemplateDir%\*.json
    {
        name := RegExReplace(A_LoopFileName, "\.json$", "")
        displayName := name . " [NB]"
        if (list != "")
            list .= "|"
        list .= displayName
        NB_SettingsTplPathMap[displayName] := NB_TemplateDir . "\" . A_LoopFileName
    }

    ; CPFS templates
    Loop, Files, %CF_TemplateDir%\*.json
    {
        ; Skip spy dump files
        if (InStr(A_LoopFileName, "cpfs_spy_"))
            continue
        name := RegExReplace(A_LoopFileName, "\.json$", "")
        displayName := name . " [CF]"
        if (list != "")
            list .= "|"
        list .= displayName
        NB_SettingsTplPathMap[displayName] := CF_TemplateDir . "\" . A_LoopFileName
    }

    GuiControl, 84:, NB_SettingsTplDDL, |%list%
}

NB_ReadTemplateSpeed(filePath) {
    FileRead, content, %filePath%
    if (ErrorLevel)
        return 600
    if (RegExMatch(content, """speed"":\s*(\d+)", spdM))
        return spdM1 + 0
    return 600
}

NB_WriteTemplateSpeed(filePath, speed) {
    FileRead, content, %filePath%
    if (ErrorLevel)
        return false
    if (RegExMatch(content, """speed"":\s*\d+")) {
        content := RegExReplace(content, """speed"":\s*\d+", """speed"": " . speed)
    } else {
        ; Add speed field after "format" line
        content := RegExReplace(content, "(""format"":\s*\d+),", "$1,`n  ""speed"": " . speed . ",")
    }
    f := FileOpen(filePath, "w", "UTF-8")
    if (!f)
        return false
    f.Write(content)
    f.Close()
    return true
}

NB_ReadTemplateLeafSpeed(filePath) {
    FileRead, content, %filePath%
    if (ErrorLevel)
        return 50
    if (RegExMatch(content, """leaf_speed"":\s*(\d+)", spdM))
        return spdM1 + 0
    return 50
}

NB_WriteTemplateLeafSpeed(filePath, speed) {
    FileRead, content, %filePath%
    if (ErrorLevel)
        return false
    if (RegExMatch(content, """leaf_speed"":\s*\d+")) {
        content := RegExReplace(content, """leaf_speed"":\s*\d+", """leaf_speed"": " . speed)
    } else {
        ; Add leaf_speed after "speed" line
        if (RegExMatch(content, """speed"":\s*\d+")) {
            content := RegExReplace(content, "(""speed"":\s*\d+),", "$1,`n  ""leaf_speed"": " . speed . ",")
        } else {
            content := RegExReplace(content, "(""format"":\s*\d+),", "$1,`n  ""leaf_speed"": " . speed . ",")
        }
    }
    f := FileOpen(filePath, "w", "UTF-8")
    if (!f)
        return false
    f.Write(content)
    f.Close()
    return true
}

; Parse groups array from format-3 JSON
NB_ParseGroups(jsonContent) {
    groups := []

    gPos := InStr(jsonContent, """groups""")
    if (!gPos)
        return groups

    gArrStart := InStr(jsonContent, "[",, gPos)
    if (!gArrStart)
        return groups

    ; Find matching ] using depth counting
    depth := 1
    scanPos := gArrStart + 1
    gArrEnd := 0
    while (scanPos <= StrLen(jsonContent) && depth > 0) {
        ch := SubStr(jsonContent, scanPos, 1)
        if (ch = "[")
            depth++
        else if (ch = "]")
            depth--
        if (depth = 0)
            gArrEnd := scanPos
        scanPos++
    }
    if (!gArrEnd)
        return groups

    ; Find each group object
    searchPos := gArrStart
    while (true) {
        cbPos := InStr(jsonContent, """checkboxes""",, searchPos + 1)
        if (!cbPos || cbPos > gArrEnd)
            break

        cbArrStart := InStr(jsonContent, "[",, cbPos)
        if (!cbArrStart || cbArrStart > gArrEnd)
            break

        ; Find matching ]
        cbDepth := 1
        cbScan := cbArrStart + 1
        cbArrEnd := 0
        while (cbScan <= StrLen(jsonContent) && cbDepth > 0) {
            c := SubStr(jsonContent, cbScan, 1)
            if (c = "[")
                cbDepth++
            else if (c = "]")
                cbDepth--
            if (cbDepth = 0)
                cbArrEnd := cbScan
            cbScan++
        }
        if (!cbArrEnd)
            break

        ; Parse checkbox items within this group
        groupItems := []
        itemPos := cbArrStart
        while (itemPos := InStr(jsonContent, "{",, itemPos + 1)) {
            if (itemPos > cbArrEnd)
                break
            itemEnd := InStr(jsonContent, "}",, itemPos)
            if (!itemEnd)
                break
            itemStr := SubStr(jsonContent, itemPos, itemEnd - itemPos + 1)

            idx := 0
            if (RegExMatch(itemStr, """idx"":\s*(\d+)", idxM))
                idx := idxM1 + 0

            cls := ""
            if (RegExMatch(itemStr, """cls"":\s*""([^""]*)""", clsM))
                cls := clsM1

            checked := (InStr(itemStr, """checked"": true") || InStr(itemStr, """checked"":true"))
                ? true : false

            depthVal := 0
            if (RegExMatch(itemStr, """depth"":\s*(\d+)", depM))
                depthVal := depM1 + 0

            label := ""
            if (RegExMatch(itemStr, """label"":\s*""((?:[^""\\]|\\.)*)""", lblM))
                label := lblM1

            groupItems.Push({idx: idx, cls: cls, checked: checked, label: label, depth: depthVal})
            itemPos := itemEnd
        }

        groups.Push(groupItems)
        searchPos := cbArrEnd
    }

    return groups
}


;============================================================================================
; NURSING BOOSTER - DIALOG DUMP (Debug tool)
; Triggered from Nursing Booster dropdown or Ctrl+Shift+D
;============================================================================================

NB_DumpDialogControls:
    dlgHwnd := NB_FindActiveDialogWindow()
    if (!dlgHwnd) {
        MsgBox, 48, %NB_AppTitle%, Open a reminder dialogue in CPRS first.
        return
    }
    FormatTime, nowStamp,, yyyyMMddHHmmss
    dumpPath := NB_LogDir . "\dialog_dump_" . nowStamp . ".txt"
    FileDelete, %dumpPath%
    FormatTime, nowDisp,, yyyy-MM-dd HH:mm:ss
    WinGetTitle, dlgTitle, ahk_id %dlgHwnd%
    WinGetClass, dlgClass, ahk_id %dlgHwnd%
    dumpHeader := "=== CPRS Dialog Control Dump ===`n"
    dumpHeader .= "Time: " . nowDisp . "`n"
    dumpHeader .= "Dialog Title: " . dlgTitle . "`n"
    dumpHeader .= "Dialog Class: " . dlgClass . "`n"
    dumpHeader .= "Dialog HWND: " . dlgHwnd . "`n`n"
    FileAppend, %dumpHeader%, %dumpPath%, UTF-8

    global NB__dumpPath := dumpPath
    global NB__dumpDlgHwnd := dlgHwnd
    global NB__dumpCount := 0
    global NB__dumpCBCount := 0
    global NB__dumpParentCBs := []

    enumDump := RegisterCallback("NB__DumpCallback", "Fast")
    DllCall("EnumChildWindows", "Ptr", dlgHwnd, "Ptr", enumDump, "Ptr", 0)

    ; Post-process: resolve parent checkbox labels via sibling TDlgFieldPanel
    ; NOTE: CPRS renders parent CB labels using non-windowed TLabel (TGraphicControl)
    ; when no screen reader is active. These have no HWND and are invisible to all
    ; Windows APIs (Win32, MSAA, UI Automation). Labels may show as "(not accessible)".
    if (NB__dumpParentCBs.Length() > 0) {
        parentSection := "`n=== Parent Checkboxes ===`n"
        parentSection .= "(Parent CB labels use non-windowed TLabel - may not be readable)`n"
        for i, pcb in NB__dumpParentCBs {
            label := NB_ResolveParentCBLabel(pcb.hwnd)
            if (label = "")
                label := "(not accessible)"
            chk := pcb.checked ? "YES" : "NO"
            parentSection .= "  CHECKED=" . chk . " label='" . label . "'`n"
        }
        FileAppend, %parentSection%, %dumpPath%, UTF-8
    }

    dumpFooter := "`n=== Summary ===`nTotal controls: " . NB__dumpCount . "`nCheckboxes: " . NB__dumpCBCount . "`n"
    FileAppend, %dumpFooter%, %dumpPath%, UTF-8

    MsgBox, 64, %NB_AppTitle%, Dump written to:`n%dumpPath%`n`n%NB__dumpCount% controls and %NB__dumpCBCount% checkboxes.
return

NB__DumpCallback(hwnd, lParam) {
    global NB__dumpPath, NB__dumpDlgHwnd, NB__dumpCount, NB__dumpCBCount, NB__dumpParentCBs
    NB__dumpCount++

    VarSetCapacity(buf, 256, 0)
    DllCall("GetClassName", "Ptr", hwnd, "Str", buf, "Int", 256)
    className := buf

    ; Simple text retrieval only (this is a Fast callback - no COM allowed)
    text := ""
    tLen := DllCall("GetWindowTextLengthW", "Ptr", hwnd, "Int")
    if (tLen > 0) {
        VarSetCapacity(tBuf, (tLen + 1) * 2, 0)
        DllCall("GetWindowTextW", "Ptr", hwnd, "Ptr", &tBuf, "Int", tLen + 1)
        text := Trim(StrGet(&tBuf, "UTF-16"))
    }

    depth := 0
    p := hwnd
    Loop {
        p := DllCall("GetParent", "Ptr", p, "Ptr")
        if (!p || p = NB__dumpDlgHwnd)
            break
        depth++
    }

    parentHwnd := DllCall("GetParent", "Ptr", hwnd, "Ptr")
    parentClass := "none"
    if (parentHwnd) {
        VarSetCapacity(parentBuf, 256, 0)
        DllCall("GetClassName", "Ptr", parentHwnd, "Str", parentBuf, "Int", 256)
        parentClass := parentBuf
    }

    extra := ""
    if (className = "TORCheckBox" || className = "TCPRSDialogParentCheckBox" || className = "TCPRSDialogCheckBox") {
        SendMessage, 0x00F0, 0, 0,, ahk_id %hwnd%
        checked := ErrorLevel
        extra := " CHECKED=" . (checked ? "YES" : "NO")
        NB__dumpCBCount++
        ; Track parent checkboxes for post-processing label lookup
        if (className = "TCPRSDialogParentCheckBox")
            NB__dumpParentCBs.Push({hwnd: hwnd, checked: checked})
    }

    style := DllCall("GetWindowLong", "Ptr", hwnd, "Int", -16, "Int")
    visible := (style & 0x10000000) ? "Y" : "N"

    indent := ""
    Loop, %depth%
        indent .= "  "

    line := indent . className . " hwnd=" . hwnd . " text='" . text . "' vis=" . visible . " parent=" . parentClass . extra . "`n"
    FileAppend, %line%, %NB__dumpPath%, UTF-8
    return 1
}


;============================================================================================
; NURSING BOOSTER - UTILITY FUNCTIONS
;============================================================================================

NB_ClearToolTip:
    ToolTip
return

NB_SanitizeFilename(name) {
    result := RegExReplace(Trim(name), "[<>:""/\\|?*]", "_")
    return result
}

; Extract version string from TRichEdit controls in a CPRS reminder dialog.
; Scans ControlList for RichEdit controls, reads their text, and looks for
; "Version X.Y" pattern. Returns the version number (e.g. "2.2") or "" if
; no version found. Only checks the first matching control.
NB_GetDialogVersion(dlgHwnd) {
    WinGet, ctrlList, ControlList, ahk_id %dlgHwnd%
    Loop, Parse, ctrlList, `n
    {
        if (InStr(A_LoopField, "RichEdit")) {
            ControlGetText, richText, %A_LoopField%, ahk_id %dlgHwnd%
            if (RegExMatch(richText, "i)Version\s+(\d+(?:\.\d+)*)", vM))
                return vM1
        }
    }
    return ""
}

NB_EscJson(str) {
    str := StrReplace(str, "\", "\\")
    str := StrReplace(str, """", "\""")
    str := StrReplace(str, "`n", "\n")
    str := StrReplace(str, "`r", "\r")
    str := StrReplace(str, "`t", "\t")
    return """" . str . """"
}

; Attempt to resolve parent checkbox label. CPRS sets parent CB Caption to ' '
; and renders the text via a non-windowed TLabel (TGraphicControl) inside a
; sibling TDlgFieldPanel. Without a screen reader (JAWS), TLabel has no HWND
; and is invisible to Win32, MSAA, and UI Automation APIs.
; This function tries GetWindowText on the sibling panel and its windowed
; children as a best-effort attempt. Returns "" if unresolvable.
NB_ResolveParentCBLabel(cbHwnd) {
    static junkNames := "|system|application|pane|check box|"
    if !DllCall("IsWindow", "Ptr", cbHwnd, "Int")
        return ""
    cbParent := DllCall("GetParent", "Ptr", cbHwnd, "Ptr")
    if (!cbParent)
        return ""
    ; Get checkbox screen Y position
    VarSetCapacity(cbRect, 16, 0)
    DllCall("GetWindowRect", "Ptr", cbHwnd, "Ptr", &cbRect)
    cbY := NumGet(cbRect, 4, "Int")
    ; Find the nearest sibling TDlgFieldPanel by Y position
    bestPanel := 0
    bestDist := 999999
    child := DllCall("GetWindow", "Ptr", cbParent, "UInt", 5, "Ptr")  ; GW_CHILD
    while (child) {
        VarSetCapacity(clsBuf, 256, 0)
        DllCall("GetClassName", "Ptr", child, "Str", clsBuf, "Int", 256)
        if (clsBuf = "TDlgFieldPanel") {
            VarSetCapacity(pRect, 16, 0)
            DllCall("GetWindowRect", "Ptr", child, "Ptr", &pRect)
            pY := NumGet(pRect, 4, "Int")
            dist := Abs(pY - cbY)
            if (dist < bestDist) {
                bestPanel := child
                bestDist := dist
            }
        }
        child := DllCall("GetWindow", "Ptr", child, "UInt", 2, "Ptr")  ; GW_HWNDNEXT
    }
    if (!bestPanel || bestDist > 100)
        return ""
    ; Try GetWindowText on the panel itself
    text := ""
    tLen := DllCall("GetWindowTextLengthW", "Ptr", bestPanel, "Int")
    if (tLen > 0) {
        VarSetCapacity(tBuf, (tLen + 1) * 2, 0)
        DllCall("GetWindowTextW", "Ptr", bestPanel, "Ptr", &tBuf, "Int", tLen + 1)
        text := Trim(StrGet(&tBuf, "UTF-16"))
    }
    if (text != "" && !InStr(junkNames, "|" . text . "|"))
        return text
    ; Try GetWindowText on windowed children of the panel
    panelChild := DllCall("GetWindow", "Ptr", bestPanel, "UInt", 5, "Ptr")
    while (panelChild) {
        pcLen := DllCall("GetWindowTextLengthW", "Ptr", panelChild, "Int")
        if (pcLen > 0) {
            VarSetCapacity(pcBuf, (pcLen + 1) * 2, 0)
            DllCall("GetWindowTextW", "Ptr", panelChild, "Ptr", &pcBuf, "Int", pcLen + 1)
            text := Trim(StrGet(&pcBuf, "UTF-16"))
            if (text != "" && !InStr(junkNames, "|" . text . "|"))
                return text
        }
        panelChild := DllCall("GetWindow", "Ptr", panelChild, "UInt", 2, "Ptr")
    }

    return ""
}


;============================================================================================
; NURSING BOOSTER - HOTKEYS (global — not restricted to CPRS window)
; NOTE: ^+b is registered via Hotkey command in auto-execute (near Gui 67 setup)
;============================================================================================
#If (NB_Enabled)  ; Only register these hotkeys when NB is enabled

^+d::
    gosub NB_DumpDialogControls
return

; Hide panel for 6 seconds when any F-key is pressed (sign, navigation, etc.)
~F1::
~F2::
~F3::
~F4::
~F5::
~F6::
~F7::
~F8::
~F9::
~F10::
~F11::
~F12::
    if (NB_BoosterGuiVisible = 1) {
        Gui, 80:Hide
        NB_BoosterGuiVisible := 0
        NB_SignWasVisible := 1
        SetTimer, NB_RestorePanelAfterFKey, -6000
    }
return



;############################################################################################
;################### END NURSING BOOSTER ####################################################
;############################################################################################
;############################################################################################
;############################################################################################

; ============================================================================================
; CP FLOWSHEETS BOOSTER LABELS / FUNCTIONS
; ============================================================================================

;################### CP FLOWSHEETS BOOSTER ###################################################
;############################################################################################
;############################################################################################
;
; Automates the "Add Data" screen in CP Flowsheets (CPFlowsheets.exe).
; Supports checkboxes, radio buttons, and dropdowns (ComboBoxes).
; Text fields are excluded for now.
;
; Uses generic Win32 style-bit detection so it works regardless of whether
; CP Flowsheets is built with Delphi, .NET WinForms, or MFC.
;
; SAFETY: Never clicks Submit/Save/File/Sign buttons.
; The user always reviews and submits manually.
;
; PREFIX: CF_ for all functions, variables, and labels.
;############################################################################################


;============================================================================================
; CF - WINDOW DETECTION
;============================================================================================

CF_ReadLastEntryTime() {
    ; Read the time from the TDateTimePicker control in CP Flowsheets.
    ; Cache it and only update if new time is EARLIER than current clock
    ; (a saved entry is always in the past; Add Data sets it to now).
    static cachedTime := ""
    cfHwnd := WinExist("ahk_exe CPFlowsheets.exe")
    if (!cfHwnd)
        return cachedTime
    ; Find TDateTimePicker with a time value (HH:MM format)
    readTime := ""
    ControlGetText, dtText, TDateTimePicker1, ahk_id %cfHwnd%
    if (RegExMatch(dtText, "^\d{1,2}:\d{2}"))
        readTime := dtText
    if (readTime = "") {
        ControlGetText, dtText2, TDateTimePicker2, ahk_id %cfHwnd%
        if (RegExMatch(dtText2, "^\d{1,2}:\d{2}"))
            readTime := dtText2
    }
    if (readTime != "") {
        ; Only update cache if the read time is NOT the current time
        ; (Add Data sets picker to current time; last entry is in the past)
        FormatTime, nowTime,, HH:mm
        if (readTime != nowTime)
            cachedTime := readTime
    }
    return cachedTime
}

CF_FindCPFlowsheetsWindow() {
    ; Find the main CP Flowsheets window
    SetTitleMatchMode, 2
    hwnd := WinExist("ahk_exe CPFlowsheets.exe")
    if (hwnd)
        return hwnd
    return 0
}

CF_ClickAddDataButton() {
    global CF_AppTitle, CF__foundGridToolbarHwnd, CF__debugToolbarInfo
    mainHwnd := CF_FindCPFlowsheetsWindow()
    if (!mainHwnd) {
        MsgBox, 48, %CF_AppTitle%, CP Flowsheets not detected.
        return
    }

    ; Find the visible TToolBar inside TfraGridFrame (contains sbtnInsert = Add Data)
    ; Enumerate all child windows manually instead of using a callback
    CF__foundGridToolbarHwnd := 0
    CF__debugToolbarInfo := ""
    enumTB := RegisterCallback("CF__FindGridToolbarCallback", "Fast")
    DllCall("EnumChildWindows", "Ptr", mainHwnd, "Ptr", enumTB, "Ptr", 0)

    if (!CF__foundGridToolbarHwnd) {
        MsgBox, 48, %CF_AppTitle%, Could not find the grid toolbar in CP Flowsheets.`n`nDebug:`n%CF__debugToolbarInfo%
        return
    }

    ; Delphi's TToolBar doesn't respond to standard TB_* messages.
    ; sbtnInsert (Add Data) is always the first button on this toolbar.
    ; ControlClick at the first button position — coordinates are relative
    ; to the toolbar control itself, not the screen, so this works regardless
    ; of window position, screen size, or scroll state.
    ControlClick, x40 y25, ahk_id %CF__foundGridToolbarHwnd%
}

CF__FindGridToolbarCallback(hwnd, lParam) {
    global CF__foundGridToolbarHwnd, CF__debugToolbarInfo
    VarSetCapacity(buf, 256, 0)
    DllCall("GetClassName", "Ptr", hwnd, "Str", buf, "Int", 256)
    if (buf != "TToolBar")
        return 1

    ; Log every TToolBar we find
    style := DllCall("GetWindowLong", "Ptr", hwnd, "Int", -16, "UInt")
    vis := (style & 0x10000000) ? "Y" : "N"

    ; Get parent chain
    parentChain := ""
    p := DllCall("GetParent", "Ptr", hwnd, "Ptr")
    Loop, 6 {
        if (!p)
            break
        VarSetCapacity(pBuf, 256, 0)
        DllCall("GetClassName", "Ptr", p, "Str", pBuf, "Int", 256)
        parentChain .= pBuf . " > "
        if (pBuf = "TfraGridFrame") {
            CF__foundGridToolbarHwnd := hwnd
            CF__debugToolbarInfo .= "MATCH: hwnd=" . hwnd . " vis=" . vis . " parents=" . parentChain . "`n"
            return 0
        }
        p := DllCall("GetParent", "Ptr", p, "Ptr")
    }
    CF__debugToolbarInfo .= "SKIP: hwnd=" . hwnd . " vis=" . vis . " parents=" . parentChain . "`n"
    return 1
}

CF__FindGridPageCtrlCallback(hwnd, lParam) {
    global CF__foundPageCtrlHwnd
    VarSetCapacity(buf, 256, 0)
    DllCall("GetClassName", "Ptr", hwnd, "Str", buf, "Int", 256)
    if (buf != "TPageControl")
        return 1

    ; Check if this page control is visible and inside TfraGridView
    ; by checking if its parent is TfraGridView
    parentHwnd := DllCall("GetParent", "Ptr", hwnd, "Ptr")
    if (!parentHwnd)
        return 1
    VarSetCapacity(pBuf, 256, 0)
    DllCall("GetClassName", "Ptr", parentHwnd, "Str", pBuf, "Int", 256)
    if (pBuf = "TfraGridView") {
        CF__foundPageCtrlHwnd := hwnd
        return 0
    }
    return 1
}

CF_FindAddDataWindow() {
    ; Strategy 1: Look for a window with "Add Data" in its title
    SetTitleMatchMode, 2
    hwnd := WinExist("Add Data ahk_exe CPFlowsheets.exe")
    if (hwnd)
        return hwnd

    ; Strategy 2: Look for any CP Flowsheets window that has form controls
    ; (checkboxes, radios, or combos)
    mainHwnd := CF_FindCPFlowsheetsWindow()
    if (!mainHwnd)
        return 0

    ; Check the main window itself
    if (CF_HasFormControls(mainHwnd))
        return mainHwnd

    ; Check child/owned windows
    WinGet, wndList, List, ahk_exe CPFlowsheets.exe
    Loop, %wndList%
    {
        wnd := wndList%A_Index%
        if (CF_HasFormControls(wnd))
            return wnd
    }
    return 0
}

CF_HasFormControls(windowHwnd) {
    global CF__hasFormControls
    CF__hasFormControls := false
    enumCB := RegisterCallback("CF__CheckForFormControls", "Fast")
    DllCall("EnumChildWindows", "Ptr", windowHwnd, "Ptr", enumCB, "Ptr", 0)
    return CF__hasFormControls
}

CF__CheckForFormControls(hwnd, lParam) {
    global CF__hasFormControls
    VarSetCapacity(buf, 512, 0)
    DllCall("GetClassName", "Ptr", hwnd, "Str", buf, "Int", 256)
    className := buf

    ; Get window style
    style := DllCall("GetWindowLong", "Ptr", hwnd, "Int", -16, "UInt")
    buttonStyle := style & 0x0F

    ; Check for checkbox styles (BS_CHECKBOX=0x02, BS_AUTOCHECKBOX=0x03)
    if (buttonStyle = 0x02 || buttonStyle = 0x03) {
        CF__hasFormControls := true
        return 0
    }
    ; Check for radio button styles (BS_RADIOBUTTON=0x04, BS_AUTORADIOBUTTON=0x09)
    if (buttonStyle = 0x04 || buttonStyle = 0x09) {
        CF__hasFormControls := true
        return 0
    }
    ; Check for Delphi-specific class names
    if (InStr(className, "TCheckBox") || InStr(className, "TRadioButton")
        || InStr(className, "TComboBox") || className = "ComboBox"
        || InStr(className, "TCheckListBox")) {
        CF__hasFormControls := true
        return 0
    }
    ; Check for .NET WinForms class names
    if (InStr(className, "WindowsForms") && (InStr(className, "CheckBox")
        || InStr(className, "RadioButton") || InStr(className, "ComboBox"))) {
        CF__hasFormControls := true
        return 0
    }
    return 1
}


;============================================================================================
; CF - CONTROL TYPE CLASSIFICATION
;
; Uses Win32 style bits to classify controls. This works for Delphi, .NET, MFC, etc.
; BS_CHECKBOX      = 0x02
; BS_AUTOCHECKBOX  = 0x03
; BS_RADIOBUTTON   = 0x04
; BS_AUTORADIOBUTTON = 0x09
; BS_GROUPBOX      = 0x07
;============================================================================================

CF_ClassifyControl(hwnd) {
    ; Returns: "checkbox", "radio", "combo", "groupbox", "label", or ""
    VarSetCapacity(buf, 512, 0)
    DllCall("GetClassName", "Ptr", hwnd, "Str", buf, "Int", 256)
    className := buf

    ; ComboBox detection (class name based)
    if (className = "ComboBox" || InStr(className, "TComboBox")
        || (InStr(className, "WindowsForms") && InStr(className, "ComboBox"))) {
        return "combo"
    }

    ; Delphi TCheckListBox — a listbox with per-item checkboxes
    if (InStr(className, "TCheckListBox"))
        return "checklist"

    ; Delphi-specific class name detection
    if (InStr(className, "TCheckBox"))
        return "checkbox"
    if (InStr(className, "TRadioButton"))
        return "radio"

    ; .NET WinForms class name detection
    if (InStr(className, "WindowsForms") && InStr(className, "CheckBox"))
        return "checkbox"
    if (InStr(className, "WindowsForms") && InStr(className, "RadioButton"))
        return "radio"

    ; CPRS-specific classes (in case CP Flowsheets shares any)
    if (className = "TORCheckBox" || className = "TCPRSDialogCheckBox")
        return "checkbox"
    if (className = "TCPRSDialogParentCheckBox")
        return "checkbox"

    ; Generic Win32 Button style classification
    style := DllCall("GetWindowLong", "Ptr", hwnd, "Int", -16, "UInt")
    buttonStyle := style & 0x0F

    if (buttonStyle = 0x02 || buttonStyle = 0x03)  ; BS_CHECKBOX / BS_AUTOCHECKBOX
        return "checkbox"
    if (buttonStyle = 0x04 || buttonStyle = 0x09)  ; BS_RADIOBUTTON / BS_AUTORADIOBUTTON
        return "radio"
    if (buttonStyle = 0x07)  ; BS_GROUPBOX
        return "groupbox"

    ; Label detection
    if (className = "Static" || InStr(className, "TLabel") || InStr(className, "TStaticText"))
        return "label"

    return ""
}


;============================================================================================
; CF - SPY / DISCOVERY TOOL
;
; Dumps the full control hierarchy of the CP Flowsheets window.
; Run this once to discover what control classes the app uses.
;============================================================================================

CF_SpyDumpControls:
    global CF_TemplateDir, CF_AppTitle

    targetHwnd := CF_FindCPFlowsheetsWindow()
    if (!targetHwnd) {
        ; Fallback: try the active window (user might have it focused)
        targetHwnd := WinExist("A")
        if (!targetHwnd) {
            MsgBox, 48, %CF_AppTitle%, CP Flowsheets not detected. Open CP Flowsheets first.`n`nAlternatively focus the target window and try again.
            return
        }
    }

    ToolTip, Scanning CP Flowsheets controls...

    WinGetTitle, winTitle, ahk_id %targetHwnd%
    WinGetClass, winClass, ahk_id %targetHwnd%

    ; Enumerate all child controls
    global CF__spyFile, CF__spyTargetHwnd, CF__spyCount, CF__spyCBCount, CF__spyRadioCount, CF__spyComboCount

    FormatTime, nowStamp,, yyyyMMdd_HHmmss
    dumpPath := CF_TemplateDir . "\cpfs_spy_" . nowStamp . ".txt"

    CF__spyFile := FileOpen(dumpPath, "w", "UTF-8")
    CF__spyFile.Write("=== CP Flowsheets Control Dump ===`n")
    FormatTime, nowTime,, yyyy-MM-dd HH:mm:ss
    CF__spyFile.Write("Time: " . nowTime . "`n")
    CF__spyFile.Write("Window Title: " . winTitle . "`n")
    CF__spyFile.Write("Window Class: " . winClass . "`n")
    CF__spyFile.Write("Window HWND: " . targetHwnd . "`n`n")

    CF__spyTargetHwnd := targetHwnd
    CF__spyCount := 0
    CF__spyCBCount := 0
    CF__spyRadioCount := 0
    CF__spyComboCount := 0

    enumSpy := RegisterCallback("CF__SpyCallback", "Fast")
    DllCall("EnumChildWindows", "Ptr", targetHwnd, "Ptr", enumSpy, "Ptr", 0)

    CF__spyFile.Write("`n=== Summary ===`n")
    CF__spyFile.Write("Total controls: " . CF__spyCount . "`n")
    CF__spyFile.Write("Checkboxes: " . CF__spyCBCount . "`n")
    CF__spyFile.Write("Radio buttons: " . CF__spyRadioCount . "`n")
    CF__spyFile.Write("ComboBoxes: " . CF__spyComboCount . "`n")
    CF__spyFile.Close()

    ToolTip, Spy dump: %CF__spyCount% controls (%CF__spyCBCount% CB / %CF__spyRadioCount% Radio / %CF__spyComboCount% Combo)`nSaved to: %dumpPath%
    SetTimer, CF_ClearToolTip, -5000

    MsgBox, 64, %CF_AppTitle%, Control dump complete!`n`n%CF__spyCount% total controls found:`n- %CF__spyCBCount% checkboxes`n- %CF__spyRadioCount% radio buttons`n- %CF__spyComboCount% dropdowns`n`nSaved to:`n%dumpPath%
return

CF__SpyCallback(hwnd, lParam) {
    global CF__spyFile, CF__spyTargetHwnd, CF__spyCount, CF__spyCBCount, CF__spyRadioCount, CF__spyComboCount
    CF__spyCount++

    VarSetCapacity(buf, 512, 0)
    DllCall("GetClassName", "Ptr", hwnd, "Str", buf, "Int", 256)
    className := buf

    ; Get window text
    text := ""
    SendMessage, 0x000E, 0, 0,, ahk_id %hwnd%   ; WM_GETTEXTLENGTH
    tLen := ErrorLevel
    if (tLen > 0 && tLen < 1024) {
        VarSetCapacity(tBuf, (tLen + 1) * 2, 0)
        SendMessage, 0x000D, tLen + 1, &tBuf,, ahk_id %hwnd%   ; WM_GETTEXT
        text := StrGet(&tBuf)
    }

    ; Get style
    style := DllCall("GetWindowLong", "Ptr", hwnd, "Int", -16, "UInt")
    buttonStyle := style & 0x0F

    ; Depth calculation
    depth := 0
    p := hwnd
    Loop
    {
        p := DllCall("GetParent", "Ptr", p, "Ptr")
        if (!p || p = CF__spyTargetHwnd)
            break
        depth++
    }

    ; Get parent class
    parentHwnd := DllCall("GetParent", "Ptr", hwnd, "Ptr")
    VarSetCapacity(pBuf, 512, 0)
    if (parentHwnd)
        DllCall("GetClassName", "Ptr", parentHwnd, "Str", pBuf, "Int", 256)
    parentClass := parentHwnd ? pBuf : "none"

    ; Classify
    controlType := CF_ClassifyControl(hwnd)
    extra := ""
    if (controlType = "checkbox") {
        SendMessage, 0x00F0, 0, 0,, ahk_id %hwnd%   ; BM_GETCHECK
        checked := ErrorLevel
        extra := " [CHECKBOX] CHECKED=" . (checked ? "YES" : "NO")
        CF__spyCBCount++
    }
    else if (controlType = "radio") {
        SendMessage, 0x00F0, 0, 0,, ahk_id %hwnd%   ; BM_GETCHECK
        checked := ErrorLevel
        extra := " [RADIO] SELECTED=" . (checked ? "YES" : "NO")
        CF__spyRadioCount++
    }
    else if (controlType = "combo") {
        SendMessage, 0x0147, 0, 0,, ahk_id %hwnd%   ; CB_GETCURSEL
        selIdx := ErrorLevel
        extra := " [COMBOBOX] SELECTED_IDX=" . selIdx
        CF__spyComboCount++
    }
    else if (controlType = "checklist") {
        ; Enumerate items in the TCheckListBox
        SendMessage, 0x018B, 0, 0,, ahk_id %hwnd%   ; LB_GETCOUNT
        clItemCount := ErrorLevel
        extra := " [CHECKLISTBOX] ITEMS=" . clItemCount
        CF__spyCBCount += clItemCount
    }
    else if (controlType = "groupbox") {
        extra := " [GROUPBOX]"
    }

    ; Visibility
    visible := (style & 0x10000000) ? "Y" : "N"

    ; Build indent
    indent := ""
    Loop, %depth%
        indent .= "  "

    ; Get rect
    VarSetCapacity(rect, 16, 0)
    DllCall("GetWindowRect", "Ptr", hwnd, "Ptr", &rect)
    rx := NumGet(rect, 0, "Int")
    ry := NumGet(rect, 4, "Int")
    rw := NumGet(rect, 8, "Int") - rx
    rh := NumGet(rect, 12, "Int") - ry

    CF__spyFile.Write(indent . className . " hwnd=" . hwnd . " text='" . text . "' style=0x" . Format("{:08X}", style) . " vis=" . visible . " pos=" . rx . "," . ry . " size=" . rw . "x" . rh . " parent=" . parentClass . extra . "`n")
    return 1
}


;============================================================================================
; CF - ENUMERATE FORM CONTROLS (checkboxes, radios, combos)
;
; Returns an array of objects with:
;   .hwnd, .type ("checkbox"/"radio"/"combo"), .className, .label, .checked/.selected/.value
;   .y (screen Y for sorting/matching), .x, .parentHwnd, .parentLabel
;============================================================================================

CF_EnumFormControls(windowHwnd) {
    global CF__enumResults, CF__enumTargetHwnd, CF__checkListHwndStr
    CF__enumResults := []
    CF__enumTargetHwnd := windowHwnd

    ; Pass 1: Enumerate standard controls (checkboxes, radios, combos)
    enumCB := RegisterCallback("CF__EnumFormCallback", "Fast")
    DllCall("EnumChildWindows", "Ptr", windowHwnd, "Ptr", enumCB, "Ptr", 0)

    ; Pass 2: Find TCheckListBox controls (separate pass — no array methods in callbacks)
    CF__checkListHwndStr := ""
    enumCL := RegisterCallback("CF__FindCheckListCallback", "Fast")
    DllCall("EnumChildWindows", "Ptr", windowHwnd, "Ptr", enumCL, "Ptr", 0)

    ; Expand each TCheckListBox into individual items (safe — outside callbacks)
    if (CF__checkListHwndStr != "") {
        Loop, Parse, CF__checkListHwndStr, |
        {
            if (A_LoopField != "")
                CF_EnumCheckListBoxItems(A_LoopField + 0)
        }
    }

    ; Sort by Y position (insertion sort for stable ordering)
    results := CF__enumResults
    if (results.Length() > 1) {
        Loop, % results.Length() - 1
        {
            i := A_Index + 1
            key := results[i]
            j := i - 1
            while (j >= 1 && (results[j].y > key.y || (results[j].y = key.y && results[j].x > key.x))) {
                results[j + 1] := results[j]
                j--
            }
            results[j + 1] := key
        }
    }

    return results
}

CF__EnumFormCallback(hwnd, lParam) {
    global CF__enumResults, CF__enumTargetHwnd

    ; Skip invisible controls (WS_VISIBLE = 0x10000000)
    cfStyle := DllCall("GetWindowLong", "Ptr", hwnd, "Int", -16, "UInt")
    if !(cfStyle & 0x10000000)
        return 1

    controlType := CF_ClassifyControl(hwnd)
    if (controlType != "checkbox" && controlType != "radio" && controlType != "combo")
        return 1

    VarSetCapacity(buf, 512, 0)
    DllCall("GetClassName", "Ptr", hwnd, "Str", buf, "Int", 256)
    className := buf

    ; Get screen position
    VarSetCapacity(rect, 16, 0)
    DllCall("GetWindowRect", "Ptr", hwnd, "Ptr", &rect)
    y := NumGet(rect, 4, "Int")
    x := NumGet(rect, 0, "Int")

    ; Get label text
    label := ""
    SendMessage, 0x000E, 0, 0,, ahk_id %hwnd%   ; WM_GETTEXTLENGTH
    tLen := ErrorLevel
    if (tLen > 0 && tLen < 1024) {
        VarSetCapacity(tBuf, (tLen + 1) * 2, 0)
        SendMessage, 0x000D, tLen + 1, &tBuf,, ahk_id %hwnd%   ; WM_GETTEXT
        label := Trim(StrGet(&tBuf))
    }

    ; If label is empty or just a space, try to find adjacent label control
    if (label = "" || label = " ") {
        label := CF_FindAdjacentLabel(hwnd, CF__enumTargetHwnd)
    }

    ; Get parent for radio button grouping
    parentHwnd := DllCall("GetParent", "Ptr", hwnd, "Ptr")
    parentLabel := ""
    if (parentHwnd) {
        VarSetCapacity(pBuf, 512, 0)
        DllCall("GetClassName", "Ptr", parentHwnd, "Str", pBuf, "Int", 256)
        parentClass := pBuf
        ; If parent is a groupbox, get its text as group label
        if (InStr(parentClass, "GroupBox") || InStr(parentClass, "TGroupBox")
            || (DllCall("GetWindowLong", "Ptr", parentHwnd, "Int", -16, "UInt") & 0x0F) = 0x07) {
            SendMessage, 0x000E, 0, 0,, ahk_id %parentHwnd%
            pLen := ErrorLevel
            if (pLen > 0 && pLen < 256) {
                VarSetCapacity(plBuf, (pLen + 1) * 2, 0)
                SendMessage, 0x000D, pLen + 1, &plBuf,, ahk_id %parentHwnd%
                parentLabel := Trim(StrGet(&plBuf))
            }
        }
    }

    ; Get state
    checked := false
    selected := false
    value := ""
    valueIdx := -1

    if (controlType = "checkbox") {
        SendMessage, 0x00F0, 0, 0,, ahk_id %hwnd%   ; BM_GETCHECK
        checked := ErrorLevel ? true : false
    }
    else if (controlType = "radio") {
        SendMessage, 0x00F0, 0, 0,, ahk_id %hwnd%   ; BM_GETCHECK
        selected := ErrorLevel ? true : false
    }
    else if (controlType = "combo") {
        SendMessage, 0x0147, 0, 0,, ahk_id %hwnd%   ; CB_GETCURSEL
        valueIdx := ErrorLevel
        if (valueIdx != 0xFFFFFFFF && valueIdx >= 0) {
            ; Get the text of the selected item
            SendMessage, 0x0149, valueIdx, 0,, ahk_id %hwnd%  ; CB_GETLBTEXTLEN
            cbLen := ErrorLevel
            if (cbLen > 0 && cbLen < 1024) {
                VarSetCapacity(cbBuf, (cbLen + 2) * 2, 0)
                SendMessage, 0x0148, valueIdx, &cbBuf,, ahk_id %hwnd%  ; CB_GETLBTEXT
                value := StrGet(&cbBuf)
            }
        }
    }

    entry := {hwnd: hwnd, type: controlType, className: className, label: label
        , checked: checked, selected: selected, value: value, valueIdx: valueIdx
        , y: y, x: x, parentHwnd: parentHwnd, parentLabel: parentLabel}
    CF__enumResults.Push(entry)
    return 1
}


;============================================================================================
; CF - FIND CHECKLIST CALLBACK
;
; Second-pass callback that only looks for TCheckListBox controls.
; Uses string concatenation (not array methods) because Fast callbacks
; cannot safely call .Push() or other object methods.
;============================================================================================

CF__FindCheckListCallback(hwnd, lParam) {
    global CF__checkListHwndStr

    ; Skip invisible controls
    cfStyle := DllCall("GetWindowLong", "Ptr", hwnd, "Int", -16, "UInt")
    if !(cfStyle & 0x10000000)
        return 1

    ; Get class name
    VarSetCapacity(clBuf, 512, 0)
    DllCall("GetClassName", "Ptr", hwnd, "Str", clBuf, "Int", 256)
    clName := clBuf

    ; Only interested in TCheckListBox
    if (clName = "TCheckListBox") {
        CF__checkListHwndStr .= hwnd . "|"
    }

    return 1
}


;============================================================================================
; CF - FIND ADJACENT LABEL
;
; When a checkbox/radio has no text, look for a Static/TLabel sibling
; positioned immediately to its right on the same Y row.
;============================================================================================

CF_FindAdjacentLabel(controlHwnd, dialogHwnd) {
    global CF__adjLabel, CF__adjControlRect, CF__adjControlHwnd

    ; Get the control's rect
    VarSetCapacity(rect, 16, 0)
    DllCall("GetWindowRect", "Ptr", controlHwnd, "Ptr", &rect)
    CF__adjControlRect := {left: NumGet(rect, 0, "Int"), top: NumGet(rect, 4, "Int")
        , right: NumGet(rect, 8, "Int"), bottom: NumGet(rect, 12, "Int")}
    CF__adjControlHwnd := controlHwnd
    CF__adjLabel := ""

    parentHwnd := DllCall("GetParent", "Ptr", controlHwnd, "Ptr")
    if (!parentHwnd)
        parentHwnd := dialogHwnd

    enumAdj := RegisterCallback("CF__AdjLabelCallback", "Fast")
    DllCall("EnumChildWindows", "Ptr", parentHwnd, "Ptr", enumAdj, "Ptr", 0)
    return CF__adjLabel
}

CF__AdjLabelCallback(hwnd, lParam) {
    global CF__adjLabel, CF__adjControlRect, CF__adjControlHwnd

    if (hwnd = CF__adjControlHwnd)
        return 1

    VarSetCapacity(buf, 512, 0)
    DllCall("GetClassName", "Ptr", hwnd, "Str", buf, "Int", 256)
    className := buf

    ; Only look at label-type controls
    if !(className = "Static" || InStr(className, "TLabel") || InStr(className, "TStaticText")
        || InStr(className, "TVA508StaticText") || InStr(className, "TCPRSDialogStaticLabel"))
        return 1

    ; Check position: must be on the same row (within 10px Y) and to the right
    VarSetCapacity(rect, 16, 0)
    DllCall("GetWindowRect", "Ptr", hwnd, "Ptr", &rect)
    labelTop := NumGet(rect, 4, "Int")
    labelLeft := NumGet(rect, 0, "Int")

    yDiff := Abs(labelTop - CF__adjControlRect.top)
    if (yDiff > 10)
        return 1
    if (labelLeft < CF__adjControlRect.right)
        return 1

    ; Get text
    SendMessage, 0x000E, 0, 0,, ahk_id %hwnd%
    tLen := ErrorLevel
    if (tLen > 0 && tLen < 256) {
        VarSetCapacity(tBuf, (tLen + 1) * 2, 0)
        SendMessage, 0x000D, tLen + 1, &tBuf,, ahk_id %hwnd%
        text := Trim(StrGet(&tBuf))
        if (text != "" && text != " ") {
            CF__adjLabel := text
            return 0  ; Stop searching
        }
    }
    return 1
}


;============================================================================================
; CF - TCHECKLISTBOX SUPPORT
;
; Delphi TCheckListBox is a single listbox control that draws per-item checkboxes.
; Items are NOT child windows — they live inside the listbox.
; We use LB_ messages to enumerate items and ReadProcessMemory to read check state
; from Delphi's internal TCheckListBoxDataWrapper (FState at offset +4 from item data pointer).
;============================================================================================

CF_EnumCheckListBoxItems(listBoxHwnd) {
    global CF__enumResults

    ; Get item count
    SendMessage, 0x018B, 0, 0,, ahk_id %listBoxHwnd%   ; LB_GETCOUNT
    itemCount := ErrorLevel
    if (itemCount <= 0 || itemCount > 500)
        return

    ; Get screen position of the listbox itself
    VarSetCapacity(lbRect, 16, 0)
    DllCall("GetWindowRect", "Ptr", listBoxHwnd, "Ptr", &lbRect)
    lbY := NumGet(lbRect, 4, "Int")
    lbX := NumGet(lbRect, 0, "Int")

    ; Open the process for memory reading (needed for check state)
    WinGet, pid, PID, ahk_id %listBoxHwnd%
    hProc := DllCall("OpenProcess", "UInt", 0x0010, "Int", 0, "UInt", pid, "Ptr")  ; PROCESS_VM_READ

    Loop, %itemCount%
    {
        idx := A_Index - 1

        ; Get item text via LB_GETTEXT
        ; First get text length
        SendMessage, 0x018A, idx, 0,, ahk_id %listBoxHwnd%   ; LB_GETTEXTLEN
        tLen := ErrorLevel
        itemText := ""
        if (tLen > 0 && tLen < 1024) {
            VarSetCapacity(tBuf, (tLen + 2) * 2, 0)
            SendMessage, 0x0189, idx, &tBuf,, ahk_id %listBoxHwnd%   ; LB_GETTEXT
            itemText := StrGet(&tBuf)
        }

        ; Get item rect for Y position
        VarSetCapacity(itemRect, 16, 0)
        NumPut(idx, itemRect, 0, "Int")  ; LB_GETITEMRECT needs index in RECT
        SendMessage, 0x0198, idx, &itemRect,, ahk_id %listBoxHwnd%   ; LB_GETITEMRECT
        ; itemRect is in client coords — convert to screen
        VarSetCapacity(pt, 8, 0)
        NumPut(NumGet(itemRect, 0, "Int"), pt, 0, "Int")
        NumPut(NumGet(itemRect, 4, "Int"), pt, 4, "Int")
        DllCall("ClientToScreen", "Ptr", listBoxHwnd, "Ptr", &pt)
        itemY := NumGet(pt, 4, "Int")

        ; Read check state from Delphi internals via LB_GETITEMDATA + ReadProcessMemory
        ; TCheckListBoxDataWrapper layout (32-bit Delphi):
        ;   Offset 0: VMT pointer (4 bytes)
        ;   Offset 4: FData (LongInt, 4 bytes)
        ;   Offset 8: FState (TCheckBoxState: 0=unchecked, 1=checked, 2=grayed)
        itemChecked := false
        SendMessage, 0x0199, idx, 0,, ahk_id %listBoxHwnd%   ; LB_GETITEMDATA
        dataPtr := ErrorLevel
        if (hProc && dataPtr && dataPtr != 0xFFFFFFFF && dataPtr != -1) {
            VarSetCapacity(stateVal, 4, 0)
            bytesRead := 0
            DllCall("ReadProcessMemory", "Ptr", hProc, "Ptr", dataPtr + 8
                , "Ptr", &stateVal, "UInt", 4, "Ptr*", bytesRead)
            if (bytesRead > 0) {
                state := NumGet(stateVal, 0, "Int")
                itemChecked := (state = 1) ? true : false  ; cbChecked=1
            }
        }

        entry := {hwnd: listBoxHwnd, type: "checklist", className: "TCheckListBox"
            , label: itemText, checked: itemChecked, selected: false, value: ""
            , valueIdx: -1, y: itemY, x: lbX, parentHwnd: 0, parentLabel: ""
            , checklistIdx: idx}
        CF__enumResults.Push(entry)
    }

    if (hProc)
        DllCall("CloseHandle", "Ptr", hProc)
}

CF_ReadCheckListItemState(listBoxHwnd, itemIdx) {
    ; Read the check state of a single TCheckListBox item
    ; Returns true if checked, false otherwise
    WinGet, pid, PID, ahk_id %listBoxHwnd%
    hProc := DllCall("OpenProcess", "UInt", 0x0010, "Int", 0, "UInt", pid, "Ptr")
    if (!hProc)
        return false

    SendMessage, 0x0199, itemIdx, 0,, ahk_id %listBoxHwnd%   ; LB_GETITEMDATA
    dataPtr := ErrorLevel
    result := false
    if (dataPtr && dataPtr != 0xFFFFFFFF && dataPtr != -1) {
        ; FState is at offset +8: past VMT pointer (4) and FData (4)
        VarSetCapacity(stateVal, 4, 0)
        bytesRead := 0
        DllCall("ReadProcessMemory", "Ptr", hProc, "Ptr", dataPtr + 8
            , "Ptr", &stateVal, "UInt", 4, "Ptr*", bytesRead)
        if (bytesRead > 0) {
            state := NumGet(stateVal, 0, "Int")
            result := (state = 1) ? true : false
        }
    }
    DllCall("CloseHandle", "Ptr", hProc)
    return result
}

CF_WriteCheckListItemState(listBoxHwnd, itemIdx, newChecked) {
    ; Write the check state of a single TCheckListBox item via WriteProcessMemory
    ; Same memory layout as CF_ReadCheckListItemState: FState at dataPtr + 8
    WinGet, pid, PID, ahk_id %listBoxHwnd%
    hProc := DllCall("OpenProcess", "UInt", 0x0038, "Int", 0, "UInt", pid, "Ptr")  ; PROCESS_VM_READ | PROCESS_VM_WRITE | PROCESS_VM_OPERATION
    if (!hProc)
        return false

    SendMessage, 0x0199, itemIdx, 0,, ahk_id %listBoxHwnd%   ; LB_GETITEMDATA
    dataPtr := ErrorLevel
    result := false
    if (dataPtr && dataPtr != 0xFFFFFFFF && dataPtr != -1) {
        ; FState: 0=unchecked, 1=checked
        newState := newChecked ? 1 : 0
        VarSetCapacity(stateVal, 4, 0)
        NumPut(newState, stateVal, 0, "Int")
        bytesWritten := 0
        DllCall("WriteProcessMemory", "Ptr", hProc, "Ptr", dataPtr + 8
            , "Ptr", &stateVal, "UInt", 4, "Ptr*", bytesWritten)
        result := (bytesWritten > 0)
    }
    DllCall("CloseHandle", "Ptr", hProc)
    return result
}


;============================================================================================
; CF - DEBUG LOGGING
;============================================================================================

CF__LogControlStates(action, controls, templateNameOrPath := "", windowTitle := "", statA := 0, statB := 0) {
    global CF_LogDir, NB_DebugLogging
    if (!NB_DebugLogging)
        return

    FormatTime, nowStamp,, yyyyMMddHHmmss
    FormatTime, nowDisp,, yyyy-MM-dd HH:mm:ss
    logPath := CF_LogDir . "\" . action . "_" . nowStamp . ".txt"
    FileDelete, %logPath%

    controlCount := controls.Length()

    logText := "============================================================`n"
    logText .= "  CP FLOWSHEETS " . action . " LOG`n"
    logText .= "============================================================`n"
    logText .= "Timestamp:    " . nowDisp . "`n"
    logText .= "Action:       " . action . "`n"
    logText .= "Template:     " . templateNameOrPath . "`n"
    logText .= "Window:       " . windowTitle . "`n"
    logText .= "User:         " . A_UserName . "`n"
    logText .= "Controls:     " . controlCount . "`n"
    if (action = "SAVE")
        logText .= "Total saved:  " . statA . "`n"
    else if (action = "APPLY")
        logText .= "Applied: " . statA . "  |  Not matched: " . statB . "`n"
    logText .= "============================================================`n`n"
    FileAppend, %logText%, %logPath%, UTF-8

    cbCount := 0
    radioCount := 0
    comboCount := 0
    clCount := 0

    for ci, ctrl in controls {
        ctrlType := ctrl.type
        ctrlLabel := ctrl.label != "" ? ctrl.label : "(unlabeled)"
        ctrlLine := ""

        if (ctrlType = "checkbox") {
            state := ctrl.checked ? "[X]" : "[ ]"
            ctrlLine := "  " . state . " CHECKBOX  " . ctrlLabel . "`n"
            cbCount++
        }
        else if (ctrlType = "checklist") {
            state := ctrl.checked ? "[X]" : "[ ]"
            clIdx := ctrl.checklistIdx
            ctrlLine := "  " . state . " CHECKLIST idx=" . clIdx . "  " . ctrlLabel . "`n"
            clCount++
        }
        else if (ctrlType = "radio") {
            state := ctrl.selected ? "(O)" : "( )"
            grp := ctrl.parentLabel != "" ? " group=""" . ctrl.parentLabel . """" : ""
            ctrlLine := "  " . state . " RADIO" . grp . "  " . ctrlLabel . "`n"
            radioCount++
        }
        else if (ctrlType = "combo") {
            val := ctrl.value != "" ? ctrl.value : "(empty)"
            ctrlLine := "  [v] COMBO  " . ctrlLabel . " = " . val . "`n"
            comboCount++
        }

        FileAppend, %ctrlLine%, %logPath%, UTF-8
    }

    footerText := "`n============================================================`n"
    footerText .= "TOTALS: " . cbCount . " checkboxes, " . clCount . " checklist items, " . radioCount . " radios, " . comboCount . " combos`n"
    footerText .= "============================================================`n"
    FileAppend, %footerText%, %logPath%, UTF-8
}


;============================================================================================
; CF - SAVE TEMPLATE
;============================================================================================

CF_BtnSaveTemplate:
    global CF_TemplateDir, CF_AppTitle

    targetHwnd := CF_FindAddDataWindow()
    if (!targetHwnd) {
        targetHwnd := CF_FindCPFlowsheetsWindow()
    }
    if (!targetHwnd) {
        MsgBox, 48, %CF_AppTitle%, CP Flowsheets not detected.`nOpen CP Flowsheets and navigate to the Add Data screen first.
        return
    }

    InputBox, cfTemplateName, %CF_AppTitle% - Save Template, Template name:`n`nUse a descriptive name like 'ICU Default' or 'Vitals Baseline'.
    if (ErrorLevel || cfTemplateName = "")
        return

    ToolTip, Scanning CP Flowsheets controls...

    controls := CF_EnumFormControls(targetHwnd)
    if (controls.Length() = 0) {
        MsgBox, 48, %CF_AppTitle%, No checkboxes, radio buttons, or dropdowns found in this window.`n`nTry running CPFS Spy to see what controls are available.
        return
    }

    ; Build JSON
    WinGetTitle, cfWinTitle, ahk_id %targetHwnd%
    FormatTime, cfNowTime,, yyyy-MM-dd HH:mm
    json := "{"
    json .= "`n  ""name"": " . CF_EscJson(cfTemplateName) . ","
    json .= "`n  ""format"": 1,"
    json .= "`n  ""speed"": 100,"
    json .= "`n  ""app"": ""CPFlowsheets"","
    json .= "`n  ""created"": """ . cfNowTime . ""","
    json .= "`n  ""window_title"": " . CF_EscJson(cfWinTitle) . ","
    json .= "`n  ""controls"": ["

    cbCount := 0
    radioCount := 0
    comboCount := 0

    for ci, ctrl in controls {
        if (ci > 1)
            json .= ","

        json .= "`n    {""type"": """ . ctrl.type . """"
        json .= ", ""label"": " . CF_EscJson(ctrl.label)
        json .= ", ""cls"": " . CF_EscJson(ctrl.className)
        json .= ", ""idx"": " . (ci - 1)
        json .= ", ""y"": " . ctrl.y

        if (ctrl.type = "checkbox" || ctrl.type = "checklist") {
            json .= ", ""checked"": " . (ctrl.checked ? "true" : "false")
            if (ctrl.type = "checklist")
                json .= ", ""checklistIdx"": " . ctrl.checklistIdx
            cbCount++
        }
        else if (ctrl.type = "radio") {
            json .= ", ""selected"": " . (ctrl.selected ? "true" : "false")
            if (ctrl.parentLabel != "")
                json .= ", ""group_label"": " . CF_EscJson(ctrl.parentLabel)
            radioCount++
        }
        else if (ctrl.type = "combo") {
            json .= ", ""value"": " . CF_EscJson(ctrl.value)
            json .= ", ""valueIdx"": " . ctrl.valueIdx
            comboCount++
        }

        json .= "}"
    }

    json .= "`n  ]"
    json .= "`n}"

    filePath := CF_TemplateDir . "\" . CF_SanitizeFilename(cfTemplateName) . ".json"
    f := FileOpen(filePath, "w", "UTF-8")
    f.Write(json)
    f.Close()

    totalControls := controls.Length()

    if (NB_DebugLogging)
        CF__LogControlStates("SAVE", controls, cfTemplateName, cfWinTitle, cbCount + radioCount + comboCount, 0)

    ToolTip, Saved "%cfTemplateName%": %totalControls% controls (%cbCount% CB / %radioCount% Radio / %comboCount% Combo)
    SetTimer, CF_ClearToolTip, -3000
return


;============================================================================================
; CF - LOAD / APPLY TEMPLATE
;============================================================================================

CF_BtnLoadTemplate:
    global CF_TemplateDir, CF_AppTitle

    targetHwnd := CF_FindAddDataWindow()
    if (!targetHwnd)
        targetHwnd := CF_FindCPFlowsheetsWindow()
    if (!targetHwnd) {
        MsgBox, 48, %CF_AppTitle%, CP Flowsheets not detected.`nOpen CP Flowsheets first.
        return
    }

    ; Build template list
    cfLoadList := ""
    cfLoadPaths := []
    Loop, Files, %CF_TemplateDir%\*.json
    {
        SplitPath, A_LoopFileFullPath,,,,nameNoExt
        cfLoadList .= nameNoExt . "|"
        cfLoadPaths.Push(A_LoopFileFullPath)
    }

    if (cfLoadPaths.Length() = 0) {
        MsgBox, 64, %CF_AppTitle%, No saved CP Flowsheets templates found.`n`nTo create one:`n1. Open the Add Data screen in CP Flowsheets`n2. Set up your checkboxes, radios, and dropdowns`n3. Click 'CPFS Save'
        return
    }

    ; Show picker GUI (using Gui 69 to avoid conflicts)
    Gui, 82:Destroy
    Gui, 82:+AlwaysOnTop
    Gui, 82:Font, s9, Segoe UI
    Gui, 82:Add, Text,, Select a CP Flowsheets template to apply:
    Gui, 82:Add, ListBox, w300 h200 vCF_LoadSelection, %cfLoadList%
    Gui, 82:Add, Button, y+5 w120 Default gCF_DoLoadTemplate, Apply
    Gui, 82:Add, Button, x+5 w120 gCF_CancelLoad, Cancel
    Gui, 82:Show,, %CF_AppTitle% - Load Template
return

CF_DoLoadTemplate:
    Gui, 82:Submit
    Gui, 82:Destroy
    if (CF_LoadSelection = "") {
        MsgBox, 48, %CF_AppTitle%, Select a template first.
        return
    }
    templatePath := CF_TemplateDir . "\" . CF_SanitizeFilename(CF_LoadSelection) . ".json"
    if (FileExist(templatePath)) {
        if (CF_ChainAddData) {
            CF_ClickAddDataButton()
            ; Wait for the input screen to appear
            Loop, 20 {
                Sleep, 250
                addDataHwnd := CF_FindAddDataWindow()
                if (addDataHwnd)
                    break
            }
            if (!addDataHwnd) {
                MsgBox, 48, %CF_AppTitle%, Add Data screen did not open. Try clicking Add Data manually first.
                return
            }
            ; Extra delay for controls to fully load
            Sleep, %CF_AddDataDelay%
        }
        CF_ApplyTemplate(templatePath)
    }
return

CF_CancelLoad:
    Gui, 82:Destroy
return

CF_ApplyTemplate(templatePath) {
    global CF_AppTitle, NB_ApplySpeed, NB_SpeedOverride, CF_AutoSaveDelay, NB_ApplyCancelled

    targetHwnd := CF_FindAddDataWindow()
    if (!targetHwnd) {
        MsgBox, 48, %CF_AppTitle%, Not on the Add Data screen.`nClick Add Data first`, or check Auto-Add on the Booster panel.
        return
    }

    FileRead, content, %templatePath%
    if (ErrorLevel) {
        MsgBox, 48, %CF_AppTitle%, Failed to read template: %templatePath%
        return
    }

    ; Parse controls from JSON
    templateControls := CF_ParseControls(content)
    if (templateControls.Length() = 0) {
        MsgBox, 48, %CF_AppTitle%, Template has no controls.
        return
    }

    ; Determine effective speed: override → main panel, else → template speed (default 100ms for CPFS)
    cfTplSpeed := 100
    if (RegExMatch(content, """speed"":\s*(\d+)", spdM))
        cfTplSpeed := spdM1 + 0
    if (NB_SpeedOverride)
        cfEffectiveSpeed := NB_ApplySpeed
    else
        cfEffectiveSpeed := cfTplSpeed

    ToolTip, Scanning live controls...
    WinActivate, ahk_id %targetHwnd%
    Sleep, 300

    ; Wait for controls to stabilize (poll until count stops changing)
    prevCount := 0
    stableRounds := 0
    Loop, 20 {
        liveControls := CF_EnumFormControls(targetHwnd)
        curCount := liveControls.Length()
        if (curCount > 0 && curCount = prevCount) {
            stableRounds++
            if (stableRounds >= 2)
                break
        } else {
            stableRounds := 0
        }
        prevCount := curCount
        Sleep, 50
    }

    if (liveControls.Length() = 0) {
        MsgBox, 48, %CF_AppTitle%, No controls found in the current window.
        return
    }

    ; Match template controls to live controls by label + Y-position
    ; Use "claimed" tracking so duplicate labels (Yes/No) match by position order
    totalApplied := 0
    totalNotFound := 0
    cfNotFoundList := ""
    cfClaimed := {}  ; track which live indices are already matched
    cfAutoSaveCancelled := false

    ; Register right-click hotkey to set cancel flag
    NB_ApplyCancelled := false
    Hotkey, ~RButton, NB_CancelApplyHotkey, On

    cfTotalTpl := templateControls.Length()
    for ti, tplCtrl in templateControls {
        ; Cancel template apply on right-click
        if (NB_ApplyCancelled) {
            Hotkey, ~RButton, NB_CancelApplyHotkey, Off
            ToolTip, Template apply cancelled at control %ti%/%cfTotalTpl%.
            SetTimer, CF_ClearToolTip, -3000
            return
        }
        ; Check Esc to cancel auto-save throughout the apply process
        if (CF_AutoSave && GetKeyState("Escape", "P")) {
            cfAutoSaveCancelled := true
            ToolTip, AutoSave cancelled - still applying template
            SetTimer, CF_ClearToolTip, -2000
        }
        ; Extract all template control properties to plain variables (AHK v1 safe)
        cfTplType := tplCtrl.type
        cfTplLabel := tplCtrl.label
        cfTplChecked := tplCtrl.checked
        cfTplSelected := tplCtrl.selected
        cfTplValue := tplCtrl.value
        cfTplValueIdx := tplCtrl.valueIdx
        cfTplY := tplCtrl.y
        cfTplGroupLabel := tplCtrl.group_label
        cfTplCls := tplCtrl.cls

        ; Skip TDateTimePicker — saved as "radio" type but is actually a time/date control
        if (cfTplCls = "TDateTimePicker")
            continue

        ToolTip, Applying control %ti%/%cfTotalTpl%: %cfTplLabel%

        ; Find best matching live control (that hasn't been claimed yet)
        bestLiveIdx := 0
        bestScore := 0
        bestYDist := 999999

        for li, liveCtrl in liveControls {
            ; Skip already-claimed controls
            if (cfClaimed[li])
                continue

            ; Extract live control properties to plain variables
            cfLiveType := liveCtrl.type
            cfLiveLabel := liveCtrl.label
            cfLiveY := liveCtrl.y
            cfLiveParentLabel := liveCtrl.parentLabel

            ; Must be same type (checklist matches checklist)
            if (cfLiveType != cfTplType)
                continue

            score := 0

            ; Label match (highest priority)
            if (cfTplLabel != "" && cfLiveLabel = cfTplLabel) {
                score := 100
            }
            else if (cfTplLabel != "" && cfLiveLabel != "" && InStr(cfLiveLabel, cfTplLabel)) {
                score := 70
            }
            else if (cfTplLabel != "" && cfLiveLabel != "" && InStr(cfTplLabel, cfLiveLabel)) {
                score := 60
            }

            ; Y-position proximity bonus (if labels don't match, use position)
            if (score = 0 && cfTplLabel = "" && cfLiveLabel = "") {
                yDiff := Abs(cfLiveY - cfTplY)
                if (yDiff < 20)
                    score := 50
                else if (yDiff < 50)
                    score := 30
            }

            ; For radios, also check group label
            if (cfTplType = "radio" && cfTplGroupLabel != "" && cfLiveParentLabel = cfTplGroupLabel) {
                score += 20
            }

            ; When scores tie, prefer the one closest in Y position
            yDist := Abs(cfLiveY - cfTplY)
            if (score > bestScore || (score = bestScore && score > 0 && yDist < bestYDist)) {
                bestScore := score
                bestLiveIdx := li
                bestYDist := yDist
            }
        }

        if (bestLiveIdx = 0 || bestScore < 30) {
            totalNotFound++
            cfNotFoundList .= ti . ": " . cfTplType . " """ . cfTplLabel . """ (score=" . bestScore . ")`n"
            continue
        }

        ; Claim this live control so it can't be matched again
        cfClaimed[bestLiveIdx] := true

        cfMatchHwnd := liveControls[bestLiveIdx].hwnd

        ; Scroll the control into view before interacting
        CF_ScrollIntoView(cfMatchHwnd)

        ; Apply the state change
        if (cfTplType = "checkbox") {
            ; Check current state
            SendMessage, 0x00F0, 0, 0,, ahk_id %cfMatchHwnd%   ; BM_GETCHECK
            currentChecked := ErrorLevel ? true : false
            if (currentChecked != cfTplChecked) {
                PostMessage, 0x00F5, 0, 0,, ahk_id %cfMatchHwnd%   ; BM_CLICK
                totalApplied++
                Sleep, %cfEffectiveSpeed%
            }
        }
        else if (cfTplType = "checklist") {
            ; TCheckListBox item: select then ControlSend Space to toggle
            cfCLIdx := liveControls[bestLiveIdx].checklistIdx
            currentCLChecked := CF_ReadCheckListItemState(cfMatchHwnd, cfCLIdx)
            if (currentCLChecked != cfTplChecked) {
                SendMessage, 0x0186, cfCLIdx, 0,, ahk_id %cfMatchHwnd%   ; LB_SETCURSEL
                Sleep, 50
                ControlSend,, {Space}, ahk_id %cfMatchHwnd%
                totalApplied++
                Sleep, %cfEffectiveSpeed%
            }
        }
        else if (cfTplType = "radio") {
            if (cfTplSelected) {
                SendMessage, 0x00F0, 0, 0,, ahk_id %cfMatchHwnd%   ; BM_GETCHECK
                currentSelected := ErrorLevel ? true : false
                if (!currentSelected) {
                    PostMessage, 0x00F5, 0, 0,, ahk_id %cfMatchHwnd%   ; BM_CLICK
                    totalApplied++
                    Sleep, %cfEffectiveSpeed%
                }
            }
        }
        else if (cfTplType = "combo") {
            ; Combo boxes in CPFS are system settings (location, frequency, etc.)
            ; that should not be changed by template apply. Skip them entirely.
        }
    }

    Hotkey, ~RButton, NB_CancelApplyHotkey, Off

    CF_DismissIntermediatePopups()

    if (NB_DebugLogging) {
        WinGetTitle, cfApplyWinTitle, ahk_id %targetHwnd%
        cfApplyLiveControls := CF_EnumFormControls(targetHwnd)
        CF__LogControlStates("APPLY", cfApplyLiveControls, templatePath, cfApplyWinTitle, totalApplied, totalNotFound)
    }

    if (CF_AutoSave && totalApplied > 0) {
        ; Check if Esc/right-click was pressed at any point during apply
        if (cfAutoSaveCancelled || NB_ApplyCancelled || GetKeyState("Escape", "P")) {
            ToolTip, AutoSave cancelled - %totalApplied% applied`, review and save manually
            SetTimer, CF_ClearToolTip, -3000
            return
        }
        ; Wait before saving, then click Save (right-click or Esc cancels during delay)
        ToolTip, %totalApplied% applied - saving in %CF_AutoSaveDelay% ms... (right-click or Esc to cancel)
        Sleep, %CF_AutoSaveDelay%
        ; Re-check cancel after delay
        if (NB_ApplyCancelled || GetKeyState("Escape", "P")) {
            ToolTip, AutoSave cancelled - %totalApplied% applied`, review and save manually
            SetTimer, CF_ClearToolTip, -3000
            return
        }
        CF_ClickSaveButton(targetHwnd)
        ToolTip, %totalApplied% applied and saved
        SetTimer, CF_ClearToolTip, -3000
    } else if (CF_AutoSave && totalApplied = 0) {
        ToolTip, No controls applied - nothing to save
        SetTimer, CF_ClearToolTip, -3000
    } else {
        cfUnmatchedTip := "Done: " . totalApplied . " applied, " . totalNotFound . " not matched"
        if (cfNotFoundList != "")
            cfUnmatchedTip .= " [" . RTrim(cfNotFoundList, "`n") . "]"
        cfUnmatchedTip .= " - review before submitting"
        ToolTip, %cfUnmatchedTip%
        SetTimer, CF_ClearToolTip, -8000
    }

    ; Re-assert AlwaysOnTop on the panel — WinActivate on CPFS dialog strips it
    if (NB_BoosterGuiVisible = 1)
        WinSet, AlwaysOnTop, On, ahk_id %NB_PanelHwnd%
}


;============================================================================================
; CF - DELETE TEMPLATE
;============================================================================================

CF_BtnDeleteTemplate:
    global CF_TemplateDir, CF_AppTitle

    cfDelList := ""
    cfDelPaths := []
    Loop, Files, %CF_TemplateDir%\*.json
    {
        SplitPath, A_LoopFileFullPath,,,,nameNoExt
        cfDelList .= A_Index . ": " . nameNoExt . "`n"
        cfDelPaths.Push(A_LoopFileFullPath)
    }

    if (cfDelPaths.Length() = 0) {
        MsgBox, 64, %CF_AppTitle%, No CP Flowsheets templates to delete.
        return
    }

    InputBox, cfDelChoice, %CF_AppTitle% - Delete Template, Enter the number of the template to delete:`n`n%cfDelList%,, 350, 300
    if (ErrorLevel || cfDelChoice = "")
        return

    cfDelIdx := cfDelChoice + 0
    if (cfDelIdx < 1 || cfDelIdx > cfDelPaths.Length()) {
        MsgBox, 48, %CF_AppTitle%, Invalid selection.
        return
    }

    SplitPath, % cfDelPaths[cfDelIdx],,,,cfDelName
    MsgBox, 36, %CF_AppTitle%, Delete template "%cfDelName%"?
    IfMsgBox, Yes
    {
        FileDelete, % cfDelPaths[cfDelIdx]
        ToolTip, Template "%cfDelName%" deleted
        SetTimer, CF_ClearToolTip, -2000
    }
return


;============================================================================================
; CF - PARSE TEMPLATE JSON
;============================================================================================

CF_ParseControls(jsonContent) {
    controls := []

    ; Find the "controls" array
    cPos := InStr(jsonContent, """controls""")
    if (!cPos)
        return controls

    ; Find opening [
    arrStart := InStr(jsonContent, "[",, cPos)
    if (!arrStart)
        return controls

    ; Find matching ] using depth counting
    depth := 1
    scanPos := arrStart + 1
    arrEnd := 0
    while (scanPos <= StrLen(jsonContent) && depth > 0) {
        ch := SubStr(jsonContent, scanPos, 1)
        if (ch = "[")
            depth++
        else if (ch = "]")
            depth--
        if (depth = 0)
            arrEnd := scanPos
        scanPos++
    }
    if (!arrEnd)
        return controls

    ; Find each control object
    itemPos := arrStart
    while (true) {
        itemPos := InStr(jsonContent, "{",, itemPos + 1)
        if (!itemPos || itemPos > arrEnd)
            break
        itemEnd := InStr(jsonContent, "}",, itemPos)
        if (!itemEnd)
            break
        itemStr := SubStr(jsonContent, itemPos, itemEnd - itemPos + 1)

        ; Parse fields
        ctrlType := ""
        if (RegExMatch(itemStr, """type"":\s*""([^""]*)""", m))
            ctrlType := m1

        label := ""
        if (RegExMatch(itemStr, """label"":\s*""((?:[^""\\]|\\.)*)""", m))
            label := m1

        checked := InStr(itemStr, """checked"": true") || InStr(itemStr, """checked"":true") ? true : false
        selected := InStr(itemStr, """selected"": true") || InStr(itemStr, """selected"":true") ? true : false

        value := ""
        if (RegExMatch(itemStr, """value"":\s*""((?:[^""\\]|\\.)*)""", m))
            value := m1

        valueIdx := -1
        if (RegExMatch(itemStr, """valueIdx"":\s*(-?\d+)", m))
            valueIdx := m1 + 0

        yPos := 0
        if (RegExMatch(itemStr, """y"":\s*(-?\d+)", m))
            yPos := m1 + 0

        group_label := ""
        if (RegExMatch(itemStr, """group_label"":\s*""((?:[^""\\]|\\.)*)""", m))
            group_label := m1

        checklistIdx := -1
        if (RegExMatch(itemStr, """checklistIdx"":\s*(-?\d+)", m))
            checklistIdx := m1 + 0

        ctrlCls := ""
        if (RegExMatch(itemStr, """cls"":\s*""([^""]*)""", m))
            ctrlCls := m1

        entry := {type: ctrlType, label: label, checked: checked, selected: selected
            , value: value, valueIdx: valueIdx, y: yPos, group_label: group_label
            , checklistIdx: checklistIdx, cls: ctrlCls}
        controls.Push(entry)

        itemPos := itemEnd
    }

    return controls
}


;============================================================================================
; CF - SAFETY: DISMISS INTERMEDIATE POPUPS
;============================================================================================

CF_DismissIntermediatePopups() {
    Sleep, 150
    Loop, 3
    {
        found := false
        WinGet, wndList, List, ahk_exe CPFlowsheets.exe
        Loop, %wndList%
        {
            wnd := wndList%A_Index%
            WinGetClass, cls, ahk_id %wnd%

            ; Skip the main window
            WinGetPos,,, w, h, ahk_id %wnd%
            if (w > 500 || h > 400)
                continue

            ; Check for dangerous buttons
            if (CF_HasDangerousButton(wnd))
                continue

            ; Find and click OK button
            okHwnd := CF_FindOKButton(wnd)
            if (okHwnd) {
                PostMessage, 0x00F5, 0, 0,, ahk_id %okHwnd%  ; BM_CLICK
                Sleep, 200
                found := true
            }
        }
        if (!found)
            break
    }
}

CF_HasDangerousButton(windowHwnd) {
    global CF__hasDangerous
    CF__hasDangerous := false
    enumDang := RegisterCallback("CF__CheckDangerousCallback", "Fast")
    DllCall("EnumChildWindows", "Ptr", windowHwnd, "Ptr", enumDang, "Ptr", 0)
    return CF__hasDangerous
}

CF__CheckDangerousCallback(hwnd, lParam) {
    global CF__hasDangerous
    VarSetCapacity(buf, 512, 0)
    DllCall("GetClassName", "Ptr", hwnd, "Str", buf, "Int", 256)
    className := buf

    ; Text input fields = data entry form, not an OK popup
    if (InStr(className, "TEdit") || InStr(className, "TMemo") || InStr(className, "TRichEdit")
        || InStr(className, "Edit") || InStr(className, "RichEdit")) {
        CF__hasDangerous := true
        return 0
    }

    ; Check button text for dangerous labels
    if (InStr(className, "Button") || InStr(className, "TButton") || InStr(className, "TBitBtn")) {
        SendMessage, 0x000E, 0, 0,, ahk_id %hwnd%
        tLen := ErrorLevel
        if (tLen > 0 && tLen < 256) {
            VarSetCapacity(tBuf, (tLen + 1) * 2, 0)
            SendMessage, 0x000D, tLen + 1, &tBuf,, ahk_id %hwnd%
            StringUpper, textUpper, % StrGet(&tBuf)
            if (InStr(textUpper, "FINISH") || InStr(textUpper, "SUBMIT")
                || InStr(textUpper, "SIGN") || InStr(textUpper, "FILE")
                || InStr(textUpper, "COMPLETE") || InStr(textUpper, "SAVE")
                || InStr(textUpper, "DELETE") || InStr(textUpper, "REMOVE")) {
                CF__hasDangerous := true
                return 0
            }
        }
    }
    return 1
}

CF_FindOKButton(windowHwnd) {
    global CF__foundOKHwnd
    CF__foundOKHwnd := 0
    enumOK := RegisterCallback("CF__FindOKCallback", "Fast")
    DllCall("EnumChildWindows", "Ptr", windowHwnd, "Ptr", enumOK, "Ptr", 0)
    return CF__foundOKHwnd
}

CF__FindOKCallback(hwnd, lParam) {
    global CF__foundOKHwnd
    VarSetCapacity(buf, 512, 0)
    DllCall("GetClassName", "Ptr", hwnd, "Str", buf, "Int", 256)
    className := buf

    if !(InStr(className, "Button") || InStr(className, "TButton") || InStr(className, "TBitBtn"))
        return 1

    SendMessage, 0x000E, 0, 0,, ahk_id %hwnd%
    tLen := ErrorLevel
    if (tLen > 0 && tLen < 256) {
        VarSetCapacity(tBuf, (tLen + 1) * 2, 0)
        SendMessage, 0x000D, tLen + 1, &tBuf,, ahk_id %hwnd%
        StringUpper, textUpper, % StrGet(&tBuf)
        if (textUpper = "OK" || textUpper = "&OK" || textUpper = "CONTINUE"
            || textUpper = "&CONTINUE" || textUpper = "YES" || textUpper = "&YES") {
            CF__foundOKHwnd := hwnd
            return 0
        }
    }
    return 1
}


;============================================================================================
; CF - FIND AND CLICK SAVE BUTTON
;
; Finds the "Save" TButton in CP Flowsheets and clicks it.
; Used by AutoSave feature after template apply.
;============================================================================================

CF_ClickSaveButton(windowHwnd) {
    global CF_AppTitle, CF__foundSaveHwnd
    CF__foundSaveHwnd := 0
    enumSave := RegisterCallback("CF__FindSaveCallback", "Fast")
    DllCall("EnumChildWindows", "Ptr", windowHwnd, "Ptr", enumSave, "Ptr", 0)

    if (CF__foundSaveHwnd) {
        PostMessage, 0x00F5, 0, 0,, ahk_id %CF__foundSaveHwnd%   ; BM_CLICK
        ToolTip, AutoSave: Save clicked
        SetTimer, CF_ClearToolTip, -2000
    } else {
        ToolTip, AutoSave: Save button not found - save manually
        SetTimer, CF_ClearToolTip, -3000
    }
}

CF__FindSaveCallback(hwnd, lParam) {
    global CF__foundSaveHwnd

    ; Skip invisible
    cfStyle := DllCall("GetWindowLong", "Ptr", hwnd, "Int", -16, "UInt")
    if !(cfStyle & 0x10000000)
        return 1

    VarSetCapacity(buf, 512, 0)
    DllCall("GetClassName", "Ptr", hwnd, "Str", buf, "Int", 256)
    className := buf

    if !(InStr(className, "Button") || InStr(className, "TButton"))
        return 1

    ; Get button text
    VarSetCapacity(tBuf, 256, 0)
    DllCall("GetWindowText", "Ptr", hwnd, "Str", tBuf, "Int", 128)
    btnText := tBuf

    if (btnText = "Save" || btnText = "&Save") {
        CF__foundSaveHwnd := hwnd
        return 0
    }
    return 1
}


;============================================================================================
; CF - SCROLL INTO VIEW
;
; Scrolls the parent TScrollBox so the target control is visible.
; Walks up the parent chain to find a TScrollBox, then scrolls it.
;============================================================================================

CF_ScrollIntoView(controlHwnd) {
    ; Find the parent TScrollBox
    scrollBoxHwnd := 0
    parent := controlHwnd
    Loop, 10
    {
        parent := DllCall("GetParent", "Ptr", parent, "Ptr")
        if (!parent)
            break
        VarSetCapacity(pBuf, 512, 0)
        DllCall("GetClassName", "Ptr", parent, "Str", pBuf, "Int", 256)
        pClass := pBuf
        if (pClass = "TScrollBox") {
            scrollBoxHwnd := parent
            break
        }
    }
    if (!scrollBoxHwnd)
        return

    ; Get scroll box client rect (visible area)
    VarSetCapacity(sbRect, 16, 0)
    DllCall("GetWindowRect", "Ptr", scrollBoxHwnd, "Ptr", &sbRect)
    sbTop := NumGet(sbRect, 4, "Int")
    sbBottom := NumGet(sbRect, 12, "Int")

    ; Get control screen rect
    VarSetCapacity(ctrlRect, 16, 0)
    DllCall("GetWindowRect", "Ptr", controlHwnd, "Ptr", &ctrlRect)
    ctrlTop := NumGet(ctrlRect, 4, "Int")
    ctrlBottom := NumGet(ctrlRect, 12, "Int")

    ; If already visible, no scroll needed
    if (ctrlTop >= sbTop && ctrlBottom <= sbBottom)
        return

    ; Calculate how much to scroll
    if (ctrlBottom > sbBottom) {
        scrollAmount := ctrlBottom - sbBottom + 30
    } else {
        scrollAmount := ctrlTop - sbTop - 30
    }

    ; Get current scroll position
    VarSetCapacity(si, 28, 0)
    NumPut(28, si, 0, "UInt")
    NumPut(0x17, si, 4, "UInt")   ; SIF_ALL
    DllCall("GetScrollInfo", "Ptr", scrollBoxHwnd, "Int", 1, "Ptr", &si)  ; SB_VERT=1
    currentPos := NumGet(si, 20, "Int")

    ; Set new position
    newPos := currentPos + scrollAmount
    NumPut(newPos, si, 20, "Int")
    NumPut(0x04, si, 4, "UInt")   ; SIF_POS
    DllCall("SetScrollInfo", "Ptr", scrollBoxHwnd, "Int", 1, "Ptr", &si, "Int", 1)

    ; Notify the scrollbox to scroll
    wParam := (newPos << 16) | 4  ; SB_THUMBPOSITION=4
    PostMessage, 0x0115, wParam, 0,, ahk_id %scrollBoxHwnd%  ; WM_VSCROLL
    Sleep, 80
}


;============================================================================================
; CF - UTILITY FUNCTIONS
;============================================================================================

CF_EscJson(str) {
    str := StrReplace(str, "\", "\\")
    str := StrReplace(str, """", "\""")
    str := StrReplace(str, "`n", "\n")
    str := StrReplace(str, "`r", "\r")
    str := StrReplace(str, "`t", "\t")
    return """" . str . """"
}

CF_SanitizeFilename(name) {
    name := Trim(name)
    name := RegExReplace(name, "[<>:""/\\|?*]", "_")
    return name
}

CF_ClearToolTip:
    ToolTip
return


;============================================================================================
; CF - HOTKEY: Ctrl+Shift+F - Spy dump CP Flowsheets
;============================================================================================

^+f::
    gosub CF_SpyDumpControls
return


;============================================================================================
; CTRL+SHIFT+I - Control Inspector (Window Spy replacement)
; Hover mouse over any control and press Ctrl+Shift+I to see its info.
;============================================================================================

^+i::
    CoordMode, Mouse, Screen
    MouseGetPos, mX, mY, winUnderMouse, ctrlHwnd, 2  ; 2 = get HWND
    if (!ctrlHwnd)
        ctrlHwnd := winUnderMouse

    ; Control class
    VarSetCapacity(clsBuf, 256, 0)
    DllCall("GetClassName", "Ptr", ctrlHwnd, "Str", clsBuf, "Int", 256)

    ; Control text
    VarSetCapacity(txtBuf, 512, 0)
    DllCall("GetWindowText", "Ptr", ctrlHwnd, "Str", txtBuf, "Int", 256)

    ; Control rect
    VarSetCapacity(rc, 16, 0)
    DllCall("GetWindowRect", "Ptr", ctrlHwnd, "Ptr", &rc)
    rcX := NumGet(rc, 0, "Int"), rcY := NumGet(rc, 4, "Int")
    rcW := NumGet(rc, 8, "Int") - rcX, rcH := NumGet(rc, 12, "Int") - rcY

    ; Parent info
    parentHwnd := DllCall("GetParent", "Ptr", ctrlHwnd, "Ptr")
    VarSetCapacity(pClsBuf, 256, 0)
    VarSetCapacity(pTxtBuf, 512, 0)
    if (parentHwnd) {
        DllCall("GetClassName", "Ptr", parentHwnd, "Str", pClsBuf, "Int", 256)
        DllCall("GetWindowText", "Ptr", parentHwnd, "Str", pTxtBuf, "Int", 256)
    }

    ; Window info
    VarSetCapacity(wClsBuf, 256, 0)
    VarSetCapacity(wTxtBuf, 512, 0)
    DllCall("GetClassName", "Ptr", winUnderMouse, "Str", wClsBuf, "Int", 256)
    DllCall("GetWindowText", "Ptr", winUnderMouse, "Str", wTxtBuf, "Int", 256)

    ; Style
    style := DllCall("GetWindowLong", "Ptr", ctrlHwnd, "Int", -16, "UInt")
    visible := (style & 0x10000000) ? "Y" : "N"

    info := "=== Control Inspector ===`n"
    info .= "Mouse: " . mX . ", " . mY . "`n"
    info .= "---`n"
    info .= "Control HWND: " . ctrlHwnd . " (0x" . Format("{:x}", ctrlHwnd) . ")`n"
    info .= "Control Class: " . clsBuf . "`n"
    info .= "Control Text: " . (txtBuf != "" ? txtBuf : "(empty)") . "`n"
    info .= "Pos: " . rcX . "," . rcY . " Size: " . rcW . "x" . rcH . "`n"
    info .= "Visible: " . visible . "`n"
    info .= "---`n"
    info .= "Parent HWND: " . parentHwnd . "`n"
    info .= "Parent Class: " . pClsBuf . "`n"
    info .= "Parent Text: " . (pTxtBuf != "" ? pTxtBuf : "(empty)") . "`n"
    info .= "---`n"
    info .= "Window HWND: " . winUnderMouse . "`n"
    info .= "Window Class: " . wClsBuf . "`n"
    info .= "Window Title: " . wTxtBuf

    MsgBox, 64, Control Inspector, %info%
return


;############################################################################################
;################### END CP FLOWSHEETS BOOSTER ###############################################

    if (NB_SignWasVisible = 1)
    {
        Gui, 80:Show, NA
        WinSet, AlwaysOnTop, On, ahk_id %NB_PanelHwnd%
        NB_BoosterGuiVisible := 1
    }
return

#If  ; Restore default hotkey context
