[CmdletBinding()]
param(
    [string]$ProjectRoot,
    [int]$HeartbeatMaxAgeSeconds = 120,
    [int]$StatePollTimeoutSeconds = 120,
    [int]$ResultPollTimeoutSeconds = 240
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$targetScenePath = "Assets/Scenes/ClickMoveTest.unity"
$resultRelativePath = "Temp/UnityBridge/results/clickmove-element-surface-q-wide-visual-runtime.json"

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $scriptRoot = if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
        $PSScriptRoot
    }
    else {
        Split-Path -Parent $PSCommandPath
    }

    $ProjectRoot = (Resolve-Path (Join-Path $scriptRoot "..")).Path
}

$bridgeRoot = Join-Path $ProjectRoot "Temp\UnityBridge"
$commandsDir = Join-Path $bridgeRoot "commands"
$resultsDir = Join-Path $bridgeRoot "results"
$heartbeatPath = Join-Path $bridgeRoot "heartbeat"

function Get-BridgeHeartbeatInfo {
    param([string]$Path)

    $raw = Get-Content -LiteralPath $Path -Raw
    $heartbeat = $raw | ConvertFrom-Json
    $heartbeatTime = [DateTimeOffset]::FromUnixTimeMilliseconds([Int64]$heartbeat.timestamp)
    $ageSeconds = [Math]::Floor(([DateTimeOffset]::UtcNow - $heartbeatTime).TotalSeconds)
    $process = $null
    if ($heartbeat.PSObject.Properties.Name -contains "pid") {
        $process = Get-Process -Id ([int]$heartbeat.pid) -ErrorAction SilentlyContinue
    }

    return [ordered]@{
        Path = $Path
        Raw = $raw.Trim()
        TimestampUtc = $heartbeatTime.UtcDateTime.ToString("o")
        AgeSeconds = [int]$ageSeconds
        Pid = if ($null -ne $process) { $process.Id } else { $null }
        ProcessName = if ($null -ne $process) { $process.ProcessName } else { $null }
        Responding = if ($null -ne $process) { $process.Responding } else { $null }
    }
}

function Assert-BridgeHeartbeatReady {
    param(
        [string]$Path,
        [int]$MaxAgeSeconds
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Unity FileBridge heartbeat is missing: $Path"
    }

    $info = Get-BridgeHeartbeatInfo -Path $Path
    if ($null -eq $info.Pid) {
        throw "Unity Editor process from FileBridge heartbeat is not running. Heartbeat=$($info.Raw)"
    }

    if ($info.Responding -eq $false) {
        throw "Unity Editor process is not responding. PID=$($info.Pid), heartbeatAgeSeconds=$($info.AgeSeconds)"
    }

    if ($info.AgeSeconds -gt $MaxAgeSeconds) {
        throw "Unity FileBridge heartbeat is stale. ageSeconds=$($info.AgeSeconds), maxAgeSeconds=$MaxAgeSeconds"
    }

    return $info
}

function Invoke-FileBridgeJson {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ToolName,
        [hashtable]$Params = @{},
        [int]$TimeoutSeconds = 120
    )

    New-Item -ItemType Directory -Force -Path $commandsDir | Out-Null
    New-Item -ItemType Directory -Force -Path $resultsDir | Out-Null

    $id = "{0:yyyyMMddHHmmssfff}-{1}" -f [DateTime]::UtcNow, ([Guid]::NewGuid().ToString("N").Substring(0, 8))
    $commandPath = Join-Path $commandsDir "$id.json"
    $resultPath = Join-Path $resultsDir "$id.json"
    $payload = [ordered]@{
        id = $id
        tool = $ToolName
        params = $Params
    }
    $json = $payload | ConvertTo-Json -Compress -Depth 32
    $tmpPath = "$commandPath.tmp"
    [System.IO.File]::WriteAllText($tmpPath, $json, [System.Text.Encoding]::UTF8)
    Move-Item -LiteralPath $tmpPath -Destination $commandPath -Force

    $deadline = [DateTimeOffset]::UtcNow.AddSeconds($TimeoutSeconds)
    do {
        if (Test-Path -LiteralPath $resultPath) {
            $resultJson = [System.IO.File]::ReadAllText($resultPath, [System.Text.Encoding]::UTF8)
            $result = $resultJson | ConvertFrom-Json
            if ($result.status -ne "success") {
                throw "FileBridge tool '$ToolName' failed: $($result.message)"
            }

            return $result
        }

        Start-Sleep -Milliseconds 200
    } while ([DateTimeOffset]::UtcNow -lt $deadline)

    throw "Timed out waiting for FileBridge result. tool=$ToolName id=$id"
}

function Convert-BridgeMessageJson {
    param([object]$Response)

    if ($null -eq $Response -or -not ($Response.PSObject.Properties.Name -contains "message")) {
        return $null
    }

    $message = [string]$Response.message
    if ([string]::IsNullOrWhiteSpace($message)) {
        return $null
    }

    return $message | ConvertFrom-Json
}

function Get-EditorState {
    $response = Invoke-FileBridgeJson -ToolName "editor-application-get-state" -TimeoutSeconds $StatePollTimeoutSeconds
    return Convert-BridgeMessageJson -Response $response
}

function Get-OpenedScenes {
    $response = Invoke-FileBridgeJson -ToolName "scene-list-opened" -TimeoutSeconds $StatePollTimeoutSeconds
    $message = Convert-BridgeMessageJson -Response $response
    if ($null -eq $message) {
        return @()
    }

    return @($message)
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

function Wait-ResultFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [int]$TimeoutSeconds
    )

    $deadline = [DateTimeOffset]::UtcNow.AddSeconds($TimeoutSeconds)
    do {
        if (Test-Path -LiteralPath $Path) {
            $json = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
            $result = $json | ConvertFrom-Json
            if ($result.Completed) {
                return $result
            }
        }

        Start-Sleep -Milliseconds 500
    } while ([DateTimeOffset]::UtcNow -lt $deadline)

    throw "Timed out waiting for visual validator result file: $Path"
}

$heartbeatInfo = Assert-BridgeHeartbeatReady -Path $heartbeatPath -MaxAgeSeconds $HeartbeatMaxAgeSeconds
[void](Invoke-FileBridgeJson -ToolName "assets-refresh" -Params @{} -TimeoutSeconds $StatePollTimeoutSeconds)
$initialState = Get-EditorState
$openedScenes = @(Get-OpenedScenes)

if ($openedScenes.Count -ne 1) {
    throw "Element surface visual validation requires a single opened scene. Current count: $($openedScenes.Count)."
}

$originalScenePath = [string]$openedScenes[0].path
if ([bool]$openedScenes[0].isDirty -and $originalScenePath -ne $targetScenePath) {
    throw "Opened scene [$originalScenePath] is dirty and is not the target validation scene. Save or discard changes before running element surface visual validation."
}

if ($initialState.isPlaying -and $originalScenePath -ne $targetScenePath) {
    throw "Unity is already in PlayMode and the opened scene is not [$targetScenePath]. Exit PlayMode or switch scenes first."
}

$resultPath = Join-Path $ProjectRoot $resultRelativePath
if (Test-Path -LiteralPath $resultPath) {
    Remove-Item -LiteralPath $resultPath -Force
}

$startedPlayMode = $false

try {
    if ($initialState.isPlaying) {
        [void](Invoke-FileBridgeJson -ToolName "editor-application-set-state" -Params @{
                isPlaying = $false
                isPaused = $false
            } -TimeoutSeconds $StatePollTimeoutSeconds)
        [void](Wait-EditorState -IsPlaying $false -TimeoutSeconds $StatePollTimeoutSeconds)
    }

    [void](Invoke-FileBridgeJson -ToolName "editor-application-set-state" -Params @{
            isPlaying = $true
            isPaused = $false
        } -TimeoutSeconds $StatePollTimeoutSeconds)
    [void](Wait-EditorState -IsPlaying $true -TimeoutSeconds $StatePollTimeoutSeconds)
    $startedPlayMode = $true

    $validatorCode = @'
using FantasyWord.GameCore;

public class Script
{
    public static object Main()
    {
        return ClickMoveTestElementSurfaceVisualValidator.Start();
    }
}
'@

    [void](Invoke-FileBridgeJson -ToolName "script-execute" -Params @{
        csharpCode = $validatorCode
        className = "Script"
        methodName = "Main"
    } -TimeoutSeconds 120)

    $validatorResult = Wait-ResultFile -Path $resultPath -TimeoutSeconds $ResultPollTimeoutSeconds

    Write-Host "Element surface visual validation finished."
    Write-Host "Heartbeat:"
    Write-Host ($heartbeatInfo | ConvertTo-Json -Compress -Depth 5)
    Write-Host "VisualValidationResult:"
    Write-Host ($validatorResult | ConvertTo-Json -Depth 10)

    if (-not $validatorResult.Success) {
        throw "Element surface visual validation failed: $($validatorResult.Message)"
    }
}
finally {
    if ($startedPlayMode) {
        [void](Invoke-FileBridgeJson -ToolName "editor-application-set-state" -Params @{
                isPlaying = $false
                isPaused = $false
            } -TimeoutSeconds $StatePollTimeoutSeconds)
        [void](Wait-EditorState -IsPlaying $false -TimeoutSeconds $StatePollTimeoutSeconds)
    }
}
