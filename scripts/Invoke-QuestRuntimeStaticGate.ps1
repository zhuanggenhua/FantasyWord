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

function Read-Text {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path) {
        return Get-Content -Raw -LiteralPath $Path
    }

    return ""
}

$violations = [System.Collections.Generic.List[string]]::new()
$runtimeRoot = Join-Path $ProjectRoot "Assets/Scripts/GameCore/Runtime"
$questRoot = Join-Path $runtimeRoot "Quest"
$questDatabaseRoot = Join-Path $runtimeRoot "Database/Quest"
$journalPath = Join-Path $runtimeRoot "Game/Systems/JournalSystem.cs"
$questTaskProgressPath = Join-Path $questRoot "QuestTaskProgress.cs"
$questProgressPath = Join-Path $questRoot "QuestProgress.cs"

$journalText = Read-Text $journalPath
$questTaskProgressText = Read-Text $questTaskProgressPath
$questProgressText = Read-Text $questProgressPath

$questTaskProgressHasDestructor = $questTaskProgressText -match "~QuestTaskProgress\s*\("
if ($questTaskProgressHasDestructor) {
    [void]$violations.Add("QuestTaskProgress must not rely on a finalizer/destructor to unregister gameplay event listeners.")
}

$questTaskProgressHasStopContract = $questTaskProgressText -match "public\s+void\s+StopTracking\s*\("
if (-not $questTaskProgressHasStopContract) {
    [void]$violations.Add("IQuestTaskProgress must expose an explicit StopTracking contract for listener cleanup.")
}

$questTaskProgressPublicTrackingHooks =
    $questTaskProgressText -match "public\s+(abstract\s+)?void\s+OnProgressTrackingStarted\s*\(" -or
    $questTaskProgressText -match "public\s+(abstract\s+)?void\s+OnProgressTrackingStopped\s*\("
if ($questTaskProgressPublicTrackingHooks) {
    [void]$violations.Add("Quest task progress tracking hooks must not remain public lifecycle owners; callers should use StopTracking.")
}

$questTaskProgressCompletionStopsTracking =
    $questTaskProgressText -match "m_completionNotified\s*=\s*true" -and
    $questTaskProgressText -match "StopTracking\s*\(\s*\)\s*;\s*\r?\n\s*m_completionCallback\?\.Invoke"
if (-not $questTaskProgressCompletionStopsTracking) {
    [void]$violations.Add("QuestTaskProgress.UpdateProgression must stop tracking before notifying completion.")
}

$questProgressStopsOnCompletion =
    $questProgressText -match "if\s*\(\s*taskProgress\s*==\s*null\s*\|\|\s*!m_currentTasks\.Remove\s*\(\s*taskProgress\s*\)\s*\)" -and
    $questProgressText -match "taskProgress\.StopTracking\s*\(\s*\)"
if (-not $questProgressStopsOnCompletion) {
    [void]$violations.Add("QuestProgress.OnTaskCompleted must remove from current tasks and explicitly StopTracking the completed task.")
}

$questProgressHasStopTracking = $questProgressText -match "public\s+void\s+StopTracking\s*\("
if (-not $questProgressHasStopTracking) {
    [void]$violations.Add("QuestProgress must expose StopTracking so JournalSystem can release active task listeners before clearing or unloading.")
}

$questProgressFullfillmentStopsTracking =
    $questProgressText -match "m_fullfilledNotified\s*=\s*true" -and
    $questProgressText -match "StopTracking\s*\(\s*\)\s*;\s*\r?\n\s*m_fullfilledCallback\?\.Invoke"
if (-not $questProgressFullfillmentStopsTracking) {
    [void]$violations.Add("QuestProgress.CheckFullfillment must stop tracking before notifying the JournalSystem that a quest is fullfilled.")
}

$questProgressForceCompletionUsesSnapshot =
    $questProgressText -match "foreach\s*\(\s*IQuestTaskProgress\s+taskProgress\s+in\s+m_currentTasks\.ToArray\s*\(\s*\)\s*\)"
if (-not $questProgressForceCompletionUsesSnapshot) {
    [void]$violations.Add("QuestProgress.CompleteTask must iterate a current-task snapshot because completion mutates the current task list.")
}

$journalStopsBeforeLoadClear =
    $journalText -match "public\s+void\s+LoadDataBlock\s*\(\s*JournalDataBlock\s+block\s*\)[\s\S]*?StopActiveQuestTracking\s*\(\s*\)\s*;[\s\S]*?m_unlockedQuests\.Clear\s*\("
if (-not $journalStopsBeforeLoadClear) {
    [void]$violations.Add("JournalSystem.LoadDataBlock must stop active quest tracking before clearing runtime quest lists.")
}

$journalStopsOnSystemStop =
    $journalText -match "public\s+override\s+void\s+OnSystemStop\s*\(\s*\)[\s\S]*?StopActiveQuestTracking\s*\(\s*\)"
if (-not $journalStopsOnSystemStop) {
    [void]$violations.Add("JournalSystem.OnSystemStop must stop active quest tracking before unregistering the system.")
}

$journalStopsOnFullfilled =
    $journalText -match "private\s+void\s+OnQuestFullfilled\s*\(\s*QuestProgress\s+instance\s*\)[\s\S]*?instance\.StopTracking\s*\(\s*\)"
if (-not $journalStopsOnFullfilled) {
    [void]$violations.Add("JournalSystem.OnQuestFullfilled must stop the active QuestProgress before moving it out of active quests.")
}

$journalUsesTryCreateReferences =
    $journalText -match "CreateQuestReferences" -and
    $journalText -match "database\.TryCreateReference\s*\("
if (-not $journalUsesTryCreateReferences) {
    [void]$violations.Add("JournalSystem.CreateDataBlock must use TryCreateReference and skip unresolved quest assets instead of writing empty GUIDs.")
}

$journalResultRequiresQuestAsset =
    $journalText -match "private\s+static\s+void\s+EnsureValidQuest\s*\(\s*Quest\s+quest\s*,\s*string\s+operationName\s*\)[\s\S]*?throw\s+new\s+InvalidOperationException" -and
    $journalText -match "public\s+void\s+StartQuest\s*\(\s*Quest\s+quest\s*,\s*GameCommandContext\s+context\s*\)[\s\S]*?EnsureValidQuest\s*\(\s*quest\s*,\s*nameof\s*\(\s*StartQuest\s*\)\s*\)" -and
    $journalText -match "public\s+async\s+Task\s+CompleteQuest\s*\(\s*Quest\s+quest\s*,\s*GameCommandContext\s+context\s*\)[\s\S]*?EnsureValidQuest\s*\(\s*quest\s*,\s*nameof\s*\(\s*CompleteQuest\s*\)\s*\)" -and
    $journalText -match "public\s+void\s+UnlockQuest\s*\(\s*Quest\s+quest\s*\)[\s\S]*?EnsureValidQuest\s*\(\s*quest\s*,\s*nameof\s*\(\s*UnlockQuest\s*\)\s*\)"

if (-not $journalResultRequiresQuestAsset) {
    [void]$violations.Add("JournalSystem.StartQuest, CompleteQuest, and UnlockQuest must require a valid quest asset instead of logging and silently returning.")
}

$journalResultSilentlyReturnsOnMissingQuest =
    $journalText -match "public\s+void\s+StartQuest\s*\(\s*Quest\s+quest\s*,\s*GameCommandContext\s+context\s*\)[\s\S]*?if\s*\(\s*!\s*quest\s*\)[\s\S]*?return\s*;" -or
    $journalText -match "public\s+async\s+Task\s+CompleteQuest\s*\(\s*Quest\s+quest\s*,\s*GameCommandContext\s+context\s*\)[\s\S]*?if\s*\(\s*!\s*quest\s*\)[\s\S]*?return\s*;" -or
    $journalText -match "public\s+void\s+UnlockQuest\s*\(\s*Quest\s+quest\s*\)[\s\S]*?if\s*\(\s*!\s*quest\s*\)[\s\S]*?return\s*;"

if ($journalResultSilentlyReturnsOnMissingQuest) {
    [void]$violations.Add("JournalSystem quest result entrances must not return after a missing quest check.")
}

$journalDirectCreateReference = $journalText -match "(?<!Try)CreateReference\s*\("
if ($journalDirectCreateReference) {
    [void]$violations.Add("JournalSystem must not directly call DatabaseRegistry.CreateReference; quest save lists must go through TryCreateReference.")
}

$moduleRoots = @($questRoot, $questDatabaseRoot)
foreach ($root in $moduleRoots) {
    if (-not (Test-Path -LiteralPath $root)) {
        continue
    }

    foreach ($file in Get-ChildItem -LiteralPath $root -Recurse -File -Filter "*.cs") {
        $repoPath = ConvertTo-RepoPath $file.FullName
        $lineNumber = 0
        foreach ($line in Get-Content -LiteralPath $file.FullName) {
            $lineNumber++
            if ($line -match "(?<!Try)CreateReference\s*\(") {
                [void]$violations.Add(("{0}:{1}: quest runtime save writers must use TryCreateReference and skip unresolved assets: {2}" -f $repoPath, $lineNumber, $line.Trim()))
            }
        }
    }
}

$result = [ordered]@{
    Passed = $violations.Count -eq 0
    QuestTaskProgressHasDestructor = $questTaskProgressHasDestructor
    QuestTaskProgressHasStopContract = $questTaskProgressHasStopContract
    QuestTaskProgressPublicTrackingHooks = $questTaskProgressPublicTrackingHooks
    QuestTaskProgressCompletionStopsTracking = $questTaskProgressCompletionStopsTracking
    QuestProgressStopsOnCompletion = $questProgressStopsOnCompletion
    QuestProgressHasStopTracking = $questProgressHasStopTracking
    QuestProgressFullfillmentStopsTracking = $questProgressFullfillmentStopsTracking
    QuestProgressForceCompletionUsesSnapshot = $questProgressForceCompletionUsesSnapshot
    JournalStopsBeforeLoadClear = $journalStopsBeforeLoadClear
    JournalStopsOnSystemStop = $journalStopsOnSystemStop
    JournalStopsOnFullfilled = $journalStopsOnFullfilled
    JournalUsesTryCreateReferences = $journalUsesTryCreateReferences
    JournalResultRequiresQuestAsset = $journalResultRequiresQuestAsset
    JournalResultSilentlyReturnsOnMissingQuest = $journalResultSilentlyReturnsOnMissingQuest
    JournalDirectCreateReference = $journalDirectCreateReference
    ViolationCount = $violations.Count
    Violations = $violations
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 8
}
else {
    if ($result.Passed) {
        Write-Host "Quest runtime static gate passed."
    }
    else {
        Write-Host "Quest runtime static gate failed."
        foreach ($violation in $violations) {
            Write-Host " - $violation"
        }
    }
}

if ($violations.Count -gt 0) {
    exit 2
}
