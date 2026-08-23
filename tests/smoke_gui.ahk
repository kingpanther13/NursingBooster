; ===========================================================================
; smoke_gui.ahk - GUI smoke test for the real module on a live desktop.
;
; Runs on the windows-latest runner (interactive desktop). Initializes the
; module for real (NB_Enabled=1, temp onedrivelocal), then asserts the
; focus/z-order contracts that broke historically:
;   - the panel toggles visible WITHOUT stealing activation (Show NA fix)
;   - F-key press hides the panel fast; it restores ~6s later, again
;     without stealing activation
;   - Ctrl+Shift+B is registered and toggles the panel
;   - the Gui 85 drop-up appears next to a window titled "fxnbar",
;     follows it when it moves, is left alone while its list is open
;     (CB_GETDROPPEDSTATE guard), and disappears when the bar dies
;   - quick-action button labels come from the selected template's name and
;     are shrunk/trimmed to fit the 68px buttons
;   - an InputBox armed via NB_ArmTopmostDialog is pinned topmost while open
;   - the Settings window opens above a later stay-on-top window
;   - the CPRS/CPFS panel dropdowns exist, open on the no-activate panel,
;     route every pick to its action and snap back to the header; AutoSave
;     is gone; every panel control fits the panel
;   - Advanced Mode is applied at init and resizes/hides on toggle
;
; Output: PASS/FAIL lines on stdout; exit code = number of failures.
; Run with: AutoHotkeyU64.exe /ErrorStdOut smoke_gui.ahk
; ===========================================================================
#NoEnv
#SingleInstance force
SetBatchLines, -1
SetTitleMatchMode, 2

global SmokeFails := 0

; --- Host stubs, then real module init ---
NB_Enabled := 1
onedrivelocal := A_Temp . "\nb_smoke_" . A_TickCount
FileCreateDir, %onedrivelocal%

gosub NB_ModuleInit

; --- 1. Panel exists but is hidden after init ---
DetectHiddenWindows, On
SmokeAssert(WinExist("NursingBoosterPanel") != 0, "panel window created by init")
DetectHiddenWindows, Off
SmokeAssert(!WinExist("NursingBoosterPanel"), "panel starts hidden")

; --- 2. A focus-holder window to detect activation stealing ---
Gui, 2:Add, Text,, focus holder
Gui, 2:Show, x60 y60 w220 h90, NBSmokeFocusHolder
WinActivate, NBSmokeFocusHolder
WinWaitActive, NBSmokeFocusHolder,, 3
SmokeAssert(WinActive("NBSmokeFocusHolder") != 0, "focus holder active")

; --- 3. Toggle panel on: visible, still no activation steal ---
gosub NB_TogglePanel
Sleep, 400
SmokeAssert(WinExist("NursingBoosterPanel") != 0, "panel visible after toggle")
SmokeAssert(NB_BoosterGuiVisible = 1, "NB_BoosterGuiVisible set")
SmokeAssert(WinActive("NBSmokeFocusHolder") != 0, "toggle did NOT steal activation (Show NA)")

; --- 4. Sign-dialog auto-hide. (F-key injection CANNOT be tested here: the
;        module's #If-scoped hotkeys install the keyboard hook, and the hook
;        excludes injected input (LLKHF_INJECTED) from the physical state, so
;        a Send'd F1 never reads as physically down. The same 30ms poll also
;        hides on a CPRS Sign window - drive that path with a stub Sign Note
;        window from a CPRSChart.exe-named process.) ---
signStub := A_Temp . "\CPRSChart.exe"
SmokeAssert(FileExist(signStub) != "", "CPRSChart.exe stub runner present")
Run, "%signStub%" /ErrorStdOut "%A_ScriptDir%\smoke_sign_stub.ahk"
WinWait, Sign Note ahk_exe CPRSChart.exe,, 5
SmokeAssert(!ErrorLevel, "stub Sign Note window appeared")
hidden := false
start := A_TickCount
while (A_TickCount - start < 1500)
{
    if (NB_BoosterGuiVisible = 0)
    {
        hidden := true
        break
    }
    Sleep, 50
}
SmokeAssert(hidden, "panel hidden while Sign window open (took " . (A_TickCount - start) . "ms)")
SmokeAssert(NB_SignWasVisible = 1, "restore state armed")

; --- 5. Close the sign window; auto-restore ~6s later, no activation steal ---
WinClose, Sign Note ahk_exe CPRSChart.exe
Process, WaitClose, CPRSChart.exe, 5
WinActivate, NBSmokeFocusHolder
Sleep, 6600
SmokeAssert(NB_BoosterGuiVisible = 1, "panel auto-restored after ~6s")
SmokeAssert(WinActive("NBSmokeFocusHolder") != 0, "restore did NOT steal activation")

; --- 6. Ctrl+Shift+B registered: hide, then re-show via the hotkey ---
gosub NB_TogglePanel   ; hide
Sleep, 200
SmokeAssert(NB_BoosterGuiVisible = 0, "panel hidden before hotkey test")
Send, ^+b
Sleep, 500
SmokeAssert(NB_BoosterGuiVisible = 1, "Ctrl+Shift+B re-shows the panel")

; --- 7. Mini drop-up bar appears next to a window titled fxnbar ---
Gui, 3:Add, Text,, fake function bar
Gui, 3:+AlwaysOnTop -Caption +ToolWindow
Gui, 3:Show, x100 y600 w300 h21, fxnbar
found := SmokeWaitExist("NB_MiniBar", 3000)
SmokeAssert(found, "mini bar appears next to fxnbar")
WinGetPos, mbX, mbY,,, NB_MiniBar
SmokeAssert(Abs(mbX - 402) <= 8, "mini bar docked at bar's right edge (x=" . mbX . ")")

; --- 8. Mini bar follows the bar when it moves ---
WinMove, fxnbar,, 150, 600
moved := SmokeWaitX("NB_MiniBar", 452, 8, 2500)
SmokeAssert(moved, "mini bar follows the bar (moved to x~452)")

; --- 9. Open drop-up list; the follow timer must leave it alone ---
hDDL := NB_MiniDDLHwnd
SmokeAssert(hDDL != 0, "drop-up control hwnd captured")
SendMessage, 0x014F, 1, 0,, ahk_id %hDDL%   ; CB_SHOWDROPDOWN open
Sleep, 200
SendMessage, 0x0157, 0, 0,, ahk_id %hDDL%   ; CB_GETDROPPEDSTATE
SmokeAssert(ErrorLevel = 1, "drop-up list opened")
WinMove, fxnbar,, 200, 600
Sleep, 1400                                  ; several 500ms follow ticks
SendMessage, 0x0157, 0, 0,, ahk_id %hDDL%
SmokeAssert(ErrorLevel = 1, "list still open - follow timer left it alone")
WinGetPos, mbX2,,,, NB_MiniBar
SmokeAssert(Abs(mbX2 - 452) <= 8, "mini bar did not move while list open (x=" . mbX2 . ")")
SendMessage, 0x014F, 0, 0,, ahk_id %hDDL%   ; close the list
moved2 := SmokeWaitX("NB_MiniBar", 502, 8, 2500)
SmokeAssert(moved2, "mini bar catches up after the list closes (x~502)")

; --- 10. Bar destroyed -> mini bar goes away ---
Gui, 3:Destroy
gone := SmokeWaitGone("NB_MiniBar", 2500)
SmokeAssert(gone, "mini bar removed when fxnbar dies")

; --- 11. Disable guard: ^+b stays registered until the host unhooks it,
;         so NB_TogglePanel itself must refuse to SHOW while disabled ---
gosub NB_TogglePanel   ; hide (hiding is allowed even when disabled)
Sleep, 200
SmokeAssert(NB_BoosterGuiVisible = 0, "panel hidden before disable-guard test")
NB_Enabled := 0
Send, ^+b
Sleep, 400
SmokeAssert(NB_BoosterGuiVisible = 0, "^+b does NOT re-show the panel while disabled")
NB_Enabled := 1

; --- 12. Quick-action button labels derive from the action and fit the
;         68px buttons: long names are trimmed with an ellipsis, short names
;         shown verbatim, empty slots fall back to "Quick N" ---
NB_HK1_Action := "nb_template:Neurological Assessment Negative Findings"
NB_HK1_Label := NB_HKLabelFromAction(NB_HK1_Action, "Quick 1")
NB_HK2_Action := "cf_template:Vitals"
NB_HK2_Label := NB_HKLabelFromAction(NB_HK2_Action, "Quick 2")
NB_HK3_Action := ""
NB_HK3_Label := NB_HKLabelFromAction(NB_HK3_Action, "Quick 3")
NB_ApplyHKButtonLabels()
ell := A_IsUnicode ? Chr(0x2026) : "..."
GuiControlGet, hkText1, 80:, NB_HK1_Btn
GuiControlGet, hkText2, 80:, NB_HK2_Btn
GuiControlGet, hkText3, 80:, NB_HK3_Btn
GuiControlGet, hkBtn1, 80:Hwnd, NB_HK1_Btn
SendMessage, 0x31, 0, 0,, ahk_id %hkBtn1%   ; WM_GETFONT
hkFont1 := ErrorLevel
VarSetCapacity(hkRc, 16, 0)
DllCall("GetClientRect", "Ptr", hkBtn1, "Ptr", &hkRc)
hkBtnW := NumGet(hkRc, 8, "Int")
SmokeAssert(hkText1 != NB_HK1_Label && SubStr(hkText1, 1 - StrLen(ell)) = ell, "long quick label trimmed with ellipsis ('" . hkText1 . "')")
SmokeAssert(NB_TextWidthPx(hkBtn1, hkFont1, hkText1) < hkBtnW, "trimmed quick label fits inside the " . hkBtnW . "px button")
SmokeAssert(hkText2 = "Vitals", "short quick label shown verbatim")
SmokeAssert(hkText3 = "Quick 3", "empty slot falls back to Quick 3")

; --- 12b. The middle branch: a name that is too wide at s7 but fits at s6 is
;          shown whole (shrunk, not trimmed). Button 2 now carries the s7 font
;          and button 1 the s6 font, so measure candidates with both and pick
;          a prefix of the long name that sits in that band. ---
GuiControlGet, hkBtn2, 80:Hwnd, NB_HK2_Btn
SendMessage, 0x31, 0, 0,, ahk_id %hkBtn2%   ; WM_GETFONT (s7)
hkFont7 := ErrorLevel
hkFont6 := hkFont1                          ; button 1 was shrunk to s6 above
hkUsable := hkBtnW - Round(10 * A_ScreenDPI / 96)
hkCand := ""
hkKeep := StrLen(NB_HK1_Label)
while (hkKeep > 0)
{
    hkTry := RTrim(SubStr(NB_HK1_Label, 1, hkKeep))
    if (NB_TextWidthPx(hkBtn1, hkFont7, hkTry) > hkUsable && NB_TextWidthPx(hkBtn1, hkFont6, hkTry) <= hkUsable)
    {
        hkCand := hkTry
        break
    }
    hkKeep -= 1
}
SmokeAssert(hkCand != "", "found a name that fits only at s6 (band " . hkUsable . "px)")
hkShown := NB_FitHKButtonText("NB_HK4_Btn", hkCand)
GuiControlGet, hkBtn4, 80:Hwnd, NB_HK4_Btn
SendMessage, 0x31, 0, 0,, ahk_id %hkBtn4%
hkFont4 := ErrorLevel
SmokeAssert(hkShown = hkCand, "s6-only name shown whole, not trimmed ('" . hkShown . "')")
SmokeAssert(NB_TextWidthPx(hkBtn4, hkFont4, hkCand) <= hkUsable, "button 4 now wears a font that fits the name (shrunk to s6)")

; --- 13. Issue #13: an InputBox armed via NB_ArmTopmostDialog is pinned
;         topmost (WS_EX_TOPMOST) and activated by the raise timer while it is
;         still open. Timers keep firing during InputBox, so a one-shot probe
;         inspects the live dialog and then cancels it (8s timeout backstop). ---
SmokeProbeExStyle := ""
SmokeProbeActive := ""
SetTimer, SmokeProbeInputBox, -1500
NB_ArmTopmostDialog("NB Smoke Prompt")
InputBox, smokeIn, NB Smoke Prompt, probe, , , , , , , 8
SmokeAssert(SmokeProbeExStyle != "" && (SmokeProbeExStyle & 0x8), "armed InputBox pinned topmost (exstyle=" . SmokeProbeExStyle . ")")
SmokeAssert(SmokeProbeActive = 1, "armed InputBox was activated")

; --- 14. Settings window opens ABOVE a stay-on-top window that appeared after
;         init. Gui 84 is shown NA (never activates), which keeps its old
;         z-position below any later topmost window; the toggle must re-assert
;         topmost so it lands on top (dev23 fix). ---
Gui, 4:Add, Text,, fake stay-on-top dialog
Gui, 4:+AlwaysOnTop +HwndSmokeTopHwnd
Gui, 4:Show, x0 y0 w420 h320, NBSmokeTopmostDialog   ; activated -> top of the topmost band
Sleep, 300
gosub NB_ToggleSettings
Sleep, 300
SmokeAssert(NB_SettingsVisible = 1 && WinExist("ahk_id " . NB_SettingsHwnd), "settings window shown")
SmokeAssert(DllCall("GetWindow", "Ptr", NB_SettingsHwnd, "UInt", 4, "Ptr") = NB_PanelHwnd, "settings window is owned by the panel (GW_OWNER)")
SmokeAssert(WinActive("ahk_id " . SmokeTopHwnd) != 0, "settings open did NOT steal activation")
WinGet, smokeSetEx, ExStyle, ahk_id %NB_SettingsHwnd%
SmokeAssert(smokeSetEx != "" && (smokeSetEx & 0x8), "settings window is topmost (exstyle=" . smokeSetEx . ")")
WinGet, smokeZ, List
smokeSetIdx := 0
smokeTopIdx := 0
Loop, %smokeZ%
{
    if (smokeZ%A_Index% = NB_SettingsHwnd)
        smokeSetIdx := A_Index
    if (smokeZ%A_Index% = SmokeTopHwnd)
        smokeTopIdx := A_Index
}
SmokeAssert(smokeSetIdx > 0 && smokeTopIdx > 0 && smokeSetIdx < smokeTopIdx, "settings window sits above the later stay-on-top window (z " . smokeSetIdx . " < " . smokeTopIdx . ")")
gosub NB_ToggleSettings   ; hide again
Gui, 4:Destroy

; --- 15. Issue #8: one dropdown per section replaces the Save/Load/Del
;         buttons; AutoSave is gone - that assertion is a patient-safety
;         regression guard (it clicked Save in CP Flowsheets, writing to the
;         record without a final review), not a layout check. The six picks
;         are driven for real: with no CPRS/CPFS window and an empty save
;         folder each lands on a distinct modal MsgBox that a one-shot probe
;         reads and closes. ---
if (NB_BoosterGuiVisible = 0)
    gosub NB_TogglePanel
Sleep, 300
SmokeAssert(NB_BoosterGuiVisible = 1, "panel visible for the dropdown checks")
GuiControlGet, hCprsMenu, 80:Hwnd, NB_CprsMenuChoice
SmokeAssert(!ErrorLevel && hCprsMenu != "", "CPRS dropdown exists")
GuiControlGet, hCfMenu, 80:Hwnd, CF_MenuChoice
SmokeAssert(!ErrorLevel && hCfMenu != "", "CPFS dropdown exists")
SendMessage, 0x0146, 0, 0,, ahk_id %hCprsMenu%   ; CB_GETCOUNT
cprsItems := ErrorLevel
SendMessage, 0x0146, 0, 0,, ahk_id %hCfMenu%
cfItems := ErrorLevel
SmokeAssert(cprsItems = 4, "CPRS dropdown has header + Save/Load/Delete (" . cprsItems . ")")
SmokeAssert(cfItems = 4, "CPFS dropdown has header + Save/Load/Delete (" . cfItems . ")")
; AltSubmit contract the handlers depend on: GuiControlGet yields the position
GuiControl, 80:Choose, NB_CprsMenuChoice, 2
GuiControlGet, cprsPick, 80:, NB_CprsMenuChoice
SmokeAssert(cprsPick = 2, "AltSubmit dropdown reads back a position index ('" . cprsPick . "')")
GuiControl, 80:Choose, NB_CprsMenuChoice, 1
; The lists open on the no-activate panel (same contract as the Gui 85 bar)
SendMessage, 0x014F, 1, 0,, ahk_id %hCprsMenu%   ; CB_SHOWDROPDOWN open
Sleep, 300
SendMessage, 0x0157, 0, 0,, ahk_id %hCprsMenu%   ; CB_GETDROPPEDSTATE
cprsDropped := ErrorLevel
SendMessage, 0x014F, 0, 0,, ahk_id %hCprsMenu%   ; close
SmokeAssert(cprsDropped = 1, "CPRS dropdown list opens on the no-activate panel")
SendMessage, 0x014F, 1, 0,, ahk_id %hCfMenu%
Sleep, 300
SendMessage, 0x0157, 0, 0,, ahk_id %hCfMenu%
cfDropped := ErrorLevel
SendMessage, 0x014F, 0, 0,, ahk_id %hCfMenu%
SmokeAssert(cfDropped = 1, "CPFS dropdown list opens on the no-activate panel")
; Routing: every index reaches its action (each first guard is a distinct
; MsgBox body) and the dropdown is back on its header afterwards
smokePicks := [ ["NB_CprsMenuChoice", "NB_CprsMenuAction", 2, hCprsMenu, "reminder dialogue in CPRS first", "CPRS pick 2 -> Save"]
              , ["NB_CprsMenuChoice", "NB_CprsMenuAction", 3, hCprsMenu, "first, then load", "CPRS pick 3 -> Load"]
              , ["NB_CprsMenuChoice", "NB_CprsMenuAction", 4, hCprsMenu, "Nothing saved to delete", "CPRS pick 4 -> Delete"]
              , ["CF_MenuChoice", "CF_MenuAction", 2, hCfMenu, "navigate to the Add Data screen first", "CPFS pick 2 -> Save"]
              , ["CF_MenuChoice", "CF_MenuAction", 3, hCfMenu, "Open CP Flowsheets first.", "CPFS pick 3 -> Load"]
              , ["CF_MenuChoice", "CF_MenuAction", 4, hCfMenu, "Nothing saved for CP Flowsheets to delete", "CPFS pick 4 -> Delete"] ]
for smokeI, smokeP in smokePicks
{
    SmokeProbeMsgText := ""
    SmokeProbeTries := 0
    GuiControl, 80:Choose, % smokeP[1], % smokeP[3]
    SetTimer, SmokeProbeMsgBox, -1000
    smokeHandler := smokeP[2]
    Gosub, %smokeHandler%
    smokeH := smokeP[4]
    SendMessage, 0x0147, 0, 0,, ahk_id %smokeH%   ; CB_GETCURSEL
    smokeSel := ErrorLevel
    SmokeAssert(InStr(SmokeProbeMsgText, smokeP[5]) != 0, smokeP[6] . " (got '" . SubStr(SmokeProbeMsgText, 1, 70) . "')")
    SmokeAssert(smokeSel = 0, smokeP[6] . " - dropdown snapped back to its header (" . smokeSel . ")")
}
GuiControlGet, hAutoSave, 80:Hwnd, CF_AutoSaveChk
SmokeAssert(ErrorLevel = 1 && hAutoSave = "", "AutoSave checkbox no longer exists")
GuiControlGet, hAutoAdd, 80:Hwnd, CF_AutoAddChk
SmokeAssert(!ErrorLevel && hAutoAdd != "", "Auto-Add checkbox still present")
; Every panel control ends inside the panel's client width (physical px)
VarSetCapacity(pnRc, 16, 0)
DllCall("GetClientRect", "Ptr", NB_PanelHwnd, "Ptr", &pnRc)
pnW := NumGet(pnRc, 8, "Int")
WinGet, pnCtrls, ControlListHwnd, ahk_id %NB_PanelHwnd%
pnOverflow := ""
Loop, Parse, pnCtrls, `n
{
    if (A_LoopField = "")
        continue
    VarSetCapacity(cRc, 16, 0)
    DllCall("GetWindowRect", "Ptr", A_LoopField, "Ptr", &cRc)
    VarSetCapacity(cPt, 8, 0)
    NumPut(NumGet(cRc, 8, "Int"), cPt, 0, "Int")    ; right
    NumPut(NumGet(cRc, 12, "Int"), cPt, 4, "Int")   ; bottom
    DllCall("ScreenToClient", "Ptr", NB_PanelHwnd, "Ptr", &cPt)
    if (NumGet(cPt, 0, "Int") > pnW)
        pnOverflow .= A_LoopField . " "
}
SmokeAssert(pnOverflow = "", "every panel control ends inside the " . pnW . "px panel" . (pnOverflow != "" ? " (overflow: " . pnOverflow . ")" : ""))

; --- 16. Advanced Mode: the persisted setting is applied at init (fresh ini
;         -> off), so the first Settings open is the compact panel; toggling
;         resizes the window and shows/hides the advanced controls ---
VarSetCapacity(stRc, 16, 0)
DllCall("GetClientRect", "Ptr", NB_SettingsHwnd, "Ptr", &stRc)
stH0 := NumGet(stRc, 12, "Int")
GuiControlGet, hDbgChk, 84:Hwnd, NB_DebugLogChk
SmokeAssert(NB_AdvancedMode = 0, "fresh settings -> Advanced Mode off")
SmokeAssert(stH0 = Round(65 * A_ScreenDPI / 96), "settings window compact after init (client h=" . stH0 . ")")
SmokeAssert(!(DllCall("GetWindowLong", "Ptr", hDbgChk, "Int", -16, "UInt") & 0x10000000), "advanced control hidden at init")
NB_AdvancedMode := 1
gosub NB_ApplyAdvancedMode
DllCall("GetClientRect", "Ptr", NB_SettingsHwnd, "Ptr", &stRc)
stH1 := NumGet(stRc, 12, "Int")
SmokeAssert(stH1 = Round(164 * A_ScreenDPI / 96), "advanced on -> expanded (client h=" . stH1 . ")")
SmokeAssert((DllCall("GetWindowLong", "Ptr", hDbgChk, "Int", -16, "UInt") & 0x10000000) != 0, "advanced on -> advanced control visible")
NB_AdvancedMode := 0
gosub NB_ApplyAdvancedMode
DllCall("GetClientRect", "Ptr", NB_SettingsHwnd, "Ptr", &stRc)
stH2 := NumGet(stRc, 12, "Int")
SmokeAssert(stH2 = Round(65 * A_ScreenDPI / 96), "advanced off -> compact again (client h=" . stH2 . ")")

; --- Summary ---
if (SmokeFails > 0)
{
    FileAppend, % "FAIL: " . SmokeFails . " smoke assertion(s) failed`n", **
    ExitApp, %SmokeFails%
}
FileAppend, % "All GUI smoke assertions passed`n", *
ExitApp, 0

; Fires while the section-13 InputBox is open: record its ex-style and
; activation, then cancel it so the main thread continues.
SmokeProbeInputBox:
    WinGet, SmokeProbeExStyle, ExStyle, NB Smoke Prompt ahk_class #32770
    SmokeProbeActive := WinActive("NB Smoke Prompt ahk_class #32770") ? 1 : 0
    WinClose, NB Smoke Prompt ahk_class #32770
return

; Fires while a module MsgBox (class #32770, our own pid) is up: capture its
; body text and close it so the main thread continues. Re-arms itself for up
; to ~10 s if the dialog is not up yet, so a slow runner cannot hang the job.
SmokeProbeMsgBox:
    SmokeProbePid := DllCall("GetCurrentProcessId")
    if (!WinExist("ahk_class #32770 ahk_pid " . SmokeProbePid))
    {
        SmokeProbeTries += 1
        if (SmokeProbeTries < 40)
            SetTimer, SmokeProbeMsgBox, -250
        return
    }
    WinGetText, SmokeProbeMsgText, ahk_class #32770 ahk_pid %SmokeProbePid%
    WinClose, ahk_class #32770 ahk_pid %SmokeProbePid%
return

; ---------------------------------------------------------------------------
SmokeAssert(cond, msg)
{
    global SmokeFails
    if (cond)
        FileAppend, % "PASS: " . msg . "`n", *
    else
    {
        SmokeFails += 1
        FileAppend, % "FAIL: " . msg . "`n", *
    }
}

SmokeWaitExist(title, timeoutMs)
{
    start := A_TickCount
    while (A_TickCount - start < timeoutMs)
    {
        if WinExist(title)
            return true
        Sleep, 100
    }
    return false
}

SmokeWaitGone(title, timeoutMs)
{
    start := A_TickCount
    while (A_TickCount - start < timeoutMs)
    {
        if !WinExist(title)
            return true
        Sleep, 100
    }
    return false
}

SmokeWaitX(title, wantX, tol, timeoutMs)
{
    start := A_TickCount
    while (A_TickCount - start < timeoutMs)
    {
        WinGetPos, x,,,, %title%
        if (x != "" && Abs(x - wantX) <= tol)
            return true
        Sleep, 100
    }
    return false
}

; --- The real module (label never auto-runs; init called above via gosub) ---
#Include %A_ScriptDir%\..\nursingbooster_module.ahk
