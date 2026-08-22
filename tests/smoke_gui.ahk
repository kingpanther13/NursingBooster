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
;         buttons; AutoSave is gone. Structural only - picking an item would
;         open a modal prompt. ---
GuiControlGet, hCprsMenu, 80:Hwnd, NB_CprsMenuChoice
GuiControlGet, hCfMenu, 80:Hwnd, CF_MenuChoice
SmokeAssert(hCprsMenu != 0 && hCfMenu != 0, "CPRS and CPFS dropdowns exist")
SendMessage, 0x0146, 0, 0,, ahk_id %hCprsMenu%   ; CB_GETCOUNT
SmokeAssert(ErrorLevel = 4, "CPRS dropdown has header + Save/Load/Delete (" . ErrorLevel . ")")
SendMessage, 0x0146, 0, 0,, ahk_id %hCfMenu%
SmokeAssert(ErrorLevel = 4, "CPFS dropdown has header + Save/Load/Delete (" . ErrorLevel . ")")
SendMessage, 0x0147, 0, 0,, ahk_id %hCprsMenu%   ; CB_GETCURSEL
SmokeAssert(ErrorLevel = 0, "CPRS dropdown rests on its header")
SendMessage, 0x0147, 0, 0,, ahk_id %hCfMenu%
SmokeAssert(ErrorLevel = 0, "CPFS dropdown rests on its header")
GuiControlGet, hAutoSave, 80:Hwnd, CF_AutoSaveChk
SmokeAssert(hAutoSave = "", "AutoSave checkbox no longer exists")
GuiControlGet, hAutoAdd, 80:Hwnd, CF_AutoAddChk
SmokeAssert(hAutoAdd != 0, "Auto-Add checkbox still present")

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
