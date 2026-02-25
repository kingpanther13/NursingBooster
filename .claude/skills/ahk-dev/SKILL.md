---
name: ahk-dev
description: AutoHotkey development assistant — primarily AHK v1 (active production scripts), with AHK v2 reference for future migration. Use this skill whenever the user asks to write, modify, debug, or review AutoHotkey code — whether they say "ahk", "autohotkey", "script", "hotkey", "hotstring", mention CPRS/nursing/booster, or describe any Windows GUI automation task. Also trigger when the user mentions checkboxes, DllCall, Win commands, GUI building, or template/macro systems. Even if the user just says "fix this" or "add a feature" and the file is .ahk, use this skill.
---

# AutoHotkey Development Skill

You are an expert AutoHotkey developer working on CPRSBooster / NursingBooster — a suite of Windows GUI automation tools for VA CPRS (Computerized Patient Record System) used by nurses and clinicians.

## Critical: Default to AHK v1

The production scripts (CPRSBooster_v*_COMBINED.ahk) are **AHK v1** and are the active codebase. Always write v1 unless the user explicitly says v2.

The standalone NursingBooster.ahk / NursingPanel.ahk files are older v2 experiments — they are NOT the production code. The v2 reference section below exists for future migration only.

**NEVER mix v1 and v2 syntax in the same file.** This is the #1 source of bugs and the most likely reason a new version fails to load.

## AHK v1 Rules (Production Scripts)

These rules apply to CPRSBooster_v*_COMBINED.ahk files.

### Syntax Essentials
- Use `:=` for expressions, `=` only for legacy string assignment
- Variable dereferencing in commands: `%varName%`
- Variable dereferencing in expressions: just `varName` (no percent signs)
- String concatenation with `.` operator: `str1 . str2`
- Ternary: `var := (condition) ? valueTrue : valueFalse`
- Multi-statement lines are NOT supported — one statement per line
- Labels end with colon: `MyLabel:`; jump with `Gosub, MyLabel`

### Commands vs Functions
- Commands: `MsgBox, 262144, Title, Text` (comma-separated, no parentheses)
- Functions: `result := MyFunc(arg1, arg2)` (parentheses required)
- `MsgBox` is a COMMAND in v1, not a function
- `FileRead, OutputVar, FileName` — command form, NOT `FileRead()`
- `IfNotExist, path` then block — NOT `if !FileExist(path)`... wait, `FileExist()` IS available as a function in v1, but `IfNotExist` is the command form
- `FileCreateDir, path` — NOT `DirCreate()`
- `FileAppend, text, filename` — NOT `FileAppend()`
- `SetTimer, LabelName, Period` — NOT `SetTimer(Func, Period)`

### GUI (v1)
```autohotkey
Gui, Add, Button, x10 y10 w100 h30 gMyButtonLabel, Click Me
Gui, Add, Text, vMyTextControl w200, Status text
Gui, Show, w400 h300, Window Title
return

MyButtonLabel:
    ; handle click
return
```
- Controls use `g`-labels for events (e.g., `gBtnClick`)
- Controls use `v`-variables for reading values (e.g., `vMyEdit`)
- `Gui, Submit, NoHide` to read control values
- `GuiControl,, ControlVar, NewText` to update controls

### Common v1 Gotchas
- `if (var = "string")` uses case-insensitive comparison; `if (var == "string")` is case-sensitive
- `if var =` (no parentheses) is legacy syntax — still works but avoid mixing styles
- Arrays are 1-based: `arr[1]` is first element
- `Loop, Parse, var, delimiter` — not `StrSplit()` (though StrSplit exists in newer v1)
- `return` ends a subroutine/hotkey; `Return` and `return` are interchangeable
- `#SingleInstance force` — lowercase `force`, not `Force`
- Object literal `{}` creates an object; `.HasKey()` to check membership
- `try`/`catch` exists but `catch` takes no typed parameter: `catch e` not `catch Error as e`

### DllCall and Windows API (v1)
```autohotkey
; EnumChildWindows pattern (used extensively in this codebase)
callback := RegisterCallback("MyEnumProc", "Fast")
DllCall("EnumChildWindows", "Ptr", hwnd, "Ptr", callback, "Ptr", userData)

MyEnumProc(hwnd, lParam) {
    ; process each child window
    VarSetCapacity(className, 256)
    DllCall("GetClassName", "Ptr", hwnd, "Str", className, "Int", 256)
    return 1  ; continue enumeration
}
```

### Nursing Booster Conventions (v1 Combined Scripts)
- All nursing booster globals prefixed with `NB_` (e.g., `NB_TemplateDir`, `NB_ApplySpeed`)
- CP Flowsheets globals prefixed with `CF_`
- Template data stored as JSON in OneDrive-synced directories
- CPRS detection via `ahk_exe CPRSChart.exe`
- Dialog detection via window class names: `TfrmRemDlg`, `TfrmTemplateDialog`, `TfrmFrame`
- Checkbox control classes: `TORCheckBox`, `TCPRSDialogParentCheckBox`, `TCPRSDialogCheckBox`
- Group containers: `TGroupBox`
- Scrollbox containers: `TScrollBox`
- NEVER click OK/Finish/Submit buttons programmatically — safety rule

## AHK v2 Rules (Standalone Modules)

These rules apply to NursingBooster.ahk, NursingPanel.ahk, and future standalone scripts.

Read `tools/ClautoHotkey/Modules/Module_Instructions.md` for the comprehensive v2 reference.
Key differences from v1 are listed at `tools/ClautoHotkey/Modules/` — consult relevant module files when working on v2 code.

### Quick v2 Reference
- Everything is a function call: `MsgBox()`, `FileRead()`, `DirCreate()`
- GUIs are objects: `myGui := Gui("+AlwaysOnTop", "Title")`
- Events via `.OnEvent()`: `btn.OnEvent("Click", MyCallback)`
- Callbacks must use `.Bind(this)` in class methods
- `Map()` for dictionaries, NOT `{}` object literals
- `#Requires AutoHotkey v2.0` at top of every v2 file
- No `Gosub` — use function calls
- No `%var%` — variables are always bare names in expressions
- `CallbackCreate()` replaces `RegisterCallback()`
- `Buffer()` replaces `VarSetCapacity()`

## Testing with Yunit

Unit tests are available via `tools/Yunit/` (v1 on master branch, v2 on v2 branch).

### Writing a Yunit Test (v1)
```autohotkey
#Include tools/Yunit/Yunit.ahk
#Include tools/Yunit/Window.ahk

Yunit.Use(YunitWindow).Test(MyTestSuite)

class MyTestSuite {
    Begin() {
        ; runs before each test
    }
    End() {
        ; runs after each test
    }
    TestSomething() {
        ; test passes if no exception thrown
        Yunit.Assert(1 + 1 == 2, "Math is broken")
    }
    TestShouldFail() {
        ; force a failure
        Yunit.Assert(false, "This should fail")
    }
}
```

### What to Test
- Template JSON parsing and generation logic
- String/path manipulation helpers
- Checkbox state mapping functions
- Any pure-logic function that doesn't require a live CPRS window
- Extract testable logic into `#Include` libraries where possible

## Code Review Checklist

When reviewing or generating AHK code, verify:

1. **Version consistency** — no v2 syntax in v1 files or vice versa
2. **Variable scoping** — `global` declarations where needed, `local` in functions
3. **GUI event wiring** — g-labels (v1) or .OnEvent (v2) properly connected
4. **DllCall signatures** — correct types (Ptr, Str, Int, UInt), correct argument count
5. **Error handling** — `try`/`catch` around file operations and DllCalls
6. **CPRS safety** — never automate OK/Finish/Submit clicks
7. **Path handling** — use `\` not `/`; handle spaces in paths; use `.` concatenation for building paths
8. **Sleep timing** — adequate delays after window activation and checkbox clicks (CPRS is slow)
9. **Control identification** — use hwnd-based targeting, not fragile text matching
