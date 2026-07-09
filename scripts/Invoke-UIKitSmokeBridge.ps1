[CmdletBinding()]
param(
    [string]$ProjectRoot,
    [int]$HeartbeatMaxAgeSeconds = 120,
    [int]$StatePollTimeoutSeconds = 120
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

function Invoke-BridgeJson {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ToolName,
        [string]$JsonLiteral
    )

    return (Invoke-BridgeProcess -ToolName $ToolName -JsonLiteral $JsonLiteral) | ConvertFrom-Json
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

function Get-EditorState {
    $response = Invoke-BridgeJson -ToolName "editor-application-get-state"
    if ($response.status -ne "success") {
        throw "Failed to read editor state: $($response | ConvertTo-Json -Compress -Depth 8)"
    }

    return $response.message | ConvertFrom-Json
}

function Wait-EditorState {
    param(
        [Parameter(Mandatory = $true)]
        [bool]$IsPlaying,
        [int]$TimeoutSeconds
    )

    $deadline = [DateTimeOffset]::UtcNow.AddSeconds($TimeoutSeconds)
    do {
        Start-Sleep -Seconds 1
        $state = Get-EditorState
        if ($state.isPlaying -eq $IsPlaying -and -not $state.isCompiling -and -not $state.isUpdating) {
            return $state
        }
    } while ([DateTimeOffset]::UtcNow -lt $deadline)

    throw "Timed out waiting for Unity Editor to reach isPlaying=$IsPlaying."
}

$heartbeatPath = Join-Path $ProjectRoot "Temp\UnityBridge\heartbeat"
if (-not (Test-Path -LiteralPath $heartbeatPath)) {
    throw "Unity Editor is not connected to AIBridge. Missing heartbeat: $heartbeatPath"
}

$heartbeatInfo = Assert-BridgeHeartbeatReady -HeartbeatPath $heartbeatPath -MaxAgeSeconds $HeartbeatMaxAgeSeconds
$initialState = Get-EditorState
$startedPlayMode = $false

try {
    if (-not $initialState.isPlaying) {
        $setPlayModeJson = @{ isPlaying = $true } | ConvertTo-Json -Compress -Depth 4
        [void](Invoke-BridgeJson -ToolName "editor-application-set-state" -JsonLiteral $setPlayModeJson)
        $initialState = Wait-EditorState -IsPlaying $true -TimeoutSeconds $StatePollTimeoutSeconds
        $startedPlayMode = $true
    }

    $validatorCode = @'
using FantasyWord.GameCore;

public class Script
{
    public static object Main()
    {
        return UIKitSmokeValidator.Run();
    }
}
'@

    $validatorJson = @{
        csharpCode = $validatorCode
        bridgeSceneDirtyPolicy = "discard-generated"
    } | ConvertTo-Json -Compress -Depth 10

    $validatorResult = Invoke-BridgeJson -ToolName "script-execute" -JsonLiteral $validatorJson

    Write-Host "UIKit host smoke finished."
    Write-Host "Heartbeat:"
    Write-Host ($heartbeatInfo | ConvertTo-Json -Compress -Depth 5)
    Write-Host "ValidatorResult:"
    Write-Host ($validatorResult | ConvertTo-Json -Depth 10)
}
finally {
    if ($startedPlayMode) {
        $stopPlayModeJson = @{ isPlaying = $false } | ConvertTo-Json -Compress -Depth 4
        [void](Invoke-BridgeJson -ToolName "editor-application-set-state" -JsonLiteral $stopPlayModeJson)
        [void](Wait-EditorState -IsPlaying $false -TimeoutSeconds $StatePollTimeoutSeconds)
    }
}
