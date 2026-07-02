; ===========================================================================
; playground_host.ahk - run the REAL NursingBooster module interactively
; against the fake CPRS dialog, by hand.
;
; NOT part of automated CI (only syntax-checked). This is a tiny stand-in for
; CPRSBooster: it loads the actual module with NB_Enabled=1 and starts it, so
; you get the real floating panel (Ctrl+Shift+B) with Save Tpl / Load Tpl /
; Apply / Settings etc. You then drive it by hand against the fake dialog
; exactly like you would against real CPRS - save a template off the mock,
; toggle some boxes, load/apply it, watch it work.
;
; Launched by run_cprs_local.ps1 -Interactive, alongside the stub (running as
; CPRSChart.exe in visual mode so captions are readable).
;
; Templates you save land in Documents\NursingBooster-Playground so you can
; find and re-use them.
; ===========================================================================
#NoEnv
#SingleInstance force
SetBatchLines, -1

; --- the two globals the real host (CPRSBooster) provides before load ---
global NB_Enabled := 1
global onedrivelocal := A_MyDocuments . "\NursingBooster-Playground"
FileCreateDir, %onedrivelocal%

; Start the module the same way CPRSBooster's auto-execute does.
gosub NB_ModuleInit

; One-time hint (deferred so the panel/timers are up first).
SetTimer, PlaygroundHint, -1000
return

PlaygroundHint:
    MsgBox, 4160, NursingBooster playground, NursingBooster is loaded and running against the fake CPRS dialog.`n`nTry this:`n  1. Press Ctrl+Shift+B to show the floating panel.`n  2. Click some checkboxes in the fake dialog.`n  3. On the panel, click 'Save Tpl' and name it - it scans the dialog and saves your checkbox pattern.`n  4. Uncheck everything, then 'Load Tpl' -> pick it -> Apply. Watch it re-check exactly what you saved.`n`nInspect anything: hover a control and press Ctrl+Shift+I to see its window class (compare to a real CPRS dump). Ctrl+Shift+D dumps the whole dialog tree.`n`nSaved templates: %onedrivelocal%\NursingTemplates
return

; --- the real module ---
#Include %A_ScriptDir%\..\nursingbooster_module.ahk
