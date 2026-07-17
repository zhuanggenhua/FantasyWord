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

$violations = [System.Collections.Generic.List[string]]::new()
$dialogueChannelPath = Join-Path $ProjectRoot "Assets/Scripts/GameCore/Runtime/Dialogue/DialogueChannel.cs"

$dialogueChannelAwaitTasksLifecycleBound = $false
if (Test-Path -LiteralPath $dialogueChannelPath) {
    $text = Get-Content -Raw -LiteralPath $dialogueChannelPath

    $dialogueChannelAwaitTasksLifecycleBound =
        $text -match "private\s+void\s+OnDisable\s*\(\s*\)[\s\S]*?CancelCurrentDialogue\s*\(\s*false\s*\)[\s\S]*?ClearQueue\s*\(\s*\)" -and
        $text -match "private\s+void\s+OnDestroy\s*\(\s*\)[\s\S]*?CancelCurrentDialogue\s*\(\s*false\s*\)[\s\S]*?ClearQueue\s*\(\s*\)" -and
        $text -match "if\s*\(\s*dialogue\s*==\s*null\s*\)[\s\S]*?task\.TrySetResult\s*\(\s*false\s*\)" -and
        $text -match "Cannot start a dialogue with a null entry point node\." -and
        $text -match "CompleteDialogueTask\s*\(\s*tree\s*,\s*false\s*\)" -and
        $text -match "task\.TrySetResult\s*\(\s*true\s*\)" -and
        $text -match "private\s+void\s+CancelCurrentDialogue\s*\(\s*bool\s+notifyEnded\s*\)" -and
        $text -match "private\s+static\s+void\s+CompleteDialogueTask\s*\(\s*AwaitableDialogueTree\s+tree\s*,\s*bool\s+completed\s*\)" -and
        $text -notmatch "(?<!Try)SetResult\s*\("

    if (-not $dialogueChannelAwaitTasksLifecycleBound) {
        [void]$violations.Add(("{0}: DialogueChannel must complete queued/current await tasks with TrySetResult on null dialogue, missing entry point, disable, destroy, interrupt, and normal completion." -f (ConvertTo-RepoPath $dialogueChannelPath)))
    }
}
else {
    [void]$violations.Add("DialogueChannel.cs is missing.")
}

$result = [ordered]@{
    Passed = $violations.Count -eq 0
    DialogueChannelAwaitTasksLifecycleBound = $dialogueChannelAwaitTasksLifecycleBound
    ViolationCount = $violations.Count
    Violations = $violations
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 8
}
else {
    if ($result.Passed) {
        Write-Host "Dialogue runtime static gate passed."
    }
    else {
        Write-Host "Dialogue runtime static gate failed."
        foreach ($violation in $violations) {
            Write-Host " - $violation"
        }
    }
}

if ($violations.Count -gt 0) {
    exit 2
}
