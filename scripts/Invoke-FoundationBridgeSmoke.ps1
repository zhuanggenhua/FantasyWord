[CmdletBinding()]
param(
    [string]$ProjectRoot,
    [switch]$SkipAssetsRefresh,
    [switch]$SkipTests,
    [int]$HeartbeatMaxAgeSeconds = 120
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $scriptRoot = if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
        $PSScriptRoot
    }
    else {
        Split-Path -Parent $PSCommandPath
    }

    $ProjectRoot = (Resolve-Path (Join-Path $scriptRoot "..")).Path
}

$bridgePath = Join-Path $ProjectRoot ".codex\skills\aibridge\bridge.py"
if (-not (Test-Path -LiteralPath $bridgePath)) {
    throw "AIBridge CLI not found: $bridgePath"
}

function Quote-ProcessArgument {
    param([string]$Value)

    if ($null -eq $Value) {
        return '""'
    }

    if ($Value -notmatch '[\s"]') {
        return $Value
    }

    $escaped = $Value -replace '(\\*)"', '$1$1\"'
    $escaped = $escaped -replace '(\\+)$', '$1$1'
    return '"' + $escaped + '"'
}

function Invoke-BridgeProcess {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ToolName,
        [string]$JsonLiteral
    )

    $processStartInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $processStartInfo.FileName = "python"
    $processStartInfo.UseShellExecute = $false
    $processStartInfo.RedirectStandardOutput = $true
    $processStartInfo.RedirectStandardError = $true

    $rawArguments = [System.Collections.Generic.List[string]]::new()
    [void]$rawArguments.Add($bridgePath)
    [void]$rawArguments.Add($ToolName)
    if (-not [string]::IsNullOrWhiteSpace($JsonLiteral)) {
        [void]$rawArguments.Add($JsonLiteral)
    }

    $quotedArguments = $rawArguments | ForEach-Object { Quote-ProcessArgument $_ }
    $processStartInfo.Arguments = ($quotedArguments -join " ")

    $process = [System.Diagnostics.Process]::Start($processStartInfo)
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()

    $output = ($stdout + [Environment]::NewLine + $stderr).Trim()

    if ($process.ExitCode -ne 0) {
        throw "AIBridge call failed: $ToolName`n$output"
    }

    return $output
}

function Test-IsRecoverableBridgeSceneListTimeout {
    param(
        [string]$ToolName,
        [string]$BridgeErrorMessage
    )

    return $ToolName -eq "tests-run" -and
        $BridgeErrorMessage -like "*Timeout after 60s waiting for Unity response*" -and
        $BridgeErrorMessage -like "*tool: scene-list-opened*"
}

function Invoke-BridgeProcessWithSingleRetry {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ToolName,
        [string]$JsonLiteral
    )

    try {
        return Invoke-BridgeProcess -ToolName $ToolName -JsonLiteral $JsonLiteral
    }
    catch {
        $bridgeError = $_.Exception.Message
        if (-not (Test-IsRecoverableBridgeSceneListTimeout -ToolName $ToolName -BridgeErrorMessage $bridgeError)) {
            throw
        }

        Start-Sleep -Seconds 2
        $null = Invoke-BridgeProcess -ToolName "editor-application-get-state"
        $null = Invoke-BridgeProcess -ToolName "scene-list-opened"
        Start-Sleep -Seconds 2
        return Invoke-BridgeProcess -ToolName $ToolName -JsonLiteral $JsonLiteral
    }
}

function Get-BridgeHeartbeatInfo {
    param([string]$HeartbeatPath)

    $rawHeartbeat = Get-Content -LiteralPath $HeartbeatPath -Raw
    $heartbeat = $rawHeartbeat | ConvertFrom-Json
    $heartbeatTime = [DateTimeOffset]::FromUnixTimeMilliseconds([Int64]$heartbeat.timestamp)
    $ageSeconds = [Math]::Floor(([DateTimeOffset]::UtcNow - $heartbeatTime).TotalSeconds)
    $process = $null

    if ($heartbeat.PSObject.Properties.Name -contains "pid") {
        $process = Get-Process -Id ([int]$heartbeat.pid) -ErrorAction SilentlyContinue
    }

    return [ordered]@{
        Path = $HeartbeatPath
        Raw = $rawHeartbeat.Trim()
        TimestampUtc = $heartbeatTime.UtcDateTime.ToString("o")
        AgeSeconds = [int]$ageSeconds
        Pid = if ($null -ne $process) { $process.Id } else { $null }
        ProcessName = if ($null -ne $process) { $process.ProcessName } else { $null }
        Responding = if ($null -ne $process) { $process.Responding } else { $null }
    }
}

function Assert-BridgeHeartbeatReady {
    param(
        [string]$HeartbeatPath,
        [int]$MaxAgeSeconds
    )

    $info = Get-BridgeHeartbeatInfo -HeartbeatPath $HeartbeatPath

    if ($null -eq $info.Pid) {
        throw "Unity Editor process from AIBridge heartbeat is not running. Heartbeat=$($info.Raw)"
    }

    if ($info.Responding -eq $false) {
        throw "Unity Editor process is not responding. PID=$($info.Pid), heartbeatAgeSeconds=$($info.AgeSeconds), heartbeat=$($info.Raw)"
    }

    if ($info.AgeSeconds -gt $MaxAgeSeconds) {
        throw "Unity Editor heartbeat is stale. ageSeconds=$($info.AgeSeconds), maxAgeSeconds=$MaxAgeSeconds, heartbeat=$($info.Raw)"
    }

    return $info
}

$heartbeatPath = Join-Path $ProjectRoot "Temp\UnityBridge\heartbeat"
if (-not (Test-Path -LiteralPath $heartbeatPath)) {
    throw "Unity Editor is not connected to AIBridge. Missing heartbeat: $heartbeatPath"
}

$heartbeatInfo = Assert-BridgeHeartbeatReady -HeartbeatPath $heartbeatPath -MaxAgeSeconds $HeartbeatMaxAgeSeconds
$stateOutput = Invoke-BridgeProcess -ToolName "editor-application-get-state"

$refreshOutput = $null
if (-not $SkipAssetsRefresh) {
    $refreshJson = @{
        options = "ForceSynchronousImport"
    } | ConvertTo-Json -Compress -Depth 10
    $refreshOutput = Invoke-BridgeProcess -ToolName "assets-refresh" -JsonLiteral $refreshJson
}

$testsOutputs = New-Object System.Collections.Generic.List[string]
if (-not $SkipTests) {
    $testAssemblies = @(
        "FantasyWord.GameCore.EditModeTests"
    )

    foreach ($assemblyName in $testAssemblies) {
        $testsJson = @{
            testMode = "EditMode"
            testAssembly = $assemblyName
            includePassingTests = $false
            includeMessages = $true
            includeStacktrace = $true
            includeLogs = $false
            requestId = ("foundation-smoke-{0}-{1}" -f $assemblyName, [DateTimeOffset]::UtcNow.ToUnixTimeSeconds())
        } | ConvertTo-Json -Compress -Depth 10

        $output = Invoke-BridgeProcessWithSingleRetry -ToolName "tests-run" -JsonLiteral $testsJson
        [void]$testsOutputs.Add(("Assembly={0}`n{1}" -f $assemblyName, $output))
    }
}

Write-Host "Foundation bridge smoke finished."
Write-Host "Heartbeat:"
Write-Host ($heartbeatInfo | ConvertTo-Json -Compress -Depth 5)
Write-Host "EditorState:"
Write-Host $stateOutput

if ($refreshOutput) {
    Write-Host "AssetsRefresh:"
    Write-Host $refreshOutput
}

if ($testsOutputs.Count -gt 0) {
    Write-Host "EditModeTests:"
    foreach ($output in $testsOutputs) {
        Write-Host $output
    }
}
