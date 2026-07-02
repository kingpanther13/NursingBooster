<#
.SYNOPSIS
  Run the NursingBooster CPRS harness on a local Windows PC.

.DESCRIPTION
  Three modes:

  (default)      Automated e2e, exactly like CI: stub + driver run,
                 assertions print PASS/FAIL, exit code = failures.

  -Watch         Slow, narrated apply you can watch: opens the fake dialog
                 with readable captions and drives the real module against
                 it step by step, leaving the dialog open at the end.

  -Interactive   Playground: opens the fake dialog AND the real NursingBooster
                 panel so you can click the dialog and use Save/Load/Apply by
                 hand, just like against real CPRS. Both stay open until you
                 close them.

  The harness is AutoHotkey v1.1 (64-bit Unicode). This script finds
  AutoHotkeyU64.exe automatically, or point at it with -AhkExe.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tests\run_cprs_local.ps1
  powershell -ExecutionPolicy Bypass -File tests\run_cprs_local.ps1 -Watch
  powershell -ExecutionPolicy Bypass -File tests\run_cprs_local.ps1 -Interactive
#>
[CmdletBinding()]
param(
    [switch]$Watch,
    [switch]$Interactive,
    [string]$AhkExe
)

$ErrorActionPreference = "Stop"
$tests = $PSScriptRoot

function Find-Ahk {
    param([string]$Explicit)
    if ($Explicit) {
        if (Test-Path $Explicit) { return $Explicit }
        throw "AutoHotkey not found at -AhkExe path: $Explicit"
    }
    $candidates = @(
        "$env:ProgramFiles\AutoHotkey\AutoHotkeyU64.exe",
        "$env:ProgramFiles\AutoHotkey\v1.1.37.02\AutoHotkeyU64.exe",
        "$env:ProgramFiles\AutoHotkey\v1\AutoHotkeyU64.exe",
        "${env:ProgramFiles(x86)}\AutoHotkey\AutoHotkeyU64.exe"
    )
    foreach ($c in $candidates) { if ($c -and (Test-Path $c)) { return $c } }
    $onPath = Get-Command AutoHotkeyU64.exe -ErrorAction SilentlyContinue
    if ($onPath) { return $onPath.Source }
    throw @"
AutoHotkeyU64.exe (AutoHotkey v1.1, 64-bit Unicode) was not found.
Install AutoHotkey v1.1 from https://www.autohotkey.com/download/1.1/
(the harness uses 64-bit WNDCLASSEXW layouts, so the U64 build is required),
then re-run, or pass -AhkExe "C:\path\to\AutoHotkeyU64.exe".
"@
}

$ahk = Find-Ahk -Explicit $AhkExe
Write-Host "AutoHotkey: $ahk"

# The module detects CPRS by process name, so the stub must run as a process
# literally named CPRSChart.exe - copy the interpreter under that name.
$cprs = Join-Path $env:TEMP "CPRSChart.exe"
Copy-Item $ahk $cprs -Force

# AHK only runs files with a .ahk extension; copy each .ahk.txt source we need.
$copied = @()
function Copy-Script($name) {
    $dst = Join-Path $tests $name
    Copy-Item (Join-Path $tests "$name.txt") $dst -Force
    $script:copied += $dst
    return $dst
}

try {
    $stub = Copy-Script "e2e_cprs_stub.ahk"

    if ($Interactive) {
        $play = Copy-Script "playground_host.ahk"
        $env:NB_E2E_VISUAL = "1"
        Write-Host "INTERACTIVE mode: opening the fake dialog + the NursingBooster panel..."
        Start-Process -FilePath $cprs -ArgumentList "/ErrorStdOut", "`"$stub`""
        Start-Sleep -Seconds 2
        Start-Process -FilePath $ahk -ArgumentList "/ErrorStdOut", "`"$play`""
        Write-Host ""
        Write-Host "Both are running. Press Ctrl+Shift+B to show the NursingBooster panel," -ForegroundColor Cyan
        Write-Host "then Save Tpl / Load Tpl / Apply against the fake dialog by hand." -ForegroundColor Cyan
        Write-Host "Ctrl+Shift+I over any control inspects its window class." -ForegroundColor Cyan
        Write-Host "Close both windows (dialog + AutoHotkey tray) when you are done."
        Start-Sleep -Seconds 3   # let both processes finish loading before cleanup
    }
    elseif ($Watch) {
        $demo = Copy-Script "demo_cprs_apply.ahk"
        $env:NB_E2E_VISUAL = "1"
        Write-Host "WATCH mode: launching the fake dialog with readable captions..."
        Start-Process -FilePath $cprs -ArgumentList "/ErrorStdOut", "`"$stub`""
        Start-Sleep -Seconds 2
        Write-Host "Running the slow, narrated apply (follow the on-screen prompts)..."
        & $ahk "/ErrorStdOut" $demo   # foreground; the stub keeps the dialog open
        Write-Host "Demo driver exited. The fake dialog stays open until you close it."
    }
    else {
        $driver = Copy-Script "e2e_cprs.ahk"
        Write-Host "Running the automated CPRS e2e (same as CI)..."
        Start-Process -FilePath $cprs -ArgumentList "/ErrorStdOut", "`"$stub`""
        $out = Join-Path $env:TEMP "nb_e2e_out.txt"
        $err = Join-Path $env:TEMP "nb_e2e_err.txt"
        $p = Start-Process -FilePath $ahk `
            -ArgumentList "/ErrorStdOut", "`"$driver`"" `
            -Wait -PassThru -NoNewWindow `
            -RedirectStandardOutput $out -RedirectStandardError $err
        if (Test-Path $out) { Get-Content $out }
        if (Test-Path $err) { Get-Content $err }
        Get-Process -Name CPRSChart -ErrorAction SilentlyContinue | Stop-Process -Force
        if ($p.ExitCode -eq 0) {
            Write-Host "`nRESULT: all CPRS e2e assertions passed." -ForegroundColor Green
        } else {
            Write-Host "`nRESULT: $($p.ExitCode) assertion(s) failed." -ForegroundColor Red
        }
        exit $p.ExitCode
    }
}
finally {
    # The running processes already loaded their scripts into memory, so
    # removing the temp .ahk copies here does not affect them.
    foreach ($f in $copied) { Remove-Item $f -ErrorAction SilentlyContinue }
}
