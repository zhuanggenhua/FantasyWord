using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;
using UnityEditor;
using UnityEditor.Animations;
using UnityEngine;

/// <summary>
/// 动画类型自动注册工具
/// - 提供静态方法：手动扫描所有 AnimationTypeItem 并注册到 AnimationTypeDatabase
/// - 提供 AssetPostprocessor：在导入 AnimationTypeItem 资产时自动注册
/// </summary>
public class AnimationTypeAutoRegister : AssetPostprocessor
{
    const string AnimationTypeFolder = "Assets/GameData/EquipmentSystem/AnimationType";
    static readonly string[] MiniFantasyArtRoots =
    {
        "Assets/Art/KrishnaPalacio/MINIFANTASY - Dungeon/Animation/Human",
        "Assets/Art/KrishnaPalacio/MINIFANTASY - Dungeon/Sprites/Animations/Human",
        "Assets/Art/MINIFANTASY - Crafting and Professions I/Sprites",
        "Assets/Art/KrishnaPalacio/MINIFANTASY - Farm/Animations/FarmingActions",
        "Assets/Art/MINIFANTASY Creatures - Super Low Res 2D Pixel Art by Krishna Palacio/Animations/Humanoids/Human",
        "Assets/Art/MINIFANTASY Creatures - Super Low Res 2D Pixel Art by Krishna Palacio/Sprites/Humanoids/Human",
    };

    static readonly string[] AnimationClipPathMarkers =
    {
        "/Animation/Human/",
    };

    static readonly HashSet<string> ExplicitPlayerSpriteActionFiles = new HashSet<string>(
        StringComparer.OrdinalIgnoreCase)
    {
        "Human_AnvilWorking",
        "Human_Chopping",
        "Human_Harvest",
        "Human_JewelryWorkshopWorking",
        "Human_LaboratoryWorking",
        "Human_Mining",
        "Human_WoodworkBenchWorking",
    };

    static readonly HashSet<string> ExplicitHumanActionKeys = new HashSet<string>(
        StringComparer.OrdinalIgnoreCase)
    {
        "AnvilWorking",
        "Attack",
        "Butchering",
        "ChargedAttack",
        "Chopping",
        "Die",
        "Digging",
        "Dmg",
        "Dmg2",
        "FillingBucket",
        "Harvest",
        "Harvesting",
        "Idle",
        "JewelryWorkshopWorking",
        "Jump",
        "LaboratoryWorking",
        "Milking",
        "Mining",
        "SlashAttack",
        "Shearing",
        "SoulDie",
        "SowingSeeds",
        "SpinDie",
        "TillingSoil",
        "Watering",
        "Wait",
        "Walk",
        "WoodworkBenchWorking",
    };

    static readonly HashSet<string> FarmInteractionActionKeys = new HashSet<string>(
        StringComparer.OrdinalIgnoreCase)
    {
        "Butchering",
        "Digging",
        "FillingBucket",
        "Harvesting",
        "Milking",
        "Shearing",
        "SowingSeeds",
        "TillingSoil",
        "Watering",
    };

    static readonly HashSet<string> ExplicitHumanCreatureAnimationFiles = new HashSet<string>(
        StringComparer.OrdinalIgnoreCase)
    {
        "HumanWalk_SE",
    };

    static readonly HashSet<string> ExcludedHumanCreatureVariants = new HashSet<string>(
        StringComparer.OrdinalIgnoreCase)
    {
        "Minifantasy_CreaturesAmazon",
        "Minifantasy_CreaturesHumanTownsfolk",
    };

    static readonly HashSet<string> IgnoredSuffixes = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
    {
        "Animations",
        "Icons",
        "Shadow",
        "Shadows",
    };

    static readonly HashSet<string> IgnoredActionNames = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
    {
        "X",
        "Y",
        "Clicked",
        "Speed",
        "NewState",
        "New State",
        "Blend Tree",
        "ChoppingTreeAnimation",
        "Damage",
        "HarvestAnimation",
        "HumanBaseAnimations",
        "IcyBreeze",
        "MiningAnimation",
        "Movement",
        "OrcBaseAnimations",
        "PumpkinHorrorBaseAnimations",
        "SnowBall",
        "Spikes",
        "Torch",
        "Tumble",
        "FarmingAction",
        "Townsfolk",
        "Amazon",
    };

    static readonly HashSet<string> ObsoleteGeneratedActionNames = new HashSet<string>(
        StringComparer.OrdinalIgnoreCase)
    {
        "ChoppingTreeAnimation",
        "Damage",
        "HarvestAnimation",
        "HumanBaseAnimations",
        "IcyBreeze",
        "MiningAnimation",
        "Movement",
        "OrcBaseAnimations",
        "PumpkinHorrorBaseAnimations",
        "SnowBall",
        "Spikes",
        "Torch",
        "Tumble",
    };

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

    static readonly string[] KnownSpriteActionSuffixes =
    {
        "BaseIdleActivation",
        "IdleActivation",
        "JumpAttack",
        "ChargedAttack",
        "BaseAttack",
        "BaseWalk",
        "BaseDmg2",
        "Dmg2",
        "BaseDmg",
        "BaseDie",
        "DieSoul",
        "DieSpin",
        "SlashAttack",
        "FlyIdle",
        "SoulDie",
        "SpinDie",
        "AnvilWorking",
        "LaboratoryWorking",
        "JewelryWorkshopWorking",
        "WoodworkBenchWorking",
        "Activation",
        "Butchering",
        "Chopping",
        "Digging",
        "FillingBucket",
        "Harvest",
        "Harvesting",
        "Melting",
        "Milking",
        "Mining",
        "Pouring",
        "Shearing",
        "SowingSeeds",
        "TillingSoil",
        "Watering",
        "Working",
        "Attack",
        "Sleep",
        "Walk",
        "Wait",
        "Idle",
        "Jump",
        "Dmg",
        "Die",
        "Dead",
        "Fly",
        "Hit",
        "Tumble",
        "Work",
    };

    static readonly HashSet<string> KnownSpriteActionSet =
        new HashSet<string>(KnownSpriteActionSuffixes, StringComparer.OrdinalIgnoreCase);

    static readonly string[] PlayerActionOrder =
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
        "Harvesting",
        "Chopping",
        "Mining",
        "Digging",
        "TillingSoil",
        "SowingSeeds",
        "Watering",
        "FillingBucket",
        "Butchering",
        "Milking",
        "Shearing",
        "AnvilWorking",
        "JewelryWorkshopWorking",
        "LaboratoryWorking",
        "WoodworkBenchWorking",
    };

    static readonly HashSet<string> PlayerActionWhitelist =
        new HashSet<string>(PlayerActionOrder, StringComparer.OrdinalIgnoreCase);

    /// <summary>
    /// 手动扫描项目中所有 AnimationTypeItem，并注册到第一个 AnimationTypeDatabase
    /// （供 AnimationTypeDatabase Inspector 按钮调用）
    /// </summary>
    public static void ScanAndRegisterAll()
    {
        var db = FindDatabase(logIfNotFound: true);
        if (db == null)
            return;

        // 先清理数据库中的 null 引用
        var items = db.Items;
        int removed = 0;
        for (int i = items.Count - 1; i >= 0; i--)
        {
            if (items[i] == null)
            {
                items.RemoveAt(i);
                removed++;
            }
        }
        if (removed > 0)
            db.RebuildCache();

        SortedSet<string> sourceBackedActionNames = BuildMiniFantasySourceBackedActionNames();

        // 扫描并注册当前玩家换装工作台认可的动作类型。
        // 旧的动物/怪物动作资产可能仍留在目录里，但不应被重新塞回玩家动作库。
        string[] typeGuids = AssetDatabase.FindAssets("t:AnimationTypeItem");
        int added = 0;

        foreach (var guid in typeGuids)
        {
            string path = AssetDatabase.GUIDToAssetPath(guid);
            var item = AssetDatabase.LoadAssetAtPath<AnimationTypeItem>(path);
            if (item == null)
                continue;

            if (!ShouldAutoRegisterImportedActionType(item, ref sourceBackedActionNames))
                continue;

            if (!db.Contains(item))
            {
                db.EditorAddItem(item);
                added++;
            }
        }

        if (added > 0 || removed > 0)
        {
            EditorUtility.SetDirty(db);
            AssetDatabase.SaveAssets();
        }

        Debug.Log($"[AnimationTypeAutoRegister] 手动扫描完成，新增 {added} 个，清理 {removed} 个空引用。");
    }

    /// <summary>
    /// 从 MiniFantasy 素材文件名同步动作类型。
    /// 这里只维护“动作类型名”这个正式索引，不自动伪造 CharacterFrameData 帧数据。
    /// </summary>
    public static void SyncMiniFantasyActionTypes()
    {
        var db = FindDatabase(logIfNotFound: true);
        if (db == null)
            return;

        EnsureFolder(AnimationTypeFolder);

        SortedSet<string> actionNames = BuildMiniFantasySourceBackedActionNames();
        int removed = RemoveActionTypesNotBackedBySource(db, actionNames);

        int created = 0;
        int registered = 0;
        foreach (string actionName in SortPlayerActions(actionNames))
        {
            if (!IsValidActionName(actionName))
                continue;

            AnimationTypeItem item = FindOrCreateActionType(actionName, ref created);
            if (item != null && !db.Contains(item))
            {
                db.EditorAddItem(item);
                registered++;
            }
        }

        bool sorted = SortDatabaseItems(db);

        if (created > 0 || registered > 0 || removed > 0 || sorted)
        {
            EditorUtility.SetDirty(db);
            AssetDatabase.SaveAssets();
            AssetDatabase.Refresh();
        }

        Debug.Log(
            $"[AnimationTypeAutoRegister] MiniFantasy 动作类型同步完成：确认 {actionNames.Count} 个玩家动作键，"
            + $"新建 {created} 个，注册 {registered} 个，清理误注册 {removed} 个。"
            + "换装工作台只展示玩家人形动作；其它角色通过覆盖控制器复用同一组动作键。");
    }

    /// <summary>
    /// 监听资产变更：
    /// - 导入 AnimationTypeItem 时自动注册到数据库
    /// - 删除 AnimationTypeItem 时自动从数据库中移除空引用
    /// </summary>
    static void OnPostprocessAllAssets(string[] importedAssets, string[] deletedAssets,
        string[] movedAssets, string[] movedFromAssetPaths)
    {
        AnimationTypeDatabase db = null;
        int added = 0;
        int removed = 0;

        // 处理导入：自动注册新的 AnimationTypeItem
        if (importedAssets != null && importedAssets.Length > 0)
        {
            var newItems = new List<AnimationTypeItem>();
            SortedSet<string> sourceBackedActionNames = null;
            foreach (var path in importedAssets)
            {
                var item = AssetDatabase.LoadAssetAtPath<AnimationTypeItem>(path);
                if (item != null && ShouldAutoRegisterImportedActionType(item, ref sourceBackedActionNames))
                    newItems.Add(item);
            }

            if (newItems.Count > 0)
            {
                db ??= FindDatabase(logIfNotFound: false);
                if (db != null)
                {
                    foreach (var item in newItems)
                    {
                        if (!db.Contains(item))
                        {
                            db.EditorAddItem(item);
                            added++;
                        }
                    }
                }
            }
        }

        // 处理删除：清理数据库中变成 null 的引用
        if (deletedAssets != null && deletedAssets.Length > 0)
        {
            db ??= FindDatabase(logIfNotFound: false);
            if (db != null)
            {
                var items = db.Items;
                for (int i = items.Count - 1; i >= 0; i--)
                {
                    if (items[i] == null)
                    {
                        items.RemoveAt(i);
                        removed++;
                    }
                }

                if (removed > 0)
                    db.RebuildCache();
            }
        }

        if (db != null && (added > 0 || removed > 0))
        {
            EditorUtility.SetDirty(db);
            AssetDatabase.SaveAssets();

            if (added > 0)
                Debug.Log($"[AnimationTypeAutoRegister] 自动注册 {added} 个动画类型。");
            if (removed > 0)
                Debug.Log($"[AnimationTypeAutoRegister] 自动移除 {removed} 个已删除的动画类型引用。");
        }
    }

    /// <summary>
    /// 查找一个 AnimationTypeDatabase 资源（当前实现：取项目中找到的第一个）
    /// </summary>
    static AnimationTypeDatabase FindDatabase(bool logIfNotFound)
    {
        string[] guids = AssetDatabase.FindAssets("t:AnimationTypeDatabase");
        if (guids == null || guids.Length == 0)
        {
            if (logIfNotFound)
                Debug.LogWarning("[AnimationTypeAutoRegister] 未找到 AnimationTypeDatabase 资源，请先创建数据库资产。");
            return null;
        }

        string path = AssetDatabase.GUIDToAssetPath(guids[0]);
        var db = AssetDatabase.LoadAssetAtPath<AnimationTypeDatabase>(path);
        if (db == null && logIfNotFound)
        {
            Debug.LogWarning($"[AnimationTypeAutoRegister] 无法加载 AnimationTypeDatabase: {path}");
        }

        return db;
    }

    static void CollectAnimatorBoolParameters(ISet<string> actionNames)
    {
        string[] controllerGuids = AssetDatabase.FindAssets("t:AnimatorController", MiniFantasyArtRoots);
        foreach (string guid in controllerGuids)
        {
            string path = AssetDatabase.GUIDToAssetPath(guid);
            if (!ShouldUseAnimatorControllerForActionScan(path))
                continue;

            AnimatorController controller = AssetDatabase.LoadAssetAtPath<AnimatorController>(path);
            if (controller == null)
                continue;

            foreach (AnimatorControllerParameter parameter in controller.parameters)
            {
                if (parameter.type != AnimatorControllerParameterType.Bool
                    && parameter.type != AnimatorControllerParameterType.Trigger)
                {
                    continue;
                }

                AddNormalizedActionName(actionNames, parameter.name);
            }
        }
    }

    static void CollectAnimatorStateNames(ISet<string> actionNames)
    {
        string[] controllerGuids = AssetDatabase.FindAssets("t:AnimatorController", MiniFantasyArtRoots);
        foreach (string guid in controllerGuids)
        {
            string path = AssetDatabase.GUIDToAssetPath(guid);
            if (!ShouldUseAnimatorControllerForActionScan(path))
                continue;

            AnimatorController controller = AssetDatabase.LoadAssetAtPath<AnimatorController>(path);
            if (controller == null)
                continue;

            foreach (AnimatorControllerLayer layer in controller.layers)
            {
                if (layer?.stateMachine != null)
                    CollectAnimatorStateNames(layer.stateMachine, actionNames);
            }
        }
    }

    static void CollectAnimatorStateNames(AnimatorStateMachine stateMachine, ISet<string> actionNames)
    {
        foreach (ChildAnimatorState child in stateMachine.states)
        {
            if (child.state == null)
                continue;

            AddNormalizedActionName(actionNames, child.state.name, preserveSpecificName: false);
            if (child.state.motion != null)
                AddNormalizedActionName(actionNames, child.state.motion.name, preserveSpecificName: true);
        }

        foreach (ChildAnimatorStateMachine child in stateMachine.stateMachines)
        {
            if (child.stateMachine != null)
                CollectAnimatorStateNames(child.stateMachine, actionNames);
        }
    }

    static void CollectMiniFantasyAnimationClipNames(ISet<string> actionNames)
    {
        string[] clipGuids = AssetDatabase.FindAssets("t:AnimationClip", MiniFantasyArtRoots);
        foreach (string guid in clipGuids)
        {
            string path = AssetDatabase.GUIDToAssetPath(guid);
            if (!ShouldUseAnimationClipForActionScan(path))
                continue;

            AddNormalizedActionName(actionNames, Path.GetFileNameWithoutExtension(path), preserveSpecificName: true);
        }
    }

    static void CollectMiniFantasySpriteActionNames(ISet<string> actionNames)
    {
        foreach (string root in MiniFantasyArtRoots)
        {
            if (!AssetDatabase.IsValidFolder(root))
                continue;

            string[] textureGuids = AssetDatabase.FindAssets("t:Texture2D", new[] { root });
            foreach (string guid in textureGuids)
            {
                string path = AssetDatabase.GUIDToAssetPath(guid);
                if (path.IndexOf("Shadow", StringComparison.OrdinalIgnoreCase) >= 0)
                    continue;
                if (!ShouldUseSpriteForActionScan(path))
                    continue;

                string fileName = Path.GetFileNameWithoutExtension(path);
                if (fileName.EndsWith("Animations", StringComparison.OrdinalIgnoreCase))
                    continue;

                AddNormalizedActionName(actionNames, fileName, preserveSpecificName: true);
            }
        }
    }

    static int RemoveActionTypesNotBackedBySource(AnimationTypeDatabase db, ISet<string> actionNames)
    {
        int removed = 0;
        List<AnimationTypeItem> items = db.Items;
        for (int i = items.Count - 1; i >= 0; i--)
        {
            AnimationTypeItem item = items[i];
            if (item == null)
            {
                items.RemoveAt(i);
                removed++;
                continue;
            }

            if (IsValidActionName(item.name) && actionNames.Contains(item.name))
                continue;

            items.RemoveAt(i);
            removed++;
        }

        if (removed > 0)
            db.RebuildCache();

        return removed;
    }

    static AnimationTypeItem FindOrCreateActionType(string actionName, ref int created)
    {
        string[] existing = AssetDatabase.FindAssets($"{actionName} t:AnimationTypeItem", new[] { AnimationTypeFolder });
        foreach (string guid in existing)
        {
            string path = AssetDatabase.GUIDToAssetPath(guid);
            var item = AssetDatabase.LoadAssetAtPath<AnimationTypeItem>(path);
            if (item != null && item.name == actionName)
                return item;
        }

        string assetPath = AssetDatabase.GenerateUniqueAssetPath($"{AnimationTypeFolder}/{actionName}.asset");
        var newItem = ScriptableObject.CreateInstance<AnimationTypeItem>();
        newItem.name = actionName;
        AssetDatabase.CreateAsset(newItem, assetPath);
        created++;
        return newItem;
    }

    static bool ShouldAutoRegisterImportedActionType(
        AnimationTypeItem item,
        ref SortedSet<string> sourceBackedActionNames)
    {
        if (item == null || string.IsNullOrWhiteSpace(item.name))
            return false;

        string path = AssetDatabase.GetAssetPath(item);
        if (string.IsNullOrWhiteSpace(path))
            return false;

        string normalizedPath = path.Replace('\\', '/');
        if (!normalizedPath.StartsWith(AnimationTypeFolder + "/", StringComparison.OrdinalIgnoreCase))
            return true;

        sourceBackedActionNames ??= BuildMiniFantasySourceBackedActionNames();
        return sourceBackedActionNames.Contains(item.name);
    }

    static SortedSet<string> BuildMiniFantasySourceBackedActionNames()
    {
        SortedSet<string> actionNames = new SortedSet<string>(StringComparer.Ordinal);
        CollectMiniFantasyAnimationClipNames(actionNames);
        CollectMiniFantasySpriteActionNames(actionNames);
        CollectMiniFantasyFarmInteractionActionNames(actionNames);
        RetainOnlyPlayerActionNames(actionNames);
        return actionNames;
    }

    static void CollectMiniFantasyFarmInteractionActionNames(ISet<string> actionNames)
    {
        const string farmActionRoot =
            "Assets/Art/KrishnaPalacio/MINIFANTASY - Farm/Animations/FarmingActions";
        if (actionNames == null || !AssetDatabase.IsValidFolder(farmActionRoot))
            return;

        string[] clipGuids = AssetDatabase.FindAssets("t:AnimationClip", new[] { farmActionRoot });
        foreach (string guid in clipGuids)
        {
            string path = AssetDatabase.GUIDToAssetPath(guid);
            string actionName = CanonicalizeActionName(Path.GetFileNameWithoutExtension(path));
            if (FarmInteractionActionKeys.Contains(actionName))
                actionNames.Add(actionName);
        }
    }

    static void RetainOnlyPlayerActionNames(SortedSet<string> actionNames)
    {
        if (actionNames == null)
            return;

        if (actionNames.Contains("SoulDie") || actionNames.Contains("SpinDie"))
            actionNames.Add("Die");

        actionNames.RemoveWhere(actionName => !IsValidActionName(actionName));
    }

    static bool SortDatabaseItems(AnimationTypeDatabase db)
    {
        if (db == null)
            return false;

        string[] before = db.Items
            .Select(item => item != null ? item.name : string.Empty)
            .ToArray();

        db.Items.Sort((left, right) =>
        {
            string leftName = left != null ? left.name : string.Empty;
            string rightName = right != null ? right.name : string.Empty;
            int leftIndex = Array.FindIndex(
                PlayerActionOrder,
                action => string.Equals(action, leftName, StringComparison.OrdinalIgnoreCase));
            int rightIndex = Array.FindIndex(
                PlayerActionOrder,
                action => string.Equals(action, rightName, StringComparison.OrdinalIgnoreCase));

            leftIndex = leftIndex >= 0 ? leftIndex : PlayerActionOrder.Length + 1000;
            rightIndex = rightIndex >= 0 ? rightIndex : PlayerActionOrder.Length + 1000;
            int indexCompare = leftIndex.CompareTo(rightIndex);
            return indexCompare != 0
                ? indexCompare
                : string.CompareOrdinal(leftName, rightName);
        });
        db.RebuildCache();

        return !before.SequenceEqual(db.Items.Select(item => item != null ? item.name : string.Empty));
    }

    static IEnumerable<string> SortPlayerActions(IEnumerable<string> actionNames)
    {
        HashSet<string> remaining = new HashSet<string>(
            actionNames.Where(IsValidActionName),
            StringComparer.Ordinal);

        foreach (string actionName in PlayerActionOrder)
        {
            if (remaining.Remove(actionName))
                yield return actionName;
        }

        foreach (string actionName in remaining.OrderBy(name => name, StringComparer.Ordinal))
            yield return actionName;
    }

    static string ExtractActionName(string fileName)
    {
        return ExtractActionName(fileName, preserveSpecificName: false);
    }

    static string ExtractActionName(string fileName, bool preserveSpecificName)
    {
        if (string.IsNullOrWhiteSpace(fileName))
            return null;

        if (TryGetExplicitHumanCreatureSpriteAction(fileName, out string explicitAction))
            return explicitAction;

        fileName = StripBlendTreeSuffix(fileName);

        fileName = StripDirectionSuffix(fileName);
        fileName = StripKnownCharacterPrefix(fileName);

        int underscore = fileName.LastIndexOf('_');
        if (underscore >= 0 && underscore < fileName.Length - 1)
        {
            string suffix = fileName.Substring(underscore + 1);
            if (KnownSpriteActionSet.Contains(suffix))
                return CanonicalizeActionName(suffix);
        }

        foreach (string suffix in KnownSpriteActionSuffixes.OrderByDescending(suffix => suffix.Length))
        {
            if (fileName.EndsWith(suffix, StringComparison.OrdinalIgnoreCase))
                return CanonicalizeActionName(suffix);
        }

        return CanonicalizeActionName(fileName);
    }

    static void AddNormalizedActionName(ISet<string> actionNames, string rawName)
    {
        AddNormalizedActionName(actionNames, rawName, preserveSpecificName: false);
    }

    static void AddNormalizedActionName(ISet<string> actionNames, string rawName, bool preserveSpecificName)
    {
        string actionName = ExtractActionName(rawName, preserveSpecificName);
        if (IsValidActionName(actionName))
            actionNames.Add(actionName);
    }

    static string StripBlendTreeSuffix(string value)
    {
        const string suffix = " Blend Tree";
        return value.EndsWith(suffix, StringComparison.OrdinalIgnoreCase)
            ? value.Substring(0, value.Length - suffix.Length)
            : value;
    }

    static string StripDirectionSuffix(string value)
    {
        foreach (string suffix in DirectionSuffixes)
        {
            if (value.EndsWith(suffix, StringComparison.OrdinalIgnoreCase))
                return value.Substring(0, value.Length - suffix.Length);
        }

        return value;
    }

    static string StripKnownCharacterPrefix(string value)
    {
        if (string.IsNullOrWhiteSpace(value))
            return value;

        const string miniFantasyCreaturesPrefix = "Minifantasy_Creatures";
        if (value.StartsWith(miniFantasyCreaturesPrefix, StringComparison.Ordinal))
        {
            string withoutPackPrefix = value.Substring(miniFantasyCreaturesPrefix.Length);
            string strippedCreature = StripLeadingCreatureName(withoutPackPrefix);
            if (!string.IsNullOrWhiteSpace(strippedCreature))
                return strippedCreature;
        }

        int underscore = value.IndexOf('_');
        if (underscore <= 0 || underscore >= value.Length - 1)
            return value;

        string prefix = value.Substring(0, underscore);
        if (!IsKnownCharacterOrCreaturePrefix(prefix))
            return value;

        return value.Substring(underscore + 1);
    }

    static string StripLeadingCreatureName(string value)
    {
        if (string.IsNullOrWhiteSpace(value))
            return value;

        string[] knownPrefixes =
        {
            "HumanTownsfolk",
            "MotherSlimeGreen",
            "BlueMotherSlime",
            "DwarfYellowBeard",
            "DwarfYellowBear",
            "PumpkinHorror",
            "EvilSnowman",
            "BlueSlime",
            "SlimeGreen",
            "WildOrc",
            "Skeleton",
            "Wildfire",
            "Centaur",
            "Cyclop",
            "Minotaur",
            "Amazon",
            "Dwarf",
            "Goblin",
            "Halfling",
            "Human",
            "Trasgo",
            "Troll",
            "Wargo",
            "Yeti",
            "Zombie",
            "Wolf",
            "Bat",
            "Elf",
            "Orc",
        };

        foreach (string prefix in knownPrefixes.OrderByDescending(prefix => prefix.Length))
        {
            if (value.StartsWith(prefix, StringComparison.Ordinal))
            {
                string stripped = value.Substring(prefix.Length);
                if (!string.IsNullOrWhiteSpace(stripped)
                    && KnownSpriteActionSet.Contains(stripped))
                {
                    return stripped;
                }
            }
        }

        return value;
    }

    static bool IsKnownCharacterOrCreaturePrefix(string prefix)
    {
        switch (prefix)
        {
            case "Human":
            case "Orc":
            case "Elf":
            case "Dwarf":
            case "Goblin":
            case "Halfling":
                return true;
            default:
                return false;
        }
    }

    static string CanonicalizeActionName(string actionName)
    {
        if (string.IsNullOrWhiteSpace(actionName))
            return actionName;

        if (actionName.StartsWith("Base", StringComparison.OrdinalIgnoreCase)
            && actionName.Length > "Base".Length)
        {
            string withoutBase = actionName.Substring("Base".Length);
            if (ExplicitHumanActionKeys.Contains(withoutBase))
                actionName = withoutBase;
        }

        if (string.Equals(actionName, "HumanWalk", StringComparison.OrdinalIgnoreCase))
            return "Walk";
        if (string.Equals(actionName, "DieSoul", StringComparison.OrdinalIgnoreCase))
            return "SoulDie";
        if (string.Equals(actionName, "DieSpin", StringComparison.OrdinalIgnoreCase))
            return "SpinDie";
        if (string.Equals(actionName, "Damage", StringComparison.OrdinalIgnoreCase))
            return "Dmg";
        if (string.Equals(actionName, "JewerlyWorking", StringComparison.OrdinalIgnoreCase)
            || string.Equals(actionName, "JewelryWorking", StringComparison.OrdinalIgnoreCase))
            return "JewelryWorkshopWorking";
        if (string.Equals(actionName, "WoodworkWorking", StringComparison.OrdinalIgnoreCase))
            return "WoodworkBenchWorking";
        if (actionName.StartsWith("is", StringComparison.Ordinal)
            && actionName.Length > 2
            && char.IsUpper(actionName[2]))
        {
            return actionName.Substring(2);
        }

        return actionName;
    }

    static bool ShouldUseAnimatorControllerForActionScan(string path)
    {
        string normalized = path.Replace('\\', '/');
        return IsHumanDungeonAnimationPath(normalized);
    }

    static bool ShouldUseSpriteForActionScan(string path)
    {
        string normalized = path.Replace('\\', '/');
        if (IsNonPlayerActionPath(normalized))
            return false;

        string fileName = Path.GetFileNameWithoutExtension(normalized);
        if (IsCraftingProfessionHumanPlayerSpritePath(normalized))
            return ExplicitPlayerSpriteActionFiles.Contains(fileName)
                && IsExplicitHumanAction(ExtractActionName(fileName, preserveSpecificName: true));

        if (IsHumanDungeonSpritePath(normalized))
            return IsHumanDungeonSpriteActionFile(fileName);

        return IsHumanCreatureSpritePath(normalized)
            && IsHumanCreatureSpriteActionFile(fileName);
    }

    static bool ShouldUseAnimationClipForActionScan(string path)
    {
        string normalized = path.Replace('\\', '/');
        if (IsNonPlayerActionPath(normalized))
            return false;

        return IsHumanDungeonAnimationPath(normalized)
            || IsHumanCreatureAnimationPath(normalized);
    }

    static bool IsHumanDungeonAnimationPath(string normalizedPath)
    {
        return normalizedPath.IndexOf(
            "/KrishnaPalacio/MINIFANTASY - Dungeon/Animation/Human/",
            StringComparison.OrdinalIgnoreCase) >= 0;
    }

    static bool IsCraftingProfessionHumanPlayerSpritePath(string normalizedPath)
    {
        return normalizedPath.IndexOf(
            "/MINIFANTASY - Crafting and Professions I/Sprites/",
            StringComparison.OrdinalIgnoreCase) >= 0
            && (normalizedPath.IndexOf("/Characters/", StringComparison.OrdinalIgnoreCase) >= 0
                || normalizedPath.IndexOf("/Character/", StringComparison.OrdinalIgnoreCase) >= 0)
            && Path.GetFileNameWithoutExtension(normalizedPath).StartsWith(
                "Human_",
                StringComparison.OrdinalIgnoreCase);
    }

    static bool IsHumanDungeonSpritePath(string normalizedPath)
    {
        return normalizedPath.IndexOf(
            "/KrishnaPalacio/MINIFANTASY - Dungeon/Sprites/Animations/Human/",
            StringComparison.OrdinalIgnoreCase) >= 0;
    }

    static bool IsHumanDungeonSpriteActionFile(string fileName)
    {
        const string prefix = "HumanBase";
        if (string.IsNullOrWhiteSpace(fileName)
            || !fileName.StartsWith(prefix, StringComparison.OrdinalIgnoreCase)
            || fileName.EndsWith("Animations", StringComparison.OrdinalIgnoreCase)
            || fileName.Length <= prefix.Length)
        {
            return false;
        }

        string actionName = CanonicalizeActionName(fileName.Substring(prefix.Length));
        return IsExplicitHumanAction(actionName);
    }

    static bool IsHumanCreatureAnimationPath(string normalizedPath)
    {
        if (normalizedPath.IndexOf(
                "/MINIFANTASY Creatures - Super Low Res 2D Pixel Art by Krishna Palacio/Animations/Humanoids/Human/",
                StringComparison.OrdinalIgnoreCase) < 0)
        {
            return false;
        }

        return ExplicitHumanCreatureAnimationFiles.Contains(Path.GetFileNameWithoutExtension(normalizedPath));
    }

    static bool IsHumanCreatureSpritePath(string normalizedPath)
    {
        return normalizedPath.IndexOf(
                "/MINIFANTASY Creatures - Super Low Res 2D Pixel Art by Krishna Palacio/Sprites/Humanoids/Human/Human/",
                StringComparison.OrdinalIgnoreCase) >= 0
            && normalizedPath.IndexOf("/Human_Amazon/", StringComparison.OrdinalIgnoreCase) < 0
            && normalizedPath.IndexOf("/Human_Townsfolk/", StringComparison.OrdinalIgnoreCase) < 0;
    }

    static bool IsHumanCreatureSpriteActionFile(string fileName)
    {
        if (TryGetExplicitHumanCreatureSpriteAction(fileName, out string explicitAction))
            return IsExplicitHumanAction(explicitAction);

        const string prefix = "Minifantasy_CreaturesHuman";
        if (string.IsNullOrWhiteSpace(fileName)
            || !fileName.StartsWith(prefix, StringComparison.OrdinalIgnoreCase)
            || IsExcludedHumanCreatureVariant(fileName)
            || fileName.Length <= prefix.Length)
        {
            return false;
        }

        string actionName = CanonicalizeActionName(fileName.Substring(prefix.Length));
        return IsExplicitHumanAction(actionName);
    }

    static bool TryGetExplicitHumanCreatureSpriteAction(string fileName, out string actionName)
    {
        actionName = null;
        if (string.IsNullOrWhiteSpace(fileName))
            return false;

        if (string.Equals(fileName, "Slash_Character_human", StringComparison.OrdinalIgnoreCase))
        {
            actionName = "SlashAttack";
            return true;
        }

        return false;
    }

    static bool IsNonPlayerActionPath(string normalizedPath)
    {
        return normalizedPath.IndexOf("/Sprites/Farm_Animals/", StringComparison.OrdinalIgnoreCase) >= 0
            || normalizedPath.IndexOf("/Sprites/Monsters/", StringComparison.OrdinalIgnoreCase) >= 0
            || normalizedPath.IndexOf("/Sprites/Beasts/", StringComparison.OrdinalIgnoreCase) >= 0
            || normalizedPath.IndexOf("/Sprites/Big_Guys/", StringComparison.OrdinalIgnoreCase) >= 0
            || normalizedPath.IndexOf("/Sprites/Actions/ActionInProgress", StringComparison.OrdinalIgnoreCase) >= 0
            || normalizedPath.IndexOf("/Animations/FarmingActions/", StringComparison.OrdinalIgnoreCase) >= 0
            || normalizedPath.IndexOf("/Sprites/Minifantasy_IW_Assets/Animations/Penguin/", StringComparison.OrdinalIgnoreCase) >= 0
            || normalizedPath.IndexOf("/Animations/Animals/", StringComparison.OrdinalIgnoreCase) >= 0
            || normalizedPath.IndexOf("/Animation/Penguin/", StringComparison.OrdinalIgnoreCase) >= 0
            || normalizedPath.IndexOf("/Animations/Chick/", StringComparison.OrdinalIgnoreCase) >= 0
            || normalizedPath.IndexOf("/Animations/Hen/", StringComparison.OrdinalIgnoreCase) >= 0;
    }

    static bool IsExcludedHumanCreatureVariant(string fileName)
    {
        if (string.IsNullOrWhiteSpace(fileName))
            return false;

        foreach (string prefix in ExcludedHumanCreatureVariants)
        {
            if (fileName.StartsWith(prefix, StringComparison.OrdinalIgnoreCase))
                return true;
        }

        return false;
    }

    static bool IsValidActionName(string actionName)
    {
        return !string.IsNullOrWhiteSpace(actionName)
            && !IgnoredSuffixes.Contains(actionName)
            && !IgnoredActionNames.Contains(actionName)
            && PlayerActionWhitelist.Contains(actionName)
            && !actionName.EndsWith("Animations", StringComparison.OrdinalIgnoreCase)
            && !actionName.EndsWith("Animation", StringComparison.OrdinalIgnoreCase)
            && Regex.IsMatch(actionName, "^[A-Za-z][A-Za-z0-9_]*$", RegexOptions.CultureInvariant);
    }

    static bool IsExplicitHumanAction(string actionName)
    {
        return !string.IsNullOrWhiteSpace(actionName)
            && ExplicitHumanActionKeys.Contains(CanonicalizeActionName(actionName));
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
}
