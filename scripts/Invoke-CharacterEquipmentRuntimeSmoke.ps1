[CmdletBinding()]
param(
    [string]$ProjectRoot,
    [int]$HeartbeatMaxAgeSeconds = 120,
    [int]$StatePollTimeoutSeconds = 120,
    [int]$ResultPollTimeoutSeconds = 120
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$targetScenePath = "Assets/Scenes/ClickMoveTest.unity"
$resultRelativePath = "Temp/UnityBridge/results/character-equipment-runtime-smoke.json"

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

function Test-IsGitTrackedFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRootPath,
        [Parameter(Mandatory = $true)]
        [string]$RelativePath
    )

    $gitOutput = & git -C $ProjectRootPath ls-files -- $RelativePath 2>$null
    if ($LASTEXITCODE -ne 0) {
        return $false
    }

    return -not [string]::IsNullOrWhiteSpace(($gitOutput | Out-String).Trim())
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

    $trimmedStdout = $stdout.Trim()
    $trimmedStderr = $stderr.Trim()
    $output = ($trimmedStdout + [Environment]::NewLine + $trimmedStderr).Trim()
    if ($process.ExitCode -ne 0) {
        throw "AIBridge call failed: $ToolName`n$output"
    }

    if (-not [string]::IsNullOrWhiteSpace($trimmedStderr)) {
        Write-Warning $trimmedStderr
    }

    if (-not [string]::IsNullOrWhiteSpace($trimmedStdout)) {
        return $trimmedStdout
    }

    return $trimmedStderr
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

function Wait-EditorIdle {
    param([int]$TimeoutSeconds)

    $deadline = [DateTimeOffset]::UtcNow.AddSeconds($TimeoutSeconds)
    do {
        $state = Get-EditorState
        if (-not $state.isCompiling -and -not $state.isUpdating -and -not $state.isPlayingOrWillChangePlaymode) {
            return $state
        }

        Start-Sleep -Seconds 1
    } while ([DateTimeOffset]::UtcNow -lt $deadline)

    throw "Timed out waiting for Unity Editor to become idle."
}

function Get-OpenedScenes {
    $response = Invoke-BridgeJson -ToolName "scene-list-opened"
    if ($response.status -ne "success") {
        throw "Failed to read opened scenes: $($response | ConvertTo-Json -Compress -Depth 8)"
    }

    $message = $response.message
    if ([string]::IsNullOrWhiteSpace($message)) {
        return @()
    }

    return @($message | ConvertFrom-Json)
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

        Start-Sleep -Milliseconds 300
    } while ([DateTimeOffset]::UtcNow -lt $deadline)

    throw "Timed out waiting for runtime smoke result file: $Path"
}

function Get-ScriptExecuteFieldValue {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Response,
        [Parameter(Mandatory = $true)]
        [string]$FieldName
    )

    if ($null -eq $Response -or -not ($Response.PSObject.Properties.Name -contains "message")) {
        return $null
    }

    $message = $Response.message
    if ([string]::IsNullOrWhiteSpace($message)) {
        return $null
    }

    $trimmedMessage = $message.Trim()
    if (-not $trimmedMessage.StartsWith("{")) {
        throw "script-execute did not return structured JSON. Raw message: $trimmedMessage"
    }

    $payload = $trimmedMessage | ConvertFrom-Json
    $field = $payload.fields | Where-Object { $_.name -eq $FieldName } | Select-Object -First 1
    if ($null -ne $field) {
        return $field.value
    }

    return $null
}

$heartbeatPath = Join-Path $ProjectRoot "Temp\UnityBridge\heartbeat"
if (-not (Test-Path -LiteralPath $heartbeatPath)) {
    throw "Unity Editor is not connected to AIBridge. Missing heartbeat: $heartbeatPath"
}

foreach ($requiredTrackedPath in @(
    "Assets/Scenes/ClickMoveTest.unity",
    "Assets/Scenes/ClickMoveTest.unity.meta"
)) {
    if (-not (Test-IsGitTrackedFile -ProjectRootPath $ProjectRoot -RelativePath $requiredTrackedPath)) {
        throw "CharacterEquipment runtime smoke refuses to use untracked candidate validation scene asset: $requiredTrackedPath"
    }
}

$heartbeatInfo = Assert-BridgeHeartbeatReady -HeartbeatPath $heartbeatPath -MaxAgeSeconds $HeartbeatMaxAgeSeconds
[void](Invoke-BridgeJson -ToolName "assets-refresh" -JsonLiteral (@{
            bridgeSceneDirtyPolicy = "discard-generated"
        } | ConvertTo-Json -Compress -Depth 10))
$initialState = Wait-EditorIdle -TimeoutSeconds $StatePollTimeoutSeconds
$openedScenes = Get-OpenedScenes

if ($openedScenes.Count -ne 1) {
    throw "CharacterEquipment runtime smoke requires a single opened scene. Current count: $($openedScenes.Count)."
}

$originalScenePath = [string]$openedScenes[0].path
if ([bool]$openedScenes[0].isDirty) {
    throw "Opened scene [$originalScenePath] is dirty. Save or discard changes before running CharacterEquipment runtime smoke."
}

if ($initialState.isPlaying -and $originalScenePath -ne $targetScenePath) {
    throw "Unity is already in PlayMode and the opened scene is not [$targetScenePath]. Exit PlayMode or switch scenes first."
}

$resultPath = Join-Path $ProjectRoot $resultRelativePath
if (Test-Path -LiteralPath $resultPath) {
    Remove-Item -LiteralPath $resultPath -Force
}

$startedPlayMode = $false
$lockToken = $null
$sceneSwitched = $false

try {
    $lockResponse = Invoke-BridgeJson -ToolName "scene-lock-acquire" -JsonLiteral (@{
            owner = "codex-character-equipment-runtime-smoke"
            reason = "character equipment composition runtime smoke"
            mode = "wait"
            timeoutSeconds = 600
        } | ConvertTo-Json -Compress -Depth 10)
    $lockToken = if ($lockResponse.PSObject.Properties.Name -contains "lock" -and $null -ne $lockResponse.lock) {
        [string]$lockResponse.lock.token
    }
    else {
        [string](($lockResponse.message | ConvertFrom-Json).token)
    }

    if ([string]::IsNullOrWhiteSpace($lockToken)) {
        throw "AIBridge scene lock did not return a token."
    }

    if ($originalScenePath -ne $targetScenePath) {
        $sceneOpenJson = @{
            sceneRef = @{
                assetPath = $targetScenePath
            }
            loadSceneMode = "Single"
            bridgeSceneLockToken = $lockToken
            bridgeSceneDirtyPolicy = "discard-generated"
        } | ConvertTo-Json -Compress -Depth 10
        [void](Invoke-BridgeJson -ToolName "scene-open" -JsonLiteral $sceneOpenJson)
        $sceneSwitched = $true
    }

    if (-not $initialState.isPlaying) {
        $startPlayModeJson = @{
            isPlaying = $true
            bridgeSceneLockToken = $lockToken
            bridgeSceneDirtyPolicy = "discard-generated"
        } | ConvertTo-Json -Compress -Depth 10
        [void](Invoke-BridgeJson -ToolName "editor-application-set-state" -JsonLiteral $startPlayModeJson)
        [void](Wait-EditorState -IsPlaying $true -TimeoutSeconds $StatePollTimeoutSeconds)
        $startedPlayMode = $true
    }

    $validatorCode = @'
using FantasyWord.GameCore;

public class Script
{
    public static object Main()
    {
        return CharacterEquipmentRuntimeSmokeValidator.Start();
    }
}
'@

    $validatorJson = @{
        csharpCode = $validatorCode
        bridgeSceneLockToken = $lockToken
        bridgeSceneDirtyPolicy = "discard-generated"
    } | ConvertTo-Json -Compress -Depth 10

    $validatorResponse = Invoke-BridgeJson -ToolName "script-execute" -JsonLiteral $validatorJson
    $validatorResultPath = [string](Get-ScriptExecuteFieldValue -Response $validatorResponse -FieldName "ResultPath")
    if ([string]::IsNullOrWhiteSpace($validatorResultPath)) {
        throw "CharacterEquipment runtime smoke did not return a result file path."
    }

    $validatorResult = Wait-ResultFile -Path $validatorResultPath -TimeoutSeconds $ResultPollTimeoutSeconds

    Write-Host "CharacterEquipment runtime smoke finished."
    Write-Host "Heartbeat:"
    Write-Host ($heartbeatInfo | ConvertTo-Json -Compress -Depth 5)
    Write-Host "RuntimeSmokeResult:"
    Write-Host ($validatorResult | ConvertTo-Json -Depth 10)

    if (-not $validatorResult.Success) {
        throw "CharacterEquipment runtime smoke failed: $($validatorResult.Message)"
    }
}
finally {
    if ($startedPlayMode) {
        $stopPlayModeJson = @{
            isPlaying = $false
            bridgeSceneLockToken = $lockToken
            bridgeSceneDirtyPolicy = "discard-generated"
            bridgeFormalSceneRecoveryMode = "reload-if-disk-clean"
            bridgeFormalSceneRecoveryScenePaths = @($targetScenePath)
        } | ConvertTo-Json -Compress -Depth 10
        [void](Invoke-BridgeJson -ToolName "editor-application-set-state" -JsonLiteral $stopPlayModeJson)
        [void](Wait-EditorState -IsPlaying $false -TimeoutSeconds $StatePollTimeoutSeconds)
    }

    if ($startedPlayMode -and -not $sceneSwitched -and $originalScenePath -eq $targetScenePath) {
        $reloadTargetSceneJson = @{
            sceneRef = @{
                assetPath = $targetScenePath
            }
            loadSceneMode = "Single"
            bridgeSceneLockToken = $lockToken
            bridgeSceneDirtyPolicy = "discard-generated"
            bridgeFormalSceneRecoveryMode = "reload-if-disk-clean"
            bridgeFormalSceneRecoveryScenePaths = @($targetScenePath)
        } | ConvertTo-Json -Compress -Depth 10
        [void](Invoke-BridgeJson -ToolName "scene-open" -JsonLiteral $reloadTargetSceneJson)
    }

    if ($sceneSwitched -and -not [string]::IsNullOrWhiteSpace($originalScenePath)) {
        $restoreSceneJson = @{
            sceneRef = @{
                assetPath = $originalScenePath
            }
            loadSceneMode = "Single"
            bridgeSceneLockToken = $lockToken
            bridgeSceneDirtyPolicy = "discard-generated"
        } | ConvertTo-Json -Compress -Depth 10
        [void](Invoke-BridgeJson -ToolName "scene-open" -JsonLiteral $restoreSceneJson)
    }

    if (-not [string]::IsNullOrWhiteSpace($lockToken)) {
        $releaseLockJson = @{
            token = $lockToken
        } | ConvertTo-Json -Compress -Depth 10
        [void](Invoke-BridgeJson -ToolName "scene-lock-release" -JsonLiteral $releaseLockJson)
    }
}
