[CmdletBinding()]
param(
    [switch]$AllowDirtyFormalScene,
    [switch]$SkipAutoSaveCleanScene,
    [switch]$AsJson,
    [string]$Owner = "codex-formal-input-root",
    [string]$Reason = "formal scene explicit input root repair",
    [int]$HeartbeatMaxAgeSeconds = 120
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-ProjectRoot {
    $scriptRoot = if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
        $PSScriptRoot
    }
    else {
        Split-Path -Parent $PSCommandPath
    }

    [System.IO.Path]::GetFullPath((Join-Path $scriptRoot ".."))
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
        [string]$BridgePath,
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
    [void]$rawArguments.Add($BridgePath)
    [void]$rawArguments.Add($ToolName)
    if (-not [string]::IsNullOrWhiteSpace($JsonLiteral)) {
        [void]$rawArguments.Add($JsonLiteral)
    }

    $processStartInfo.Arguments = (($rawArguments | ForEach-Object { Quote-ProcessArgument $_ }) -join " ")

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
        [string]$BridgePath,
        [Parameter(Mandatory = $true)]
        [string]$ToolName,
        [hashtable]$Payload
    )

    $jsonLiteral = if ($null -eq $Payload -or $Payload.Count -eq 0) {
        $null
    }
    else {
        $Payload | ConvertTo-Json -Compress -Depth 12
    }

    return (Invoke-BridgeProcess -BridgePath $BridgePath -ToolName $ToolName -JsonLiteral $jsonLiteral) | ConvertFrom-Json
}

function Get-BridgeHeartbeatInfo {
    param([string]$HeartbeatPath)

    if (-not (Test-Path -LiteralPath $HeartbeatPath)) {
        return $null
    }

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
        TimestampLocal = $heartbeatTime.ToLocalTime().ToString("yyyy-MM-dd HH:mm:ss zzz")
        AgeSeconds = [int]$ageSeconds
        Pid = if ($null -ne $process) { $process.Id } else { $null }
        ProcessName = if ($null -ne $process) { $process.ProcessName } else { $null }
        Responding = if ($null -ne $process) { $process.Responding } else { $null }
        StartTime = if ($null -ne $process) { $process.StartTime.ToString("o") } else { $null }
        MainWindowTitle = if ($null -ne $process) { $process.MainWindowTitle } else { $null }
    }
}

function Get-BridgeCommandQueueInfo {
    param([Parameter(Mandatory = $true)][string]$CommandDirectoryPath)

    if (-not (Test-Path -LiteralPath $CommandDirectoryPath)) {
        return [ordered]@{
            Path = $CommandDirectoryPath
            Exists = $false
            FileCount = 0
            LatestFiles = @()
        }
    }

    $files = @(Get-ChildItem -LiteralPath $CommandDirectoryPath -File | Sort-Object LastWriteTime -Descending)
    $latestFiles = @(
        $files |
            Select-Object -First 10 |
            ForEach-Object {
                [ordered]@{
                    Name = $_.Name
                    Length = $_.Length
                    LastWriteTime = $_.LastWriteTime.ToString("o")
                }
            }
    )

    return [ordered]@{
        Path = $CommandDirectoryPath
        Exists = $true
        FileCount = @($files).Count
        LatestFiles = $latestFiles
    }
}

function Get-FileContent {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }

    Get-Content -LiteralPath $Path -Raw
}

function Get-PatternCount {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Content,
        [Parameter(Mandatory = $true)]
        [string]$Pattern
    )

    [regex]::Matches($Content, [regex]::Escape($Pattern)).Count
}

function Get-MissingPatterns {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Content,
        [Parameter(Mandatory = $true)]
        [string[]]$Patterns
    )

    $missing = New-Object System.Collections.Generic.List[string]
    foreach ($pattern in $Patterns) {
        if (-not $Content.Contains($pattern)) {
            [void]$missing.Add($pattern)
        }
    }

    @($missing)
}

function Get-FormalSceneInputRootStaticSceneReport {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot,
        [Parameter(Mandatory = $true)]
        [string]$RelativeScenePath
    )

    $sceneFullPath = Join-Path $ProjectRoot $RelativeScenePath
    $sceneContent = Get-FileContent -Path $sceneFullPath

    $formalRootPatterns = @(
        "m_Name: EventSystem",
        "Unity.InputSystem::UnityEngine.InputSystem.UI.InputSystemUIInputModule",
        "UnityEngine.UI::UnityEngine.EventSystems.EventSystem"
    )

    $actionReferencePatterns = @(
        "m_ActionsAsset:",
        "m_PointAction:",
        "m_MoveAction:",
        "m_SubmitAction:",
        "m_CancelAction:",
        "m_LeftClickAction:",
        "m_MiddleClickAction:",
        "m_RightClickAction:",
        "m_ScrollWheelAction:",
        "m_TrackedDevicePositionAction:",
        "m_TrackedDeviceOrientationAction:",
        "m_DeselectOnBackgroundClick: 0",
        "m_ScrollDeltaPerTick: 6"
    )

    if ($null -eq $sceneContent) {
        return [ordered]@{
            ScenePath = $RelativeScenePath
            SceneExists = $false
            HasExplicitInputRoot = $false
            Verdict = "scene-missing"
            EventSystemMarkerCount = 0
            InputSystemUIInputModuleCount = 0
            StandaloneInputModuleCount = 0
            MainCameraMarkerCount = 0
            MissingFormalRootPatterns = @($formalRootPatterns)
            MissingActionReferencePatterns = @($actionReferencePatterns)
        }
    }

    $eventSystemCount = Get-PatternCount -Content $sceneContent -Pattern "UnityEngine.UI::UnityEngine.EventSystems.EventSystem"
    $inputModuleCount = Get-PatternCount -Content $sceneContent -Pattern "Unity.InputSystem::UnityEngine.InputSystem.UI.InputSystemUIInputModule"
    $standaloneModuleCount = Get-PatternCount -Content $sceneContent -Pattern "UnityEngine.UI::UnityEngine.EventSystems.StandaloneInputModule"
    $mainCameraMarkerCount = Get-PatternCount -Content $sceneContent -Pattern "m_TagString: MainCamera"
    $missingFormalRootPatterns = @(Get-MissingPatterns -Content $sceneContent -Patterns $formalRootPatterns)
    $missingActionReferencePatterns = @(Get-MissingPatterns -Content $sceneContent -Patterns $actionReferencePatterns)
    $hasExplicitInputRoot = $missingFormalRootPatterns.Count -eq 0

    $verdict =
        if ($eventSystemCount -gt 1 -or $inputModuleCount -gt 1 -or $standaloneModuleCount -gt 1) {
            "multiple-root-markers"
        }
        elseif (-not $hasExplicitInputRoot) {
            "missing-explicit-root"
        }
        elseif ($missingActionReferencePatterns.Count -gt 0) {
            "missing-action-references"
        }
        else {
            "explicit-root-present"
        }

    [ordered]@{
        ScenePath = $RelativeScenePath
        SceneExists = $true
        HasExplicitInputRoot = $hasExplicitInputRoot
        Verdict = $verdict
        EventSystemMarkerCount = $eventSystemCount
        InputSystemUIInputModuleCount = $inputModuleCount
        StandaloneInputModuleCount = $standaloneModuleCount
        MainCameraMarkerCount = $mainCameraMarkerCount
        MissingFormalRootPatterns = @($missingFormalRootPatterns)
        MissingActionReferencePatterns = @($missingActionReferencePatterns)
    }
}

function Get-FormalSceneInputRootStaticInspection {
    param([Parameter(Mandatory = $true)][string]$ProjectRoot)

    $sceneReports = @(
        (Get-FormalSceneInputRootStaticSceneReport -ProjectRoot $ProjectRoot -RelativeScenePath "Assets/Scenes/SampleScene.unity")
    )

    [ordered]@{
        ProjectRoot = $ProjectRoot
        SceneReports = $sceneReports
        MissingExplicitRootScenes = @($sceneReports | Where-Object { -not $_.HasExplicitInputRoot } | ForEach-Object { $_.ScenePath })
    }
}

function Get-SuggestedNextAction {
    param([Parameter(Mandatory = $true)][System.Collections.IDictionary]$WorkflowReport)

    if (-not $WorkflowReport.BridgeReady) {
        $missingScenes = @()
        $commandQueueSummary = $null
        if ($null -ne $WorkflowReport.StaticInspection) {
            $missingScenes = @($WorkflowReport.StaticInspection.MissingExplicitRootScenes)
        }
        if ($null -ne $WorkflowReport.BridgeCommandQueue -and $WorkflowReport.BridgeCommandQueue.Exists -and $WorkflowReport.BridgeCommandQueue.FileCount -gt 0) {
            $commandQueueSummary = " Pending command files are still present in Temp/UnityBridge/commands."
        }

        if ($missingScenes.Count -gt 0) {
            return "Restore Unity Editor responsiveness first, then reopen this workflow. Static evidence already shows missing explicit input root scenes: $($missingScenes -join ', ').$commandQueueSummary"
        }

        return "Restore Unity Editor responsiveness first, then rerun the workflow.$commandQueueSummary"
    }

    if ($WorkflowReport.PendingUserSaveDecision) {
        return "The workflow is waiting for an explicit user decision about an already-dirty formal scene."
    }

    if (-not $WorkflowReport.Success) {
        return "Inspect the latest workflow result and fix the failing precondition before retrying."
    }

    if ($WorkflowReport.AutoSavedCleanFormalScene) {
        return "Bridge and repair flow succeeded. Continue with post-repair Unity-side verification when the editor is healthy."
    }

    return "No additional action is required from this script right now."
}

function Assert-BridgeHeartbeatReady {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$HeartbeatInfo,
        [int]$MaxAgeSeconds
    )

    if ($null -eq $HeartbeatInfo.Pid) {
        throw "Unity Editor process from AIBridge heartbeat is not running. Heartbeat=$($HeartbeatInfo.Raw)"
    }

    if ($HeartbeatInfo.Responding -eq $false) {
        throw "Unity Editor process is not responding. PID=$($HeartbeatInfo.Pid), MainWindowTitle=$($HeartbeatInfo.MainWindowTitle), heartbeatAgeSeconds=$($HeartbeatInfo.AgeSeconds), heartbeat=$($HeartbeatInfo.Raw)"
    }

    if ($HeartbeatInfo.AgeSeconds -gt $MaxAgeSeconds) {
        throw "Unity Editor heartbeat is stale. PID=$($HeartbeatInfo.Pid), MainWindowTitle=$($HeartbeatInfo.MainWindowTitle), ageSeconds=$($HeartbeatInfo.AgeSeconds), maxAgeSeconds=$MaxAgeSeconds, heartbeat=$($HeartbeatInfo.Raw)"
    }
}

function Invoke-FormalSceneAutomationMethod {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BridgePath,
        [Parameter(Mandatory = $true)]
        [string]$MethodName,
        [Parameter(Mandatory = $true)]
        [string]$SceneLockToken
    )

    $csharpCode = @"
public class Script
{
    public static object Main()
    {
        return FantasyWord.GameCore.FormalSceneInputRootAutomation.$MethodName();
    }
}
"@

    $response = Invoke-BridgeJson -BridgePath $BridgePath -ToolName "script-execute" -Payload @{
        csharpCode = $csharpCode
        bridgeSceneLockToken = $SceneLockToken
        bridgeSceneDirtyPolicy = "ignore"
    }

    if ($response.status -ne "success") {
        throw "Formal scene automation call failed: $MethodName`n$($response | ConvertTo-Json -Compress -Depth 12)"
    }

    return $response.message
}

$projectRoot = Get-ProjectRoot
$bridgePath = Join-Path $projectRoot ".codex\skills\aibridge\bridge.py"
if (-not (Test-Path -LiteralPath $bridgePath)) {
    throw "AIBridge CLI not found: $bridgePath"
}

$workflowReport = [ordered]@{
    ProjectRoot = $projectRoot
    BridgeHealthChecked = $false
    BridgeReady = $false
    BridgeHeartbeat = $null
    BridgeCommandQueue = $null
    BridgeHealthError = $null
    StaticInspection = $null
    LockAcquired = $false
    InitialInspection = $null
    RepairAttempted = $false
    RepairMethod = $null
    RepairResult = $null
    AutoSavedCleanFormalScene = $false
    FinalInspection = $null
    PendingUserSaveDecision = $false
    SuggestedNextAction = $null
    Success = $false
    Message = ""
}

$sceneLockToken = $null
$heartbeatPath = Join-Path $projectRoot "Temp\UnityBridge\heartbeat"
$commandDirectoryPath = Join-Path $projectRoot "Temp\UnityBridge\commands"
$canContinueWorkflow = $true

try {
    $workflowReport.BridgeHealthChecked = $true
    $workflowReport.StaticInspection = Get-FormalSceneInputRootStaticInspection -ProjectRoot $projectRoot
    $heartbeatInfo = Get-BridgeHeartbeatInfo -HeartbeatPath $heartbeatPath
    $commandQueueInfo = Get-BridgeCommandQueueInfo -CommandDirectoryPath $commandDirectoryPath
    $workflowReport.BridgeHeartbeat = $heartbeatInfo
    $workflowReport.BridgeCommandQueue = $commandQueueInfo

    if ($null -eq $heartbeatInfo) {
        $workflowReport.BridgeHealthError = "Missing heartbeat: $heartbeatPath"
        $workflowReport.Message = "AIBridge is not connected to a Unity Editor. The repair workflow did not start."
        $workflowReport.Success = $false
        $canContinueWorkflow = $false
    }

    if ($canContinueWorkflow) {
        try {
            Assert-BridgeHeartbeatReady -HeartbeatInfo $heartbeatInfo -MaxAgeSeconds $HeartbeatMaxAgeSeconds
            $workflowReport.BridgeReady = $true
        }
        catch {
            $workflowReport.BridgeHealthError = $_.Exception.Message
            $workflowReport.Message = "AIBridge is not ready. The repair workflow did not start."
            $workflowReport.Success = $false
            $canContinueWorkflow = $false
        }
    }

    if ($canContinueWorkflow) {
        $lockResponse = Invoke-BridgeJson -BridgePath $bridgePath -ToolName "scene-lock-acquire" -Payload @{
            owner = $Owner
            reason = $Reason
            mode = "wait"
            timeoutSeconds = 600
        }

        if ($lockResponse.status -ne "success") {
            throw "Failed to acquire scene lock: $($lockResponse | ConvertTo-Json -Compress -Depth 12)"
        }

        $sceneLockToken = [string]$lockResponse.message.token
        $workflowReport.LockAcquired = $true

        $initialInspection = Invoke-FormalSceneAutomationMethod -BridgePath $bridgePath -MethodName "InspectOpenFormalScene" -SceneLockToken $sceneLockToken
        $workflowReport.InitialInspection = $initialInspection

        if (-not $initialInspection.Success) {
            $workflowReport.Message = "Formal scene input root inspection failed. Repair was not started."
            $workflowReport.FinalInspection = $initialInspection
            $workflowReport.Success = $false
        }
        elseif (-not $initialInspection.IsFormalScene) {
            $workflowReport.Message = "The active scene is not a formal scene. Repair was skipped."
            $workflowReport.FinalInspection = $initialInspection
            $workflowReport.Success = $true
        }
        elseif (-not $initialInspection.NeedsRepair) {
            $workflowReport.Message = "The active formal scene already has an explicit input root. No repair is required."
            $workflowReport.FinalInspection = $initialInspection
            $workflowReport.Success = $true
        }
        else {
            $repairMethod = [string]$initialInspection.RecommendedRepairMethod
            if ([string]::IsNullOrWhiteSpace($repairMethod)) {
                throw "Initial inspection requires repair but did not provide RecommendedRepairMethod."
            }

            $workflowReport.RepairMethod = $repairMethod

            if ($initialInspection.SceneIsDirty -and -not $AllowDirtyFormalScene) {
                $workflowReport.PendingUserSaveDecision = $true
                $workflowReport.FinalInspection = $initialInspection
                $workflowReport.Message = "The active formal scene was already dirty before repair. Workflow stopped and now requires explicit authorization for dirty-scene handling."
                $workflowReport.Success = $true
            }
            else {
                $repairResult = Invoke-FormalSceneAutomationMethod -BridgePath $bridgePath -MethodName $repairMethod -SceneLockToken $sceneLockToken
                $workflowReport.RepairAttempted = $true
                $workflowReport.RepairResult = $repairResult

                if (-not $repairResult.Success) {
                    $workflowReport.FinalInspection = $repairResult
                    $workflowReport.Message = "Formal scene input root repair was executed, but the post-repair result is still not valid."
                    $workflowReport.Success = $false
                }
                elseif (-not $initialInspection.SceneIsDirty -and -not $SkipAutoSaveCleanScene) {
                    $saveResponse = Invoke-BridgeJson -BridgePath $bridgePath -ToolName "scene-save" -Payload @{
                        bridgeSceneLockToken = $sceneLockToken
                        bridgeSceneDirtyPolicy = "ignore"
                    }

                    if ($saveResponse.status -ne "success") {
                        throw "scene-save failed after clean formal scene repair: $($saveResponse | ConvertTo-Json -Compress -Depth 12)"
                    }

                    $workflowReport.AutoSavedCleanFormalScene = $true
                    $workflowReport.FinalInspection = Invoke-FormalSceneAutomationMethod -BridgePath $bridgePath -MethodName "InspectOpenFormalScene" -SceneLockToken $sceneLockToken
                    $workflowReport.Message = "Formal scene input root repair completed and the formal scene was saved in the same workflow."
                    $workflowReport.Success = $true
                }
                else {
                    $workflowReport.PendingUserSaveDecision = $initialInspection.SceneIsDirty
                    $workflowReport.FinalInspection = Invoke-FormalSceneAutomationMethod -BridgePath $bridgePath -MethodName "InspectOpenFormalScene" -SceneLockToken $sceneLockToken
                    if ($initialInspection.SceneIsDirty) {
                        $workflowReport.Message = "Formal scene input root repair completed on an already-dirty formal scene, but the workflow did not save it. A user decision is still required."
                    }
                    else {
                        $workflowReport.Message = "Formal scene input root repair completed, but auto-save was skipped by parameter."
                    }
                    $workflowReport.Success = $true
                }
            }
        }
    }
}
finally {
    if (-not [string]::IsNullOrWhiteSpace($sceneLockToken)) {
        try {
            [void](Invoke-BridgeJson -BridgePath $bridgePath -ToolName "scene-lock-release" -Payload @{
                token = $sceneLockToken
            })
        }
        catch {
            if ([string]::IsNullOrWhiteSpace([string]$workflowReport.Message)) {
                $workflowReport.Message = "Scene lock release failed: $($_.Exception.Message)"
            }
            else {
                $workflowReport.Message = "$($workflowReport.Message) Scene lock release failed: $($_.Exception.Message)"
            }

            if ($workflowReport.Success) {
                $workflowReport.Success = $false
            }
        }
    }
}

$workflowReport.SuggestedNextAction = Get-SuggestedNextAction -WorkflowReport $workflowReport

if ($AsJson) {
    $workflowReport | ConvertTo-Json -Depth 12
    exit 0
}

Write-Host "FantasyWord formal scene input root repair"
Write-Host ("Success: {0}" -f $workflowReport.Success)
Write-Host ("LockAcquired: {0}" -f $workflowReport.LockAcquired)
Write-Host ("RepairAttempted: {0}" -f $workflowReport.RepairAttempted)
Write-Host ("RepairMethod: {0}" -f $workflowReport.RepairMethod)
Write-Host ("AutoSavedCleanFormalScene: {0}" -f $workflowReport.AutoSavedCleanFormalScene)
Write-Host ("PendingUserSaveDecision: {0}" -f $workflowReport.PendingUserSaveDecision)
Write-Host ("Message: {0}" -f $workflowReport.Message)
