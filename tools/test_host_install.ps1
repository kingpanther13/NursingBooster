param(
    [Parameter(Mandatory = $true)][string]$AhkExe,
    [string]$Repo = (Split-Path $PSScriptRoot -Parent)
)

$ErrorActionPreference = 'Stop'
$sandbox = Join-Path ([IO.Path]::GetTempPath()) ('nb-install-' + [guid]::NewGuid())
$hostText = [IO.File]::ReadAllText((Join-Path $Repo 'CPRSBooster_with_NursingBooster.ahk'))
$utf8 = [Text.UTF8Encoding]::new($true)

try {
    foreach ($modulePresent in @($false, $true)) {
        $name = if ($modulePresent) { 'cached-module' } else { 'fresh-install' }
        $root = Join-Path $sandbox $name
        $engine = Join-Path $root 'Engine'
        New-Item -ItemType Directory -Path $engine -Force | Out-Null
        if ($modulePresent) {
            Copy-Item (Join-Path $Repo 'nursingbooster_module.ahk') $root
        }
        $script = Join-Path $engine 'CPRSBooster_ACTIVE_PRODUCTION_SCRIPT.ahk'
        # AHK parses the entire real host before executing ExitApp. Do not use
        # /iLib: it exits before the label-resolution pass that failed in the
        # reported first installation. Never execute CPRS/network startup code.
        [IO.File]::WriteAllText($script, "ExitApp, 0`r`n" + $hostText, $utf8)
        $stdout = Join-Path $root 'stdout.txt'
        $stderr = Join-Path $root 'stderr.txt'
        $proc = Start-Process -FilePath $AhkExe -ArgumentList '/ErrorStdOut', ('"' + $script + '"') `
            -PassThru -NoNewWindow -RedirectStandardOutput $stdout -RedirectStandardError $stderr
        if (-not $proc.WaitForExit(30000)) {
            $proc.Kill()
            throw "$name timed out"
        }
        $proc.WaitForExit()
        $output = [IO.File]::ReadAllText($stdout) + [IO.File]::ReadAllText($stderr)
        if ($proc.ExitCode -ne 0 -or $output -match '(?im)(Error:|==>)') {
            throw "$name failed (exit $($proc.ExitCode)):`n$output"
        }
        Write-Host "PASS: $name loads with real AutoHotkey v1"
    }
} finally {
    if (Test-Path $sandbox) { Remove-Item $sandbox -Recurse -Force }
}
