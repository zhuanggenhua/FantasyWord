[CmdletBinding()]
param(
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

    return [System.IO.Path]::GetFullPath((Join-Path $scriptRoot ".."))
}

function Get-RelativePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot,
        [Parameter(Mandatory = $true)]
        [string]$FullPath
    )

    $normalizedRoot = [System.IO.Path]::GetFullPath($ProjectRoot).TrimEnd('\')
    $normalizedPath = [System.IO.Path]::GetFullPath($FullPath)

    if ($normalizedPath.StartsWith($normalizedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $normalizedPath.Substring($normalizedRoot.Length).TrimStart('\')
    }

    return $normalizedPath
}

$projectRoot = Get-ProjectRoot
$scriptsRoot = Join-Path $projectRoot "Assets/Scripts"
$editorRoot = Join-Path $projectRoot "Assets/Editor"

$allowedEquipmentPrefixes = @(
    "Assets\Scripts\Presentation\EquipmentSystem\",
    "Assets\Editor\Presentation\EquipmentSystem\Bridge\",
    "Assets\Scripts\Items\Runtime\Equipment\",
    "Assets\Editor\GameCore\EditorWindows\"
)

$allowedEquipmentPaths = @(
    "Assets\Scripts\GameCore\Runtime\Presentation\CuePlayGameCoreAnimator.cs",
    "Assets\Scripts\Presentation\WaterReflection\Runtime\WaterReflectionCaster2D.cs",
    "Assets\Scripts\Presentation\WaterReflection\Editor\ClickMoveTestWaterReflectionInstaller.cs"
)

$allowedCombatPrefixes = @()

$allowedCombatPaths = @(
    "Assets\Scripts\GameCore\Runtime\Combat\FormalAttributeCatalog.cs",
    "Assets\Scripts\GameCore\Runtime\Combat\FormalGameplayEffectDamageBridge.cs",
    "Assets\Scripts\GameCore\Runtime\Combat\FormalGameplayEffectDamageHelper.cs",
    "Assets\Scripts\GameCore\Runtime\Combat\FormalGameplayEffectDamageSystem.cs",
    "Assets\Scripts\GameCore\Runtime\Combat\FormalGameplayEffectResourceModifier.cs",
    "Assets\Scripts\GameCore\Runtime\Combat\FormalGameplayTagCatalog.cs",
    "Assets\Scripts\GameCore\Runtime\Combat\Gas2DTargetCatchers.cs",
    "Assets\Scripts\GameCore\Runtime\Combat\Abilities\Active\ActiveAbilityBase.cs",
    "Assets\Scripts\GameCore\Runtime\Combat\Abilities\Active\TimelineActiveAbility.cs",
    "Assets\Scripts\GameCore\Runtime\Combat\GAS\TaskApplyWorldElement.cs",
    "Assets\Scripts\GameCore\Runtime\Database\Abilities\AbilitySheet.cs",
    "Assets\Scripts\GameCore\Runtime\Entities\Characters\CharacterAbilitySet.cs",
    "Assets\Scripts\GameCore\Runtime\Entities\Characters\CharacterAbilitySet.FormalRules.cs",
    "Assets\Scripts\GameCore\Runtime\Entities\Characters\CharacterBase.Abilities.cs",
    "Assets\Scripts\GameCore\Runtime\Entities\Characters\CharacterCommandExecutor.cs",
    "Assets\Scripts\GameCore\Runtime\Game\FormalAbilityRuntimeBootstrap.cs",
    "Assets\Editor\GameCore\Tests\FormalAttributeSingleSourceEditModeTests.cs",
    "Assets\Editor\GameCore\Tests\FormalDamagePipelineEditModeTests.cs",
    "Assets\Editor\GameCore\Tests\GasEditModeTestHelper.cs",
    "Assets\Editor\GameCore\Tests\MeleeAttackAbilityEditModeTests.cs",
    "Assets\Editor\GameCore\Tests\TerrainSurfaceDamageSystemEditModeTests.cs",
    "Assets\Scripts\GameCore\Runtime\Combat\Effects\Temporal\ITemporalEffect.cs",
    "Assets\Scripts\GameCore\Runtime\Combat\Effects\Temporal\ATemporalEffect.cs",
    "Assets\Scripts\GameCore\Runtime\Combat\Effects\Temporal\FormalTemporalPeriodicDamageBuilder.cs",
    "Assets\Scripts\GameCore\Runtime\Combat\Effects\Temporal\FormalTemporalPeriodicSpecBuilder.cs",
    "Assets\Scripts\GameCore\Runtime\Combat\Effects\Temporal\FormalTemporalPeriodicCurrentResourceBuilder.cs",
    "Assets\Scripts\GameCore\Runtime\Entities\Characters\CharacterBase.Contracts.cs",
    "Assets\Scripts\GameCore\Runtime\Entities\Characters\CharacterBase.cs",
    "Assets\Scripts\GameCore\Runtime\Entities\Characters\FormalAbilitySystemAttributeExtensions.cs",
    "Assets\Scripts\GameCore\Runtime\Entities\Characters\CharacterBase.StateApi.cs",
    "Assets\Scripts\GameCore\Runtime\Entities\Characters\CharacterBase.GASRuntime.cs",
    "Assets\Scripts\GameCore\Runtime\Entities\Characters\CharacterBase.Resources.cs",
    "Assets\Scripts\GameCore\Runtime\Presentation\CuePlayGameCoreAnimator.cs",
    "Assets\Scripts\GameCore\Runtime\Presentation\CuePlayGameCoreAudio.cs",
    "Assets\Scripts\GameCore\Runtime\Presentation\CuePlayGameCoreFeedback.cs",
    "Assets\Editor\GameCore\GAS\GasTimelineHitboxSceneHandle.cs",
    "Assets\Editor\GameCore\Bridge\CompositeRuntimeSmokeValidator.cs",
    "Assets\Editor\GameCore\Bridge\ClickMoveTestElementSurfaceVisualValidator.cs",
    "Assets\Editor\GameCore\Bridge\ClickMoveTestGasBasicAttackValidator.cs"
)

$allowedPresentationPrefixes = @(
    "Assets\Scripts\GameCore\Runtime\Audio\",
    "Assets\Scripts\GameCore\Runtime\Database\Audio\"
)

$allowedSaveKitPaths = @(
    "Assets\Scripts\GameCore\Runtime\Game\Systems\SaveSystem.cs",
    "Assets\Scripts\GameCore\Runtime\Game\Systems\SaveFileStorageRuntime.cs"
)

$equipmentPatterns = @(
    '^\s*using\s+EquipmentSystem\s*;',
    '\bEquipmentRenderer\b',
    '\bEquipmentRenderData\b',
    '\bCharacterAppearance\b'
)

$combatPatterns = @(
    '^\s*using\s+GAS\.Runtime\s*;',
    '\bAbilitySystemComponent\b',
    '\bGameplayEffectAsset\b',
    '\bAbilityAsset\b'
)

$presentationPatterns = @(
    '^\s*using\s+Ami\.BroAudio\s*;',
    '\bBroAudio\.',
    '\bSoundID\b'
)

$forbiddenLayerNamePatterns = @(
    '(^|\\)(Compatibility|Compat|FoundationSupport|Adapter|Adapters|Wrapper|Wrappers|Facade|Facades)(\\|$)',
    '\b(class|struct|interface)\s+[A-Za-z0-9_]*(Compatibility|Compat|FoundationSupport|Adapter|Wrapper|Facade)[A-Za-z0-9_]*\b'
)

$forbiddenLifecycleDependencyPatterns = @(
    '^\s*using\s+MoreMountains\.',
    '\bMoreMountains\.',
    '\bTopDownEngineEvent\b',
    '\bTopDownEngineEventTypes\b',
    '\bMMEventListener\s*<',
    '\bMMSingleton\s*<',
    '\bMMCameraEvent\b',
    '\bMMFade(In|Out|Stop)?Event\b',
    '\bLevelManager\s*\.',
    '\bGUIManager\s*\.',
    '\bInputManager\s*\.Instance\b',
    '\bYokiFrame\.Architecture\b',
    '\bArchitecture\s*<',
    '\bIArchitecture\b',
    '\bSingletonKit\s*<',
    '\bMonoSingleton\s*<'
)

$forbiddenUiHostDependencyPatterns = @(
    '\bUIKit\s*\.',
    '\bUIRoot\s*\.',
    '\bUIPanel\b'
)

$allowedUiHostDependencyPrefixes = @(
    "Assets\Scripts\GameCore\Runtime\UI\",
    "Assets\Scripts\GameCore\Runtime\UI\UIKitSmoke\",
    "Assets\Editor\GameCore\Bridge\UIKitSmoke\"
)

$forbiddenSaveKitDirectCallPatterns = @(
    '\bSaveKit\s*\.'
)

$allowedFeedbackBoundaryPaths = @(
    "Assets\Editor\GameCore\Tests\MeleeAttackAbilityEditModeTests.cs",
    "Assets\Scripts\GameCore\Runtime\Presentation\GameplayFeedbackSet.cs"
)

$allowedFeedbackBoundaryPatterns = @(
    '^\s*using\s+MoreMountains\.Feedbacks\s*;',
    '\bMMFeedbacks\b',
    '\.PlayFeedbacks\s*\('
)

$allowedLayerPrefixes = @(
    "Assets\Editor\GameCore\Bridge\"
)

function Test-IsAllowedLifecycleDependency {
    param(
        [Parameter(Mandatory = $true)]
        [string]$NormalizedRelativePath,
        [Parameter(Mandatory = $true)]
        [string]$Line
    )

    $isFeedbackBoundary = $false
    foreach ($path in $allowedFeedbackBoundaryPaths) {
        if ($NormalizedRelativePath -eq $path.ToLowerInvariant()) {
            $isFeedbackBoundary = $true
            break
        }
    }

    if ($isFeedbackBoundary) {
        foreach ($pattern in $allowedFeedbackBoundaryPatterns) {
            if ($Line -match $pattern) {
                return $true
            }
        }
    }

    return $false
}

function Test-IsAllowedExactPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$NormalizedRelativePath,
        [Parameter(Mandatory = $true)]
        [string[]]$AllowedPaths
    )

    foreach ($path in $AllowedPaths) {
        if ($NormalizedRelativePath -eq $path.ToLowerInvariant()) {
            return $true
        }
    }

    return $false
}

function Test-IsAllowedUiHostDependencyPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$NormalizedRelativePath
    )

    foreach ($prefix in $allowedUiHostDependencyPrefixes) {
        if ($NormalizedRelativePath.StartsWith($prefix.ToLowerInvariant())) {
            return $true
        }
    }

    return $false
}

$violations = New-Object System.Collections.Generic.List[object]
$scriptFiles = @()
if (Test-Path -LiteralPath $scriptsRoot) {
    $scriptFiles += Get-ChildItem -Path $scriptsRoot -Recurse -Filter *.cs -File
}
if (Test-Path -LiteralPath $editorRoot) {
    $scriptFiles += Get-ChildItem -Path $editorRoot -Recurse -Filter *.cs -File
}

foreach ($file in $scriptFiles) {
    $relativePath = Get-RelativePath -ProjectRoot $projectRoot -FullPath $file.FullName
    $normalizedRelativePath = $relativePath.Replace('/', '\').ToLowerInvariant()

    $isLayerNameAllowed = $false
    foreach ($prefix in $allowedLayerPrefixes) {
        if ($normalizedRelativePath.StartsWith($prefix.ToLowerInvariant())) {
            $isLayerNameAllowed = $true
            break
        }
    }

    if (-not $isLayerNameAllowed) {
        foreach ($pattern in $forbiddenLayerNamePatterns) {
            if ($relativePath -match $pattern) {
                $violations.Add([ordered]@{
                    Plugin = "Forbidden compatibility layer"
                    RelativePath = $relativePath
                    LineNumber = 0
                    Line = "Forbidden path segment: $pattern"
                })
            }
        }
    }

    $checkSets = @(
        @{
            AllowedPrefixes = $allowedEquipmentPrefixes
            AllowedPaths = $allowedEquipmentPaths
            Patterns = $equipmentPatterns
            Plugin = "EquipmentSystem"
        },
        @{
            AllowedPrefixes = $allowedCombatPrefixes
            AllowedPaths = $allowedCombatPaths
            Patterns = $combatPatterns
            Plugin = "EX-GAS"
        },
        @{
            AllowedPrefixes = $allowedPresentationPrefixes
            Patterns = $presentationPatterns
            Plugin = "BroAudio"
        }
    )

    $lineNumber = 0
    foreach ($line in [System.IO.File]::ReadLines($file.FullName)) {
        $lineNumber++
        $trimmedLine = $line.TrimStart()
        $isCommentLine = $trimmedLine.StartsWith("//") -or $trimmedLine.StartsWith("///") -or $trimmedLine.StartsWith("*")

        if (-not $isCommentLine -and -not $isLayerNameAllowed) {
            foreach ($pattern in $forbiddenLayerNamePatterns) {
                if ($line -match $pattern) {
                    $violations.Add([ordered]@{
                        Plugin = "Forbidden compatibility layer"
                        RelativePath = $relativePath
                        LineNumber = $lineNumber
                        Line = $line.Trim()
                    })
                }
            }
        }

        if (-not $isCommentLine) {
            foreach ($pattern in $forbiddenLifecycleDependencyPatterns) {
                if ($line -match $pattern) {
                    if (Test-IsAllowedLifecycleDependency -NormalizedRelativePath $normalizedRelativePath -Line $line) {
                        continue
                    }

                    $violations.Add([ordered]@{
                        Plugin = "Forbidden lifecycle dependency"
                        RelativePath = $relativePath
                        LineNumber = $lineNumber
                        Line = $line.Trim()
                    })
                }
            }

            foreach ($pattern in $forbiddenUiHostDependencyPatterns) {
                if ($line -match $pattern) {
                    if (Test-IsAllowedUiHostDependencyPath -NormalizedRelativePath $normalizedRelativePath) {
                        continue
                    }

                    $violations.Add([ordered]@{
                        Plugin = "Forbidden UIKit dependency outside formal UI closure"
                        RelativePath = $relativePath
                        LineNumber = $lineNumber
                        Line = $line.Trim()
                    })
                }
            }

            foreach ($pattern in $forbiddenSaveKitDirectCallPatterns) {
                if ($line -match $pattern) {
                    if (Test-IsAllowedExactPath -NormalizedRelativePath $normalizedRelativePath -AllowedPaths $allowedSaveKitPaths) {
                        continue
                    }

                    $violations.Add([ordered]@{
                        Plugin = "Forbidden SaveKit direct call"
                        RelativePath = $relativePath
                        LineNumber = $lineNumber
                        Line = $line.Trim()
                    })
                }
            }
        }

        if (-not $isCommentLine) {
            foreach ($check in $checkSets) {
                if ($check.ContainsKey("AllowedPaths") -and
                    (Test-IsAllowedExactPath -NormalizedRelativePath $normalizedRelativePath -AllowedPaths $check.AllowedPaths)) {
                    continue
                }

                $isAllowed = $false
                foreach ($prefix in $check.AllowedPrefixes) {
                    if ($normalizedRelativePath.StartsWith($prefix.ToLowerInvariant())) {
                        $isAllowed = $true
                        break
                    }
                }

                if ($isAllowed) {
                    continue
                }

                foreach ($pattern in $check.Patterns) {
                    if ($line -match $pattern) {
                        $violations.Add([ordered]@{
                            Plugin = $check.Plugin
                            RelativePath = $relativePath
                            LineNumber = $lineNumber
                            Line = $line.Trim()
                        })
                    }
                }
            }
        }
    }
}

$violationArray = @($violations.ToArray() |
    Group-Object -Property Plugin, RelativePath, LineNumber, Line |
    ForEach-Object { $_.Group[0] })

$report = [ordered]@{
    ProjectRoot = $projectRoot
    ScriptsRoot = $scriptsRoot
    EditorRoot = $editorRoot
    ViolationCount = $violationArray.Count
    Violations = $violationArray
}

if ($AsJson) {
    $report | ConvertTo-Json -Depth 6
    exit 0
}

Write-Host "FantasyWord plugin facade boundary gate"
Write-Host ("ProjectRoot: {0}" -f $report.ProjectRoot)
Write-Host ("ScriptsRoot: {0}" -f $report.ScriptsRoot)
Write-Host ("EditorRoot: {0}" -f $report.EditorRoot)
Write-Host ("Violations: {0}" -f $report.ViolationCount)

foreach ($violation in $report.Violations) {
    Write-Host ("  [{0}] {1}:{2} -> {3}" -f
        $violation.Plugin,
        $violation.RelativePath,
        $violation.LineNumber,
        $violation.Line)
}

if ($report.ViolationCount -gt 0) {
    exit 2
}

exit 0
