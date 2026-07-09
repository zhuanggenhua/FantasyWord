[CmdletBinding()]
param(
    [string[]]$ScenePaths = @(
        "Assets/Scenes/SampleScene.unity"
    ),
    [switch]$AsJson
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

function Get-FormalSceneInputRootReport {
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

$projectRoot = Get-ProjectRoot
$sceneReports = foreach ($scenePath in $ScenePaths) {
    Get-FormalSceneInputRootReport -ProjectRoot $projectRoot -RelativeScenePath $scenePath
}

$report = [ordered]@{
    ProjectRoot = $projectRoot
    SceneReports = @($sceneReports)
}

if ($AsJson) {
    $report | ConvertTo-Json -Depth 6
    exit 0
}

Write-Host "FantasyWord formal scene input root inspection"
Write-Host ("ProjectRoot: {0}" -f $report.ProjectRoot)

foreach ($sceneReport in $report.SceneReports) {
    Write-Host ("Scene: {0}" -f $sceneReport.ScenePath)
    Write-Host ("  Exists: {0}" -f $sceneReport.SceneExists)
    Write-Host ("  Verdict: {0}" -f $sceneReport.Verdict)
    Write-Host ("  HasExplicitInputRoot: {0}" -f $sceneReport.HasExplicitInputRoot)
    Write-Host ("  EventSystemMarkerCount: {0}" -f $sceneReport.EventSystemMarkerCount)
    Write-Host ("  InputSystemUIInputModuleCount: {0}" -f $sceneReport.InputSystemUIInputModuleCount)
    Write-Host ("  StandaloneInputModuleCount: {0}" -f $sceneReport.StandaloneInputModuleCount)
    Write-Host ("  MainCameraMarkerCount: {0}" -f $sceneReport.MainCameraMarkerCount)

    foreach ($pattern in $sceneReport.MissingFormalRootPatterns) {
        Write-Host ("  [missing-formal-root] {0}" -f $pattern)
    }

    foreach ($pattern in $sceneReport.MissingActionReferencePatterns) {
        Write-Host ("  [missing-action-reference] {0}" -f $pattern)
    }
}
