using System;
using System.Collections.Generic;
using System.Linq;
using UnityEditor;
using UnityEditor.U2D.Sprites;
using UnityEngine;

/// <summary>
/// MiniFantasy 像素素材导入审计和修复工具。
/// 默认只处理项目内 MiniFantasy 素材路径，不修改第三方包源码逻辑。
/// </summary>
public static class MiniFantasyPixelImportTool
{
    const string MenuRoot = "Tools/Equipment System/MiniFantasy Import/";
    const float MiniFantasyCharacterPixelsPerUnit = 8f;
    static readonly Vector2Int MiniFantasyCharacterFrameSize = new Vector2Int(32, 32);
    internal const string CreatureRoot = "Assets/Art/MINIFANTASY Creatures - Super Low Res 2D Pixel Art by Krishna Palacio";
    static readonly string[] EquipmentPixelRoots =
    {
        "Assets/Art/KrishnaPalacio/MINIFANTASY - Dungeon",
        "Assets/Art/KrishnaPalacio/MINIFANTASY - Farm",
        "Assets/Art/MINIFANTASY - Crafting and Professions I",
        "Assets/Art/MINIFANTASY Creatures - Super Low Res 2D Pixel Art by Krishna Palacio",
        "Assets/GameData/EquipmentSystem",
    };

    static readonly string[] AllMiniFantasyPixelRoots =
    {
        "Assets/Art/KrishnaPalacio",
        "Assets/Art/MINIFANTASY - Crafting and Professions I",
        "Assets/Art/MINIFANTASY Creatures - Super Low Res 2D Pixel Art by Krishna Palacio",
        "Assets/GameData/EquipmentSystem",
    };

    [MenuItem(MenuRoot + "审计 Creatures 像素导入设置")]
    public static void AuditCreaturesImportSettings()
    {
        string[] textureGuids = AssetDatabase.FindAssets("t:Texture2D", new[] { CreatureRoot });
        int checkedCount = 0;
        int mismatchCount = 0;

        for (int i = 0; i < textureGuids.Length; i++)
        {
            string path = AssetDatabase.GUIDToAssetPath(textureGuids[i]);
            if (!TryGetTextureImporter(path, out TextureImporter importer))
                continue;

            checkedCount++;
            if (!HasExpectedPixelSettings(importer, path, out string reason))
            {
                mismatchCount++;
                Debug.LogWarning(
                    $"MiniFantasy 像素导入设置不一致: {path} ({reason}) " +
                    $"filter={importer.filterMode}, ppu={importer.spritePixelsPerUnit}, " +
                    $"mode={importer.spriteImportMode}, mipmap={importer.mipmapEnabled}");
            }
        }

        Debug.Log($"MiniFantasy Creatures 导入设置审计完成: 检查 {checkedCount} 张贴图，发现 {mismatchCount} 个不一致。");
    }

    [MenuItem(MenuRoot + "应用 Creatures 像素导入设置", true)]
    public static bool ValidateApplyCreaturesImportSettings()
    {
        return true;
    }

    [MenuItem(MenuRoot + "应用 Creatures 像素导入设置")]
    public static void ApplyCreaturesImportSettings()
    {
        if (!ConfirmApplyPixelImportSettings("Creatures 素材"))
            return;

        var result = ApplyPixelImportSettings(new[] { CreatureRoot }, IsManagedCreatureTexture);
        Debug.Log(
            $"MiniFantasy Creatures 像素导入设置已应用: 检查 {result.checkedCount} 张贴图，修复 {result.changedCount} 张。");
    }

    [MenuItem(MenuRoot + "审计换装相关像素导入设置")]
    public static void AuditEquipmentImportSettings()
    {
        var result = AuditPixelImportSettings(EquipmentPixelRoots, IsEquipmentPixelTexture);
        Debug.Log(
            $"换装相关 MiniFantasy 像素导入设置审计完成: 检查 {result.checkedCount} 张贴图，发现 {result.mismatchCount} 个不一致。");
    }

    [MenuItem(MenuRoot + "应用换装相关像素导入设置")]
    public static void ApplyEquipmentImportSettings()
    {
        if (!ConfirmApplyPixelImportSettings("换装相关素材"))
            return;

        var result = ApplyPixelImportSettings(EquipmentPixelRoots, IsEquipmentPixelTexture);
        Debug.Log(
            $"换装相关 MiniFantasy 像素导入设置已应用: 检查 {result.checkedCount} 张贴图，修复 {result.changedCount} 张。");
    }

    /// <summary>
    /// 给自动化验证使用的无弹窗入口；范围仍只限换装相关素材。
    /// </summary>
    public static object ApplyEquipmentImportSettingsForAutomation()
    {
        var result = ApplyPixelImportSettings(EquipmentPixelRoots, IsEquipmentPixelTexture);
        return new
        {
            checkedCount = result.checkedCount,
            changedCount = result.changedCount,
        };
    }

    [MenuItem(MenuRoot + "审计全部 MiniFantasy 像素导入设置")]
    public static void AuditAllMiniFantasyImportSettings()
    {
        var result = AuditPixelImportSettings(AllMiniFantasyPixelRoots, IsMiniFantasyPixelTexture);
        Debug.Log(
            $"全部 MiniFantasy 像素导入设置审计完成: 检查 {result.checkedCount} 张贴图，发现 {result.mismatchCount} 个不一致。");
    }

    [MenuItem(MenuRoot + "应用全部 MiniFantasy 像素导入设置")]
    public static void ApplyAllMiniFantasyImportSettings()
    {
        if (!ConfirmApplyPixelImportSettings("全部 MiniFantasy 素材"))
            return;

        var result = ApplyPixelImportSettings(AllMiniFantasyPixelRoots, IsMiniFantasyPixelTexture);
        Debug.Log(
            $"全部 MiniFantasy 像素导入设置已应用: 检查 {result.checkedCount} 张贴图，修复 {result.changedCount} 张。");
    }

    internal static (int checkedCount, int mismatchCount) AuditPixelImportSettings(
        string[] roots,
        System.Func<string, bool> pathFilter)
    {
        int checkedCount = 0;
        int mismatchCount = 0;
        foreach (string path in EnumerateTexturePaths(roots, pathFilter))
        {
            if (!TryGetTextureImporter(path, out TextureImporter importer))
                continue;

            checkedCount++;
            if (IsGeneratedEquipmentUVMap(path))
            {
                if (!HasExpectedGeneratedUVMapSettings(importer, out string uvReason))
                {
                    mismatchCount++;
                    Debug.LogWarning(
                        $"换装 UV 数据贴图导入设置不一致: {path} ({uvReason}) "
                        + $"type={importer.textureType}, sRGB={importer.sRGBTexture}, "
                        + $"filter={importer.filterMode}, mode={importer.spriteImportMode}, "
                        + $"mipmap={importer.mipmapEnabled}, compression={importer.textureCompression}");
                }

                continue;
            }

            if (!HasExpectedPixelSettings(importer, path, out string reason))
            {
                mismatchCount++;
                Debug.LogWarning(
                    $"MiniFantasy 像素导入设置不一致: {path} ({reason}) "
                    + $"filter={importer.filterMode}, mode={importer.spriteImportMode}, "
                    + $"mipmap={importer.mipmapEnabled}, compression={importer.textureCompression}");
            }
        }

        return (checkedCount, mismatchCount);
    }

    internal static (int checkedCount, int changedCount) ApplyPixelImportSettings(
        string[] roots,
        System.Func<string, bool> pathFilter)
    {
        int checkedCount = 0;
        int changedCount = 0;
        foreach (string path in EnumerateTexturePaths(roots, pathFilter))
        {
            if (!TryGetTextureImporter(path, out TextureImporter importer))
                continue;

            checkedCount++;
            if (IsGeneratedEquipmentUVMap(path))
            {
                if (ApplyGeneratedUVMapSettings(importer))
                {
                    importer.SaveAndReimport();
                    changedCount++;
                }

                continue;
            }

            bool expectedReadable = IsGeneratedEquipmentTexture(path);
            bool changed = false;
            bool expectedMultiple = IsAnimationSheet(path);
            if (importer.textureType != TextureImporterType.Sprite)
            {
                importer.textureType = TextureImporterType.Sprite;
                changed = true;
            }

            if (importer.filterMode != FilterMode.Point)
            {
                importer.filterMode = FilterMode.Point;
                changed = true;
            }

            if (importer.mipmapEnabled)
            {
                importer.mipmapEnabled = false;
                changed = true;
            }

            if (importer.textureCompression != TextureImporterCompression.Uncompressed)
            {
                importer.textureCompression = TextureImporterCompression.Uncompressed;
                changed = true;
            }

            if (!importer.alphaIsTransparency)
            {
                importer.alphaIsTransparency = true;
                changed = true;
            }

            if (expectedReadable && !importer.isReadable)
            {
                importer.isReadable = true;
                changed = true;
            }

            if (EnsureFullRectSpriteMesh(importer))
                changed = true;

            if (expectedMultiple && importer.spriteImportMode != SpriteImportMode.Multiple)
            {
                importer.spriteImportMode = SpriteImportMode.Multiple;
                changed = true;
            }

            if (IsCharacterActionSheet(path)
                && Math.Abs(importer.spritePixelsPerUnit - MiniFantasyCharacterPixelsPerUnit) > 0.001f)
            {
                importer.spritePixelsPerUnit = MiniFantasyCharacterPixelsPerUnit;
                changed = true;
            }

            bool spriteRectsChanged = expectedMultiple
                && TryApplyFixedGridSpriteRects(importer, path);

            if (!changed && !spriteRectsChanged)
                continue;

            importer.SaveAndReimport();
            changedCount++;
        }

        AssetDatabase.SaveAssets();
        AssetDatabase.Refresh();
        return (checkedCount, changedCount);
    }

    static bool ApplyGeneratedUVMapSettings(TextureImporter importer)
    {
        bool changed = false;

        if (importer.textureType != TextureImporterType.Default)
        {
            importer.textureType = TextureImporterType.Default;
            changed = true;
        }

        if (importer.sRGBTexture)
        {
            importer.sRGBTexture = false;
            changed = true;
        }

        if (importer.filterMode != FilterMode.Point)
        {
            importer.filterMode = FilterMode.Point;
            changed = true;
        }

        if (importer.mipmapEnabled)
        {
            importer.mipmapEnabled = false;
            changed = true;
        }

        if (importer.textureCompression != TextureImporterCompression.Uncompressed)
        {
            importer.textureCompression = TextureImporterCompression.Uncompressed;
            changed = true;
        }

        if (importer.alphaIsTransparency)
        {
            importer.alphaIsTransparency = false;
            changed = true;
        }

        if (importer.wrapMode != TextureWrapMode.Clamp)
        {
            importer.wrapMode = TextureWrapMode.Clamp;
            changed = true;
        }

        return changed;
    }

    static bool HasExpectedGeneratedUVMapSettings(TextureImporter importer, out string reason)
    {
        reason = string.Empty;

        if (importer.textureType != TextureImporterType.Default)
            reason += "TextureType 不是 Default 数据贴图; ";
        if (importer.sRGBTexture)
            reason += "sRGB 未关闭; ";
        if (importer.filterMode != FilterMode.Point)
            reason += "FilterMode 不是 Point; ";
        if (importer.mipmapEnabled)
            reason += "MipMap 未关闭; ";
        if (importer.textureCompression != TextureImporterCompression.Uncompressed)
            reason += "压缩未关闭; ";
        if (importer.alphaIsTransparency)
            reason += "Alpha Transparency 不应启用; ";
        if (importer.wrapMode != TextureWrapMode.Clamp)
            reason += "WrapMode 不是 Clamp; ";

        return string.IsNullOrEmpty(reason);
    }

    static bool ConfirmApplyPixelImportSettings(string scopeDescription)
    {
        return EditorUtility.DisplayDialog(
            "确认修改 MiniFantasy 导入设置",
            $"即将批量修改 {scopeDescription} 的 TextureImporter 设置，并写入对应 .meta 文件。\n\n"
            + "建议先运行同目录下的“审计”菜单，确认数量和范围后再应用。\n"
            + "此操作不会修改第三方脚本，但会改变素材导入参数。",
            "确认应用",
            "取消");
    }

    internal static bool IsManagedCreatureTexture(string path)
    {
        return !string.IsNullOrWhiteSpace(path)
            && path.StartsWith(CreatureRoot, System.StringComparison.OrdinalIgnoreCase)
            && (path.EndsWith(".png", System.StringComparison.OrdinalIgnoreCase)
                || path.EndsWith(".psd", System.StringComparison.OrdinalIgnoreCase)
                || path.EndsWith(".jpg", System.StringComparison.OrdinalIgnoreCase)
                || path.EndsWith(".jpeg", System.StringComparison.OrdinalIgnoreCase));
    }

    static bool TryGetTextureImporter(string path, out TextureImporter importer)
    {
        importer = AssetImporter.GetAtPath(path) as TextureImporter;
        return importer != null;
    }

    internal static bool HasExpectedPixelSettings(
        TextureImporter importer,
        string path,
        out string reason)
    {
        bool expectedMultiple = IsAnimationSheet(path);
        reason = string.Empty;

        if (importer.textureType != TextureImporterType.Sprite)
            reason += "TextureType 不是 Sprite; ";
        if (importer.filterMode != FilterMode.Point)
            reason += "FilterMode 不是 Point; ";
        if (importer.mipmapEnabled)
            reason += "MipMap 未关闭; ";
        if (importer.textureCompression != TextureImporterCompression.Uncompressed)
            reason += "压缩未关闭; ";
        if (!importer.alphaIsTransparency)
            reason += "Alpha Transparency 未启用; ";
        if (IsGeneratedEquipmentTexture(path) && !importer.isReadable)
            reason += "项目侧生成装备贴图未启用 Read/Write; ";
        if (!IsFullRectSpriteMesh(importer))
            reason += "Sprite Mesh Type 不是 Full Rect; ";
        if (expectedMultiple && importer.spriteImportMode != SpriteImportMode.Multiple)
            reason += "动画总图不是 Multiple; ";

        return string.IsNullOrEmpty(reason);
    }

    static bool EnsureFullRectSpriteMesh(TextureImporter importer)
    {
        var settings = new TextureImporterSettings();
        importer.ReadTextureSettings(settings);
        if (settings.spriteMeshType == SpriteMeshType.FullRect)
            return false;

        settings.spriteMeshType = SpriteMeshType.FullRect;
        importer.SetTextureSettings(settings);
        return true;
    }

    static bool IsFullRectSpriteMesh(TextureImporter importer)
    {
        var settings = new TextureImporterSettings();
        importer.ReadTextureSettings(settings);
        return settings.spriteMeshType == SpriteMeshType.FullRect;
    }

    static bool TryApplyFixedGridSpriteRects(TextureImporter importer, string path)
    {
        if (importer == null || !IsCharacterActionSheet(path))
            return false;

        Texture2D texture = AssetDatabase.LoadAssetAtPath<Texture2D>(path);
        if (texture == null
            || texture.width < MiniFantasyCharacterFrameSize.x
            || texture.height < MiniFantasyCharacterFrameSize.y)
        {
            return false;
        }

        int columns = texture.width / MiniFantasyCharacterFrameSize.x;
        int rows = texture.height / MiniFantasyCharacterFrameSize.y;
        if (columns <= 0 || rows <= 0)
            return false;

        var factory = new SpriteDataProviderFactories();
        factory.Init();
        ISpriteEditorDataProvider dataProvider = factory.GetSpriteEditorDataProviderFromObject(importer);
        if (dataProvider == null)
            return false;

        dataProvider.InitSpriteEditorDataProvider();

        SpriteRect[] currentRects = dataProvider.GetSpriteRects();
        bool alreadyFixedGrid = currentRects != null
            && currentRects.Length == columns * rows
            && currentRects.All(rect =>
                Mathf.Approximately(rect.rect.width, MiniFantasyCharacterFrameSize.x)
                && Mathf.Approximately(rect.rect.height, MiniFantasyCharacterFrameSize.y));
        if (alreadyFixedGrid)
            return false;

        string baseName = System.IO.Path.GetFileNameWithoutExtension(path);
        var spriteRects = new List<SpriteRect>(columns * rows);
        var nameFileIdPairs = new List<SpriteNameFileIdPair>(columns * rows);
        for (int row = 0; row < rows; row++)
        {
            for (int column = 0; column < columns; column++)
            {
                string spriteName = $"{baseName}_{row}_{column:00}";
                GUID spriteId = GUID.Generate();
                var spriteRect = new SpriteRect
                {
                    name = spriteName,
                    spriteID = spriteId,
                    rect = new Rect(
                        column * MiniFantasyCharacterFrameSize.x,
                        texture.height - ((row + 1) * MiniFantasyCharacterFrameSize.y),
                        MiniFantasyCharacterFrameSize.x,
                        MiniFantasyCharacterFrameSize.y),
                    alignment = SpriteAlignment.Center,
                    pivot = new Vector2(0.5f, 0.5f),
                    border = Vector4.zero,
                };
                spriteRects.Add(spriteRect);
                nameFileIdPairs.Add(new SpriteNameFileIdPair(spriteName, spriteId));
            }
        }

        dataProvider.SetSpriteRects(spriteRects.ToArray());
        ISpriteNameFileIdDataProvider nameFileIdDataProvider =
            dataProvider.GetDataProvider<ISpriteNameFileIdDataProvider>();
        nameFileIdDataProvider?.SetNameFileIdPairs(nameFileIdPairs);
        dataProvider.Apply();
        return true;
    }

    static bool IsAnimationSheet(string path)
    {
        string fileName = System.IO.Path.GetFileName(path);
        return fileName.EndsWith("Animations.png", System.StringComparison.OrdinalIgnoreCase)
            || fileName.EndsWith("BaseAnimations.png", System.StringComparison.OrdinalIgnoreCase)
            || IsCharacterActionSheet(path);
    }

    static bool IsCharacterActionSheet(string path)
    {
        if (string.IsNullOrWhiteSpace(path))
            return false;

        string normalized = path.Replace('\\', '/');
        string fileName = System.IO.Path.GetFileNameWithoutExtension(normalized);
        return normalized.IndexOf("/Sprites/Animations/", StringComparison.OrdinalIgnoreCase) >= 0
            || normalized.IndexOf("/Sprites/Humanoids/", StringComparison.OrdinalIgnoreCase) >= 0
            || normalized.IndexOf("/Sprites/Crafting Professions/", StringComparison.OrdinalIgnoreCase) >= 0
            || normalized.IndexOf("/Sprites/Gathering Professions/", StringComparison.OrdinalIgnoreCase) >= 0
            || fileName.StartsWith("Human_", StringComparison.OrdinalIgnoreCase)
            || fileName.StartsWith("Elf_", StringComparison.OrdinalIgnoreCase)
            || fileName.StartsWith("Dwarf_", StringComparison.OrdinalIgnoreCase)
            || fileName.StartsWith("Goblin_", StringComparison.OrdinalIgnoreCase)
            || fileName.StartsWith("Halfling_", StringComparison.OrdinalIgnoreCase)
            || fileName.StartsWith("Orc_", StringComparison.OrdinalIgnoreCase)
            || fileName.StartsWith("Minifantasy_Creatures", StringComparison.OrdinalIgnoreCase);
    }

    static IEnumerable<string> EnumerateTexturePaths(
        string[] roots,
        System.Func<string, bool> pathFilter)
    {
        string[] textureGuids = AssetDatabase.FindAssets("t:Texture2D", roots);
        foreach (string guid in textureGuids)
        {
            string path = AssetDatabase.GUIDToAssetPath(guid);
            if (pathFilter == null || pathFilter(path))
                yield return path;
        }
    }

    static bool IsEquipmentPixelTexture(string path)
    {
        if (string.IsNullOrWhiteSpace(path))
            return false;

        string normalized = path.Replace('\\', '/');
        if (!(normalized.EndsWith(".png", StringComparison.OrdinalIgnoreCase)
              || normalized.EndsWith(".psd", StringComparison.OrdinalIgnoreCase)
              || normalized.EndsWith(".jpg", StringComparison.OrdinalIgnoreCase)
              || normalized.EndsWith(".jpeg", StringComparison.OrdinalIgnoreCase)
              || normalized.EndsWith(".gif", StringComparison.OrdinalIgnoreCase)))
        {
            return false;
        }

        if (normalized.StartsWith("Assets/GameData/EquipmentSystem/", StringComparison.OrdinalIgnoreCase))
            return true;

        return normalized.IndexOf("/Sprites/Animations/Human/", StringComparison.OrdinalIgnoreCase) >= 0
            || normalized.IndexOf("/Sprites/Animations/Orc/", StringComparison.OrdinalIgnoreCase) >= 0
            || normalized.IndexOf("/Sprites/Humanoids/", StringComparison.OrdinalIgnoreCase) >= 0
            || normalized.IndexOf("/Sprites/Crafting Professions/", StringComparison.OrdinalIgnoreCase) >= 0
            || normalized.IndexOf("/Sprites/Gathering Professions/", StringComparison.OrdinalIgnoreCase) >= 0
            || normalized.IndexOf("/Sprites/Craftable Items Icons/", StringComparison.OrdinalIgnoreCase) >= 0
            || normalized.IndexOf("/Sprites/Miscellany/", StringComparison.OrdinalIgnoreCase) >= 0
            || normalized.IndexOf("/Sprites/FarmingActions/", StringComparison.OrdinalIgnoreCase) >= 0
            || normalized.IndexOf("/Sprites/Farm_Animals/", StringComparison.OrdinalIgnoreCase) >= 0;
    }

    static bool IsGeneratedEquipmentUVMap(string path)
    {
        if (string.IsNullOrWhiteSpace(path))
            return false;

        string normalized = path.Replace('\\', '/');
        return normalized.StartsWith("Assets/GameData/EquipmentSystem/GeneratedUV/", StringComparison.OrdinalIgnoreCase)
            && normalized.EndsWith(".png", StringComparison.OrdinalIgnoreCase)
            && (normalized.EndsWith("_BodyUV.png", StringComparison.OrdinalIgnoreCase)
                || normalized.EndsWith("_HeadUV.png", StringComparison.OrdinalIgnoreCase));
    }

    static bool IsGeneratedEquipmentTexture(string path)
    {
        if (string.IsNullOrWhiteSpace(path))
            return false;

        string normalized = path.Replace('\\', '/');
        return normalized.StartsWith("Assets/GameData/EquipmentSystem/Equip/Generated/", StringComparison.OrdinalIgnoreCase)
            && normalized.EndsWith(".png", StringComparison.OrdinalIgnoreCase);
    }

    static bool IsMiniFantasyPixelTexture(string path)
    {
        if (string.IsNullOrWhiteSpace(path))
            return false;

        string normalized = path.Replace('\\', '/');
        if (!(normalized.EndsWith(".png", StringComparison.OrdinalIgnoreCase)
              || normalized.EndsWith(".psd", StringComparison.OrdinalIgnoreCase)
              || normalized.EndsWith(".jpg", StringComparison.OrdinalIgnoreCase)
              || normalized.EndsWith(".jpeg", StringComparison.OrdinalIgnoreCase)
              || normalized.EndsWith(".gif", StringComparison.OrdinalIgnoreCase)))
        {
            return false;
        }

        return normalized.StartsWith("Assets/Art/KrishnaPalacio/MINIFANTASY", StringComparison.OrdinalIgnoreCase)
            || normalized.StartsWith("Assets/Art/MINIFANTASY - Crafting and Professions I/", StringComparison.OrdinalIgnoreCase)
            || normalized.StartsWith("Assets/Art/MINIFANTASY Creatures - Super Low Res 2D Pixel Art by Krishna Palacio/", StringComparison.OrdinalIgnoreCase)
            || normalized.StartsWith("Assets/GameData/EquipmentSystem/", StringComparison.OrdinalIgnoreCase);
    }
}

/// <summary>
/// MiniFantasy 像素导入设置只允许通过上面的菜单手动审计或应用。
/// 不注册 AssetPostprocessor，避免 AssetDatabase.Refresh 时自动重写第三方素材 .meta。
/// </summary>
public sealed class MiniFantasyPixelImportPolicyMarker
{
}
