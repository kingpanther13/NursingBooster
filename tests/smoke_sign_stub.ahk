; ===========================================================================
; smoke_sign_stub.ahk - fake CPRS "Sign Note" window.
;
; Run with a copy of AutoHotkeyU64.exe renamed to CPRSChart.exe: the module's
; NB_CheckFKeyHide poll hides the booster panel when it sees a window
; matching "Sign Note ahk_exe CPRSChart.exe". Shown with NA so it never
; steals activation from the smoke test's focus-holder window.
; Exits when its window is closed, or after 60s as a failsafe.
; ===========================================================================
#NoEnv
#SingleInstance force
#Persistent
SetBatchLines, -1

Gui, Add, Text,, fake sign dialog
Gui, Show, x400 y60 w220 h90 NA, Sign Note - smoke stub
SetTimer, SelfDestruct, -60000
return

GuiClose:
SelfDestruct:
    ExitApp
