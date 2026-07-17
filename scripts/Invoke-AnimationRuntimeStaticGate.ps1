param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [switch]$AsJson
)

$ErrorActionPreference = "Stop"

function ConvertTo-RepoPath {
    param([string]$Path)

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $rootPath = [System.IO.Path]::GetFullPath($ProjectRoot).TrimEnd('\', '/')
    if ($fullPath.StartsWith($rootPath, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $fullPath.Substring($rootPath.Length).TrimStart('\', '/').Replace('\', '/')
    }

    return $fullPath.Replace('\', '/')
}

function Get-CSharpMethodBlock {
    param(
        [string]$Text,
        [string]$MethodName
    )

    $lines = $Text -split "`r?`n"
    $capturing = $false
    $sawOpeningBrace = $false
    $braceDepth = 0
    $block = [System.Collections.Generic.List[string]]::new()

    foreach ($line in $lines) {
        if (-not $capturing) {
            if ($line -notmatch ("\b{0}\s*\(" -f [regex]::Escape($MethodName))) {
                continue
            }

            $capturing = $true
        }

        [void]$block.Add($line)

        foreach ($char in $line.ToCharArray()) {
            if ($char -eq '{') {
                $braceDepth++
                $sawOpeningBrace = $true
            }
            elseif ($char -eq '}') {
                $braceDepth--
            }
        }

        if ($sawOpeningBrace -and $braceDepth -le 0) {
            return ($block -join "`n")
        }
    }

    return ($block -join "`n")
}

$violations = [System.Collections.Generic.List[string]]::new()
$animationRuntimeRoot = Join-Path $ProjectRoot "Assets/Scripts/GameCore/Runtime/Animation"
$uiRuntimeRoot = Join-Path $ProjectRoot "Assets/Scripts/GameCore/Runtime/UI"
$followTargetDirectionPath = Join-Path $animationRuntimeRoot "FollowTargetDirection.cs"
$transformShakerPath = Join-Path $animationRuntimeRoot "TransformShaker.cs"
$cameraShakePath = Join-Path $animationRuntimeRoot "CameraShake.cs"
$damageScreenFlashPath = Join-Path $animationRuntimeRoot "DamageScreenFlash.cs"
$uiStatBarPath = Join-Path $uiRuntimeRoot "HUD/Stats/UIStatBar.cs"

$followTargetDirectionLifecycleBound = $false
if (Test-Path -LiteralPath $followTargetDirectionPath) {
    $text = Get-Content -Raw -LiteralPath $followTargetDirectionPath
    $awakeBlock = Get-CSharpMethodBlock -Text $text -MethodName "Awake"
    $onEnableBlock = Get-CSharpMethodBlock -Text $text -MethodName "OnEnable"
    $startBlock = Get-CSharpMethodBlock -Text $text -MethodName "Start"
    $onDisableBlock = Get-CSharpMethodBlock -Text $text -MethodName "OnDisable"
    $destroyBlock = Get-CSharpMethodBlock -Text $text -MethodName "OnDestroy"
    $followTargetDirectionLifecycleBound =
        $awakeBlock -notmatch "AddTargetDirectionChangedListener\s*\(" -and
        $text -match "bool\s+m_targetDirectionListening" -and
        $onEnableBlock -match "StartTargetDirectionListeningIfReady\s*\(\s*\)" -and
        $startBlock -match "StartTargetDirectionListeningIfReady\s*\(\s*\)" -and
        $onDisableBlock -match "StopTargetDirectionListening\s*\(\s*\)" -and
        $destroyBlock -match "StopTargetDirectionListening\s*\(\s*\)" -and
        $text -match "AddTargetDirectionChangedListener\s*\(\s*OnTargetDirectionChanged\s*\)" -and
        $text -match "RemoveTargetDirectionChangedListener\s*\(\s*OnTargetDirectionChanged\s*\)" -and
        $text -match "GetTargetDirection\s*\(\s*\)"

    if (-not $followTargetDirectionLifecycleBound) {
        [void]$violations.Add(("{0}: FollowTargetDirection must bind target-direction events on enable/start retry, unbind on disable/destroy, and apply the current target direction after binding." -f (ConvertTo-RepoPath $followTargetDirectionPath)))
    }
}
else {
    [void]$violations.Add("FollowTargetDirection.cs is missing.")
}

$transformShakerExplicitOwnerBound = $false
if ((Test-Path -LiteralPath $transformShakerPath) -and
    (Test-Path -LiteralPath $cameraShakePath) -and
    (Test-Path -LiteralPath $uiStatBarPath)) {
    $transformShakerText = Get-Content -Raw -LiteralPath $transformShakerPath
    $cameraShakeText = Get-Content -Raw -LiteralPath $cameraShakePath
    $uiStatBarText = Get-Content -Raw -LiteralPath $uiStatBarPath
    $cameraShakeOnDisableBlock = Get-CSharpMethodBlock -Text $cameraShakeText -MethodName "OnDisable"
    $uiStatBarOnDisableBlock = Get-CSharpMethodBlock -Text $uiStatBarText -MethodName "OnDisable"
    $uiStatBarDestroyBlock = Get-CSharpMethodBlock -Text $uiStatBarText -MethodName "OnDestroy"

    $transformShakerExplicitOwnerBound =
        $transformShakerText -match "Shake\s*\(\s*MonoBehaviour\s+owner" -and
        $transformShakerText -match "owner\.StartCoroutine\s*\(" -and
        $transformShakerText -match "handler\.Owner\.StopCoroutine\s*\(" -and
        $transformShakerText -notmatch "GameManager\.Instance" -and
        $cameraShakeText -match "TransformShaker\.Shake\s*\(\s*this\s*," -and
        $cameraShakeText -match "StopActiveShake\s*\(\s*\)" -and
        $cameraShakeOnDisableBlock -match "StopActiveShake\s*\(\s*\)" -and
        $uiStatBarText -match "owner:\s*this" -and
        $uiStatBarText -match "StopShake\s*\(\s*\)" -and
        $uiStatBarOnDisableBlock -match "StopShake\s*\(\s*\)" -and
        $uiStatBarDestroyBlock -match "StopShake\s*\(\s*\)"

    if (-not $transformShakerExplicitOwnerBound) {
        [void]$violations.Add("TransformShaker must use an explicit MonoBehaviour coroutine owner, and CameraShake/UIStatBar must stop active shakes on disable or destroy.")
    }
}
else {
    [void]$violations.Add("TransformShaker, CameraShake, or UIStatBar is missing.")
}

$damagePresentationListenersGuardGameManager = $false
if ((Test-Path -LiteralPath $cameraShakePath) -and
    (Test-Path -LiteralPath $damageScreenFlashPath)) {
    $cameraShakeText = Get-Content -Raw -LiteralPath $cameraShakePath
    $damageScreenFlashText = Get-Content -Raw -LiteralPath $damageScreenFlashPath
    $cameraShakeSourcesBlock = Get-CSharpMethodBlock -Text $cameraShakeText -MethodName "TryGetCameraShakeSources"
    $cameraShakeWithoutSourcesBlock = $cameraShakeText.Replace($cameraShakeSourcesBlock, "")
    $cameraShakeCurrentCharacterBlock = Get-CSharpMethodBlock -Text $cameraShakeText -MethodName "TryGetCurrentControlledCharacter"
    $damageFlashCurrentCharacterBlock = Get-CSharpMethodBlock -Text $damageScreenFlashText -MethodName "TryGetCurrentControlledCharacter"

    $damagePresentationListenersGuardGameManager =
        $cameraShakeText -match "TryGetCameraShakeSources\s*\(" -and
        $cameraShakeSourcesBlock -match "GameManager\.Exists\s*\(\s*\)" -and
        $cameraShakeSourcesBlock -match "GameManager\.Config\s*==\s*null" -and
        $cameraShakeSourcesBlock -match "GameManager\.Config\.cameraShakeSources" -and
        $cameraShakeWithoutSourcesBlock -notmatch "GameManager\.Config\.cameraShakeSources" -and
        $cameraShakeCurrentCharacterBlock -match "GameManager\.Exists\s*\(\s*\)" -and
        $cameraShakeCurrentCharacterBlock -match "currentControlledCharacter\s*=\s*null" -and
        $cameraShakeCurrentCharacterBlock -match "return\s+false" -and
        $damageScreenFlashText -match "TryGetCurrentControlledCharacter\s*\(" -and
        $damageFlashCurrentCharacterBlock -match "GameManager\.Exists\s*\(\s*\)" -and
        $damageFlashCurrentCharacterBlock -match "currentControlledCharacter\s*=\s*null" -and
        $damageFlashCurrentCharacterBlock -match "return\s+false"

    if (-not $damagePresentationListenersGuardGameManager) {
        [void]$violations.Add("Damage presentation listeners must guard GameManager/PlayerSystem readiness before reading controlled-character or camera-shake settings.")
    }
}
else {
    [void]$violations.Add("CameraShake.cs or DamageScreenFlash.cs is missing.")
}

$result = [ordered]@{
    Passed = $violations.Count -eq 0
    FollowTargetDirectionLifecycleBound = $followTargetDirectionLifecycleBound
    TransformShakerExplicitOwnerBound = $transformShakerExplicitOwnerBound
    DamagePresentationListenersGuardGameManager = $damagePresentationListenersGuardGameManager
    ViolationCount = $violations.Count
    Violations = $violations
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 8
}
else {
    if ($result.Passed) {
        Write-Host "Animation runtime static gate passed."
    }
    else {
        Write-Host "Animation runtime static gate failed."
        foreach ($violation in $violations) {
            Write-Host " - $violation"
        }
    }
}

if ($violations.Count -gt 0) {
    exit 2
}

