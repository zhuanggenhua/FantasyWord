param(
    [string]$OutputRoot = "Assets/Art/装备/真正英雄拆分",
    [string]$AppearanceOutputRoot = "Assets/Art/角色外观/真正英雄拆分"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

$frameSize = 32
$directions = @("SE", "SW", "NE", "NW")
$skinColors = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::OrdinalIgnoreCase
)
@(
    "DDB78FFF",
    "EEC39AFF",
    "FACBA6FF",
    "CDAC85FF",
    "BB9E79FF"
) | ForEach-Object { [void]$skinColors.Add($_) }

function Get-ColorKey {
    param([System.Drawing.Color]$Color)

    return "{0:X2}{1:X2}{2:X2}{3:X2}" -f $Color.R, $Color.G, $Color.B, $Color.A
}

function Test-InSet {
    param(
        [string]$Value,
        [string[]]$Set
    )

    return $Set -contains $Value
}

function New-EquipmentMask {
    param(
        [System.Drawing.Bitmap]$Source,
        [int]$RowIndex,
        [scriptblock]$SeedPredicate
    )

    $mask = New-Object 'bool[,]' $frameSize, $frameSize

    for ($y = 0; $y -lt $frameSize; $y++) {
        for ($x = 0; $x -lt $frameSize; $x++) {
            $color = $Source.GetPixel($x, $RowIndex * $frameSize + $y)
            if ($color.A -eq 0) {
                continue
            }

            $key = Get-ColorKey $color
            if ($key -eq "000000FF" -or $skinColors.Contains($key)) {
                continue
            }

            if (& $SeedPredicate $key $x $y) {
                $mask[$x, $y] = $true
            }
        }
    }

    # 装备彩色像素只负责确定归属，黑色像素按一像素邻域作为原作者描边补回。
    $outlinePixels = [System.Collections.Generic.List[object]]::new()
    for ($y = 0; $y -lt $frameSize; $y++) {
        for ($x = 0; $x -lt $frameSize; $x++) {
            $color = $Source.GetPixel($x, $RowIndex * $frameSize + $y)
            if ((Get-ColorKey $color) -ne "000000FF") {
                continue
            }

            $touchesEquipment = $false
            for ($dy = -1; $dy -le 1 -and -not $touchesEquipment; $dy++) {
                for ($dx = -1; $dx -le 1; $dx++) {
                    if ($dx -eq 0 -and $dy -eq 0) {
                        continue
                    }

                    $nx = $x + $dx
                    $ny = $y + $dy
                    if ($nx -ge 0 -and $nx -lt $frameSize -and
                        $ny -ge 0 -and $ny -lt $frameSize -and
                        $mask[$nx, $ny]) {
                        $touchesEquipment = $true
                        break
                    }
                }
            }

            if ($touchesEquipment) {
                $outlinePixels.Add(@($x, $y))
            }
        }
    }

    foreach ($pixel in $outlinePixels) {
        $mask[$pixel[0], $pixel[1]] = $true
    }

    return ,$mask
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

function Set-PixelSpriteMeta {
    param([string]$MetaPath)

    if (-not (Test-Path -LiteralPath $MetaPath)) {
        return $false
    }

    $content = [System.IO.File]::ReadAllText($MetaPath)
    $updated = $content
    $replacements = @(
        @('(?m)^    enableMipMap: \d+$', '    enableMipMap: 0'),
        @('(?m)^    filterMode: \d+$', '    filterMode: 0'),
        @('(?m)^    wrapU: \d+$', '    wrapU: 1'),
        @('(?m)^    wrapV: \d+$', '    wrapV: 1'),
        @('(?m)^    wrapW: \d+$', '    wrapW: 1'),
        @('(?m)^  nPOTScale: \d+$', '  nPOTScale: 0'),
        @('(?m)^  spriteMode: \d+$', '  spriteMode: 1'),
        @('(?m)^  spritePixelsToUnits: .+$', '  spritePixelsToUnits: 8'),
        @('(?m)^  alphaIsTransparency: \d+$', '  alphaIsTransparency: 1'),
        @('(?m)^  textureType: \d+$', '  textureType: 8')
    )

    foreach ($replacement in $replacements) {
        $updated = [System.Text.RegularExpressions.Regex]::Replace(
            $updated,
            $replacement[0],
            $replacement[1]
        )
    }

    $updated = [System.Text.RegularExpressions.Regex]::Replace(
        $updated,
        '(?ms)(^    buildTarget: DefaultTexturePlatform.*?^    textureCompression: )\d+$',
        '${1}0'
    )

    if ($updated -ne $content) {
        [System.IO.File]::WriteAllText(
            $MetaPath,
            $updated,
            [System.Text.UTF8Encoding]::new($false)
        )
    }

    return $true
}

function Export-EquipmentItem {
    param(
        [System.Drawing.Bitmap]$Source,
        [string]$HeroName,
        [string]$ItemName,
        [scriptblock]$SeedPredicate,
        [string]$Root = $OutputRoot
    )

    for ($row = 0; $row -lt $directions.Count; $row++) {
        $mask = New-EquipmentMask -Source $Source -RowIndex $row -SeedPredicate $SeedPredicate
        $output = [System.Drawing.Bitmap]::new(
            $frameSize,
            $frameSize,
            [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
        )

        try {
            for ($y = 0; $y -lt $frameSize; $y++) {
                for ($x = 0; $x -lt $frameSize; $x++) {
                    if ($mask[$x, $y]) {
                        $output.SetPixel($x, $y, $Source.GetPixel($x, $row * $frameSize + $y))
                    }
                }
            }

            $fileName = "{0}_{1}_{2}.png" -f $HeroName, $ItemName, $directions[$row]
            $path = Join-Path (Join-Path $Root $HeroName) $fileName
            Write-Png -Bitmap $output -Path $path
        }
        finally {
            $output.Dispose()
        }
    }
}

function Assert-ItemPalette {
    param(
        [string]$Root,
        [string]$HeroName,
        [string]$ItemName,
        [string[]]$AllowedColors
    )

    $allowed = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )
    [void]$allowed.Add("000000FF")
    foreach ($color in $AllowedColors) {
        [void]$allowed.Add($color)
    }

    $directory = Join-Path $Root $HeroName
    $files = @(Get-ChildItem -LiteralPath $directory -File -Filter ("{0}_{1}_*.png" -f $HeroName, $ItemName))
    if ($files.Count -ne 4) {
        throw "$HeroName/$ItemName 没有得到完整四向散件，实际数量：$($files.Count)"
    }

    foreach ($file in $files) {
        $bitmap = [System.Drawing.Bitmap]::FromFile($file.FullName)
        try {
            for ($y = 0; $y -lt $frameSize; $y++) {
                for ($x = 0; $x -lt $frameSize; $x++) {
                    $pixel = $bitmap.GetPixel($x, $y)
                    if ($pixel.A -eq 0) {
                        continue
                    }

                    $key = Get-ColorKey $pixel
                    if (-not $allowed.Contains($key)) {
                        throw "$($file.Name) 在 ($x,$y) 含有非装备颜色 $key。"
                    }
                }
            }
        }
        finally {
            $bitmap.Dispose()
        }
    }
}

$druidSource = "Assets/Art/英雄/迷你幻想_真正英雄_v1.0/迷你幻想_真正英雄_素材/德鲁伊/通用_动画/迷你幻想_真正英雄Druid待机.png"
$barbarianSource = "Assets/Art/英雄/迷你幻想_真正英雄_v1.0/迷你幻想_真正英雄_素材/野蛮人/通用_动画/迷你幻想_真正英雄Barbarian待机.png"
$rogueSource = "Assets/Art/英雄/迷你幻想_真正英雄_v1.0/迷你幻想_真正英雄_素材/游荡者/通用_动画/迷你幻想_真正英雄Rogue待机.png"

$sourcePaths = @($druidSource, $barbarianSource, $rogueSource)
foreach ($sourcePath in $sourcePaths) {
    if (-not (Test-Path -LiteralPath $sourcePath)) {
        throw "缺少真正英雄待机素材：$sourcePath"
    }
}

$druid = [System.Drawing.Bitmap]::FromFile((Resolve-Path -LiteralPath $druidSource))
$barbarian = [System.Drawing.Bitmap]::FromFile((Resolve-Path -LiteralPath $barbarianSource))
$rogue = [System.Drawing.Bitmap]::FromFile((Resolve-Path -LiteralPath $rogueSource))

try {
    foreach ($entry in @(
        @{ Name = "德鲁伊"; Bitmap = $druid },
        @{ Name = "野蛮人"; Bitmap = $barbarian },
        @{ Name = "游荡者"; Bitmap = $rogue }
    )) {
        if ($entry.Bitmap.Width -ne 512 -or $entry.Bitmap.Height -ne 128) {
            throw "$($entry.Name)待机图尺寸不是预期的 512x128。"
        }
    }

    Export-EquipmentItem -Source $druid -HeroName "德鲁伊" -ItemName "鹿角头饰" -SeedPredicate {
        param($key, $x, $y)
        return $y -le 12 -or ($y -eq 13 -and ($x -le 14 -or $x -ge 18))
    }
    $druidRobeColors = @(
        "0C4516FF",
        "378F47FF",
        "093A12FF",
        "052E0CFF",
        "2F873FFF",
        "852C2CFF",
        "511813FF",
        "AC5858FF"
    )
    Export-EquipmentItem -Source $druid -HeroName "德鲁伊" -ItemName "长袍" -SeedPredicate {
        param($key, $x, $y)
        return $y -ge 16 -and (Test-InSet -Value $key -Set $druidRobeColors)
    }

    Export-EquipmentItem -Source $barbarian -HeroName "野蛮人" -ItemName "角盔" -SeedPredicate {
        param($key, $x, $y)
        return $y -le 10 -and $x -le 18
    }
    $barbarianArmorColors = @(
        "979797FF",
        "7E7E7EFF",
        "6A6A6AFF"
    )
    Export-EquipmentItem -Source $barbarian -HeroName "野蛮人" -ItemName "护甲" -SeedPredicate {
        param($key, $x, $y)
        return $y -ge 11 -and (Test-InSet -Value $key -Set $barbarianArmorColors)
    }

    $rogueHairColors = @("D69428FF", "E6AB4BFF", "B17719FF")
    $rogueScarfColors = @("980101FF", "C60A0AFF", "EC4242FF")
    $rogueClothingColors = @("613822FF", "42302CFF", "67534EFF")

    Export-EquipmentItem -Source $rogue -HeroName "游荡者" -ItemName "头发" -Root $AppearanceOutputRoot -SeedPredicate {
        param($key, $x, $y)
        return Test-InSet -Value $key -Set $rogueHairColors
    }
    Export-EquipmentItem -Source $rogue -HeroName "游荡者" -ItemName "红色面巾" -SeedPredicate {
        param($key, $x, $y)
        return Test-InSet -Value $key -Set $rogueScarfColors
    }
    Export-EquipmentItem -Source $rogue -HeroName "游荡者" -ItemName "服装" -SeedPredicate {
        param($key, $x, $y)
        return (Test-InSet -Value $key -Set $rogueClothingColors) -or
            ($key -eq "9AA1A1FF" -and $x -le 16)
    }
}
finally {
    $druid.Dispose()
    $barbarian.Dispose()
    $rogue.Dispose()
}

$druidAntlerColors = @("835744FF", "9E7562FF", "BC9280FF", "C5BD92FF")
$barbarianHelmetColors = @(
    "6A6A6AFF",
    "7E7E7EFF",
    "979797FF",
    "C1C1C1FF",
    "D5C3A1FF",
    "E6D7BAFF",
    "FFFBF4FF"
)

Assert-ItemPalette -Root $OutputRoot -HeroName "德鲁伊" -ItemName "鹿角头饰" -AllowedColors $druidAntlerColors
Assert-ItemPalette -Root $OutputRoot -HeroName "德鲁伊" -ItemName "长袍" -AllowedColors $druidRobeColors
Assert-ItemPalette -Root $OutputRoot -HeroName "野蛮人" -ItemName "角盔" -AllowedColors $barbarianHelmetColors
Assert-ItemPalette -Root $OutputRoot -HeroName "野蛮人" -ItemName "护甲" -AllowedColors $barbarianArmorColors
Assert-ItemPalette -Root $OutputRoot -HeroName "游荡者" -ItemName "红色面巾" -AllowedColors $rogueScarfColors
Assert-ItemPalette -Root $OutputRoot -HeroName "游荡者" -ItemName "服装" -AllowedColors ($rogueClothingColors + "9AA1A1FF")
Assert-ItemPalette -Root $AppearanceOutputRoot -HeroName "游荡者" -ItemName "头发" -AllowedColors $rogueHairColors

$metaUpdatedCount = 0
$metaPendingCount = 0
foreach ($root in @($OutputRoot, $AppearanceOutputRoot)) {
    Get-ChildItem -LiteralPath $root -Recurse -File -Filter '*.png' | ForEach-Object {
        if (Set-PixelSpriteMeta -MetaPath ($_.FullName + '.meta')) {
            $metaUpdatedCount++
        }
        else {
            $metaPendingCount++
        }
    }
}

Write-Output "真正英雄装备散件已导出到：$OutputRoot"
Write-Output "真正英雄外观散件已导出到：$AppearanceOutputRoot"
Write-Output "已校准导入设置：$metaUpdatedCount；等待 Unity 生成 meta：$metaPendingCount"
