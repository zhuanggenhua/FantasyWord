using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEngine;

/// <summary>
/// 从 MiniFantasy 人形单动作素材同步工作台角色的独立 CharacterFrameData。
/// 这里只建立项目侧数据入口和动作贴图引用，不修改第三方素材本体，也不决定角色间复用策略。
/// </summary>
public static class MiniFantasyHumanoidFrameDataSyncTool
{
    const string HumanoidSpriteRoot =
        "Assets/Art/MINIFANTASY Creatures - Super Low Res 2D Pixel Art by Krishna Palacio/Sprites/Humanoids";
    const string FrameDataRoot = "Assets/GameData/EquipmentSystem/FrameData";
    const string CatalogPath = "Assets/GameData/EquipmentSystem/Data/Workbench/换装工作台目录.asset";
    const string AnimationDatabasePath =
        "Assets/GameData/EquipmentSystem/AnimationType/AnimationTypeDatabase.asset";
    const string ProfessionSpriteRoot =
        "Assets/Art/MINIFANTASY - Crafting and Professions I/Sprites";
    const string KrishnaHumanoidSpriteRoot =
        "Assets/Art/KrishnaPalacio/MINIFANTASY Creatures - Super Low Res 2D Pixel Art by Krishna Palacio/Sprites/Humanoids";

    static readonly CharacterSource[] CharacterSources =
    {
        new("人类", "人类帧数据", "Human/Human", "Human"),
        new("精灵", "精灵帧数据", "Elf", "Elf"),
        new("矮人", "矮人帧数据", "Dwarf/Dwarf", "Dwarf"),
        new("兽人", "兽人帧数据", "Orc/Orc", "Orc"),
        new("地精", "地精帧数据", "Goblin", "Goblin"),
    };

    [MenuItem("Tools/Equipment System/MiniFantasy Import/同步人形工作台帧数据")]
    public static void SyncWorkbenchHumanoidFrameData()
    {
        var database = AssetDatabase.LoadAssetAtPath<AnimationTypeDatabase>(AnimationDatabasePath);
        var catalog = AssetDatabase.LoadAssetAtPath<EquipmentWorkbenchCatalog>(CatalogPath);
        if (database == null || catalog == null)
        {
            Debug.LogError("[MiniFantasyHumanoidFrameDataSyncTool] 缺少动作类型库或换装工作台目录。");
            return;
        }

        EnsureFolder(FrameDataRoot);

        Dictionary<string, CharacterFrameData> frameDataByDisplayName = new Dictionary<string, CharacterFrameData>();
        List<object> report = new List<object>();
        foreach (CharacterSource source in CharacterSources)
        {
            CharacterFrameData frameData = LoadOrCreateFrameData(source.AssetName);
            SyncCharacterActions(frameData, database, source, out int actionCount, out string[] actions);
            frameDataByDisplayName[source.DisplayName] = frameData;
            report.Add(new { source.DisplayName, frameData = AssetDatabase.GetAssetPath(frameData), actionCount, actions });
        }

        BindCatalogFrameData(catalog, frameDataByDisplayName);

        AssetDatabase.SaveAssets();
        AssetDatabase.Refresh();

        Debug.Log(
            "[MiniFantasyHumanoidFrameDataSyncTool] 人形工作台帧数据同步完成：\n"
            + string.Join("\n", report.Select(row => JsonUtility.ToJson(new SerializableReportRow(row)))));
    }

    static CharacterFrameData LoadOrCreateFrameData(string assetName)
    {
        string assetPath = $"{FrameDataRoot}/{assetName}.asset";
        CharacterFrameData frameData = AssetDatabase.LoadAssetAtPath<CharacterFrameData>(assetPath);
        if (frameData != null)
            return frameData;

        frameData = ScriptableObject.CreateInstance<CharacterFrameData>();
        frameData.name = assetName;
        AssetDatabase.CreateAsset(frameData, assetPath);
        return frameData;
    }

    static void SyncCharacterActions(
        CharacterFrameData frameData,
        AnimationTypeDatabase database,
        CharacterSource source,
        out int actionCount,
        out string[] actionNames)
    {
        frameData.animDatabase = database;

        Dictionary<string, Texture2D> actionTextures = FindActionTextures(source);
        HashSet<string> desiredActions = new HashSet<string>(actionTextures.Keys, StringComparer.Ordinal);
        frameData.animations.RemoveAll(animation =>
            animation == null ||
            animation.animationType == null ||
            !desiredActions.Contains(animation.animationType.name));

        foreach (KeyValuePair<string, Texture2D> pair in actionTextures.OrderBy(pair => pair.Key))
        {
            AnimationTypeItem item = database.GetByKey(pair.Key);
            if (item == null)
                continue;

            AnimationData animation = frameData.GetOrCreateAnimation(item);
            Texture2D sheet = pair.Value;
            animation.spritesheet = sheet;
            animation.frameSize = new Vector2Int(32, 32);
            animation.framesPerRow = Mathf.Max(1, sheet.width / animation.frameSize.x);
            animation.rowCount = Mathf.Max(1, sheet.height / animation.frameSize.y);
            EnsureBasicFrames(animation);
        }

        FrameDataEditorTools.FixAllFramesSpriteFacing(frameData);
        EditorUtility.SetDirty(frameData);

        actionNames = frameData.animations
            .Where(animation => animation?.animationType != null)
            .Select(animation => animation.animationType.name)
            .OrderBy(name => name)
            .ToArray();
        actionCount = actionNames.Length;
    }

    static Dictionary<string, Texture2D> FindActionTextures(CharacterSource source)
    {
        Dictionary<string, Texture2D> results = new Dictionary<string, Texture2D>(StringComparer.Ordinal);
        string[] searchFolders = ResolveCharacterSearchFolders(source);

        string[] guids = AssetDatabase.FindAssets("t:Texture2D", searchFolders);
        foreach (string guid in guids)
        {
            string path = AssetDatabase.GUIDToAssetPath(guid);
            if (path.IndexOf("_Shadows", StringComparison.OrdinalIgnoreCase) >= 0)
                continue;

            string fileName = Path.GetFileNameWithoutExtension(path);
            if (!fileName.Contains(source.FileToken, StringComparison.OrdinalIgnoreCase))
                continue;

            string action = ExtractAction(fileName, source.FileToken);
            if (string.IsNullOrEmpty(action) || results.ContainsKey(action))
                continue;

            Texture2D texture = AssetDatabase.LoadAssetAtPath<Texture2D>(path);
            if (texture != null)
                results.Add(action, texture);
        }

        AddSharedProfessionActionTextures(results, source.FileToken);

        return results;
    }

    static string[] ResolveCharacterSearchFolders(CharacterSource source)
    {
        List<string> folders = new List<string>();
        AddValidFolder(folders, source.Folder);
        AddValidFolder(folders, $"{HumanoidSpriteRoot}/{source.Folder}");
        AddValidFolder(folders, $"{KrishnaHumanoidSpriteRoot}/{source.Folder}");

        if (folders.Count == 0)
        {
            AddValidFolder(folders, HumanoidSpriteRoot);
            AddValidFolder(folders, KrishnaHumanoidSpriteRoot);
        }

        return folders.Count > 0 ? folders.ToArray() : new[] { HumanoidSpriteRoot };
    }

    static void AddValidFolder(ICollection<string> folders, string folder)
    {
        if (string.IsNullOrWhiteSpace(folder)
            || !AssetDatabase.IsValidFolder(folder)
            || folders.Contains(folder))
        {
            return;
        }

        folders.Add(folder);
    }

    static void AddSharedProfessionActionTextures(
        IDictionary<string, Texture2D> results,
        string fileToken)
    {
        if (results == null || string.IsNullOrWhiteSpace(fileToken))
            return;
        if (!AssetDatabase.IsValidFolder(ProfessionSpriteRoot))
            return;

        string[] guids = AssetDatabase.FindAssets("t:Texture2D", new[] { ProfessionSpriteRoot });
        foreach (string guid in guids)
        {
            string path = AssetDatabase.GUIDToAssetPath(guid);
            string normalized = path.Replace('\\', '/');
            if (normalized.IndexOf("/Characters/", StringComparison.OrdinalIgnoreCase) < 0
                && normalized.IndexOf("/Character/", StringComparison.OrdinalIgnoreCase) < 0)
            {
                continue;
            }

            string fileName = Path.GetFileNameWithoutExtension(path);
            if (!fileName.StartsWith(fileToken + "_", StringComparison.OrdinalIgnoreCase))
                continue;

            string action = ExtractAction(fileName, fileToken);
            if (string.IsNullOrEmpty(action) || results.ContainsKey(action))
                continue;

            Texture2D texture = AssetDatabase.LoadAssetAtPath<Texture2D>(path);
            if (texture != null)
                results.Add(action, texture);
        }
    }

    static string ExtractAction(string fileName, string fileToken)
    {
        if (string.IsNullOrWhiteSpace(fileName))
            return null;

        if (TryGetExplicitAction(fileName, fileToken, out string explicitAction))
            return explicitAction;

        foreach (string suffix in DirectionSuffixes)
        {
            if (fileName.EndsWith(suffix, StringComparison.OrdinalIgnoreCase))
            {
                fileName = fileName.Substring(0, fileName.Length - suffix.Length);
                break;
            }
        }

        string action = fileName;
        if (!string.IsNullOrWhiteSpace(fileToken)
            && action.StartsWith(fileToken + "_", StringComparison.OrdinalIgnoreCase))
        {
            action = action.Substring(fileToken.Length + 1);
        }

        action = StripKnownMiniFantasyPrefix(action);
        action = CanonicalizeActionName(action);
        return IsPlayerBodyActionKey(action) ? action : null;
    }

    static bool TryGetExplicitAction(string fileName, string fileToken, out string action)
    {
        action = null;
        if (string.IsNullOrWhiteSpace(fileName)
            || string.IsNullOrWhiteSpace(fileToken))
        {
            return false;
        }

        if (string.Equals(fileToken, "Human", StringComparison.OrdinalIgnoreCase)
            && string.Equals(fileName, "Slash_Character_human", StringComparison.OrdinalIgnoreCase))
        {
            action = "SlashAttack";
            return true;
        }

        return false;
    }

    static string StripKnownMiniFantasyPrefix(string value)
    {
        if (string.IsNullOrWhiteSpace(value))
            return value;

        const string packPrefix = "Minifantasy_Creatures";
        if (value.StartsWith(packPrefix, StringComparison.Ordinal))
            value = value.Substring(packPrefix.Length);

        string[] prefixes =
        {
            "HumanTownsfolk",
            "DwarfYellowBeard",
            "DwarfYellowBear",
            "WildOrc",
            "Amazon",
            "Dwarf",
            "Goblin",
            "Halfling",
            "Human",
            "Elf",
            "Orc",
        };

        foreach (string prefix in prefixes.OrderByDescending(prefix => prefix.Length))
        {
            if (value.StartsWith(prefix, StringComparison.Ordinal))
            {
                string stripped = value.Substring(prefix.Length);
            if (IsPlayerBodyActionKey(CanonicalizeActionName(stripped)))
                    return stripped;
            }
        }

        return value;
    }

    static string CanonicalizeActionName(string action)
    {
        if (string.Equals(action, "DieSoul", StringComparison.OrdinalIgnoreCase))
            return "SoulDie";
        if (string.Equals(action, "DieSpin", StringComparison.OrdinalIgnoreCase))
            return "SpinDie";
        if (string.Equals(action, "Damage", StringComparison.OrdinalIgnoreCase))
            return "Dmg";
        return action;
    }

    static bool IsPlayerBodyActionKey(string action)
    {
        return !string.IsNullOrWhiteSpace(action)
            && PlayerBodyActionKeys.Contains(action);
    }

    // 这里只同步真实人形身体帧。Farm/FarmingActions 里的屠宰、浇水、播种等是 16x16
    // 进度提示图标，不是角色身体动作；它们可以保留为交互提示类型，但不能写入
    // CharacterFrameData，否则换装预览会把提示 UI 当成人物来播放。
    static readonly HashSet<string> PlayerBodyActionKeys = new HashSet<string>(
        new[]
        {
            "Idle",
            "Walk",
            "Wait",
            "Attack",
            "ChargedAttack",
            "Dmg",
            "Dmg2",
            "SlashAttack",
            "Jump",
            "SoulDie",
            "SpinDie",
            "Die",
            "Harvest",
            "Chopping",
            "Mining",
            "AnvilWorking",
            "JewelryWorkshopWorking",
            "LaboratoryWorking",
            "WoodworkBenchWorking",
        },
        StringComparer.OrdinalIgnoreCase);

    static readonly string[] DirectionSuffixes =
    {
        "_NE",
        "_NW",
        "_SE",
        "_SW",
        "_N",
        "_S",
        "_E",
        "_W",
    };

    static void EnsureBasicFrames(AnimationData animation)
    {
        int rows = Mathf.Max(1, animation.rowCount);
        int frames = Mathf.Max(1, animation.framesPerRow);
        for (int row = 0; row < rows; row++)
        {
            for (int frame = 0; frame < frames; frame++)
                animation.GetOrCreateFrame(frame, row);
        }
    }

    static void BindCatalogFrameData(
        EquipmentWorkbenchCatalog catalog,
        IReadOnlyDictionary<string, CharacterFrameData> frameDataByDisplayName)
    {
        SerializedObject serializedCatalog = new SerializedObject(catalog);
        SerializedProperty characters = serializedCatalog.FindProperty("characters");
        if (characters == null || !characters.isArray)
            return;

        for (int i = 0; i < characters.arraySize; i++)
        {
            SerializedProperty character = characters.GetArrayElementAtIndex(i);
            SerializedProperty displayNameProperty = character.FindPropertyRelative("displayName");
            string displayName = displayNameProperty != null ? displayNameProperty.stringValue : string.Empty;
            if (!frameDataByDisplayName.TryGetValue(displayName, out CharacterFrameData frameData))
                continue;

            SerializedProperty frameDataProperty = character.FindPropertyRelative("frameData");
            if (frameDataProperty != null)
                frameDataProperty.objectReferenceValue = frameData;
        }

        serializedCatalog.ApplyModifiedPropertiesWithoutUndo();
        EditorUtility.SetDirty(catalog);
    }

    static void EnsureFolder(string folderPath)
    {
        if (AssetDatabase.IsValidFolder(folderPath))
            return;

        string[] parts = folderPath.Split('/');
        string current = parts[0];
        for (int i = 1; i < parts.Length; i++)
        {
            string next = $"{current}/{parts[i]}";
            if (!AssetDatabase.IsValidFolder(next))
                AssetDatabase.CreateFolder(current, parts[i]);
            current = next;
        }
    }

    readonly struct CharacterSource
    {
        public CharacterSource(string displayName, string assetName, string folder, string fileToken)
        {
            DisplayName = displayName;
            AssetName = assetName;
            Folder = folder;
            FileToken = fileToken;
        }

        public string DisplayName { get; }
        public string AssetName { get; }
        public string Folder { get; }
        public string FileToken { get; }
    }

    [Serializable]
    sealed class SerializableReportRow
    {
        public string text;

        public SerializableReportRow(object source)
        {
            text = source.ToString();
        }
    }
}
