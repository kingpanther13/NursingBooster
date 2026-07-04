; ===========================================================================
; e2e_cpfs.ahk - end-to-end test of the CP Flowsheets apply engine against
; the stub "Add Data" form (e2e_cpfs_stub.ahk running as CPFlowsheets.exe).
;
; Exercises the real module code paths:
;   CF_FindAddDataWindow -> CF_EnumFormControls (style-bit classification,
;   adjacent-label resolution) -> CF_ApplyTemplate (label matching via
;   CF_FindBestMatch, BM_CLICK application, combo skip-by-design).
;
; Asserts:
;   - enumeration finds all 6 controls with correct types/labels
;   - apply checks an unchecked box, unchecks a checked one, selects the
;     radio, leaves the combo untouched, leaves unrelated boxes alone
;
; Output: PASS/FAIL lines on stdout; exit code = failures.
; Run with: AutoHotkeyU64.exe /ErrorStdOut e2e_cpfs.ahk  (after starting the stub)
; ===========================================================================
#NoEnv
#SingleInstance force
SetBatchLines, -1
SetTitleMatchMode, 2

global E2eFails := 0

; --- Module globals normally set by NB_ModuleInit (init stays inert) ---
NB_Enabled := 0
onedrivelocal := A_Temp . "\nb_e2e_cpfs_" . A_TickCount
CF_TemplateDir := onedrivelocal
CF_LogDir := onedrivelocal . "\Logs"
FileCreateDir, %CF_TemplateDir%
FileCreateDir, %CF_LogDir%
CF_AppTitle := "CP Flowsheets Booster"
CF_AutoSave := 0
CF_ChainAddData := 0
CF_AddDataDelay := 50
CF_AutoSaveDelay := 500
NB_SpeedOverride := 0
NB_ApplySpeed := 0
NB_LeafSpeed := 0
NB_DebugLogging := 0
NB_BoosterGuiVisible := 0
NB_PanelHwnd := 0
NB_AppTitle := "Nursing Booster"

; --- Wait for the stub (started by CI as CPFlowsheets.exe) ---
WinWait, Add Data ahk_exe CPFlowsheets.exe,, 20
if (ErrorLevel) {
    FileAppend, % "FAIL: stub Add Data window never appeared`n", **
    ExitApp, 1
}
stubHwnd := WinExist("Add Data ahk_exe CPFlowsheets.exe")
E2eAssert(stubHwnd != 0, "stub window found via exe+title detection")

foundHwnd := CF_FindAddDataWindow()
E2eAssert(foundHwnd = stubHwnd, "CF_FindAddDataWindow resolves the stub")

; --- Enumeration: 3 checkboxes + 2 radios + 1 combo ---
controls := CF_EnumFormControls(stubHwnd)
E2eAssert(controls.Length() = 6, "enumerated 6 controls (got " . controls.Length() . ")")
counts := {checkbox: 0, radio: 0, combo: 0}
labels := ""
for i, c in controls {
    counts[c.type] := counts[c.type] + 1
    labels .= "|" . c.label
}
E2eAssert(counts.checkbox = 3, "3 checkboxes (got " . counts.checkbox . ")")
E2eAssert(counts.radio = 2, "2 radios (got " . counts.radio . ")")
E2eAssert(counts.combo = 1, "1 combo (got " . counts.combo . ")")
E2eAssert(InStr(labels, "|Oriented x4"), "checkbox label read")
E2eAssert(InStr(labels, "|Yes") && InStr(labels, "|No"), "radio labels read")

; --- Template fixture: flip CB1 on, CB2 off, select Yes, try to change the
;     combo (must be skipped by design), leave CB3 alone (false=already) ---
tpl := "{`n  ""name"": ""e2e"",`n  ""format"": 1,`n  ""speed"": 20,`n  ""app"": ""CPFlowsheets"",`n  ""controls"": ["
tpl .= "`n    {""type"": ""checkbox"", ""label"": ""Oriented x4"", ""idx"": 0, ""y"": 0, ""checked"": true},"
tpl .= "`n    {""type"": ""checkbox"", ""label"": ""Denies pain"", ""idx"": 1, ""y"": 0, ""checked"": false},"
tpl .= "`n    {""type"": ""radio"", ""label"": ""Yes"", ""idx"": 2, ""y"": 0, ""selected"": true},"
tpl .= "`n    {""type"": ""combo"", ""label"": ""Oral"", ""idx"": 3, ""y"": 0, ""value"": ""IM"", ""valueIdx"": 2},"
tpl .= "`n    {""type"": ""checkbox"", ""label"": ""Skin intact"", ""idx"": 4, ""y"": 0, ""checked"": false}"
tpl .= "`n  ]`n}"
tplPath := CF_TemplateDir . "\e2e.json"
FileDelete, %tplPath%
FileAppend, %tpl%, %tplPath%, UTF-8

CF_ApplyTemplate(tplPath)
Sleep, 500

; --- Re-read live state through the module's own enumerator ---
after := CF_EnumFormControls(stubHwnd)
state := {}
for i, c in after {
    if (c.type = "checkbox")
        state[c.label] := c.checked
    else if (c.type = "radio")
        state[c.label] := c.selected
    else if (c.type = "combo")
        state["__combo"] := c.valueIdx
}
E2eAssert(state["Oriented x4"] = 1, "unchecked box got checked")
E2eAssert(state["Denies pain"] = 0, "checked box got unchecked (CPFS applies both ways)")
E2eAssert(state["Yes"] = 1, "radio Yes selected")
E2eAssert(state["No"] = 0, "radio No deselected by group behavior")
E2eAssert(state["Skin intact"] = 0, "already-correct box untouched")
E2eAssert(state["__combo"] = 0, "combo untouched (skipped by design), idx=" . state["__combo"])

; --- Summary ---
WinClose, ahk_id %stubHwnd%
if (E2eFails > 0)
{
    FileAppend, % "FAIL: " . E2eFails . " CPFS e2e assertion(s) failed`n", **
    ExitApp, %E2eFails%
}
FileAppend, % "All CPFS e2e assertions passed`n", *
ExitApp, 0

E2eAssert(cond, msg)
{
    global E2eFails
    if (cond)
        FileAppend, % "PASS: " . msg . "`n", *
    else
    {
        E2eFails += 1
        FileAppend, % "FAIL: " . msg . "`n", *
    }
}

; --- The real module under test ---
#Include %A_ScriptDir%\..\nursingbooster_module.ahk
