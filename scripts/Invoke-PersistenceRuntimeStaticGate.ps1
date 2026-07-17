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

function New-StringFromCodePoints {
    param([int[]]$CodePoints)

    return -join ($CodePoints | ForEach-Object { [char]$_ })
}

function Read-Text {
    param([string]$Path)

    if (Test-Path -LiteralPath $Path) {
        return Get-Content -Raw -Encoding UTF8 -LiteralPath $Path
    }

    return ""
}

$violations = [System.Collections.Generic.List[string]]::new()
$runtimeRoot = Join-Path $ProjectRoot "Assets/Scripts/GameCore/Runtime"
$inventoryPath = Join-Path $runtimeRoot "Game/Systems/InventorySystem.cs"
$persistenceContractsPath = Join-Path $runtimeRoot "Persistence/Persistable.Contracts.cs"
$persistablePath = Join-Path $runtimeRoot "Persistence/Persistable.cs"
$persistenceSystemPath = Join-Path $runtimeRoot "Game/Systems/PersistenceSystem.cs"
$persistenceInstantiationPath = Join-Path $runtimeRoot "Game/Systems/PersistenceSystem.InstantiationRuntime.cs"
$databaseRegistryPath = Join-Path $runtimeRoot "Database/DatabaseRegistry.cs"

$inventoryText = Read-Text $inventoryPath
$persistenceContractsText = Read-Text $persistenceContractsPath
$persistableText = Read-Text $persistablePath
$persistenceSystemText = Read-Text $persistenceSystemPath
$persistenceInstantiationText = Read-Text $persistenceInstantiationPath
$databaseRegistryText = Read-Text $databaseRegistryPath

$cannotCreateStableReferenceText = New-StringFromCodePoints @(0x4E0D, 0x80FD, 0x521B, 0x5EFA, 0x7A33, 0x5B9A, 0x5F15, 0x7528)
$validPrefabRequiredText = (New-StringFromCodePoints @(0x6301, 0x4E45, 0x5316, 0x5B9E, 0x4F8B, 0x5316, 0x9700, 0x8981, 0x6709, 0x6548)) + " Prefab"
$missingPersistableText = (New-StringFromCodePoints @(0x7F3A, 0x5C11)) + " {nameof(Persistable)}"
$mustContainPersistableTypeText = (New-StringFromCodePoints @(0x5FC5, 0x987B, 0x5305, 0x542B)) + " {typeof(TPersistable).Name}"
$customPersistableRequiredText = New-StringFromCodePoints @(0x6CE8, 0x518C, 0x81EA, 0x5B9A, 0x4E49, 0x6301, 0x4E45, 0x5316, 0x5B9E, 0x4F8B, 0x9700, 0x8981, 0x6709, 0x6548)
$blankPersistenceIdentifierText = New-StringFromCodePoints @(0x6301, 0x4E45, 0x5316, 0x5B9E, 0x4F8B, 0x6807, 0x8BC6, 0x7B26, 0x4E0D, 0x80FD, 0x662F, 0x7A7A, 0x5B57, 0x7B26, 0x4E32)

$inventoryOwnerUsesInstanceId = $inventoryText -match "GetInstanceID\s*\(" -or $inventoryText -match "scene:\{"
if ($inventoryOwnerUsesInstanceId) {
    [void]$violations.Add("Inventory owner ids must not fall back to scene handle or GetInstanceID; saved owner ids must be stable identifiers.")
}

$inventoryOwnerUsesDefaultFallback = $inventoryText -match "new\s+InventoryOwnerHandle\s*\(\s*kind\s*,\s*`"default`"\s*\)"
if ($inventoryOwnerUsesDefaultFallback) {
    [void]$violations.Add("Persistable-backed inventory owners must not fall back to kind:default; missing stable ids must fail as invalid owners.")
}

$runtimePrefabUsesDatabaseReference = $persistenceContractsText.Contains("DatabaseEntryReference<PrefabReference> prefab")
if (-not $runtimePrefabUsesDatabaseReference) {
    [void]$violations.Add("RuntimeInstancedPersistentDataHandler must store PrefabReference as DatabaseEntryReference GUID, not Unity object reference.")
}

if ($persistenceContractsText -match "public\s+PrefabReference\s+prefab\s*;") {
    [void]$violations.Add("RuntimeInstancedPersistentDataHandler still stores direct PrefabReference object.")
}

$makeRuntimeWritesPrefabGuid = $persistableText -match "TryCreateReference\s*\(\s*instance"
if (-not $makeRuntimeWritesPrefabGuid) {
    [void]$violations.Add("Persistable.MakeRuntimeInstanced must serialize PrefabReference through DatabaseRegistry GUID.")
}

$runtimeRestoreLoadsPrefabGuid = $persistenceSystemText.Contains("GameManager.Database.LoadFromReference(handler.prefab)")
if (-not $runtimeRestoreLoadsPrefabGuid) {
    [void]$violations.Add("PersistenceSystem must restore runtime-instanced prefabs through DatabaseRegistry references.")
}

$inventoryReportsMissingItems =
    $inventoryText -match "LoadFromReference\s*\(\s*itemReference\s*\)" -and
    $inventoryText -match "if\s*\(\s*!item\s*\)" -and
    $inventoryText -match "Debug\.LogError"
if (-not $inventoryReportsMissingItems) {
    [void]$violations.Add("InventorySystem must report unresolved item DatabaseEntryReference during save load instead of writing null item keys.")
}

$inventorySkipsUnregisteredItemsOnSave =
    $inventoryText -match "TryCreateReference\s*\(\s*item\s*,\s*out\s+DatabaseEntryReference<Item>\s+itemReference\s*\)"
if (-not $inventorySkipsUnregisteredItemsOnSave) {
    [void]$violations.Add("InventorySystem must not serialize item entries whose DatabaseRegistry reference has an empty GUID.")
}

$persistableDestroyNullSafe =
    $persistableText.Contains("m_executeOnDeath?.Execute(context)") -or
    $persistableText.Contains("m_executeOnDeath.ExecuteFireAndReport(context")
if (-not $persistableDestroyNullSafe) {
    [void]$violations.Add("Persistable.Destroy must treat execute-on-death command as optional and must not drop async command exceptions.")
}

$databaseReferenceNullSafe =
    $databaseRegistryText -match "reference\s*==\s*null" -and
    $databaseRegistryText -match "string\.IsNullOrWhiteSpace\s*\(\s*reference\.guid\s*\)"
if (-not $databaseReferenceNullSafe) {
    [void]$violations.Add("DatabaseRegistry.LoadFromReference must treat null or empty GUID references as unresolved instead of throwing.")
}

$databaseCreateReferenceRejectsMissingEntries =
    $databaseRegistryText -match "DatabaseEntryToGUID" -and
    $databaseRegistryText -match "string\.IsNullOrWhiteSpace\s*\(\s*guid\s*\)" -and
    $databaseRegistryText.Contains($cannotCreateStableReferenceText)
if (-not $databaseCreateReferenceRejectsMissingEntries) {
    [void]$violations.Add("DatabaseRegistry.CreateReference must report missing registry entries instead of silently producing empty GUID references.")
}

$databaseTryCreateReferenceExists = $databaseRegistryText -match "bool\s+TryCreateReference"
if (-not $databaseTryCreateReferenceExists) {
    [void]$violations.Add("DatabaseRegistry must expose TryCreateReference so save writers can skip unresolved assets instead of serializing empty GUIDs.")
}

$persistableInstantiationRejectsInvalidPrefab =
    $persistenceInstantiationText.Contains("if (prefab == null)") -and
    $persistenceInstantiationText.Contains($validPrefabRequiredText)
if (-not $persistableInstantiationRejectsInvalidPrefab) {
    [void]$violations.Add("PersistenceSystem.InstantiateInternal must throw a clear error for null prefab instead of relying on Instantiate/assert failures.")
}

$persistableInstantiationRejectsMissingPersistable =
    $persistenceInstantiationText.Contains("TryGetComponent(out Persistable persistable)") -and
    $persistenceInstantiationText.Contains("Destroy(go)") -and
    $persistenceInstantiationText.Contains($missingPersistableText)
if (-not $persistableInstantiationRejectsMissingPersistable) {
    [void]$violations.Add("PersistenceSystem.InstantiateInternal must destroy and throw when prefab lacks Persistable instead of registering null.")
}

$persistableInstantiationRejectsWrongType =
    $persistenceInstantiationText.Contains("RequireInstantiatedPersistable<TPersistable>") -and
    $persistenceInstantiationText.Contains("m_persistables.Remove(result.identifier)") -and
    $persistenceInstantiationText.Contains($mustContainPersistableTypeText)
if (-not $persistableInstantiationRejectsWrongType) {
    [void]$violations.Add("PersistenceSystem generic instantiate helpers must reject wrong Persistable subtype and remove the bad registry entry.")
}

$persistableRegistrationRejectsNull =
    $persistenceInstantiationText.Contains("if (persistable == null)") -and
    $persistenceInstantiationText.Contains($customPersistableRequiredText)
if (-not $persistableRegistrationRejectsNull) {
    [void]$violations.Add("PersistenceSystem.RegisterCustomInstancedPersistable must reject null persistables instead of writing null into the registry.")
}

$persistableIdentifierRejectsBlank =
    $persistenceInstantiationText.Contains("ResolvePersistenceIdentifier") -and
    $persistenceInstantiationText.Contains("string.IsNullOrWhiteSpace(identifier)") -and
    $persistenceInstantiationText.Contains($blankPersistenceIdentifierText)
if (-not $persistableIdentifierRejectsBlank) {
    [void]$violations.Add("PersistenceSystem runtime/custom instance identifiers must reject blank strings instead of registering empty keys.")
}

if ($persistenceInstantiationText -match "Debug\.Assert\s*\(\s*persistable\s*!=") {
    [void]$violations.Add("PersistenceSystem instantiation contracts must throw for invalid prefab components; Debug.Assert-only checks are not enough.")
}

if (Test-Path -LiteralPath $runtimeRoot) {
    foreach ($file in Get-ChildItem -LiteralPath $runtimeRoot -Recurse -File -Filter "*.cs") {
        $repoPath = ConvertTo-RepoPath $file.FullName
        if ($repoPath -notmatch "Assets/Scripts/GameCore/Runtime/(Persistence|Game/Systems|Database)") {
            continue
        }

        $lineNumber = 0
        $editorOnlyDepth = 0
        foreach ($line in Get-Content -LiteralPath $file.FullName) {
            $lineNumber++
            $trimmedLine = $line.Trim()

            if ($trimmedLine -match "^#if\s+UNITY_EDITOR\b") {
                $editorOnlyDepth++
                continue
            }

            if ($editorOnlyDepth -gt 0 -and $trimmedLine -match "^#if\b") {
                $editorOnlyDepth++
                continue
            }

            if ($editorOnlyDepth -gt 0 -and $trimmedLine -match "^#endif\b") {
                $editorOnlyDepth--
                continue
            }

            if ($line -match "AssetDatabase" -and $editorOnlyDepth -eq 0) {
                [void]$violations.Add(("{0}:{1}: runtime persistence/database code must not depend on AssetDatabase outside editor-only code: {2}" -f $repoPath, $lineNumber, $line.Trim()))
            }

            if ($repoPath -ne "Assets/Scripts/GameCore/Runtime/Database/DatabaseRegistry.cs" -and
                $line -match "(?<!Try)CreateReference\s*\(") {
                [void]$violations.Add(("{0}:{1}: save writers must call TryCreateReference and skip unresolved assets instead of directly serializing CreateReference results: {2}" -f $repoPath, $lineNumber, $line.Trim()))
            }
        }
    }
}

$result = [ordered]@{
    Passed = $violations.Count -eq 0
    InventoryOwnerUsesInstanceId = $inventoryOwnerUsesInstanceId
    InventoryOwnerUsesDefaultFallback = $inventoryOwnerUsesDefaultFallback
    RuntimePrefabUsesDatabaseReference = $runtimePrefabUsesDatabaseReference
    MakeRuntimeWritesPrefabGuid = $makeRuntimeWritesPrefabGuid
    RuntimeRestoreLoadsPrefabGuid = $runtimeRestoreLoadsPrefabGuid
    InventoryReportsMissingItems = $inventoryReportsMissingItems
    InventorySkipsUnregisteredItemsOnSave = $inventorySkipsUnregisteredItemsOnSave
    PersistableDestroyNullSafe = $persistableDestroyNullSafe
    DatabaseReferenceNullSafe = $databaseReferenceNullSafe
    DatabaseCreateReferenceRejectsMissingEntries = $databaseCreateReferenceRejectsMissingEntries
    DatabaseTryCreateReferenceExists = $databaseTryCreateReferenceExists
    PersistableInstantiationRejectsInvalidPrefab = $persistableInstantiationRejectsInvalidPrefab
    PersistableInstantiationRejectsMissingPersistable = $persistableInstantiationRejectsMissingPersistable
    PersistableInstantiationRejectsWrongType = $persistableInstantiationRejectsWrongType
    PersistableRegistrationRejectsNull = $persistableRegistrationRejectsNull
    PersistableIdentifierRejectsBlank = $persistableIdentifierRejectsBlank
    ViolationCount = $violations.Count
    Violations = $violations
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 8
}
else {
    if ($result.Passed) {
        Write-Host "Persistence runtime static gate passed."
    }
    else {
        Write-Host "Persistence runtime static gate failed."
        foreach ($violation in $violations) {
            Write-Host " - $violation"
        }
    }
}

if ($violations.Count -gt 0) {
    exit 2
}
