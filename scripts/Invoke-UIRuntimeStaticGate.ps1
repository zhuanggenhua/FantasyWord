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
$uiRuntimeRoot = Join-Path $ProjectRoot "Assets/Scripts/GameCore/Runtime/UI"
$uiManagerRegistrationPath = Join-Path $uiRuntimeRoot "UIManager.MenuRegistrationRuntime.cs"
$uiManagerStackPath = Join-Path $uiRuntimeRoot "UIManager.MenuStackRuntime.cs"
$uiMenuPanelBasePath = Join-Path $uiRuntimeRoot "MenuPanels/UIKitMenuPanelBase.cs"
$controllerButtonManagerPath = Join-Path $uiRuntimeRoot "UIControllerButtonManager.cs"
$controllerButtonPath = Join-Path $uiRuntimeRoot "UIControllerButton.cs"
$currentControlledHudPaths = @(
    "UIPlayerControlFeedback.cs",
    "HUD/Stats/UIStatBar.cs",
    "HUD/Effects/UIHUDEffectBar.cs",
    "HUD/Abilities/UIHUDAbilityBar.cs"
) | ForEach-Object { Join-Path $uiRuntimeRoot $_ }
$currentControlledMenuPanelPaths = @(
    "Menus/Character/UICharacter.cs",
    "Menus/Inventory/UIInventory.cs",
    "Menus/Abilities/UIAbilities.cs"
) | ForEach-Object { Join-Path $uiRuntimeRoot $_ }
$abilityMenuBarPath = Join-Path $uiRuntimeRoot "Menus/Abilities/UIAbilityBar.cs"
$dialogueHudPath = Join-Path $uiRuntimeRoot "HUD/Dialogue/UIDialogue.cs"
$dialogueMessageBoxPath = Join-Path $uiRuntimeRoot "HUD/Dialogue/UIDialogueMessageBox.cs"
$tipsItemPath = Join-Path $uiRuntimeRoot "UITipsItem.cs"
$eventLogLinePath = Join-Path $uiRuntimeRoot "HUD/EventLog/UIEventLogLine.cs"
$abilityMessagePath = Join-Path $uiRuntimeRoot "HUD/Abilities/UIHUDAbilityMessage.cs"
$characterInfoPath = Join-Path $uiRuntimeRoot "UICharacterInfo.cs"
$mainMenuPath = Join-Path $uiRuntimeRoot "Menus/UIMainMenu.cs"
$characterMenuContextPath = Join-Path $uiRuntimeRoot "Menus/Character/CharacterMenuContext.cs"
$inventoryMenuContextPath = Join-Path $uiRuntimeRoot "Menus/Inventory/InventoryMenuContext.cs"
$inventoryBagPath = Join-Path $uiRuntimeRoot "Menus/Inventory/UIInventoryBag.cs"

$patterns = [ordered]@{
    "Resources.Load" = "Resources\.Load\s*<"
    "global object lookup" = "\b(GameObject\.Find|Object\.Find|FindObjectOfType|FindObjectsByType|FindFirstObjectByType|FindAnyObjectByType)\s*<*\s*"
    "transform path lookup" = "\btransform\.Find\s*\("
    "input device signature parsing" = "GetCurrentControlDevicesSignature\s*\("
    "direct FW resource key" = "\bFWRes\."
    "direct scene load" = "\bSceneManager\.LoadScene\s*\("
}

if (Test-Path -LiteralPath $uiRuntimeRoot) {
    foreach ($file in Get-ChildItem -LiteralPath $uiRuntimeRoot -Recurse -File -Filter "*.cs") {
        $lineNumber = 0
        foreach ($line in Get-Content -LiteralPath $file.FullName) {
            $lineNumber++
            foreach ($entry in $patterns.GetEnumerator()) {
                if ($line -match $entry.Value) {
                    [void]$violations.Add(("{0}:{1}: formal UI runtime must not use {2}: {3}" -f (ConvertTo-RepoPath $file.FullName), $lineNumber, $entry.Key, $line.Trim()))
                }
            }
        }

        $fileText = Get-Content -Raw -LiteralPath $file.FullName
        if ($fileText -match "onClick\.AddListener\s*\(" -and $fileText -notmatch "onClick\.RemoveListener\s*\(") {
            [void]$violations.Add(("{0}: Button.onClick listeners must be removed in the same component lifecycle." -f (ConvertTo-RepoPath $file.FullName)))
        }

        if ($fileText -match "\basync\s+void\b") {
            [void]$violations.Add(("{0}: formal UI runtime must not use async void; route Unity button callbacks through RunPanelTaskAndReport." -f (ConvertTo-RepoPath $file.FullName)))
        }
    }
}

$registrationUsesTypeReference = $false
if (Test-Path -LiteralPath $uiManagerRegistrationPath) {
    $registrationText = Get-Content -Raw -LiteralPath $uiManagerRegistrationPath
    $registrationUsesTypeReference = $registrationText.Contains("UIKitMenuPanelTypeReference")
    if (-not $registrationUsesTypeReference) {
        [void]$violations.Add("UIManager menu registration no longer uses UIKitMenuPanelTypeReference.")
    }
}
else {
    [void]$violations.Add("UIManager.MenuRegistrationRuntime.cs is missing.")
}

$stackUsesUIKitOpenPanel = $false
if (Test-Path -LiteralPath $uiManagerStackPath) {
    $stackText = Get-Content -Raw -LiteralPath $uiManagerStackPath
    $stackUsesUIKitOpenPanel = $stackText.Contains("UIKit.OpenPanelAsync")
    if (-not $stackUsesUIKitOpenPanel) {
        [void]$violations.Add("UIManager menu stack no longer routes through UIKit.OpenPanelAsync.")
    }
}
else {
    [void]$violations.Add("UIManager.MenuStackRuntime.cs is missing.")
}

$panelBaseHasAsyncReporter = $false
if (Test-Path -LiteralPath $uiMenuPanelBasePath) {
    $panelBaseText = Get-Content -Raw -LiteralPath $uiMenuPanelBasePath
    $panelBaseHasAsyncReporter =
        $panelBaseText -match "RunPanelTaskAndReport\s*\(" -and
        $panelBaseText -match "Debug\.LogException" -and
        $panelBaseText -match "catch\s*\(\s*Exception\s+exception\s*\)"
    if (-not $panelBaseHasAsyncReporter) {
        [void]$violations.Add("UIKitMenuPanelBase must expose RunPanelTaskAndReport with exception logging for Unity button async tasks.")
    }
}
else {
    [void]$violations.Add("UIKitMenuPanelBase.cs is missing.")
}

$controllerButtonLifecycleBound = $false
$controllerButtonManagerGuarded = $false
if (Test-Path -LiteralPath $controllerButtonManagerPath) {
    $managerText = Get-Content -Raw -LiteralPath $controllerButtonManagerPath
    $controllerButtonManagerGuarded =
        $managerText -match "bool\s+m_controlsChangedListening" -and
        $managerText -match "StartControlsChangedListeningIfReady\s*\(" -and
        $managerText -match "StopControlsChangedListening\s*\(" -and
        $managerText -match "TryGetValue\s*\(\s*m_controllerType"
    if (-not $controllerButtonManagerGuarded) {
        [void]$violations.Add("UIControllerButtonManager must use enable/disable input listener lifecycle and guard missing controller SpriteLibrary entries.")
    }
}
else {
    [void]$violations.Add("UIControllerButtonManager.cs is missing.")
}

if (Test-Path -LiteralPath $controllerButtonPath) {
    $buttonText = Get-Content -Raw -LiteralPath $controllerButtonPath
    $controllerButtonLifecycleBound =
        $buttonText -match "private\s+void\s+OnEnable\s*\(\s*\)[\s\S]*?RegisterWithManagerIfReady\s*\(\s*\)" -and
        $buttonText -match "private\s+void\s+OnDisable\s*\(\s*\)[\s\S]*?UnregisterFromManager\s*\(\s*\)" -and
        $buttonText -match "bool\s+m_registered"
    if (-not $controllerButtonLifecycleBound) {
        [void]$violations.Add("UIControllerButton must register on enable and unregister on disable with an idempotent guard.")
    }
}
else {
    [void]$violations.Add("UIControllerButton.cs is missing.")
}

$currentControlledHudLifecycleBound = $true
foreach ($path in $currentControlledHudPaths) {
    if (-not (Test-Path -LiteralPath $path)) {
        $currentControlledHudLifecycleBound = $false
        [void]$violations.Add(("{0} is missing." -f (ConvertTo-RepoPath $path)))
        continue
    }

    $hudText = Get-Content -Raw -LiteralPath $path
    $hasEnableDisable =
        $hudText -match "private\s+void\s+OnEnable\s*\(\s*\)[\s\S]*?(StartCurrentControlledCharacterListeningIfReady|BindInitial(?:Target|Character)IfReady)\s*\(\s*\)" -and
        $hudText -match "private\s+void\s+OnDisable\s*\(\s*\)[\s\S]*?StopCurrentControlledCharacterListening\s*\(\s*\)"
    $hasGuard =
        $hudText -match "bool\s+m_currentControlledCharacterListening" -and
        $hudText -match "GameManager\.Exists\s*\(\s*\)" -and
        $hudText -match "GameManager\.HasSystem<PlayerSystem>\s*\(\s*\)"

    if (-not $hasEnableDisable -or -not $hasGuard) {
        $currentControlledHudLifecycleBound = $false
        [void]$violations.Add(("{0}: current-controlled-character HUD listeners must use enable/disable lifecycle with an idempotent readiness guard." -f (ConvertTo-RepoPath $path)))
    }
}

$currentControlledMenuLifecycleBound = $true
foreach ($path in $currentControlledMenuPanelPaths) {
    if (-not (Test-Path -LiteralPath $path)) {
        $currentControlledMenuLifecycleBound = $false
        [void]$violations.Add(("{0} is missing." -f (ConvertTo-RepoPath $path)))
        continue
    }

    $menuText = Get-Content -Raw -LiteralPath $path
    $panelInitBlock = Get-CSharpMethodBlock -Text $menuText -MethodName "OnPanelInit"
    $panelShownBlock = Get-CSharpMethodBlock -Text $menuText -MethodName "OnPanelShown"
    $panelHiddenBlock = Get-CSharpMethodBlock -Text $menuText -MethodName "OnPanelHidden"
    $destroyBlock = Get-CSharpMethodBlock -Text $menuText -MethodName "OnDestroy"
    $panelInitKeepsLongLivedListener =
        $panelInitBlock -match "AddCurrentControlledCharacterChangedListener\s*\("
    $hasPanelShownListenerBinding =
        $panelShownBlock -match "BindCurrentControlledCharacterListenerForContext\s*\(\s*\)"
    $hasPanelHiddenUnsubscribe =
        $panelHiddenBlock -match "StopCurrentControlledCharacterListening\s*\(\s*\)"
    $hasDestroyUnsubscribe =
        $destroyBlock -match "StopCurrentControlledCharacterListening\s*\(\s*\)"
    $hasGuard =
        $menuText -match "bool\s+m_currentControlledCharacterListening" -and
        $menuText -match "GameManager\.Exists\s*\(\s*\)" -and
        $menuText -match "GameManager\.HasSystem<PlayerSystem>\s*\(\s*\)"

    if ($panelInitKeepsLongLivedListener -or
        -not $hasPanelShownListenerBinding -or
        -not $hasPanelHiddenUnsubscribe -or
        -not $hasDestroyUnsubscribe -or
        -not $hasGuard) {
        $currentControlledMenuLifecycleBound = $false
        [void]$violations.Add(("{0}: current-controlled-character menu listeners must bind on panel shown, unbind on panel hidden/destroy, and use an idempotent readiness guard." -f (ConvertTo-RepoPath $path)))
    }
}

$abilityMenuBarPresentationOnly = $false
if (Test-Path -LiteralPath $abilityMenuBarPath) {
    $abilityBarText = Get-Content -Raw -LiteralPath $abilityMenuBarPath
    $abilityMenuBarPresentationOnly =
        $abilityBarText -notmatch "AddCurrentControlledCharacterChangedListener\s*\(" -and
        $abilityBarText -notmatch "RemoveCurrentControlledCharacterChangedListener\s*\(" -and
        $abilityBarText -notmatch "GetCurrentControlledCharacterOrPlayerInstance\s*\(" -and
        $abilityBarText -notmatch "FollowCurrentControlledCharacter\s*\(" -and
        $abilityBarText -match "PresentCharacter\s*\(\s*CharacterBase\s+\w+\s*\)" -and
        $abilityBarText -match "BindCharacter\s*\(\s*null\s*\)"
    if (-not $abilityMenuBarPresentationOnly) {
        [void]$violations.Add("UIAbilityBar must remain presentation-only; UIAbilities owns current-controlled-character menu following.")
    }
}
else {
    [void]$violations.Add("UIAbilityBar.cs is missing.")
}

$dialogueHudLifecycleBound = $false
if (Test-Path -LiteralPath $dialogueHudPath) {
    $dialogueHudText = Get-Content -Raw -LiteralPath $dialogueHudPath
    $dialogueOnEnableBlock = Get-CSharpMethodBlock -Text $dialogueHudText -MethodName "OnEnable"
    $dialogueStartBlock = Get-CSharpMethodBlock -Text $dialogueHudText -MethodName "Start"
    $dialogueOnDisableBlock = Get-CSharpMethodBlock -Text $dialogueHudText -MethodName "OnDisable"
    $dialogueDestroyBlock = Get-CSharpMethodBlock -Text $dialogueHudText -MethodName "OnDestroy"

    $dialogueHudLifecycleBound =
        $dialogueOnEnableBlock -match "StartDialogueRuntimeIfReady\s*\(\s*\)" -and
        $dialogueStartBlock -match "StartDialogueRuntimeIfReady\s*\(\s*\)" -and
        $dialogueOnDisableBlock -match "StopDialogueRuntime\s*\(\s*\)" -and
        $dialogueDestroyBlock -match "StopDialogueRuntime\s*\(\s*\)" -and
        $dialogueHudText -match "bool\s+m_dialogueRuntimeListening" -and
        $dialogueHudText -match "GameManager\.Exists\s*\(\s*\)" -and
        $dialogueHudText -match "GameManager\.HasSystem<DialogueSystem>\s*\(\s*\)" -and
        $dialogueHudText -match "GameManager\.HasSystem<InputSystem>\s*\(\s*\)" -and
        $dialogueHudText -match "SyncCurrentDialogueIfPlaying\s*\(\s*\)" -and
        $dialogueHudText -match "TryGetCurrentState\s*\("

    $dialogueStartKeepsLongLivedListener =
        $dialogueStartBlock -match "AddStartedListener\s*\(" -or
        $dialogueStartBlock -match "AddUIActionListener\s*\("

    if (-not $dialogueHudLifecycleBound -or $dialogueStartKeepsLongLivedListener) {
        $dialogueHudLifecycleBound = $false
        [void]$violations.Add("UIDialogue must bind dialogue/input listeners on enable, unbind on disable/destroy, and resync current dialogue state when enabled.")
    }
}
else {
    [void]$violations.Add("UIDialogue.cs is missing.")
}

$dialogueMessageBoxLifecycleBound = $false
if (Test-Path -LiteralPath $dialogueMessageBoxPath) {
    $messageBoxText = Get-Content -Raw -LiteralPath $dialogueMessageBoxPath
    $messageBoxOnDisableBlock = Get-CSharpMethodBlock -Text $messageBoxText -MethodName "OnDisable"
    $messageBoxDestroyBlock = Get-CSharpMethodBlock -Text $messageBoxText -MethodName "OnDestroy"
    $messageBoxHideBlock = Get-CSharpMethodBlock -Text $messageBoxText -MethodName "Hide"
    $messageBoxSetTextBlock = Get-CSharpMethodBlock -Text $messageBoxText -MethodName "SetText"
    $messageBoxSkipTextBlock = Get-CSharpMethodBlock -Text $messageBoxText -MethodName "SkipTextAnimation"

    $dialogueMessageBoxLifecycleBound =
        $messageBoxText -match "Coroutine\s+m_textAnimationCoroutine" -and
        $messageBoxOnDisableBlock -match "AbortTextAnimation\s*\(\s*\)" -and
        $messageBoxDestroyBlock -match "AbortTextAnimation\s*\(\s*\)" -and
        $messageBoxHideBlock -match "AbortTextAnimation\s*\(\s*\)" -and
        $messageBoxSetTextBlock -match "AbortTextAnimation\s*\(\s*\)" -and
        $messageBoxSkipTextBlock -match "StopTextAnimationCoroutine\s*\(\s*\)" -and
        $messageBoxText -match "StopTextAnimationCoroutine\s*\(\s*\)" -and
        $messageBoxText -match "StopCoroutine\s*\(\s*m_textAnimationCoroutine\s*\)" -and
        $messageBoxText -match "m_textAnimationCoroutine\s*=\s*null"

    if (-not $dialogueMessageBoxLifecycleBound) {
        [void]$violations.Add("UIDialogueMessageBox must stop its text animation coroutine on hide, text replacement, disable, destroy, and skip.")
    }
}
else {
    [void]$violations.Add("UIDialogueMessageBox.cs is missing.")
}

$transientUiCoroutineLifecycleBound = $false
if ((Test-Path -LiteralPath $tipsItemPath) -and (Test-Path -LiteralPath $eventLogLinePath)) {
    $tipsItemText = Get-Content -Raw -LiteralPath $tipsItemPath
    $tipsItemShowBlock = Get-CSharpMethodBlock -Text $tipsItemText -MethodName "Show"
    $tipsItemOnDisableBlock = Get-CSharpMethodBlock -Text $tipsItemText -MethodName "OnDisable"
    $tipsItemDestroyBlock = Get-CSharpMethodBlock -Text $tipsItemText -MethodName "OnDestroy"
    $eventLogLineText = Get-Content -Raw -LiteralPath $eventLogLinePath
    $eventLogLineShowBlock = Get-CSharpMethodBlock -Text $eventLogLineText -MethodName "Show"
    $eventLogLineOnDisableBlock = Get-CSharpMethodBlock -Text $eventLogLineText -MethodName "OnDisable"
    $eventLogLineDestroyBlock = Get-CSharpMethodBlock -Text $eventLogLineText -MethodName "OnDestroy"
    $eventLogLineAnimateBlock = Get-CSharpMethodBlock -Text $eventLogLineText -MethodName "Animate"

    $transientUiCoroutineLifecycleBound =
        $tipsItemText -match "Coroutine\s+m_showCoroutine" -and
        $tipsItemShowBlock -match "StopShowRoutine\s*\(\s*\)" -and
        $tipsItemOnDisableBlock -match "StopShowRoutine\s*\(\s*\)" -and
        $tipsItemOnDisableBlock -match "ResetVisualState\s*\(\s*\)" -and
        $tipsItemDestroyBlock -match "StopShowRoutine\s*\(\s*\)" -and
        $tipsItemText -match "StopCoroutine\s*\(\s*m_showCoroutine\s*\)" -and
        $tipsItemText -match "m_showCoroutine\s*=\s*null" -and
        $tipsItemText -match "m_canvasGroup\.alpha\s*=\s*0f" -and
        $eventLogLineText -match "Coroutine\s+m_animationCoroutine" -and
        $eventLogLineShowBlock -match "StopAnimation\s*\(\s*\)" -and
        $eventLogLineOnDisableBlock -match "StopAnimation\s*\(\s*\)" -and
        $eventLogLineOnDisableBlock -match "ResetLine\s*\(\s*\)" -and
        $eventLogLineDestroyBlock -match "StopAnimation\s*\(\s*\)" -and
        $eventLogLineText -match "StopCoroutine\s*\(\s*m_animationCoroutine\s*\)" -and
        $eventLogLineText -match "m_animationCoroutine\s*=\s*null" -and
        $eventLogLineText -match "private\s+IEnumerator\s+Animate[\s\S]*?m_animationCoroutine\s*=\s*null"

    if (-not $transientUiCoroutineLifecycleBound) {
        [void]$violations.Add("UITipsItem and UIEventLogLine must stop transient animation coroutines on replacement, disable, and destroy, and reset pooled visual state on disable.")
    }
}
else {
    [void]$violations.Add("UITipsItem.cs or UIEventLogLine.cs is missing.")
}

$abilityMessageLifecycleBound = $false
if (Test-Path -LiteralPath $abilityMessagePath) {
    $abilityMessageText = Get-Content -Raw -LiteralPath $abilityMessagePath
    $abilityMessageShowCleansPrevious =
        $abilityMessageText -match "public\s+void\s+Show\s*\([^)]*\)[\s\S]*?InterruptPreviousMessage\s*\(\s*\)[\s\S]*?m_hideCoroutine\s*=\s*StartCoroutine\s*\("
    $abilityMessageOnDisableHides =
        $abilityMessageText -match "private\s+void\s+OnDisable\s*\(\s*\)[\s\S]*?Hide\s*\(\s*\)"
    $abilityMessageDestroyHides =
        $abilityMessageText -match "private\s+void\s+OnDestroy\s*\(\s*\)[\s\S]*?Hide\s*\(\s*\)"
    $abilityMessageHideStopsAndResets =
        $abilityMessageText -match "private\s+void\s+Hide\s*\(\s*\)[\s\S]*?StopHideCoroutine\s*\(\s*\)[\s\S]*?ResetVisualState\s*\(\s*\)"
    $abilityMessageFadeFinishesCleanly =
        $abilityMessageText -match "private\s+IEnumerator\s+FadeOutAfterDelay\s*\([^)]*\)[\s\S]*?yield\s+return\s+FadeOut\s*\([\s\S]*?m_hideCoroutine\s*=\s*null[\s\S]*?ResetVisualState\s*\(\s*\)" -and
        $abilityMessageText -notmatch "yield\s+return\s+StartCoroutine\s*\(\s*FadeOut\s*\("

    $abilityMessageLifecycleBound =
        $abilityMessageText -match "Coroutine\s+m_hideCoroutine" -and
        $abilityMessageShowCleansPrevious -and
        $abilityMessageOnDisableHides -and
        $abilityMessageDestroyHides -and
        $abilityMessageHideStopsAndResets -and
        $abilityMessageText -match "StopCoroutine\s*\(\s*m_hideCoroutine\s*\)" -and
        $abilityMessageText -match "m_hideCoroutine\s*=\s*null" -and
        $abilityMessageText -match "private\s+void\s+ResetVisualState\s*\(" -and
        $abilityMessageText -match "m_message\.text\s*=\s*string\.Empty" -and
        $abilityMessageText -match "m_message\.alpha\s*=\s*0\.0f" -and
        $abilityMessageText -match "m_message\.enabled\s*=\s*false" -and
        $abilityMessageFadeFinishesCleanly

    if (-not $abilityMessageLifecycleBound) {
        [void]$violations.Add("UIHUDAbilityMessage must stop its hide coroutine on replacement, disable, and destroy, and reset message text, alpha, and visibility when hidden.")
    }
}
else {
    [void]$violations.Add("UIHUDAbilityMessage.cs is missing.")
}

$characterInfoLifecycleBound = $false
if (Test-Path -LiteralPath $characterInfoPath) {
    $characterInfoText = Get-Content -Raw -LiteralPath $characterInfoPath
    $characterInfoAwakeBlock = Get-CSharpMethodBlock -Text $characterInfoText -MethodName "Awake"
    $characterInfoOnEnableBlock = Get-CSharpMethodBlock -Text $characterInfoText -MethodName "OnEnable"
    $characterInfoStartBlock = Get-CSharpMethodBlock -Text $characterInfoText -MethodName "Start"
    $characterInfoOnDisableBlock = Get-CSharpMethodBlock -Text $characterInfoText -MethodName "OnDisable"
    $characterInfoDestroyBlock = Get-CSharpMethodBlock -Text $characterInfoText -MethodName "OnDestroy"

    $characterInfoLifecycleBound =
        $characterInfoAwakeBlock -notmatch "Add(?:StatsChanged|CurrentStatsChanged|TemporalEffectPresentationAdded|TemporalEffectPresentationRemoved|LevelUpped)Listener\s*\(" -and
        $characterInfoOnEnableBlock -match "StartTargetListeningIfReady\s*\(\s*\)" -and
        $characterInfoStartBlock -match "StartTargetListeningIfReady\s*\(\s*\)" -and
        $characterInfoOnDisableBlock -match "StopTargetListening\s*\(\s*\)" -and
        $characterInfoOnDisableBlock -match "ReturnAllEffectIcons\s*\(\s*\)" -and
        $characterInfoDestroyBlock -match "StopTargetListening\s*\(\s*\)" -and
        $characterInfoText -match "bool\s+m_targetListening" -and
        $characterInfoText -match "AddStatsChangedListener\s*\(\s*OnStatsChanged\s*\)" -and
        $characterInfoText -match "RemoveStatsChangedListener\s*\(\s*OnStatsChanged\s*\)" -and
        $characterInfoText -match "AddTemporalEffectPresentationAddedListener\s*\(\s*OnTemporalEffectAdded\s*\)" -and
        $characterInfoText -match "RemoveTemporalEffectPresentationAddedListener\s*\(\s*OnTemporalEffectAdded\s*\)" -and
        $characterInfoText -match "AddLevelUppedListener\s*\(\s*OnLevelUpped\s*\)" -and
        $characterInfoText -match "RemoveLevelUppedListener\s*\(\s*OnLevelUpped\s*\)"

    if (-not $characterInfoLifecycleBound) {
        [void]$violations.Add("UICharacterInfo must bind character listeners on enable/start retry and unbind plus return effect icons on disable/destroy.")
    }
}
else {
    [void]$violations.Add("UICharacterInfo.cs is missing.")
}

$mainMenuCancelLifecycleBound = $false
if (Test-Path -LiteralPath $mainMenuPath) {
    $mainMenuText = Get-Content -Raw -LiteralPath $mainMenuPath
    $mainMenuStartBlock = Get-CSharpMethodBlock -Text $mainMenuText -MethodName "Start"
    $mainMenuOnEnableBlock = Get-CSharpMethodBlock -Text $mainMenuText -MethodName "OnEnable"
    $mainMenuOnDisableBlock = Get-CSharpMethodBlock -Text $mainMenuText -MethodName "OnDisable"
    $mainMenuDestroyBlock = Get-CSharpMethodBlock -Text $mainMenuText -MethodName "OnDestroy"

    $mainMenuCancelLifecycleBound =
        $mainMenuStartBlock -match "StartCancelListeningIfReady\s*\(\s*\)" -and
        $mainMenuStartBlock -notmatch "AddUIActionListener\s*\(" -and
        $mainMenuOnEnableBlock -match "StartCancelListeningIfReady\s*\(\s*\)" -and
        $mainMenuOnDisableBlock -match "StopCancelListening\s*\(\s*\)" -and
        $mainMenuDestroyBlock -match "StopCancelListening\s*\(\s*\)" -and
        $mainMenuText -match "bool\s+m_cancelListening" -and
        $mainMenuText -match "GameManager\.Exists\s*\(\s*\)" -and
        $mainMenuText -match "GameManager\.HasSystem<InputSystem>\s*\(\s*\)" -and
        $mainMenuText -match "AddUIActionListener\s*\(\s*EUIInputAction\.Cancel" -and
        $mainMenuText -match "RemoveUIActionListener\s*\(\s*EUIInputAction\.Cancel"

    if (-not $mainMenuCancelLifecycleBound) {
        [void]$violations.Add("UIMainMenu must bind Cancel input on enable/start retry and unbind on disable/destroy with an idempotent readiness guard.")
    }
}
else {
    [void]$violations.Add("UIMainMenu.cs is missing.")
}

$menuContextsKeepFailedLookupInvalid = $false
if ((Test-Path -LiteralPath $characterMenuContextPath) -and (Test-Path -LiteralPath $inventoryMenuContextPath)) {
    $characterMenuContextText = Get-Content -Raw -LiteralPath $characterMenuContextPath
    $inventoryMenuContextText = Get-Content -Raw -LiteralPath $inventoryMenuContextPath
    $characterResolveActorBlock = Get-CSharpMethodBlock -Text $characterMenuContextText -MethodName "ResolveActor"
    $inventoryResolveActorBlock = Get-CSharpMethodBlock -Text $inventoryMenuContextText -MethodName "ResolveActor"
    $inventoryResolveOwnerKeepsInvalidOwner =
        $inventoryMenuContextText -match "private\s+static\s+InventoryOwnerHandle\s+ResolveInventoryOwner\s*\(\s*CharacterBase\s+actor\s*\)" -and
        $inventoryMenuContextText -match "if\s*\(\s*actor\s*==\s*null\s*\|\|\s*!\s*GameManager\.TryGetSystem\s*\(\s*out\s+InventorySystem\s+inventorySystem\s*\)\s*\)\s*\{\s*return\s+default;\s*\}" -and
        $inventoryMenuContextText -match "return\s+inventorySystem\.GetOwner\s*\(\s*actor\s*\)\s*;" -and
        $inventoryMenuContextText -notmatch "InventoryOwnerHandle\.DefaultParty"

    $menuContextsKeepFailedLookupInvalid =
        $characterResolveActorBlock.Contains("return Actor;") -and
        $characterResolveActorBlock.Contains("GetCurrentControlledCharacterOrPlayerInstance") -and
        $characterResolveActorBlock.Contains(": null") -and
        $inventoryResolveActorBlock.Contains("return Actor;") -and
        $inventoryResolveActorBlock.Contains("GetCurrentControlledCharacterOrPlayerInstance") -and
        $inventoryResolveActorBlock.Contains(": null") -and
        $inventoryResolveOwnerKeepsInvalidOwner

    if (-not $menuContextsKeepFailedLookupInvalid) {
        [void]$violations.Add("CharacterMenuContext and InventoryMenuContext must keep current-character owner resolution non-throwing and must not turn a failed current-character lookup into a default party owner.")
    }
}
else {
    [void]$violations.Add("CharacterMenuContext.cs or InventoryMenuContext.cs is missing.")
}

$inventoryBagKeepsInvalidOwnerEmpty = $false
if (Test-Path -LiteralPath $inventoryBagPath) {
    $inventoryBagText = Get-Content -Raw -LiteralPath $inventoryBagPath
    $inventoryBagKeepsInvalidOwnerEmpty =
        $inventoryBagText -match "public\s+void\s+UpdateSlots\s*\(\s*InventoryOwnerHandle\s+owner\s*\)" -and
        $inventoryBagText.Contains("m_currentOwner = owner;") -and
        $inventoryBagText.Contains("ClearSlots();") -and
        $inventoryBagText -match "if\s*\(\s*!\s*owner\.IsValid\s*\|\|\s*!\s*GameManager\.TryGetSystem\s*\(\s*out\s+InventorySystem\s+inventorySystem\s*\)\s*\)\s*\{\s*return\s*;\s*\}" -and
        $inventoryBagText.Contains("FillSlots(owner, inventorySystem);") -and
        $inventoryBagText.Contains("private void FillSlots(InventoryOwnerHandle owner, InventorySystem inventorySystem)") -and
        $inventoryBagText.Contains("inventorySystem.GetBagEntries(owner)")

    if (-not $inventoryBagKeepsInvalidOwnerEmpty) {
        [void]$violations.Add("UIInventoryBag must keep invalid or not-ready inventory owners as empty UI state instead of falling back to the default party bag or throwing through InventorySystem.")
    }
}
else {
    [void]$violations.Add("UIInventoryBag.cs is missing.")
}

$result = [ordered]@{
    Passed = $violations.Count -eq 0
    RegistrationUsesTypeReference = $registrationUsesTypeReference
    StackUsesUIKitOpenPanelAsync = $stackUsesUIKitOpenPanel
    PanelBaseHasAsyncReporter = $panelBaseHasAsyncReporter
    ControllerButtonManagerGuarded = $controllerButtonManagerGuarded
    ControllerButtonLifecycleBound = $controllerButtonLifecycleBound
    CurrentControlledHudLifecycleBound = $currentControlledHudLifecycleBound
    CurrentControlledMenuLifecycleBound = $currentControlledMenuLifecycleBound
    AbilityMenuBarPresentationOnly = $abilityMenuBarPresentationOnly
    DialogueHudLifecycleBound = $dialogueHudLifecycleBound
    DialogueMessageBoxLifecycleBound = $dialogueMessageBoxLifecycleBound
    TransientUiCoroutineLifecycleBound = $transientUiCoroutineLifecycleBound
    AbilityMessageLifecycleBound = $abilityMessageLifecycleBound
    CharacterInfoLifecycleBound = $characterInfoLifecycleBound
    MainMenuCancelLifecycleBound = $mainMenuCancelLifecycleBound
    MenuContextsKeepFailedLookupInvalid = $menuContextsKeepFailedLookupInvalid
    InventoryBagKeepsInvalidOwnerEmpty = $inventoryBagKeepsInvalidOwnerEmpty
    ButtonOnClickListenersLifecycleChecked = $true
    ViolationCount = $violations.Count
    Violations = $violations
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 8
}
else {
    if ($result.Passed) {
        Write-Host "UI runtime static gate passed."
    }
    else {
        Write-Host "UI runtime static gate failed."
        foreach ($violation in $violations) {
            Write-Host " - $violation"
        }
    }
}

if ($violations.Count -gt 0) {
    exit 2
}


