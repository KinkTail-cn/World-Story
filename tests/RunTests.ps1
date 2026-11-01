param(
    [string]$GodotPath = "D:\steamlibrary\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe",
    [string[]]$Suites = @(),
    [int]$TimeoutSeconds = 40
)

$ErrorActionPreference = 'Stop'
$projectPath = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw "Godot executable not found: $GodotPath. Pass -GodotPath to use your installation."
}
$temporaryParent = [System.IO.Path]::GetTempPath()
if (-not (Test-Path -LiteralPath $temporaryParent -PathType Container)) {
    throw "Temporary directory not found: $temporaryParent"
}
$runDirectory = Join-Path $temporaryParent ("WorldStoryTests_" + [guid]::NewGuid().ToString('N'))
[System.IO.Directory]::CreateDirectory($runDirectory) | Out-Null
if ($Suites.Count -eq 0) {
    $Suites = @(Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.gd' -File | Sort-Object Name | ForEach-Object { $_.BaseName })
}
$originalAppData = $env:APPDATA
$failed = 0
$passPattern = '_PASS:|Integrity: PASS|INTEGRITY:.*0 failures|InventoryIntegrity:.*0 failures|BLUEPRINT_CRAFT_SMOKE:.*0 failures'
try {
    foreach ($suite in $Suites) {
        if ($suite -notmatch '^[A-Za-z0-9_]+$' -or -not (Test-Path -LiteralPath (Join-Path $PSScriptRoot "$suite.gd") -PathType Leaf)) {
            throw "Unknown test suite: $suite"
        }
        $env:APPDATA = Join-Path $runDirectory $suite
        $logPath = Join-Path $runDirectory "$suite.log"
        $startInfo = New-Object System.Diagnostics.ProcessStartInfo
        $startInfo.FileName = $GodotPath
        $startInfo.Arguments = '--headless --path "{0}" --script res://tests/{1}.gd --max-fps 60 --log-file "{2}"' -f $projectPath, $suite, $logPath
        $startInfo.UseShellExecute = $false
        $startInfo.CreateNoWindow = $true
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
        $startInfo.StandardOutputEncoding = [System.Text.Encoding]::UTF8
        $startInfo.StandardErrorEncoding = [System.Text.Encoding]::UTF8
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $startInfo
        [void]$process.Start()
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $timedOut = -not $process.WaitForExit($TimeoutSeconds * 1000)
        if ($timedOut) {
            $process.Kill()
        }
        $process.WaitForExit()
        $output = $stdoutTask.GetAwaiter().GetResult() + $stderrTask.GetAwaiter().GetResult()
        $passed = -not $timedOut -and $process.ExitCode -eq 0 -and $output -match $passPattern -and $output -notmatch 'SCRIPT ERROR:|Assertion failed'
        if ($passed) {
            "${suite}: PASS"
        } else {
            $failed += 1
            "${suite}: FAIL (exit=$($process.ExitCode), timeout=$timedOut)"
            $output
        }
        $process.Dispose()
    }
} finally {
    $env:APPDATA = $originalAppData
}
"Passed: $($Suites.Count - $failed); Failed: $failed; Logs: $runDirectory"
exit $(if ($failed -eq 0) { 0 } else { 1 })
