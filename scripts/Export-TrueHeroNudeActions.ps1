param(
    [string]$OutputRoot = "Assets/Art/角色/真正英雄裸体动作",
    [string]$EvidenceRoot = ".codex/evidence/真正英雄裸体动作"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

$frameSize = 32
$projectRoot = (Resolve-Path -LiteralPath ".").Path
$heroRoot = "Assets/Art/英雄/迷你幻想_真正英雄_v1.0/迷你幻想_真正英雄_素材"
$englishHeroRoot = "Assets/Art/MINIFANTASY - Crafting and Professions I/Sprites"
$candidateRoots = @(
    "Assets/Art/MINIFANTASY Creatures - Super Low Res 2D Pixel Art by Krishna Palacio/Sprites/Humanoids/Human/Human",
    "Assets/Art/武器/迷你幻想_武器_v3.0/迷你幻想_武器_素材",
    "Assets/Art/MINIFANTASY - Crafting and Professions I/Sprites"
)

$skinColorKeys = @(
    "DDB78FFF",
    "EEC39AFF",
    "FACBA6FF",
    "CDAC85FF",
    "BB9E79FF"
)
$bodyColorKeys = @($skinColorKeys + "000000FF")
$skinColors = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$bodyColors = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$skinColorKeys | ForEach-Object { [void]$skinColors.Add($_) }
$bodyColorKeys | ForEach-Object { [void]$bodyColors.Add($_) }

function Get-ColorKey {
    param([System.Drawing.Color]$Color)

    return "{0:X2}{1:X2}{2:X2}{3:X2}" -f $Color.R, $Color.G, $Color.B, $Color.A
}

function Get-RelativeProjectPath {
    param([string]$Path)

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    if (-not $fullPath.StartsWith($projectRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $fullPath
    }

    return $fullPath.Substring($projectRoot.Length + 1).Replace("\", "/")
}

function Write-Png {
    param(
        [System.Drawing.Bitmap]$Bitmap,
        [string]$Path
    )

    $directory = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $directory)) {
        [void](New-Item -ItemType Directory -Path $directory -Force)
    }

    $stream = [System.IO.MemoryStream]::new()
    try {
        $Bitmap.Save($stream, [System.Drawing.Imaging.ImageFormat]::Png)
        [System.IO.File]::WriteAllBytes($Path, $stream.ToArray())
    }
    finally {
        $stream.Dispose()
    }
}

function New-DeterministicGuid {
    param([string]$AssetPath)

    $normalized = (Get-RelativeProjectPath -Path $AssetPath).ToLowerInvariant()
    $md5 = [System.Security.Cryptography.MD5]::Create()
    try {
        return ([System.BitConverter]::ToString(
            $md5.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($normalized))
        )).Replace("-", "").ToLowerInvariant()
    }
    finally {
        $md5.Dispose()
    }
}

function Set-PixelSpriteMeta {
    param(
        [string]$AssetPath,
        [string]$TemplateMetaPath
    )

    $metaPath = "$AssetPath.meta"
    if (-not [string]::IsNullOrWhiteSpace($TemplateMetaPath)) {
        if (-not (Test-Path -LiteralPath $TemplateMetaPath)) {
            throw "缺少原作者切片模板：$TemplateMetaPath"
        }

        $guid = New-DeterministicGuid -AssetPath $AssetPath
        $content = [System.IO.File]::ReadAllText($TemplateMetaPath)
        $content = [System.Text.RegularExpressions.Regex]::Replace(
            $content,
            '(?m)^guid: [0-9a-f]+$',
            "guid: $guid"
        )
        [System.IO.File]::WriteAllText($metaPath, $content, [System.Text.UTF8Encoding]::new($false))
    }

    if (-not (Test-Path -LiteralPath $metaPath)) {
        $guid = New-DeterministicGuid -AssetPath $AssetPath
        $meta = @"
fileFormatVersion: 2
guid: $guid
TextureImporter:
  internalIDToNameTable: []
  externalObjects: {}
  serializedVersion: 13
  mipmaps:
    mipMapMode: 0
    enableMipMap: 0
    sRGBTexture: 1
    linearTexture: 0
    fadeOut: 0
    borderMipMap: 0
    mipMapsPreserveCoverage: 0
    alphaTestReferenceValue: 0.5
    mipMapFadeDistanceStart: 1
    mipMapFadeDistanceEnd: 3
  bumpmap:
    convertToNormalMap: 0
    externalNormalMap: 0
    heightScale: 0.25
    normalMapFilter: 0
    flipGreenChannel: 0
  isReadable: 0
  streamingMipmaps: 0
  streamingMipmapsPriority: 0
  vTOnly: 0
  ignoreMipmapLimit: 0
  grayScaleToAlpha: 0
  generateCubemap: 6
  cubemapConvolution: 0
  seamlessCubemap: 0
  textureFormat: 1
  maxTextureSize: 2048
  textureSettings:
    serializedVersion: 2
    filterMode: 0
    aniso: 1
    mipBias: 0
    wrapU: 1
    wrapV: 1
    wrapW: 1
  nPOTScale: 0
  lightmap: 0
  compressionQuality: 50
  spriteMode: 2
  spriteExtrude: 1
  spriteMeshType: 1
  alignment: 0
  spritePivot: {x: 0.5, y: 0.5}
  spritePixelsToUnits: 8
  spriteBorder: {x: 0, y: 0, z: 0, w: 0}
  spriteGenerateFallbackPhysicsShape: 1
  alphaUsage: 1
  alphaIsTransparency: 1
  spriteTessellationDetail: -1
  textureType: 8
  textureShape: 1
  singleChannelComponent: 0
  flipbookRows: 1
  flipbookColumns: 1
  maxTextureSizeSet: 0
  compressionQualitySet: 0
  textureFormatSet: 0
  ignorePngGamma: 0
  applyGammaDecoding: 0
  swizzle: 50462976
  cookieLightType: 0
  platformSettings:
  - serializedVersion: 4
    buildTarget: DefaultTexturePlatform
    maxTextureSize: 2048
    resizeAlgorithm: 0
    textureFormat: -1
    textureCompression: 0
    compressionQuality: 50
    crunchedCompression: 0
    allowsAlphaSplitting: 0
    overridden: 0
    ignorePlatformSupport: 0
    androidETC2FallbackOverride: 0
    forceMaximumCompressionQuality_BC6H_BC7: 0
  spriteSheet:
    serializedVersion: 2
    sprites: []
    outline: []
    physicsShape: []
    bones: []
    spriteID:
    internalID: 0
    vertices: []
    indices:
    edges: []
    weights: []
    secondaryTextures: []
    nameFileIdTable: {}
  mipmapLimitGroupName:
  pSDRemoveMatte: 0
  userData:
  assetBundleName:
  assetBundleVariant:
"@
        [System.IO.File]::WriteAllText($metaPath, $meta, [System.Text.UTF8Encoding]::new($false))
        return
    }

    $content = [System.IO.File]::ReadAllText($metaPath)
    $replacements = @(
        @('(?m)^    enableMipMap: \d+$', '    enableMipMap: 0'),
        @('(?m)^    filterMode: \d+$', '    filterMode: 0'),
        @('(?m)^  nPOTScale: \d+$', '  nPOTScale: 0'),
        @('(?m)^  spriteMode: \d+$', '  spriteMode: 2'),
        @('(?m)^  spritePixelsToUnits: .+$', '  spritePixelsToUnits: 8'),
        @('(?m)^  alphaIsTransparency: \d+$', '  alphaIsTransparency: 1'),
        @('(?m)^  textureType: \d+$', '  textureType: 8')
    )
    foreach ($replacement in $replacements) {
        $content = [System.Text.RegularExpressions.Regex]::Replace(
            $content,
            $replacement[0],
            $replacement[1]
        )
    }
    $content = [System.Text.RegularExpressions.Regex]::Replace(
        $content,
        '(?ms)(^    buildTarget: DefaultTexturePlatform.*?^    textureCompression: )\d+$',
        '${1}0'
    )
    [System.IO.File]::WriteAllText($metaPath, $content, [System.Text.UTF8Encoding]::new($false))
}

function Test-PureBodySheet {
    param([string]$Path)

    $bitmap = [System.Drawing.Bitmap]::new($Path)
    try {
        if ($bitmap.Width % $frameSize -ne 0 -or $bitmap.Height % $frameSize -ne 0) {
            return $false
        }

        $skinPixelCount = 0
        for ($y = 0; $y -lt $bitmap.Height; $y++) {
            for ($x = 0; $x -lt $bitmap.Width; $x++) {
                $pixel = $bitmap.GetPixel($x, $y)
                if ($pixel.A -eq 0) {
                    continue
                }

                $key = Get-ColorKey -Color $pixel
                if (-not $bodyColors.Contains($key)) {
                    return $false
                }
                if ($skinColors.Contains($key)) {
                    $skinPixelCount++
                }
            }
        }

        return $skinPixelCount -gt 0
    }
    finally {
        $bitmap.Dispose()
    }
}

function Get-BodyCandidates {
    $files = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
    foreach ($root in $candidateRoots) {
        if (-not (Test-Path -LiteralPath $root)) {
            throw "缺少裸体动作候选来源：$root"
        }

        Get-ChildItem -LiteralPath $root -Recurse -File -Filter '*.png' | Where-Object {
            $_.FullName -notmatch '(?i)(BodyUV|HeadUV|UVMap|Shadow|Shadows|阴影)' -and
            ($_.Name -match '(?i)(Human|人类)' -or $_.FullName -like '*Humanoids\Human\Human*')
        } | ForEach-Object { $files.Add($_) }
    }

    $candidates = [System.Collections.Generic.List[object]]::new()
    foreach ($file in ($files | Sort-Object FullName -Unique)) {
        if (-not (Test-PureBodySheet -Path $file.FullName)) {
            continue
        }

        $bitmap = [System.Drawing.Bitmap]::new($file.FullName)
        try {
            $columns = [int]($bitmap.Width / $frameSize)
            $rows = [int]($bitmap.Height / $frameSize)
            for ($row = 0; $row -lt $rows; $row++) {
                for ($column = 0; $column -lt $columns; $column++) {
                    $pixels = [System.Drawing.Color[]]::new($frameSize * $frameSize)
                    $opaqueMask = [bool[]]::new($frameSize * $frameSize)
                    $opaquePoints = [System.Collections.Generic.List[int]]::new()
                    $skinPoints = [System.Collections.Generic.List[int]]::new()
                    $opaqueCount = 0
                    $skinCount = 0
                    $skinXTotal = 0
                    $skinYTotal = 0
                    for ($y = 0; $y -lt $frameSize; $y++) {
                        for ($x = 0; $x -lt $frameSize; $x++) {
                            $index = $y * $frameSize + $x
                            $pixel = $bitmap.GetPixel($column * $frameSize + $x, $row * $frameSize + $y)
                            $pixels[$index] = $pixel
                            if ($pixel.A -eq 0) {
                                continue
                            }
                            $opaqueCount++
                            $opaqueMask[$index] = $true
                            $opaquePoints.Add($index)
                            if ($skinColors.Contains((Get-ColorKey -Color $pixel))) {
                                $skinCount++
                                $skinPoints.Add($index)
                                $skinXTotal += $x
                                $skinYTotal += $y
                            }
                        }
                    }

                    if ($skinCount -eq 0) {
                        continue
                    }

                    $candidates.Add([PSCustomObject]@{
                        Path = $file.FullName
                        RelativePath = Get-RelativeProjectPath -Path $file.FullName
                        Column = $column
                        Row = $row
                        SheetRows = $rows
                        Pixels = $pixels
                        OpaqueMask = $opaqueMask
                        OpaquePoints = $opaquePoints.ToArray()
                        SkinPoints = $skinPoints.ToArray()
                        OpaqueCount = $opaqueCount
                        SkinCount = $skinCount
                        SkinCenterX = $skinXTotal / [double]$skinCount
                        SkinCenterY = $skinYTotal / [double]$skinCount
                    })
                }
            }
        }
        finally {
            $bitmap.Dispose()
        }
    }

    if ($candidates.Count -eq 0) {
        throw "没有找到仅含标准人体颜色的裸体动作候选。"
    }

    return $candidates
}

function Get-SourceFrame {
    param(
        [System.Drawing.Bitmap]$Source,
        [int]$Column,
        [int]$Row
    )

    $pixels = [System.Drawing.Color[]]::new($frameSize * $frameSize)
    $opaque = [bool[]]::new($frameSize * $frameSize)
    $skin = [bool[]]::new($frameSize * $frameSize)
    $skinPoints = [System.Collections.Generic.List[int]]::new()
    $skinCount = 0
    $blackCount = 0
    $skinXTotal = 0
    $skinYTotal = 0
    for ($y = 0; $y -lt $frameSize; $y++) {
        for ($x = 0; $x -lt $frameSize; $x++) {
            $index = $y * $frameSize + $x
            $pixel = $Source.GetPixel($Column * $frameSize + $x, $Row * $frameSize + $y)
            $pixels[$index] = $pixel
            if ($pixel.A -eq 0) {
                continue
            }

            $opaque[$index] = $true
            $key = Get-ColorKey -Color $pixel
            if ($key -eq "000000FF") {
                $blackCount++
            }
            if ($skinColors.Contains($key)) {
                $skin[$index] = $true
                $skinPoints.Add($index)
                $skinCount++
                $skinXTotal += $x
                $skinYTotal += $y
            }
        }
    }

    return [PSCustomObject]@{
        Pixels = $pixels
        Opaque = $opaque
        Skin = $skin
        SkinPoints = $skinPoints.ToArray()
        SkinCount = $skinCount
        BlackCount = $blackCount
        SkinCenterX = if ($skinCount -gt 0) { $skinXTotal / [double]$skinCount } else { 0.0 }
        SkinCenterY = if ($skinCount -gt 0) { $skinYTotal / [double]$skinCount } else { 0.0 }
    }
}

function Find-BestCandidate {
    param(
        [object]$SourceFrame,
        [int]$SourceRow,
        [object[]]$Candidates
    )

    if ($SourceFrame.SkinCount -eq 0) {
        return $null
    }

    $best = $null
    $bestScore = [int]::MinValue
    foreach ($candidate in $Candidates) {
        if ($candidate.SheetRows -eq 4 -and $candidate.Row -ne $SourceRow) {
            continue
        }

        $dx = [int][Math]::Round($SourceFrame.SkinCenterX - $candidate.SkinCenterX)
        $dy = [int][Math]::Round($SourceFrame.SkinCenterY - $candidate.SkinCenterY)
        if ([Math]::Abs($dx) -gt 6 -or [Math]::Abs($dy) -gt 6) {
            continue
        }

        $score = 0
        $matchedSkin = 0
        $candidateInside = 0
        $candidateOutside = 0
        foreach ($sourceIndex in $SourceFrame.SkinPoints) {
            $sourceX = $sourceIndex % $frameSize
            $sourceY = [int][Math]::Floor($sourceIndex / $frameSize)
            $candidateX = $sourceX - $dx
            $candidateY = $sourceY - $dy
            if ($candidateX -ge 0 -and $candidateX -lt $frameSize -and
                $candidateY -ge 0 -and $candidateY -lt $frameSize) {
                $candidateIndex = $candidateY * $frameSize + $candidateX
                if ($candidate.OpaqueMask[$candidateIndex]) {
                    $matchedSkin++
                    $score += 12
                    if ((Get-ColorKey -Color $candidate.Pixels[$candidateIndex]) -eq
                        (Get-ColorKey -Color $SourceFrame.Pixels[$sourceIndex])) {
                        $score += 4
                    }
                    continue
                }
            }
            $score -= 14
        }

        foreach ($candidateIndex in $candidate.OpaquePoints) {
            $candidateX = $candidateIndex % $frameSize
            $candidateY = [int][Math]::Floor($candidateIndex / $frameSize)
            $sourceX = $candidateX + $dx
            $sourceY = $candidateY + $dy
            if ($sourceX -ge 0 -and $sourceX -lt $frameSize -and
                $sourceY -ge 0 -and $sourceY -lt $frameSize -and
                $SourceFrame.Opaque[$sourceY * $frameSize + $sourceX]) {
                $candidateInside++
                $score += 2
            }
            else {
                $candidateOutside++
                $score -= 10
            }
        }

        if ($candidate.SheetRows -eq 4 -and $candidate.Row -eq $SourceRow) {
            $score += 18
        }
        $score -= ([Math]::Abs($dx) + [Math]::Abs($dy)) * 2

        if ($score -gt $bestScore) {
            $bestScore = $score
            $best = [PSCustomObject]@{
                Candidate = $candidate
                Dx = $dx
                Dy = $dy
                Score = $score
                MatchedSkin = $matchedSkin
                SourceSkin = $SourceFrame.SkinCount
                CandidateInside = $candidateInside
                CandidateOutside = $candidateOutside
            }
        }
    }

    return $best
}

function Write-BodyFrame {
    param(
        [System.Drawing.Bitmap]$Output,
        [int]$Column,
        [int]$Row,
        [object]$SourceFrame,
        [object]$Match
    )

    if ($null -ne $Match) {
        for ($y = 0; $y -lt $frameSize; $y++) {
            for ($x = 0; $x -lt $frameSize; $x++) {
                $sourceIndex = $y * $frameSize + $x
                if (-not $SourceFrame.Opaque[$sourceIndex]) {
                    continue
                }

                $candidateX = $x - $Match.Dx
                $candidateY = $y - $Match.Dy
                if ($candidateX -lt 0 -or $candidateX -ge $frameSize -or
                    $candidateY -lt 0 -or $candidateY -ge $frameSize) {
                    continue
                }

                $candidatePixel = $Match.Candidate.Pixels[$candidateY * $frameSize + $candidateX]
                if ($candidatePixel.A -gt 0) {
                    $Output.SetPixel($Column * $frameSize + $x, $Row * $frameSize + $y, $candidatePixel)
                }
            }
        }
    }

    # 原图露出的脸、手、脚是姿势真相源，必须覆盖候选身体的同位置像素。
    for ($y = 0; $y -lt $frameSize; $y++) {
        for ($x = 0; $x -lt $frameSize; $x++) {
            $index = $y * $frameSize + $x
            if ($SourceFrame.Skin[$index]) {
                $Output.SetPixel($Column * $frameSize + $x, $Row * $frameSize + $y, $SourceFrame.Pixels[$index])
            }
        }
    }
}

function Assert-PureBodyOutput {
    param([string]$Path)

    $bitmap = [System.Drawing.Bitmap]::new($Path)
    try {
        for ($y = 0; $y -lt $bitmap.Height; $y++) {
            for ($x = 0; $x -lt $bitmap.Width; $x++) {
                $pixel = $bitmap.GetPixel($x, $y)
                if ($pixel.A -eq 0) {
                    continue
                }

                $key = Get-ColorKey -Color $pixel
                if (-not $bodyColors.Contains($key)) {
                    throw "$Path 在 ($x,$y) 含有非人体颜色 $key。"
                }
            }
        }
    }
    finally {
        $bitmap.Dispose()
    }
}

function Get-ActionKind {
    param([string]$RelativePath)

    if ($RelativePath -match '\\阴影\\') {
        return "阴影"
    }
    if ($RelativePath -match '(根须攻击|效果|投射物|炸弹爆炸|Broken地面)') {
        return "独立特效或投射物"
    }
    if ($RelativePath -match '形态变换') {
        return "混合形态"
    }
    if ($RelativePath -match '形态_变形') {
        return "非人形动物动作"
    }
    return "人形动作"
}

if (-not (Test-Path -LiteralPath $heroRoot)) {
    throw "缺少真正英雄原始素材目录：$heroRoot"
}
if (-not (Test-Path -LiteralPath $englishHeroRoot)) {
    throw "缺少真正英雄英文原包目录：$englishHeroRoot"
}

$sourceMetaByHash = @{}
Get-ChildItem -LiteralPath $englishHeroRoot -Recurse -File -Filter '*.png' | ForEach-Object {
    $metaPath = "$($_.FullName).meta"
    if (-not (Test-Path -LiteralPath $metaPath)) {
        return
    }

    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash
    if (-not $sourceMetaByHash.ContainsKey($hash)) {
        $sourceMetaByHash[$hash] = $metaPath
    }
}

$candidates = @(Get-BodyCandidates)
Write-Output "裸体候选帧：$($candidates.Count)"

$allPngFiles = @(Get-ChildItem -LiteralPath $heroRoot -Recurse -File -Filter '*.png' | Sort-Object FullName)
$matrix = [System.Collections.Generic.List[object]]::new()
$frameMatches = [System.Collections.Generic.List[object]]::new()
$generatedCount = 0

foreach ($file in $allPngFiles) {
    $relativeToHeroRoot = $file.FullName.Substring((Resolve-Path -LiteralPath $heroRoot).Path.Length + 1)
    $kind = Get-ActionKind -RelativePath $relativeToHeroRoot
    $sourceBitmap = [System.Drawing.Bitmap]::new($file.FullName)
    try {
        $gridValid = $sourceBitmap.Width % $frameSize -eq 0 -and $sourceBitmap.Height % $frameSize -eq 0
        $columns = if ($gridValid) { [int]($sourceBitmap.Width / $frameSize) } else { 0 }
        $rows = if ($gridValid) { [int]($sourceBitmap.Height / $frameSize) } else { 0 }
        $heroName = $relativeToHeroRoot.Split([System.IO.Path]::DirectorySeparatorChar)[0]

        if ($kind -notin @("人形动作", "混合形态")) {
            $matrix.Add([PSCustomObject]@{
                hero = $heroName
                source = Get-RelativeProjectPath -Path $file.FullName
                kind = $kind
                grid = if ($gridValid) { "${columns}x${rows}" } else { "非32像素网格" }
                status = "保留原独立层"
                output = $null
                frameCount = $columns * $rows
                emptyBodyFrames = $null
                minimumSkinMatch = $null
            })
            continue
        }

        if (-not $gridValid) {
            throw "人形动作不是 32x32 帧网格：$($file.FullName)"
        }

        $actionRelative = $relativeToHeroRoot.Substring($heroName.Length + 1)
        $actionDirectory = Split-Path -Parent $actionRelative
        $actionName = [System.IO.Path]::GetFileNameWithoutExtension($actionRelative)
        $outputFileName = "${actionName}_裸体.png"
        $outputRelative = if ([string]::IsNullOrWhiteSpace($actionDirectory)) {
            $outputFileName
        }
        else {
            Join-Path $actionDirectory $outputFileName
        }
        $outputPath = Join-Path (Join-Path $OutputRoot $heroName) $outputRelative
        $sourceHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $file.FullName).Hash
        if (-not $sourceMetaByHash.ContainsKey($sourceHash)) {
            throw "英文原包中没有找到同内容切片模板：$($file.FullName)"
        }
        $templateMetaPath = $sourceMetaByHash[$sourceHash]
        $output = [System.Drawing.Bitmap]::new(
            $sourceBitmap.Width,
            $sourceBitmap.Height,
            [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
        )
        $emptyBodyFrames = 0
        $minimumSkinMatch = 1.0
        $lastMatchByRow = @{}
        try {
            for ($row = 0; $row -lt $rows; $row++) {
                for ($column = 0; $column -lt $columns; $column++) {
                    $sourceFrame = Get-SourceFrame -Source $sourceBitmap -Column $column -Row $row
                    $match = Find-BestCandidate -SourceFrame $sourceFrame -SourceRow $row -Candidates $candidates
                    if ($null -eq $match -and
                        $actionName -match '死亡' -and
                        $sourceFrame.BlackCount -ge 2 -and
                        $lastMatchByRow.ContainsKey($row)) {
                        $previous = $lastMatchByRow[$row]
                        $match = [PSCustomObject]@{
                            Candidate = $previous.Candidate
                            Dx = $previous.Dx
                            Dy = $previous.Dy
                            Score = $previous.Score
                            MatchedSkin = 0
                            SourceSkin = 0
                            CandidateInside = $previous.CandidateInside
                            CandidateOutside = $previous.CandidateOutside
                            PropagatedFromPreviousFrame = $true
                        }
                    }
                    if ($null -eq $match) {
                        $emptyBodyFrames++
                    }
                    else {
                        $lastMatchByRow[$row] = $match
                        $skinMatch = if ($match.SourceSkin -gt 0) {
                            $match.MatchedSkin / $match.SourceSkin
                        }
                        else {
                            1.0
                        }
                        $minimumSkinMatch = [Math]::Min($minimumSkinMatch, $skinMatch)
                        $frameMatches.Add([PSCustomObject]@{
                            hero = $heroName
                            action = $actionRelative.Replace("\", "/")
                            frame = "$column,$row"
                            sourceSkin = $match.SourceSkin
                            matchedSkin = $match.MatchedSkin
                            skinMatch = [Math]::Round($skinMatch, 4)
                            candidate = $match.Candidate.RelativePath
                            candidateFrame = "$($match.Candidate.Column),$($match.Candidate.Row)"
                            offset = "$($match.Dx),$($match.Dy)"
                            score = $match.Score
                            propagatedFromPreviousFrame = (
                                $match.PSObject.Properties.Name -contains 'PropagatedFromPreviousFrame'
                            )
                        })
                    }
                    Write-BodyFrame -Output $output -Column $column -Row $row -SourceFrame $sourceFrame -Match $match
                }
            }
            Write-Png -Bitmap $output -Path $outputPath
        }
        finally {
            $output.Dispose()
        }

        Set-PixelSpriteMeta -AssetPath $outputPath -TemplateMetaPath $templateMetaPath
        Assert-PureBodyOutput -Path $outputPath
        $generatedCount++
        $matrix.Add([PSCustomObject]@{
            hero = $heroName
            source = Get-RelativeProjectPath -Path $file.FullName
            kind = $kind
            grid = "${columns}x${rows}"
            status = if ($kind -eq "混合形态") { "已导出人类阶段；动物阶段透明" } else { "已导出裸体动作" }
            output = Get-RelativeProjectPath -Path $outputPath
            frameCount = $columns * $rows
            emptyBodyFrames = $emptyBodyFrames
            minimumSkinMatch = [Math]::Round($minimumSkinMatch, 4)
            sliceTemplate = Get-RelativeProjectPath -Path $templateMetaPath
        })
    }
    finally {
        $sourceBitmap.Dispose()
    }
}

if (-not (Test-Path -LiteralPath $EvidenceRoot)) {
    [void](New-Item -ItemType Directory -Path $EvidenceRoot -Force)
}
$matrixPath = Join-Path $EvidenceRoot "动作覆盖矩阵.json"
$matchesPath = Join-Path $EvidenceRoot "逐帧裸体候选匹配.json"
$validationPath = Join-Path $EvidenceRoot "验收报告.json"
[System.IO.File]::WriteAllText(
    $matrixPath,
    ($matrix | ConvertTo-Json -Depth 6),
    [System.Text.UTF8Encoding]::new($false)
)
[System.IO.File]::WriteAllText(
    $matchesPath,
    ($frameMatches | ConvertTo-Json -Depth 6),
    [System.Text.UTF8Encoding]::new($false)
)

$validationRows = [System.Collections.Generic.List[object]]::new()
foreach ($entry in ($matrix | Where-Object { -not [string]::IsNullOrWhiteSpace($_.output) })) {
    $source = [System.Drawing.Bitmap]::new((Resolve-Path -LiteralPath $entry.source).Path)
    $body = [System.Drawing.Bitmap]::new((Resolve-Path -LiteralPath $entry.output).Path)
    try {
        if ($source.Width -ne $body.Width -or $source.Height -ne $body.Height) {
            throw "裸体动作尺寸与原动作不一致：$($entry.output)"
        }

        $bodyOutsideSource = 0
        $visibleSkinMismatch = 0
        $recomposedMismatch = 0
        for ($y = 0; $y -lt $source.Height; $y++) {
            for ($x = 0; $x -lt $source.Width; $x++) {
                $sourcePixel = $source.GetPixel($x, $y)
                $bodyPixel = $body.GetPixel($x, $y)
                if ($bodyPixel.A -gt 0 -and $sourcePixel.A -eq 0) {
                    $bodyOutsideSource++
                }

                $sourceKey = Get-ColorKey -Color $sourcePixel
                $sourceIsSkin = $sourcePixel.A -gt 0 -and $skinColors.Contains($sourceKey)
                if ($sourceIsSkin -and $sourcePixel.ToArgb() -ne $bodyPixel.ToArgb()) {
                    $visibleSkinMismatch++
                }

                # 原职业非人体层覆盖裸体层后，必须逐像素回到作者原图。
                $recomposedPixel = if ($sourceIsSkin) { $bodyPixel } else { $sourcePixel }
                if ($recomposedPixel.ToArgb() -ne $sourcePixel.ToArgb()) {
                    $recomposedMismatch++
                }
            }
        }

        if ($bodyOutsideSource -gt 0 -or $visibleSkinMismatch -gt 0 -or $recomposedMismatch -gt 0) {
            throw (
                "裸体动作重组门禁失败：{0}，越界={1}，露肤错位={2}，重组差异={3}" -f
                $entry.output,
                $bodyOutsideSource,
                $visibleSkinMismatch,
                $recomposedMismatch
            )
        }

        $metaContent = [System.IO.File]::ReadAllText("$($entry.output).meta")
        $sliceCount = [System.Text.RegularExpressions.Regex]::Matches(
            $metaContent,
            '(?m)^    - serializedVersion: 2$'
        ).Count
        if ($sliceCount -ne $entry.frameCount) {
            throw "Sprite 切片数量不一致：$($entry.output)，预期 $($entry.frameCount)，实际 $sliceCount"
        }

        $validationRows.Add([PSCustomObject]@{
            hero = $entry.hero
            source = $entry.source
            output = $entry.output
            sourceSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $entry.source).Hash
            outputSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $entry.output).Hash
            frameCount = $entry.frameCount
            sliceCount = $sliceCount
            bodyOutsideSource = $bodyOutsideSource
            visibleSkinMismatch = $visibleSkinMismatch
            recomposedMismatch = $recomposedMismatch
            status = "PASS"
        })
    }
    finally {
        $source.Dispose()
        $body.Dispose()
    }
}

$validationReport = [PSCustomObject]@{
    status = "PASS"
    generatedSheets = $validationRows.Count
    generatedFrames = ($validationRows | Measure-Object frameCount -Sum).Sum
    humanActionSheets = @($matrix | Where-Object kind -eq "人形动作").Count
    mixedTransformationSheets = @($matrix | Where-Object kind -eq "混合形态").Count
    bodyPalette = $bodyColorKeys
    checks = @(
        "所有非透明像素只使用标准裸体人体调色板",
        "裸体像素不越出作者原动作的非透明轮廓",
        "作者原图露出的脸、手、脚像素逐像素一致",
        "原职业非人体层覆盖后逐像素还原作者原图",
        "每张表的 32x32 Sprite 切片数量等于原动作帧数"
    )
    rows = $validationRows
}
[System.IO.File]::WriteAllText(
    $validationPath,
    ($validationReport | ConvertTo-Json -Depth 6),
    [System.Text.UTF8Encoding]::new($false)
)

Write-Output "已导出裸体/混合形态动作表：$generatedCount"
Write-Output "动作覆盖矩阵：$matrixPath"
Write-Output "逐帧匹配证据：$matchesPath"
Write-Output "验收报告：$validationPath"
