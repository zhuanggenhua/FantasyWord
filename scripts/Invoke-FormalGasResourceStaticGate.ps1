[CmdletBinding()]
param(
    [switch]$AsJson,
    [switch]$StrictRuntimeAddresses
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Get-ProjectRoot {
    $scriptRoot = if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
        $PSScriptRoot
    }
    else {
        Split-Path -Parent $PSCommandPath
    }

    return [System.IO.Path]::GetFullPath((Join-Path $scriptRoot ".."))
}

function Convert-ToProjectRelativePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot,
        [Parameter(Mandatory = $true)]
        [string]$FullPath
    )

    $rootWithSlash = $ProjectRoot.TrimEnd('\') + '\'
    if ($FullPath.StartsWith($rootWithSlash, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $FullPath.Substring($rootWithSlash.Length).Replace('\', '/')
    }

    return $FullPath.Replace('\', '/')
}

function Read-JsonText {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Required EX-GAS generated data file not found: $Path"
    }

    return Get-Content -LiteralPath $Path -Raw -Encoding UTF8
}

function Read-XlsxEntryText {
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.Compression.ZipArchive]$Archive,
        [Parameter(Mandatory = $true)]
        [string]$EntryName
    )

    $entry = $Archive.GetEntry($EntryName)
    if ($null -eq $entry) {
        return ""
    }

    $stream = $entry.Open()
    try {
        $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::UTF8)
        try {
            return $reader.ReadToEnd()
        }
        finally {
            $reader.Dispose()
        }
    }
    finally {
        $stream.Dispose()
    }
}

function Convert-XlsxColumnToIndex {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CellReference
    )

    $letters = [regex]::Match($CellReference, '^[A-Z]+').Value
    $index = 0
    foreach ($char in $letters.ToCharArray()) {
        $index = ($index * 26) + ([int][char]$char - [int][char]'A' + 1)
    }

    return $index
}

function Convert-XlsxIndexToColumn {
    param(
        [Parameter(Mandatory = $true)]
        [int]$Index
    )

    $result = ""
    while ($Index -gt 0) {
        $mod = ($Index - 1) % 26
        $result = [char]([int][char]'A' + $mod) + $result
        $Index = [math]::Floor(($Index - 1) / 26)
    }

    return $result
}

function Get-XlsxCellTextRows {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Required EX-GAS source table not found: $Path"
    }

    $archive = [System.IO.Compression.ZipFile]::OpenRead($Path)
    try {
        $sharedStrings = New-Object System.Collections.Generic.List[string]
        $sharedStringsText = Read-XlsxEntryText -Archive $archive -EntryName "xl/sharedStrings.xml"
        if (-not [string]::IsNullOrWhiteSpace($sharedStringsText)) {
            [xml]$sharedStringsXml = $sharedStringsText
            foreach ($sharedString in $sharedStringsXml.GetElementsByTagName("si")) {
                $parts = New-Object System.Collections.Generic.List[string]
                foreach ($textNode in $sharedString.GetElementsByTagName("t")) {
                    [void]$parts.Add($textNode.InnerText)
                }

                [void]$sharedStrings.Add(($parts -join ""))
            }
        }

        $sheetEntry = $archive.Entries |
            Where-Object { $_.FullName -like "xl/worksheets/sheet*.xml" } |
            Sort-Object FullName |
            Select-Object -First 1
        if ($null -eq $sheetEntry) {
            throw "Source table has no worksheet: $Path"
        }

        [xml]$sheetXml = Read-XlsxEntryText -Archive $archive -EntryName $sheetEntry.FullName
        $rows = New-Object System.Collections.Generic.List[object]
        foreach ($rowNode in $sheetXml.GetElementsByTagName("row")) {
            $cells = @{}
            foreach ($cellNode in $rowNode.GetElementsByTagName("c")) {
                $cellReference = $cellNode.GetAttribute("r")
                if ([string]::IsNullOrWhiteSpace($cellReference)) {
                    continue
                }

                $columnIndex = Convert-XlsxColumnToIndex -CellReference $cellReference
                $cellType = $cellNode.GetAttribute("t")
                $valueNodes = $cellNode.GetElementsByTagName("v")
                $value = if ($valueNodes.Count -gt 0) { $valueNodes.Item(0).InnerText } else { "" }
                if ($cellType -eq "s" -and -not [string]::IsNullOrWhiteSpace($value)) {
                    $sharedStringIndex = [int]$value
                    $value = if ($sharedStringIndex -ge 0 -and $sharedStringIndex -lt $sharedStrings.Count) {
                        $sharedStrings[$sharedStringIndex]
                    }
                    else {
                        ""
                    }
                }
                elseif ($cellType -eq "inlineStr") {
                    $inlineText = New-Object System.Collections.Generic.List[string]
                    foreach ($textNode in $cellNode.GetElementsByTagName("t")) {
                        [void]$inlineText.Add($textNode.InnerText)
                    }

                    $value = $inlineText -join ""
                }

                $cells[$columnIndex] = [string]$value
            }

            if ($cells.Count -gt 0) {
                [void]$rows.Add([pscustomobject]@{
                    Row = [int]$rowNode.GetAttribute("r")
                    Cells = $cells
                })
            }
        }

        return $rows.ToArray()
    }
    finally {
        $archive.Dispose()
    }
}

function Get-XlsxCellValue {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Cells,
        [Parameter(Mandatory = $true)]
        [int]$ColumnIndex
    )

    if ($Cells.ContainsKey($ColumnIndex)) {
        return [string]$Cells[$ColumnIndex]
    }

    return ""
}

function Add-EditorAssetPathDebt {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[string]]$Debt,
        [Parameter(Mandatory = $true)]
        [string]$Source,
        [Parameter(Mandatory = $true)]
        [string]$Owner,
        [Parameter(Mandatory = $true)]
        [string]$Field,
        [AllowEmptyString()]
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return
    }

    if ($Value.StartsWith("Assets/", [System.StringComparison]::OrdinalIgnoreCase)) {
        [void]$Debt.Add(("{0}: {1}.{2} = {3}" -f $Source, $Owner, $Field, $Value))
    }
}

function Get-DatabaseEntryTypesByGuid {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot
    )

    $result = @{}
    $gameDataRoot = Join-Path $ProjectRoot "Assets/GameData"
    if (-not (Test-Path -LiteralPath $gameDataRoot)) {
        return $result
    }

    Get-ChildItem -LiteralPath $gameDataRoot -Recurse -File -Filter "*.asset" | ForEach-Object {
        $assetPath = $_.FullName
        $metaPath = "$assetPath.meta"
        if (-not (Test-Path -LiteralPath $metaPath)) {
            return
        }

        $metaText = Get-Content -LiteralPath $metaPath -Raw -Encoding UTF8
        $guidMatch = [regex]::Match($metaText, '(?m)^guid:\s*(?<Guid>[0-9a-fA-F]{32})\s*$')
        if (-not $guidMatch.Success) {
            return
        }

        $assetText = Get-Content -LiteralPath $assetPath -Raw -Encoding UTF8
        $typeMatch = [regex]::Match(
            $assetText,
            'm_EditorClassIdentifier:\s*FantasyWord\.GameCore::FantasyWord\.GameCore\.(?<Type>[A-Za-z0-9_]+)')
        if ($typeMatch.Success) {
            $result[$guidMatch.Groups["Guid"].Value.ToLowerInvariant()] = $typeMatch.Groups["Type"].Value
        }
    }

    return $result
}

function Get-DatabaseRegistryGuidSet {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot
    )

    $registryPath = Join-Path $ProjectRoot "Assets/GameData/GameCore/DatabaseRegistry.asset"
    if (-not (Test-Path -LiteralPath $registryPath)) {
        throw "Required DatabaseRegistry not found: $registryPath"
    }

    $registryText = Get-Content -LiteralPath $registryPath -Raw -Encoding UTF8
    $result = @{}
    foreach ($match in [regex]::Matches($registryText, '(?m)^\s*-\s*(?<Guid>[0-9a-fA-F]{32})\s*$')) {
        $result[$match.Groups["Guid"].Value.ToLowerInvariant()] = $true
    }

    return $result
}

function Add-DatabaseReferenceDebtIfInvalid {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[string]]$Debt,
        [Parameter(Mandatory = $true)]
        [hashtable]$DatabaseRegistryGuids,
        [Parameter(Mandatory = $true)]
        [hashtable]$DatabaseEntryTypesByGuid,
        [Parameter(Mandatory = $true)]
        [string]$Source,
        [Parameter(Mandatory = $true)]
        [string]$Owner,
        [Parameter(Mandatory = $true)]
        [string]$Field,
        [Parameter(Mandatory = $true)]
        [string]$ExpectedType,
        [AllowEmptyString()]
        [string]$Guid
    )

    if ([string]::IsNullOrWhiteSpace($Guid)) {
        [void]$Debt.Add(("{0}: {1}.{2} is empty; expected DatabaseRegistry {3} GUID or a runtime address" -f $Source, $Owner, $Field, $ExpectedType))
        return
    }

    if (-not [regex]::IsMatch($Guid, '^[0-9a-fA-F]{32}$')) {
        [void]$Debt.Add(("{0}: {1}.{2} is not a DatabaseRegistry GUID: {3}" -f $Source, $Owner, $Field, $Guid))
        return
    }

    $normalizedGuid = $Guid.ToLowerInvariant()
    if (-not $DatabaseRegistryGuids.ContainsKey($normalizedGuid)) {
        [void]$Debt.Add(("{0}: {1}.{2} is not registered in DatabaseRegistry: {3}" -f $Source, $Owner, $Field, $Guid))
        return
    }

    if (-not $DatabaseEntryTypesByGuid.ContainsKey($normalizedGuid)) {
        [void]$Debt.Add(("{0}: {1}.{2} registry entry cannot be resolved under Assets/GameData: {3}" -f $Source, $Owner, $Field, $Guid))
        return
    }

    $actualType = [string]$DatabaseEntryTypesByGuid[$normalizedGuid]
    if ($actualType -ne $ExpectedType) {
        [void]$Debt.Add(("{0}: {1}.{2} expected {3}, got {4}: {5}" -f $Source, $Owner, $Field, $ExpectedType, $actualType, $Guid))
    }
}

function Add-AbilityGameCoreSourceDebts {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,
        [Parameter(Mandatory = $true)]
        [string]$SourceRelativePath,
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[string]]$Debt
    )

    $rows = Get-XlsxCellTextRows -Path $SourcePath
    $headerRow = $rows | Where-Object { $_.Row -eq 1 } | Select-Object -First 1
    if ($null -eq $headerRow) {
        throw "Source table has no header row: $SourcePath"
    }

    $columnsByName = @{}
    foreach ($columnIndex in $headerRow.Cells.Keys) {
        $fieldName = [string]$headerRow.Cells[$columnIndex]
        if (-not [string]::IsNullOrWhiteSpace($fieldName) -and $fieldName -ne "##var") {
            $columnsByName[$fieldName] = [int]$columnIndex
        }
    }

    foreach ($requiredColumn in @("ID", "PrefabPath", "IconPath")) {
        if (-not $columnsByName.ContainsKey($requiredColumn)) {
            throw "Source table missing required column ${requiredColumn}: $SourcePath"
        }
    }

    foreach ($row in $rows | Where-Object { $_.Row -gt 3 }) {
        $id = Get-XlsxCellValue -Cells $row.Cells -ColumnIndex $columnsByName["ID"]
        if ([string]::IsNullOrWhiteSpace($id)) {
            continue
        }

        $owner = "Ability {0}" -f $id
        Add-EditorAssetPathDebt -Debt $Debt -Source $SourceRelativePath -Owner $owner -Field "PrefabPath" -Value (Get-XlsxCellValue -Cells $row.Cells -ColumnIndex $columnsByName["PrefabPath"])
        Add-EditorAssetPathDebt -Debt $Debt -Source $SourceRelativePath -Owner $owner -Field "IconPath" -Value (Get-XlsxCellValue -Cells $row.Cells -ColumnIndex $columnsByName["IconPath"])
    }
}

function Add-GenericXlsxEditorAssetPathDebts {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,
        [Parameter(Mandatory = $true)]
        [string]$SourceRelativePath,
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[string]]$Debt
    )

    $rows = Get-XlsxCellTextRows -Path $SourcePath
    foreach ($row in $rows) {
        foreach ($columnIndex in $row.Cells.Keys) {
            $value = [string]$row.Cells[$columnIndex]
            if ([string]::IsNullOrWhiteSpace($value) -or
                -not $value.StartsWith("Assets/", [System.StringComparison]::OrdinalIgnoreCase)) {
                continue
            }

            $columnName = Convert-XlsxIndexToColumn -Index ([int]$columnIndex)
            [void]$Debt.Add(("{0}: Row {1} Cell {2}{1} = {3}" -f $SourceRelativePath, $row.Row, $columnName, $value))
        }
    }
}

$projectRoot = Get-ProjectRoot
$gasJsonRoot = Join-Path $projectRoot "Assets/DataGenerated/Luban/Json/GAS"
$gasSourceRoot = Join-Path $projectRoot "EX_GAS_Config/ProjectConfigTable/exgas_config/Datas"
$abilityGameCorePath = Join-Path $gasJsonRoot "exgas_tbabilitygamecore.json"
$timelineAbilityPath = Join-Path $gasJsonRoot "exgas_tbtimelineability.json"
$abilityGameCoreSourcePath = Join-Path $gasSourceRoot "#exgas.abilityGameCore.xlsx"
$timelineAbilitySourcePath = Join-Path $gasSourceRoot "#exgas.timelineAbility.xlsx"

$abilityGameCoreRelative = Convert-ToProjectRelativePath -ProjectRoot $projectRoot -FullPath $abilityGameCorePath
$timelineAbilityRelative = Convert-ToProjectRelativePath -ProjectRoot $projectRoot -FullPath $timelineAbilityPath
$abilityGameCoreSourceRelative = Convert-ToProjectRelativePath -ProjectRoot $projectRoot -FullPath $abilityGameCoreSourcePath
$timelineAbilitySourceRelative = Convert-ToProjectRelativePath -ProjectRoot $projectRoot -FullPath $timelineAbilitySourcePath

$editorAssetPathRuntimeDebts = New-Object System.Collections.Generic.List[string]
$sourceEditorAssetPathRuntimeDebts = New-Object System.Collections.Generic.List[string]
$missingRuntimeAddressDebts = New-Object System.Collections.Generic.List[string]
$databaseReferenceDebts = New-Object System.Collections.Generic.List[string]
$animatorNodePathDebts = New-Object System.Collections.Generic.List[string]
$formalCueRuntimePathDebts = New-Object System.Collections.Generic.List[string]
$databaseRegistryGuids = Get-DatabaseRegistryGuidSet -ProjectRoot $projectRoot
$databaseEntryTypesByGuid = Get-DatabaseEntryTypesByGuid -ProjectRoot $projectRoot

Add-AbilityGameCoreSourceDebts -SourcePath $abilityGameCoreSourcePath -SourceRelativePath $abilityGameCoreSourceRelative -Debt $sourceEditorAssetPathRuntimeDebts
Add-GenericXlsxEditorAssetPathDebts -SourcePath $timelineAbilitySourcePath -SourceRelativePath $timelineAbilitySourceRelative -Debt $sourceEditorAssetPathRuntimeDebts

$abilityGameCoreJson = Read-JsonText -Path $abilityGameCorePath
$abilityRows = $abilityGameCoreJson | ConvertFrom-Json
foreach ($row in $abilityRows) {
    $owner = "Ability {0}" -f $row.ID
    Add-EditorAssetPathDebt -Debt $editorAssetPathRuntimeDebts -Source $abilityGameCoreRelative -Owner $owner -Field "PrefabPath" -Value $row.PrefabPath
    Add-EditorAssetPathDebt -Debt $editorAssetPathRuntimeDebts -Source $abilityGameCoreRelative -Owner $owner -Field "IconPath" -Value $row.IconPath

    if ([string]::IsNullOrWhiteSpace($row.PrefabPath)) {
        Add-DatabaseReferenceDebtIfInvalid -Debt $databaseReferenceDebts -DatabaseRegistryGuids $databaseRegistryGuids -DatabaseEntryTypesByGuid $databaseEntryTypesByGuid -Source $abilityGameCoreRelative -Owner $owner -Field "PrefabGuid" -ExpectedType "PrefabReference" -Guid $row.PrefabGuid
    }

    if ([string]::IsNullOrWhiteSpace($row.IconPath) -and
        -not [string]::IsNullOrWhiteSpace($row.IconGuid)) {
        Add-DatabaseReferenceDebtIfInvalid -Debt $databaseReferenceDebts -DatabaseRegistryGuids $databaseRegistryGuids -DatabaseEntryTypesByGuid $databaseEntryTypesByGuid -Source $abilityGameCoreRelative -Owner $owner -Field "IconGuid" -ExpectedType "SpriteReference" -Guid $row.IconGuid
    }
}

$timelineAbilityJson = Read-JsonText -Path $timelineAbilityPath
$prefabPathMatches = [regex]::Matches(
    $timelineAbilityJson,
    '"PrefabPath"\s*:\s*"(?<Path>[^"]*)"')
foreach ($match in $prefabPathMatches) {
    $prefabPath = $match.Groups["Path"].Value
    if ([string]::IsNullOrWhiteSpace($prefabPath)) {
        [void]$missingRuntimeAddressDebts.Add(("{0}: CueMountPrefab.PrefabPath is empty" -f $timelineAbilityRelative))
    }
    elseif ($prefabPath.StartsWith("Assets/", [System.StringComparison]::OrdinalIgnoreCase)) {
        [void]$editorAssetPathRuntimeDebts.Add(
            ("{0}: CueMountPrefab.PrefabPath = {1}" -f $timelineAbilityRelative, $prefabPath))
    }
    elseif ([regex]::IsMatch($prefabPath, '^[0-9a-fA-F]{32}$')) {
        Add-DatabaseReferenceDebtIfInvalid -Debt $databaseReferenceDebts -DatabaseRegistryGuids $databaseRegistryGuids -DatabaseEntryTypesByGuid $databaseEntryTypesByGuid -Source $timelineAbilityRelative -Owner "CueMountPrefab" -Field "PrefabPath" -ExpectedType "PrefabReference" -Guid $prefabPath
    }
}

$timelineRows = $timelineAbilityJson | ConvertFrom-Json
foreach ($row in $timelineRows) {
    $timelineOwner = "TimelineAbility {0}" -f $row.ID
    $rowText = $row | ConvertTo-Json -Depth 32 -Compress
    foreach ($cueMatch in [regex]::Matches(
            $rowText,
            '\{[^{}]*"\$type"\s*:\s*"CuePlayGameCoreAnimator"[^{}]*"Param"\s*:\s*\{[^{}]*"AnimatorNodePath"\s*:\s*"(?<Path>[^"]*)"[^{}]*\}[^{}]*\}')) {
        $animatorNodePath = $cueMatch.Groups["Path"].Value
        if (-not [string]::IsNullOrWhiteSpace($animatorNodePath)) {
            [void]$animatorNodePathDebts.Add(("{0}: {1}.CuePlayGameCoreAnimator.AnimatorNodePath must stay empty; formal GameCore animation cues resolve ICharacterAnimationDriver from the target object, not a serialized child path: {2}" -f $timelineAbilityRelative, $timelineOwner, $animatorNodePath))
        }
    }
}

$formalAnimatorCuePath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Presentation/CuePlayGameCoreAnimator.cs"
if (-not (Test-Path -LiteralPath $formalAnimatorCuePath)) {
    [void]$formalCueRuntimePathDebts.Add("CuePlayGameCoreAnimator.cs is missing.")
}
else {
    $formalAnimatorCueText = Get-Content -LiteralPath $formalAnimatorCuePath -Raw -Encoding UTF8
    if ($formalAnimatorCueText -match "AnimatorNodePath" -or
        $formalAnimatorCueText -match "\.transform\.Find\s*\(") {
        [void]$formalCueRuntimePathDebts.Add("CuePlayGameCoreAnimator must not consume AnimatorNodePath or use transform.Find; formal cues resolve ICharacterAnimationDriver from the target object tree.")
    }
}

$report = [ordered]@{
    ProjectRoot = $projectRoot
    StrictRuntimeAddresses = [bool]$StrictRuntimeAddresses
    AbilityGameCorePath = $abilityGameCoreRelative
    TimelineAbilityPath = $timelineAbilityRelative
    AbilityGameCoreSourcePath = $abilityGameCoreSourceRelative
    TimelineAbilitySourcePath = $timelineAbilitySourceRelative
    AbilityGameCoreRowCount = @($abilityRows).Count
    SourceEditorAssetPathRuntimeDebtCount = $sourceEditorAssetPathRuntimeDebts.Count
    EditorAssetPathRuntimeDebtCount = $editorAssetPathRuntimeDebts.Count
    MissingRuntimeAddressDebtCount = $missingRuntimeAddressDebts.Count
    DatabaseReferenceDebtCount = $databaseReferenceDebts.Count
    AnimatorNodePathDebtCount = $animatorNodePathDebts.Count
    FormalCueRuntimePathDebtCount = $formalCueRuntimePathDebts.Count
    SourceEditorAssetPathRuntimeDebts = @($sourceEditorAssetPathRuntimeDebts)
    EditorAssetPathRuntimeDebts = @($editorAssetPathRuntimeDebts)
    MissingRuntimeAddressDebts = @($missingRuntimeAddressDebts)
    DatabaseReferenceDebts = @($databaseReferenceDebts)
    AnimatorNodePathDebts = @($animatorNodePathDebts)
    FormalCueRuntimePathDebts = @($formalCueRuntimePathDebts)
}

$hasStrictFailure = $StrictRuntimeAddresses -and (
    $report.SourceEditorAssetPathRuntimeDebtCount -gt 0 -or
    $report.EditorAssetPathRuntimeDebtCount -gt 0 -or
    $report.MissingRuntimeAddressDebtCount -gt 0 -or
    $report.DatabaseReferenceDebtCount -gt 0 -or
    $report.AnimatorNodePathDebtCount -gt 0 -or
    $report.FormalCueRuntimePathDebtCount -gt 0
)

if ($AsJson) {
    $report | ConvertTo-Json -Depth 6
    if ($hasStrictFailure) { exit 2 }
    exit 0
}

Write-Host "FantasyWord formal EX-GAS resource static gate"
Write-Host ("ProjectRoot: {0}" -f $report.ProjectRoot)
Write-Host ("Strict runtime addresses: {0}" -f $report.StrictRuntimeAddresses)
Write-Host ("AbilityGameCore rows: {0}" -f $report.AbilityGameCoreRowCount)
Write-Host ("Source editor asset paths used as runtime resource identities: {0}" -f $report.SourceEditorAssetPathRuntimeDebtCount)
foreach ($debt in $report.SourceEditorAssetPathRuntimeDebts) {
    Write-Host ("  [source-editor-asset-path-runtime-debt] {0}" -f $debt)
}

Write-Host ("Editor asset paths used as runtime resource identities: {0}" -f $report.EditorAssetPathRuntimeDebtCount)
foreach ($debt in $report.EditorAssetPathRuntimeDebts) {
    Write-Host ("  [editor-asset-path-runtime-debt] {0}" -f $debt)
}

Write-Host ("Missing runtime addresses with GUID fallback: {0}" -f $report.MissingRuntimeAddressDebtCount)
foreach ($debt in $report.MissingRuntimeAddressDebts) {
    Write-Host ("  [missing-runtime-address] {0}" -f $debt)
}

Write-Host ("Database reference debts: {0}" -f $report.DatabaseReferenceDebtCount)
foreach ($debt in $report.DatabaseReferenceDebts) {
    Write-Host ("  [database-reference-debt] {0}" -f $debt)
}

Write-Host ("Animator node path debts: {0}" -f $report.AnimatorNodePathDebtCount)
foreach ($debt in $report.AnimatorNodePathDebts) {
    Write-Host ("  [animator-node-path-debt] {0}" -f $debt)
}

Write-Host ("Formal cue runtime path debts: {0}" -f $report.FormalCueRuntimePathDebtCount)
foreach ($debt in $report.FormalCueRuntimePathDebts) {
    Write-Host ("  [formal-cue-runtime-path-debt] {0}" -f $debt)
}

if ($hasStrictFailure) {
    exit 2
}

exit 0
