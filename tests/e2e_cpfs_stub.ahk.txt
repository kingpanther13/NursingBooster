; ===========================================================================
; e2e_cpfs_stub.ahk - fake CP Flowsheets "Add Data" form.
;
; Run this with a copy of AutoHotkeyU64.exe RENAMED to CPFlowsheets.exe so the
; module's exe-based detection (WinExist "Add Data ahk_exe CPFlowsheets.exe",
; CF window enumeration) sees a real CPFlowsheets process. The controls are
; plain Win32 Button/ComboBox classes; the module classifies them via the
; generic style-bit path in CF_ClassifyControl, exactly as it would for a
; non-Delphi build of CP Flowsheets.
;
; The window is deliberately larger than 500x400 so the module's
; CF_DismissIntermediatePopups treats it as a main window, not a popup.
; ===========================================================================
#NoEnv
#SingleInstance force
#Persistent
SetBatchLines, -1

Gui, Margin, 16, 16
Gui, Font, s10, Segoe UI
Gui, Add, Text,, CPFS stub - assessment entry
Gui, Add, Checkbox, vCB1, Oriented x4
Gui, Add, Checkbox, vCB2 Checked, Denies pain
Gui, Add, Text,, Pain present:
Gui, Add, Radio, vR1 Group, Yes
Gui, Add, Radio, vR2 Checked, No
Gui, Add, Text,, Route:
Gui, Add, DropDownList, vDD1 Choose1 w180, Oral|IV|IM
Gui, Add, Checkbox, vCB3, Skin intact
Gui, Show, w560 h460, CPFS Stub - Add Data
return

GuiClose:
ExitApp
