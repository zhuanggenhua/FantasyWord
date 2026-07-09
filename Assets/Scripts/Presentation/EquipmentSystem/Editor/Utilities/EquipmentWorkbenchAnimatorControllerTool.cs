using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.Animations;
using UnityEngine;

/// <summary>
/// 生成换装工作台使用的代码驱动 Animator Controller。
/// 控制器只承载状态清单，运行时由 AnimationController 直接 Animator.Play 切换。
/// </summary>
public static class EquipmentWorkbenchAnimatorControllerTool
{
    const string AnimationDatabasePath =
        "Assets/GameData/EquipmentSystem/AnimationType/AnimationTypeDatabase.asset";
    const string WorkbenchCatalogPath =
        "Assets/GameData/EquipmentSystem/Data/Workbench/换装工作台目录.asset";
    const string HumanFrameDataPath =
        "Assets/GameData/EquipmentSystem/FrameData/人类帧数据.asset";
    const string ControllerPath =
        "Assets/GameData/EquipmentSystem/Animations/换装代码驱动状态机.controller";
    const string GeneratedOverrideRoot =
        "Assets/GameData/EquipmentSystem/Animations/Overrides";
    const string GeneratedClipRoot =
        "Assets/GameData/EquipmentSystem/Animations/GeneratedClips";

    static readonly string[] MotionSearchRoots =
    {
        "Assets/Art/MINIFANTASY - Crafting and Professions I/Animations/Humanoids/Human",
        "Assets/Art/MINIFANTASY - Crafting and Professions I/Sprites",
        "Assets/Art/MINIFANTASY Creatures - Super Low Res 2D Pixel Art by Krishna Palacio/Animations/Humanoids/Human",
        "Assets/Art/MINIFANTASY Creatures - Super Low Res 2D Pixel Art by Krishna Palacio/Sprites/Humanoids/Human",
        "Assets/Art/KrishnaPalacio/MINIFANTASY Creatures - Super Low Res 2D Pixel Art by Krishna Palacio/Animations/Humanoids/Human",
        "Assets/Art/KrishnaPalacio/MINIFANTASY Creatures - Super Low Res 2D Pixel Art by Krishna Palacio/Sprites/Humanoids/Human",
    };

    static readonly HashSet<string> ExplicitHumanPlayerSpriteActionFiles = new HashSet<string>(
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
        "ChargedAttack",
        "Chopping",
        "Die",
        "Dmg",
        "Dmg2",
        "Harvest",
        "Idle",
        "JewelryWorkshopWorking",
        "Jump",
        "LaboratoryWorking",
        "Mining",
        "SlashAttack",
        "SoulDie",
        "SpinDie",
        "Walk",
        "WoodworkBenchWorking",
    };

    static readonly HashSet<string> ExcludedHumanCreatureVariants = new HashSet<string>(
        StringComparer.OrdinalIgnoreCase)
    {
        "Minifantasy_CreaturesAmazon",
        "Minifantasy_CreaturesHumanTownsfolk",
    };

    static readonly HashSet<string> ExplicitHumanCreatureAnimationFiles = new HashSet<string>(
        StringComparer.OrdinalIgnoreCase)
    {
        "HumanWalk_SE",
    };

    static readonly string[] SpeciesSpriteActionSuffixes =
    {
        "ChargedAttack",
        "SlashAttack",
        "SoulDie",
        "SpinDie",
        "Attack",
        "Dmg2",
        "Dmg",
        "Idle",
        "Jump",
        "Walk",
        "Die",
    };

    static readonly string[] PlayerActionAliases =
    {
        "JewelryWorkshopWorking",
        "WoodworkBenchWorking",
        "LaboratoryWorking",
        "AnvilWorking",
        "ChargedAttack",
        "Chopping",
        "Harvest",
        "Mining",
        "SoulDie",
        "SpinDie",
        "Attack",
        "SlashAttack",
        "Dmg2",
        "Dmg",
        "Idle",
        "Jump",
        "Walk",
        "Die",
    };

    static readonly HashSet<string> LoopingActionNames = new HashSet<string>(
        StringComparer.OrdinalIgnoreCase)
    {
        "Idle",
        "Walk",
        "AnvilWorking",
        "Chopping",
        "Harvest",
        "JewelryWorkshopWorking",
        "LaboratoryWorking",
        "Mining",
        "WoodworkBenchWorking",
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

    static readonly string[] WorkbenchDirectionSuffixes =
    {
        "_SE",
        "_SW",
        "_NE",
        "_NW",
    };

    [MenuItem("Tools/Equipment System/Workbench Animator/生成或修复代码驱动状态机")]
    public static void GenerateOrRepair()
    {
        AnimationTypeDatabase database = AssetDatabase.LoadAssetAtPath<AnimationTypeDatabase>(AnimationDatabasePath);
        if (database == null)
        {
            Debug.LogError($"[EquipmentWorkbenchAnimatorControllerTool] 找不到动作类型库: {AnimationDatabasePath}");
            return;
        }

        EnsureFolder("Assets/GameData/EquipmentSystem/Animations");
        EnsureFolder(GeneratedOverrideRoot);
        EnsureFolder(GeneratedClipRoot);

        PruneObsoleteGeneratedClips();

        AnimatorController controller = AssetDatabase.LoadAssetAtPath<AnimatorController>(ControllerPath);
        if (controller == null)
            controller = AnimatorController.CreateAnimatorControllerAtPath(ControllerPath);

        Dictionary<string, Motion> motionLookup = BuildMotionLookup();

        RepairController(controller, database, motionLookup);
        PurgeUnusedControllerSubAssets(controller);
        BindWorkbenchCatalog(controller);
        PruneObsoleteGeneratedClips(CollectReferencedGeneratedClipPaths(controller));

        EditorUtility.SetDirty(controller);
        AssetDatabase.SaveAssets();
        AssetDatabase.Refresh();

        Debug.Log(
            $"[EquipmentWorkbenchAnimatorControllerTool] 已生成/修复代码驱动状态机：{ControllerPath}，"
            + $"动作状态 {database.Items.Count} 个，参数 0 个，连线 0 条。");
    }

    static void RepairController(
        AnimatorController controller,
        AnimationTypeDatabase database,
        IReadOnlyDictionary<string, Motion> motionLookup)
    {
        while (controller.parameters.Length > 0)
            controller.RemoveParameter(controller.parameters[0]);

        if (controller.layers == null || controller.layers.Length == 0)
            controller.AddLayer("Base Layer");

        AnimatorControllerLayer[] layers = controller.layers;
        AnimatorControllerLayer layer = layers[0];
        AnimatorStateMachine stateMachine = layer.stateMachine;
        if (stateMachine == null)
        {
            stateMachine = new AnimatorStateMachine { name = "Base Layer" };
            AssetDatabase.AddObjectToAsset(stateMachine, controller);
            layer.stateMachine = stateMachine;
            layers[0] = layer;
            controller.layers = layers;
        }

        RemoveAllTransitions(stateMachine);

        List<string> desiredStateNames = BuildDesiredControllerStateNames(database, motionLookup);
        HashSet<string> desired = new HashSet<string>(desiredStateNames, StringComparer.Ordinal);

        foreach (ChildAnimatorState child in stateMachine.states.ToArray())
        {
            if (child.state != null && !desired.Contains(child.state.name))
                stateMachine.RemoveState(child.state);
        }

        Dictionary<string, AnimatorState> states = stateMachine.states
            .Where(child => child.state != null)
            .ToDictionary(child => child.state.name, child => child.state, StringComparer.Ordinal);

        int column = 0;
        int row = 0;
        foreach (string stateName in desiredStateNames)
        {
            if (!states.TryGetValue(stateName, out AnimatorState state))
            {
                state = stateMachine.AddState(stateName, new Vector3(column * 220f, row * 70f, 0f));
                states.Add(stateName, state);
                column++;
                if (column >= 4)
                {
                    column = 0;
                    row++;
                }
            }

            string actionName = StripDirectionSuffix(stateName);
            state.motion = ResolveMotion(stateName, motionLookup) ?? ResolveMotion(actionName, motionLookup);
            state.writeDefaultValues = true;
        }

        AnimatorState idleState = states.TryGetValue("Idle", out AnimatorState idle)
            ? idle
            : states.Values.FirstOrDefault();
        if (idleState != null)
            stateMachine.defaultState = idleState;

        RemoveAllTransitions(stateMachine);
    }

    static List<string> BuildDesiredControllerStateNames(
        AnimationTypeDatabase database,
        IReadOnlyDictionary<string, Motion> motionLookup)
    {
        List<string> stateNames = new List<string>();
        if (database == null)
            return stateNames;

        foreach (AnimationTypeItem item in database.Items
                     .Where(item => item != null && IsExplicitHumanAction(item.name))
                     .OrderBy(item => GetPlayerActionSortKey(item.name))
                     .ThenBy(item => item.name, StringComparer.Ordinal))
        {
            AddDesiredStateName(stateNames, item.name);

            for (int i = 0; i < WorkbenchDirectionSuffixes.Length; i++)
            {
                string directionalStateName = item.name + WorkbenchDirectionSuffixes[i];
                if (ResolveMotion(directionalStateName, motionLookup) != null)
                    AddDesiredStateName(stateNames, directionalStateName);
            }
        }

        return stateNames;
    }

    static void AddDesiredStateName(List<string> stateNames, string stateName)
    {
        if (string.IsNullOrWhiteSpace(stateName) || stateNames.Contains(stateName))
            return;

        stateNames.Add(stateName);
    }

    static Dictionary<string, Motion> BuildMotionLookup()
    {
        Dictionary<string, Motion> lookup = new Dictionary<string, Motion>(StringComparer.OrdinalIgnoreCase);
        AddHumanFrameDataMotions(lookup);

        string[] clipGuids = AssetDatabase.FindAssets("t:AnimationClip", MotionSearchRoots);
        foreach (string guid in clipGuids)
        {
            string path = AssetDatabase.GUIDToAssetPath(guid);
            if (!ShouldUseAnimationClipForMotion(path))
                continue;

            AnimationClip clip = AssetDatabase.LoadAssetAtPath<AnimationClip>(path);
            if (clip == null)
                continue;

            AddMotion(lookup, clip.name, clip);
            AddMotion(lookup, Path.GetFileNameWithoutExtension(path), clip);
        }

        string[] controllerGuids = AssetDatabase.FindAssets("t:AnimatorController", MotionSearchRoots);
        foreach (string guid in controllerGuids)
        {
            string path = AssetDatabase.GUIDToAssetPath(guid);
            if (!ShouldUseAnimatorControllerForMotion(path))
                continue;

            AnimatorController controller = AssetDatabase.LoadAssetAtPath<AnimatorController>(path);
            AddControllerMotions(lookup, controller);
        }

        string[] textureGuids = AssetDatabase.FindAssets("t:Texture2D", MotionSearchRoots);
        foreach (string guid in textureGuids)
        {
            string path = AssetDatabase.GUIDToAssetPath(guid);
            if (!ShouldUseSpriteForMotion(path))
                continue;

            string fileName = Path.GetFileNameWithoutExtension(path);
            string actionName = ExtractActionAlias(fileName);
            AddSourceSpriteClips("Human", fileName, actionName, path, lookup);
        }

        return lookup;
    }

    static void AddHumanFrameDataMotions(Dictionary<string, Motion> lookup)
    {
        CharacterFrameData frameData = AssetDatabase.LoadAssetAtPath<CharacterFrameData>(HumanFrameDataPath);
        if (frameData?.animations == null)
        {
            Debug.LogWarning($"[EquipmentWorkbenchAnimatorControllerTool] 找不到人类帧数据，主控制器将退回素材搜索: {HumanFrameDataPath}");
            return;
        }

        for (int i = 0; i < frameData.animations.Count; i++)
        {
            AnimationData animation = frameData.animations[i];
            if (animation?.animationType == null || animation.spritesheet == null)
                continue;

            AnimationClip clip = LoadOrCreateFrameDataClip("人类", animation, 0, string.Empty);
            if (clip != null)
                AddMotion(lookup, animation.animationType.name, clip, true);

            for (int directionIndex = 0; directionIndex < WorkbenchDirectionSuffixes.Length; directionIndex++)
            {
                string suffix = WorkbenchDirectionSuffixes[directionIndex];
                AnimationClip directionClip = LoadOrCreateFrameDataClip(
                    "人类",
                    animation,
                    directionIndex,
                    suffix);
                if (directionClip != null)
                    AddDirectionalMotion(lookup, animation.animationType.name + suffix, directionClip, true);
            }
        }
    }

    static void AddDirectionalMotion(Dictionary<string, Motion> lookup, string key, Motion motion, bool replaceExisting)
    {
        if (lookup == null || string.IsNullOrWhiteSpace(key) || motion == null || motion is BlendTree)
            return;

        foreach (string candidate in GetMotionKeyAliases(key))
        {
            if (!string.IsNullOrWhiteSpace(candidate) && !string.Equals(candidate, StripDirectionSuffix(candidate), StringComparison.OrdinalIgnoreCase))
                SetMotion(lookup, candidate, motion, replaceExisting);
        }
    }

    static void AddSourceSpriteClips(
        string sourceFolderName,
        string fileName,
        string actionName,
        string texturePath,
        Dictionary<string, Motion> lookup)
    {
        if (lookup == null || string.IsNullOrWhiteSpace(actionName))
            return;

        AnimationClip wholeClip = LoadOrCreateSourceSpriteClip(sourceFolderName, fileName, texturePath, null);
        if (wholeClip == null)
            return;

        AddMotion(lookup, fileName, wholeClip);
        AddMotion(lookup, actionName, wholeClip);

        int directionCount = GetSourceDirectionCount(texturePath);
        for (int i = 0; i < WorkbenchDirectionSuffixes.Length && i < directionCount; i++)
        {
            string suffix = WorkbenchDirectionSuffixes[i];
            AnimationClip directionClip = LoadOrCreateSourceSpriteClip(sourceFolderName, fileName + suffix, texturePath, i);
            if (directionClip == null)
                continue;

            AddMotion(lookup, fileName + suffix, directionClip);
            AddMotion(lookup, actionName + suffix, directionClip);
        }
    }

    static void AddControllerMotions(Dictionary<string, Motion> lookup, AnimatorController controller)
    {
        if (controller == null)
            return;

        foreach (AnimatorControllerLayer layer in controller.layers)
        {
            if (layer?.stateMachine == null)
                continue;

            AddStateMachineMotions(lookup, layer.stateMachine);
        }
    }

    static void AddStateMachineMotions(Dictionary<string, Motion> lookup, AnimatorStateMachine stateMachine)
    {
        foreach (ChildAnimatorState child in stateMachine.states)
        {
            if (child.state == null || child.state.motion == null)
                continue;
            if (child.state.motion is BlendTree)
                continue;

            AddMotion(lookup, child.state.name, child.state.motion);
            AddMotion(lookup, child.state.motion.name, child.state.motion);
        }

        foreach (ChildAnimatorStateMachine child in stateMachine.stateMachines)
        {
            if (child.stateMachine != null)
                AddStateMachineMotions(lookup, child.stateMachine);
        }
    }

    static void AddMotion(Dictionary<string, Motion> lookup, string key, Motion motion)
    {
        AddMotion(lookup, key, motion, false);
    }

    static void AddMotion(Dictionary<string, Motion> lookup, string key, Motion motion, bool replaceExisting)
    {
        if (string.IsNullOrWhiteSpace(key) || motion == null)
            return;
        if (motion is BlendTree)
            return;

        foreach (string candidate in GetMotionKeyAliases(key))
        {
            if (!string.IsNullOrWhiteSpace(candidate))
                SetMotion(lookup, candidate, motion, replaceExisting);
        }

        string directionSuffix = ExtractDirectionSuffix(key);
        string actionAlias = ExtractActionAlias(key);
        if (string.IsNullOrWhiteSpace(directionSuffix) || string.IsNullOrWhiteSpace(actionAlias))
            return;

        foreach (string candidate in GetMotionKeyAliases(actionAlias))
        {
            string directionalCandidate = candidate + directionSuffix;
            if (!string.IsNullOrWhiteSpace(directionalCandidate))
                SetMotion(lookup, directionalCandidate, motion, replaceExisting);
        }
    }

    static void SetMotion(
        IDictionary<string, Motion> lookup,
        string key,
        Motion motion,
        bool replaceExisting)
    {
        if (lookup == null || string.IsNullOrWhiteSpace(key) || motion == null)
            return;

        if (replaceExisting)
            lookup[key] = motion;
        else if (!lookup.ContainsKey(key))
            lookup.Add(key, motion);
    }

    static Motion ResolveMotion(string actionName, IReadOnlyDictionary<string, Motion> motionLookup)
    {
        foreach (string candidate in GetMotionCandidates(actionName))
        {
            if (motionLookup.TryGetValue(candidate, out Motion motion) && motion != null)
                return motion;
        }

        return null;
    }

    static IEnumerable<string> GetMotionCandidates(string actionName)
    {
        yield return actionName;
        yield return CanonicalizeActionName(actionName);

        if (string.Equals(actionName, "Die", StringComparison.OrdinalIgnoreCase))
        {
            yield return "SoulDie";
            yield return "SpinDie";
            yield return "DieSoul";
            yield return "DieSpin";
        }
    }

    static IEnumerable<string> GetMotionKeyAliases(string key)
    {
        yield return key;

        string normalized = NormalizeMotionKey(key);
        if (!string.Equals(normalized, key, StringComparison.OrdinalIgnoreCase))
            yield return normalized;

        string canonical = CanonicalizeActionName(normalized);
        if (!string.Equals(canonical, normalized, StringComparison.OrdinalIgnoreCase))
            yield return canonical;

        foreach (string token in SplitMotionNameTokens(key))
        {
            yield return token;
            string tokenCanonical = CanonicalizeActionName(token);
            if (!string.Equals(tokenCanonical, token, StringComparison.OrdinalIgnoreCase))
                yield return tokenCanonical;
        }
    }

    static string NormalizeMotionKey(string key)
    {
        if (string.IsNullOrWhiteSpace(key))
            return key;

        const string blendTreeSuffix = " Blend Tree";
        if (key.EndsWith(blendTreeSuffix, StringComparison.OrdinalIgnoreCase))
            key = key.Substring(0, key.Length - blendTreeSuffix.Length);

        foreach (string suffix in DirectionSuffixes)
        {
            if (key.EndsWith(suffix, StringComparison.OrdinalIgnoreCase))
            {
                key = key.Substring(0, key.Length - suffix.Length);
                break;
            }
        }

        int underscore = key.LastIndexOf('_');
        if (underscore >= 0 && underscore < key.Length - 1)
            key = key.Substring(underscore + 1);

        return key;
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

    static string ExtractDirectionSuffix(string value)
    {
        if (string.IsNullOrWhiteSpace(value))
            return null;

        string normalized = value.Replace('\\', '/');
        normalized = Path.GetFileNameWithoutExtension(normalized);
        foreach (string suffix in DirectionSuffixes)
        {
            if (normalized.EndsWith(suffix, StringComparison.OrdinalIgnoreCase))
                return suffix;
        }

        return null;
    }

    static string SanitizeAssetFileName(string value)
    {
        char[] invalid = Path.GetInvalidFileNameChars();
        char[] chars = value.Select(ch => invalid.Contains(ch) ? '_' : ch).ToArray();
        return new string(chars);
    }

    static IEnumerable<string> SplitMotionNameTokens(string key)
    {
        if (string.IsNullOrWhiteSpace(key))
            yield break;

        string normalized = key.Replace('\\', '/');
        normalized = Path.GetFileNameWithoutExtension(normalized);

        foreach (string suffix in DirectionSuffixes)
        {
            if (normalized.EndsWith(suffix, StringComparison.OrdinalIgnoreCase))
            {
                normalized = normalized.Substring(0, normalized.Length - suffix.Length);
                break;
            }
        }

        string[] separators = { "_", "-", " " };
        foreach (string part in normalized.Split(separators, StringSplitOptions.RemoveEmptyEntries))
        {
            string cleaned = CanonicalizeActionName(part.Trim());
            if (!string.IsNullOrWhiteSpace(cleaned))
                yield return cleaned;
        }

        int underscore = normalized.LastIndexOf('_');
        if (underscore >= 0 && underscore < normalized.Length - 1)
        {
            string trailing = normalized.Substring(underscore + 1);
            if (!string.IsNullOrWhiteSpace(trailing))
                yield return CanonicalizeActionName(trailing);
        }
    }

    static string RemovePrefix(string value, string prefix)
    {
        if (string.IsNullOrWhiteSpace(value)
            || string.IsNullOrWhiteSpace(prefix)
            || !value.StartsWith(prefix, StringComparison.OrdinalIgnoreCase)
            || value.Length <= prefix.Length)
        {
            return value;
        }

        return value.Substring(prefix.Length);
    }

    static string CanonicalizeActionName(string actionName)
    {
        if (string.Equals(actionName, "DieSoul", StringComparison.OrdinalIgnoreCase))
            return "SoulDie";
        if (string.Equals(actionName, "DieSpin", StringComparison.OrdinalIgnoreCase))
            return "SpinDie";
        if (string.Equals(actionName, "Damage", StringComparison.OrdinalIgnoreCase))
            return "Dmg";
        if (actionName.StartsWith("is", StringComparison.Ordinal)
            && actionName.Length > 2
            && char.IsUpper(actionName[2]))
        {
            return actionName.Substring(2);
        }

        return actionName;
    }

    static bool ShouldUseAnimatorControllerForMotion(string path)
    {
        string normalized = path.Replace('\\', '/');
        return IsHumanDungeonAnimationPath(normalized)
            || IsCraftingProfessionHumanAnimationPath(normalized)
            || IsHumanCreatureAnimationPath(normalized);
    }

    static bool ShouldUseAnimationClipForMotion(string path)
    {
        string normalized = path.Replace('\\', '/');
        if (IsNonPlayerMotionPath(normalized))
            return false;

        return IsCraftingProfessionHumanAnimationPath(normalized)
            || IsHumanCreatureAnimationPath(normalized);
    }

    static bool ShouldUseSpriteForMotion(string path)
    {
        string normalized = path.Replace('\\', '/');
        if (IsNonPlayerMotionPath(normalized))
            return false;

        string fileName = Path.GetFileNameWithoutExtension(normalized);
        if (IsCraftingProfessionPlayerSpritePath(normalized))
            return ExplicitHumanPlayerSpriteActionFiles.Contains(fileName)
                && IsExplicitHumanAction(ExtractActionAlias(fileName));

        return IsHumanCreatureSpritePath(normalized)
            && IsSpeciesActionFile(fileName, "Human")
            && IsExplicitHumanAction(ExtractActionAlias(fileName));
    }

    static bool IsHumanDungeonAnimationPath(string normalizedPath)
    {
        return normalizedPath.IndexOf(
            "/KrishnaPalacio/MINIFANTASY - Dungeon/Animation/Human/",
            StringComparison.OrdinalIgnoreCase) >= 0;
    }

    static bool IsCraftingProfessionPlayerSpritePath(string normalizedPath)
    {
        return normalizedPath.IndexOf(
            "/MINIFANTASY - Crafting and Professions I/Sprites/",
            StringComparison.OrdinalIgnoreCase) >= 0
            && (normalizedPath.IndexOf("/Characters/", StringComparison.OrdinalIgnoreCase) >= 0
                || normalizedPath.IndexOf("/Character/", StringComparison.OrdinalIgnoreCase) >= 0);
    }

    static bool IsCraftingProfessionHumanAnimationPath(string normalizedPath)
    {
        return normalizedPath.IndexOf(
            "/MINIFANTASY - Crafting and Professions I/Animations/Humanoids/Human/",
            StringComparison.OrdinalIgnoreCase) >= 0;
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

        return IsExplicitHumanAction(ExtractActionAlias(fileName));
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

    static bool IsNonPlayerMotionPath(string normalizedPath)
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

    static bool IsExplicitHumanAction(string actionName)
    {
        return !string.IsNullOrWhiteSpace(actionName)
            && ExplicitHumanActionKeys.Contains(CanonicalizeActionName(actionName));
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

    static void RemoveAllTransitions(AnimatorStateMachine stateMachine)
    {
        foreach (AnimatorStateTransition transition in stateMachine.anyStateTransitions.ToArray())
            stateMachine.RemoveAnyStateTransition(transition);

        foreach (AnimatorTransition transition in stateMachine.entryTransitions.ToArray())
            stateMachine.RemoveEntryTransition(transition);

        foreach (ChildAnimatorState child in stateMachine.states)
        {
            if (child.state == null)
                continue;

            foreach (AnimatorStateTransition transition in child.state.transitions.ToArray())
                child.state.RemoveTransition(transition);
        }
    }

    static void PurgeUnusedControllerSubAssets(AnimatorController controller)
    {
        if (controller == null)
            return;

        string controllerPath = AssetDatabase.GetAssetPath(controller);
        if (string.IsNullOrWhiteSpace(controllerPath))
            return;

        HashSet<UnityEngine.Object> used = new HashSet<UnityEngine.Object> { controller };
        foreach (AnimatorControllerLayer layer in controller.layers)
        {
            if (layer?.stateMachine != null)
                CollectUsedControllerSubAssets(layer.stateMachine, controllerPath, used);
        }

        UnityEngine.Object[] assets = AssetDatabase.LoadAllAssetsAtPath(controllerPath);
        for (int i = assets.Length - 1; i >= 0; i--)
        {
            UnityEngine.Object asset = assets[i];
            if (asset == null || used.Contains(asset))
                continue;

            if (AssetDatabase.GetAssetPath(asset) == controllerPath)
                UnityEngine.Object.DestroyImmediate(asset, true);
        }
    }

    static void PruneObsoleteGeneratedClips()
    {
        PruneObsoleteGeneratedClips(null);
    }

    static void PruneObsoleteGeneratedClips(ISet<string> referencedClipPaths)
    {
        if (!AssetDatabase.IsValidFolder(GeneratedClipRoot))
            return;

        DeleteObsoleteGeneratedClipFiles(referencedClipPaths);

        string[] clipGuids = AssetDatabase.FindAssets("t:AnimationClip", new[] { GeneratedClipRoot });
        for (int i = 0; i < clipGuids.Length; i++)
        {
            string path = AssetDatabase.GUIDToAssetPath(clipGuids[i]);
            if (ShouldDeleteGeneratedClip(path, referencedClipPaths))
                AssetDatabase.DeleteAsset(path);
        }
    }

    static void DeleteObsoleteGeneratedClipFiles(ISet<string> referencedClipPaths)
    {
        string rootPath = Path.Combine(Application.dataPath, "GameData/EquipmentSystem/Animations/GeneratedClips")
            .Replace('\\', '/');
        if (!Directory.Exists(rootPath))
            return;

        foreach (string file in Directory.GetFiles(rootPath, "*.anim", SearchOption.AllDirectories))
        {
            string normalizedFile = file.Replace('\\', '/');
            int assetsIndex = normalizedFile.IndexOf("/Assets/", StringComparison.OrdinalIgnoreCase);
            string assetPath = assetsIndex >= 0
                ? normalizedFile.Substring(assetsIndex + 1)
                : normalizedFile;
            if (!ShouldDeleteGeneratedClip(assetPath, referencedClipPaths))
                continue;

            AssetDatabase.DeleteAsset(assetPath);
        }
    }

    static bool ShouldDeleteGeneratedClip(
        string path,
        ISet<string> referencedClipPaths)
    {
        if (string.IsNullOrWhiteSpace(path))
            return false;

        string normalized = path.Replace('\\', '/');
        string root = GeneratedClipRoot + "/";
        if (!normalized.StartsWith(root, StringComparison.OrdinalIgnoreCase))
            return false;

        if (referencedClipPaths != null)
            return !referencedClipPaths.Contains(normalized);

        string relative = normalized.Substring(root.Length);
        if (relative.IndexOf('/') < 0)
            return true;

        if (!relative.StartsWith("SourceSprites/Human/", StringComparison.OrdinalIgnoreCase))
            return false;

        string fileName = Path.GetFileNameWithoutExtension(relative);
        return fileName.StartsWith("Minifantasy_Creatures", StringComparison.OrdinalIgnoreCase)
            && (!fileName.StartsWith("Minifantasy_CreaturesHuman", StringComparison.OrdinalIgnoreCase)
                || fileName.StartsWith("Minifantasy_CreaturesHumanTownsfolk", StringComparison.OrdinalIgnoreCase));
    }

    static HashSet<string> CollectReferencedGeneratedClipPaths(AnimatorController baseController)
    {
        HashSet<string> referenced = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        AddReferencedGeneratedClipPaths(baseController, referenced);

        if (AssetDatabase.IsValidFolder(GeneratedOverrideRoot))
        {
            string[] overrideGuids = AssetDatabase.FindAssets("t:AnimatorOverrideController", new[] { GeneratedOverrideRoot });
            for (int i = 0; i < overrideGuids.Length; i++)
            {
                string overridePath = AssetDatabase.GUIDToAssetPath(overrideGuids[i]);
                AnimatorOverrideController overrideController =
                    AssetDatabase.LoadAssetAtPath<AnimatorOverrideController>(overridePath);
                AddReferencedGeneratedClipPaths(overrideController, referenced);
            }
        }

        return referenced;
    }

    static void AddReferencedGeneratedClipPaths(
        RuntimeAnimatorController controller,
        ISet<string> referenced)
    {
        if (controller == null || referenced == null)
            return;

        AnimationClip[] clips = controller.animationClips;
        for (int i = 0; i < clips.Length; i++)
        {
            string path = AssetDatabase.GetAssetPath(clips[i]).Replace('\\', '/');
            if (!string.IsNullOrWhiteSpace(path)
                && path.StartsWith(GeneratedClipRoot + "/", StringComparison.OrdinalIgnoreCase))
            {
                referenced.Add(path);
            }
        }
    }

    static void CollectUsedControllerSubAssets(
        AnimatorStateMachine stateMachine,
        string controllerPath,
        ISet<UnityEngine.Object> used)
    {
        if (stateMachine == null || used == null || used.Contains(stateMachine))
            return;

        used.Add(stateMachine);
        foreach (ChildAnimatorState child in stateMachine.states)
        {
            if (child.state == null)
                continue;

            used.Add(child.state);
            CollectUsedControllerMotion(child.state.motion, controllerPath, used);
        }

        foreach (ChildAnimatorStateMachine child in stateMachine.stateMachines)
        {
            if (child.stateMachine != null)
                CollectUsedControllerSubAssets(child.stateMachine, controllerPath, used);
        }
    }

    static void CollectUsedControllerMotion(
        Motion motion,
        string controllerPath,
        ISet<UnityEngine.Object> used)
    {
        if (motion == null || used == null || used.Contains(motion))
            return;

        if (!string.Equals(AssetDatabase.GetAssetPath(motion), controllerPath, StringComparison.Ordinal))
            return;

        used.Add(motion);
        if (motion is BlendTree blendTree)
        {
            foreach (ChildMotion child in blendTree.children)
                CollectUsedControllerMotion(child.motion, controllerPath, used);
        }
    }

    static void BindWorkbenchCatalog(AnimatorController controller)
    {
        var catalog = AssetDatabase.LoadAssetAtPath<EquipmentWorkbenchCatalog>(WorkbenchCatalogPath);
        if (catalog == null)
            return;

        SerializedObject serializedCatalog = new SerializedObject(catalog);
        SerializedProperty characters = serializedCatalog.FindProperty("characters");
        if (characters == null || !characters.isArray)
            return;

        for (int i = 0; i < characters.arraySize; i++)
        {
            SerializedProperty character = characters.GetArrayElementAtIndex(i);
            SerializedProperty controllerProperty = character.FindPropertyRelative("animatorController");
            if (controllerProperty == null)
                continue;

            string displayName = character.FindPropertyRelative("displayName")?.stringValue;
            SerializedProperty frameDataProperty = character.FindPropertyRelative("frameData");
            CharacterFrameData frameData = frameDataProperty?.objectReferenceValue as CharacterFrameData;
            controllerProperty.objectReferenceValue = ResolveCharacterController(displayName, frameData, controller);
        }

        serializedCatalog.ApplyModifiedPropertiesWithoutUndo();
        EditorUtility.SetDirty(catalog);
    }

    static RuntimeAnimatorController ResolveCharacterController(
        string displayName,
        CharacterFrameData frameData,
        AnimatorController humanController)
    {
        if (!string.Equals(displayName, "人类", StringComparison.Ordinal)
            && frameData != null)
        {
            RuntimeAnimatorController overrideController =
                CreateOrUpdateProjectOverrideController(displayName, frameData, humanController);
            if (overrideController != null)
                return overrideController;
        }

        return humanController;
    }

    static AnimatorOverrideController CreateOrUpdateProjectOverrideController(
        string displayName,
        CharacterFrameData frameData,
        AnimatorController baseController)
    {
        if (string.IsNullOrWhiteSpace(displayName) || frameData == null || baseController == null)
            return null;

        string generatedAssetName = $"换装{displayName}覆盖控制器";
        string targetPath = $"{GeneratedOverrideRoot}/{generatedAssetName}.overrideController";
        AnimatorOverrideController projectOverride =
            AssetDatabase.LoadAssetAtPath<AnimatorOverrideController>(targetPath);
        if (projectOverride == null)
        {
            projectOverride = new AnimatorOverrideController { name = generatedAssetName };
            AssetDatabase.CreateAsset(projectOverride, targetPath);
        }

        projectOverride.runtimeAnimatorController = baseController;

        Dictionary<string, AnimationClip> frameDataClips = BuildFrameDataClipLookup(displayName, frameData);
        List<KeyValuePair<AnimationClip, AnimationClip>> overrides =
            new List<KeyValuePair<AnimationClip, AnimationClip>>();
        projectOverride.GetOverrides(overrides);

        for (int i = 0; i < overrides.Count; i++)
        {
            AnimationClip originalClip = overrides[i].Key;
            AnimationClip replacement = ResolveOverrideClip(originalClip, frameDataClips);
            overrides[i] = new KeyValuePair<AnimationClip, AnimationClip>(
                originalClip,
                replacement != null ? replacement : originalClip);
        }

        projectOverride.ApplyOverrides(overrides);
        EditorUtility.SetDirty(projectOverride);
        return projectOverride;
    }

    static Dictionary<string, AnimationClip> BuildFrameDataClipLookup(
        string displayName,
        CharacterFrameData frameData)
    {
        Dictionary<string, AnimationClip> lookup =
            new Dictionary<string, AnimationClip>(StringComparer.OrdinalIgnoreCase);
        if (frameData?.animations == null)
            return lookup;

        for (int i = 0; i < frameData.animations.Count; i++)
        {
            AnimationData animation = frameData.animations[i];
            if (animation?.animationType == null || animation.spritesheet == null)
                continue;

            AnimationClip clip = LoadOrCreateFrameDataClip(displayName, animation, 0, string.Empty);
            if (clip != null)
                AddClipAlias(lookup, animation.animationType.name, clip);

            for (int directionIndex = 0; directionIndex < WorkbenchDirectionSuffixes.Length; directionIndex++)
            {
                string suffix = WorkbenchDirectionSuffixes[directionIndex];
                AnimationClip directionClip = LoadOrCreateFrameDataClip(
                    displayName,
                    animation,
                    directionIndex,
                    suffix);
                if (directionClip != null)
                    AddClipAlias(lookup, animation.animationType.name + suffix, directionClip);
            }
        }

        AddSpeciesProfessionSpriteClips(displayName, lookup);

        return lookup;
    }

    static AnimationClip ResolveOverrideClip(
        AnimationClip originalClip,
        IReadOnlyDictionary<string, AnimationClip> sourceOverrides)
    {
        if (originalClip == null || sourceOverrides == null)
            return null;

        foreach (string candidate in GetMotionKeyAliases(originalClip.name))
        {
            if (sourceOverrides.TryGetValue(candidate, out AnimationClip clip) && clip != null)
                return clip;
        }

        foreach (string fallback in GetOverrideFallbackCandidates(originalClip.name))
        {
            if (sourceOverrides.TryGetValue(fallback, out AnimationClip clip) && clip != null)
                return clip;
        }

        return null;
    }

    static IEnumerable<string> GetOverrideFallbackCandidates(string originalClipName)
    {
        string actionName = ExtractActionAlias(originalClipName);
        if (string.IsNullOrWhiteSpace(actionName))
            actionName = NormalizeMotionKey(originalClipName);

        actionName = CanonicalizeActionName(actionName);
        if (!string.IsNullOrWhiteSpace(actionName))
            yield return actionName;

        if (string.Equals(actionName, "Wait", StringComparison.OrdinalIgnoreCase))
        {
            yield return "Idle";
        }
        else if (string.Equals(actionName, "SoulDie", StringComparison.OrdinalIgnoreCase)
                 || string.Equals(actionName, "DieSoul", StringComparison.OrdinalIgnoreCase))
        {
            yield return "SpinDie";
            yield return "Die";
        }
        else if (string.Equals(actionName, "SpinDie", StringComparison.OrdinalIgnoreCase)
                 || string.Equals(actionName, "DieSpin", StringComparison.OrdinalIgnoreCase))
        {
            yield return "Die";
            yield return "SoulDie";
        }
        else if (string.Equals(actionName, "Die", StringComparison.OrdinalIgnoreCase))
        {
            yield return "SpinDie";
            yield return "SoulDie";
        }
    }

    static void AddSpeciesProfessionSpriteClips(
        string displayName,
        IDictionary<string, AnimationClip> lookup)
    {
        string prefix = ResolveSpeciesPrefix(displayName);
        if (string.IsNullOrWhiteSpace(prefix))
            return;

        string[] textureGuids = AssetDatabase.FindAssets("t:Texture2D", MotionSearchRoots);
        foreach (string guid in textureGuids)
        {
            string path = AssetDatabase.GUIDToAssetPath(guid);
            string normalized = path.Replace('\\', '/');
            if (!IsSpeciesPlayerSpritePath(normalized, prefix))
                continue;
            if (IsNonPlayerMotionPath(normalized))
                continue;

            string fileName = Path.GetFileNameWithoutExtension(path);
            if (!IsSpeciesActionFile(fileName, prefix))
                continue;

            string actionName = ExtractActionAlias(fileName);
            if (string.IsNullOrWhiteSpace(actionName))
                continue;

            AddSpeciesSourceSpriteClips(prefix, fileName, actionName, path, lookup);
        }
    }

    static void AddSpeciesSourceSpriteClips(
        string sourceFolderName,
        string fileName,
        string actionName,
        string texturePath,
        IDictionary<string, AnimationClip> lookup)
    {
        if (lookup == null || string.IsNullOrWhiteSpace(actionName))
            return;

        AnimationClip wholeClip = LoadOrCreateSourceSpriteClip(sourceFolderName, fileName, texturePath, null);
        if (wholeClip == null)
            return;

        AddClipAlias(lookup, actionName, wholeClip);

        int directionCount = GetSourceDirectionCount(texturePath);
        for (int i = 0; i < WorkbenchDirectionSuffixes.Length && i < directionCount; i++)
        {
            string suffix = WorkbenchDirectionSuffixes[i];
            AnimationClip directionClip = LoadOrCreateSourceSpriteClip(sourceFolderName, fileName + suffix, texturePath, i);
            if (directionClip != null)
                AddClipAlias(lookup, actionName + suffix, directionClip);
        }
    }

    static string ResolveSpeciesPrefix(string displayName)
    {
        switch (displayName)
        {
            case "人类":
                return "Human";
            case "精灵":
                return "Elf";
            case "矮人":
                return "Dwarf";
            case "地精":
                return "Goblin";
            case "兽人":
                return "Orc";
            case "半身人":
                return "Halfling";
            default:
                return null;
        }
    }

    static bool IsSpeciesPlayerSpritePath(string normalizedPath, string prefix)
    {
        if (IsCraftingProfessionPlayerSpritePath(normalizedPath))
            return normalizedPath.IndexOf(
                $"/{prefix}_",
                StringComparison.OrdinalIgnoreCase) >= 0;

        string speciesFolder = ResolveCreaturesSpeciesFolder(prefix);
        if (string.IsNullOrWhiteSpace(speciesFolder))
            return false;

        return normalizedPath.IndexOf(
            $"/MINIFANTASY Creatures - Super Low Res 2D Pixel Art by Krishna Palacio/Sprites/Humanoids/{speciesFolder}/",
            StringComparison.OrdinalIgnoreCase) >= 0;
    }

    static string ResolveCreaturesSpeciesFolder(string prefix)
    {
        switch (prefix)
        {
            case "Human":
                return "Human/Human";
            case "Elf":
                return "Elf/Elf";
            case "Dwarf":
                return "Dwarf/Dwarf";
            case "Goblin":
                return "Goblin/Goblin";
            case "Halfling":
                return "Halfling/Halfling";
            case "Orc":
                return "Orc/Orc";
            default:
                return null;
        }
    }

    static bool IsSpeciesActionFile(string fileName, string prefix)
    {
        if (TryGetExplicitSpeciesSpriteAction(fileName, prefix, out string explicitAction))
            return IsExplicitHumanAction(explicitAction);

        if (fileName.StartsWith(prefix + "_", StringComparison.OrdinalIgnoreCase))
            return IsExplicitHumanAction(ExtractActionAlias(fileName));

        string creaturesPrefix = $"Minifantasy_Creatures{prefix}";
        if (fileName.StartsWith(creaturesPrefix, StringComparison.OrdinalIgnoreCase))
            return SpeciesSpriteActionSuffixes.Any(suffix =>
                string.Equals(
                    fileName,
                    creaturesPrefix + suffix,
                    StringComparison.OrdinalIgnoreCase))
                && IsExplicitHumanAction(ExtractActionAlias(fileName));

        return false;
    }

    static bool TryGetExplicitSpeciesSpriteAction(string fileName, string prefix, out string actionName)
    {
        actionName = null;
        if (string.IsNullOrWhiteSpace(fileName)
            || string.IsNullOrWhiteSpace(prefix))
        {
            return false;
        }

        if (string.Equals(prefix, "Human", StringComparison.OrdinalIgnoreCase)
            && string.Equals(fileName, "Slash_Character_human", StringComparison.OrdinalIgnoreCase))
        {
            actionName = "SlashAttack";
            return true;
        }

        return false;
    }

    static AnimationClip LoadOrCreateSourceSpriteClip(
        string sourceFolderName,
        string fileName,
        string texturePath,
        int? directionRow)
    {
        string actionName = ExtractActionAlias(fileName);
        if (string.IsNullOrWhiteSpace(sourceFolderName)
            || string.IsNullOrWhiteSpace(fileName)
            || string.IsNullOrWhiteSpace(actionName)
            || string.IsNullOrWhiteSpace(texturePath))
        {
            return null;
        }

        string sourceFolder = $"{GeneratedClipRoot}/SourceSprites/{SanitizeAssetFileName(sourceFolderName)}";
        EnsureFolder(sourceFolder);

        string clipPath = $"{sourceFolder}/{SanitizeAssetFileName(fileName)}.anim";
        AnimationClip clip = AssetDatabase.LoadAssetAtPath<AnimationClip>(clipPath);
        if (clip == null)
        {
            clip = new AnimationClip { name = fileName };
            AssetDatabase.CreateAsset(clip, clipPath);
        }

        Sprite[] sprites = LoadOrderedSprites(texturePath);
        if (sprites.Length == 0)
            return null;

        if (directionRow.HasValue)
            sprites = SelectSpritesForDirectionRow(sprites, directionRow.Value);
        if (sprites.Length == 0)
            return null;

        clip.name = fileName;
        clip.frameRate = 8f;
        ApplySpriteCurve(clip, sprites);

        AnimationClipSettings settings = AnimationUtility.GetAnimationClipSettings(clip);
        settings.loopTime = IsLoopingAction(actionName);
        AnimationUtility.SetAnimationClipSettings(clip, settings);

        EditorUtility.SetDirty(clip);
        return clip;
    }

    static Sprite[] LoadOrderedSprites(string texturePath)
    {
        Sprite[] allSprites = AssetDatabase.LoadAllAssetRepresentationsAtPath(texturePath)
            .OfType<Sprite>()
            .Where(IsUsableAnimationFrameSprite)
            .ToArray();
        if (allSprites.Length == 0)
            return Array.Empty<Sprite>();

        return allSprites
            .OrderBy(sprite => TryGetTrailingNumber(sprite.name, out int index) ? index : int.MaxValue)
            .ThenBy(sprite => sprite.rect.y)
            .ThenBy(sprite => sprite.rect.x)
            .ToArray();
    }

    static int GetSourceDirectionCount(string texturePath)
    {
        Sprite[] sprites = LoadOrderedSprites(texturePath);
        if (sprites.Length == 0)
            return 0;

        return sprites
            .Select(sprite => Mathf.RoundToInt(sprite.rect.y))
            .Distinct()
            .Count();
    }

    static Sprite[] SelectSpritesForDirectionRow(Sprite[] sprites, int directionRow)
    {
        if (sprites == null || sprites.Length == 0 || directionRow < 0)
            return Array.Empty<Sprite>();

        List<IGrouping<int, Sprite>> rows = sprites
            .GroupBy(sprite => Mathf.RoundToInt(sprite.rect.y))
            .OrderByDescending(row => row.Key)
            .ToList();
        if (directionRow >= rows.Count)
            return Array.Empty<Sprite>();

        return rows[directionRow]
            .OrderBy(sprite => sprite.rect.x)
            .ToArray();
    }

    static bool IsUsableAnimationFrameSprite(Sprite sprite)
    {
        if (sprite == null)
            return false;

        string spriteName = sprite.name ?? string.Empty;
        if (spriteName.StartsWith("Menu_", StringComparison.OrdinalIgnoreCase))
            return false;

        if (sprite.rect.width < 16f || sprite.rect.height < 16f)
            return false;

        return true;
    }

    static bool MatchesAnimationFrameSize(Sprite sprite, int frameWidth, int frameHeight)
    {
        if (!IsUsableAnimationFrameSprite(sprite))
            return false;

        return Mathf.RoundToInt(sprite.rect.width) == frameWidth
            && Mathf.RoundToInt(sprite.rect.height) == frameHeight;
    }

    static bool TryGetTrailingNumber(string value, out int number)
    {
        number = 0;
        if (string.IsNullOrWhiteSpace(value))
            return false;

        int underscore = value.LastIndexOf('_');
        if (underscore < 0 || underscore >= value.Length - 1)
            return false;

        return int.TryParse(value.Substring(underscore + 1), out number);
    }

    static void ApplySpriteCurve(AnimationClip clip, Sprite[] sprites)
    {
        EditorCurveBinding binding = new EditorCurveBinding
        {
            path = string.Empty,
            type = typeof(SpriteRenderer),
            propertyName = "m_Sprite"
        };

        ObjectReferenceKeyframe[] keyframes = new ObjectReferenceKeyframe[sprites.Length];
        for (int i = 0; i < sprites.Length; i++)
        {
            keyframes[i] = new ObjectReferenceKeyframe
            {
                time = i / clip.frameRate,
                value = sprites[i]
            };
        }

        AnimationUtility.SetObjectReferenceCurve(clip, binding, keyframes);
    }

    static AnimationClip LoadOrCreateFrameDataClip(string displayName, AnimationData animation)
    {
        return LoadOrCreateFrameDataClip(displayName, animation, null, string.Empty);
    }

    static AnimationClip LoadOrCreateFrameDataClip(
        string displayName,
        AnimationData animation,
        int? directionRow,
        string suffix)
    {
        if (animation?.animationType == null || animation.spritesheet == null)
            return null;

        string characterFolder = $"{GeneratedClipRoot}/{SanitizeAssetFileName(displayName)}";
        EnsureFolder(characterFolder);

        string actionName = animation.animationType.name;
        string clipName = $"{displayName}_{actionName}{suffix}";
        string clipPath = $"{characterFolder}/{SanitizeAssetFileName(clipName)}.anim";
        AnimationClip clip = AssetDatabase.LoadAssetAtPath<AnimationClip>(clipPath);
        if (clip == null)
        {
            clip = new AnimationClip { name = clipName };
            AssetDatabase.CreateAsset(clip, clipPath);
        }

        Sprite[] sprites = BuildSpritesForAnimation(animation, directionRow);
        if (sprites.Length == 0)
            return null;

        clip.name = clipName;
        clip.frameRate = 8f;

        ApplySpriteCurve(clip, sprites);

        AnimationClipSettings settings = AnimationUtility.GetAnimationClipSettings(clip);
        settings.loopTime = IsLoopingAction(actionName);
        AnimationUtility.SetAnimationClipSettings(clip, settings);

        EditorUtility.SetDirty(clip);
        return clip;
    }

    static Sprite[] BuildSpritesForAnimation(AnimationData animation)
    {
        return BuildSpritesForAnimation(animation, null);
    }

    static Sprite[] BuildSpritesForAnimation(AnimationData animation, int? directionRow)
    {
        Sprite[] allSprites = AssetDatabase.LoadAllAssetRepresentationsAtPath(
                AssetDatabase.GetAssetPath(animation.spritesheet))
            .OfType<Sprite>()
            .ToArray();
        if (allSprites.Length == 0)
            return Array.Empty<Sprite>();

        Dictionary<string, Sprite> spritesByCell =
            new Dictionary<string, Sprite>(StringComparer.OrdinalIgnoreCase);
        int frameWidth = Mathf.Max(1, animation.frameSize.x);
        int frameHeight = Mathf.Max(1, animation.frameSize.y);
        allSprites = allSprites
            .Where(sprite => MatchesAnimationFrameSize(sprite, frameWidth, frameHeight))
            .ToArray();
        if (allSprites.Length == 0)
            return Array.Empty<Sprite>();

        int textureHeight = animation.spritesheet.height;
        for (int i = 0; i < allSprites.Length; i++)
        {
            Sprite sprite = allSprites[i];
            int frameIndex = Mathf.RoundToInt(sprite.rect.x / frameWidth);
            int rowIndex = Mathf.RoundToInt((textureHeight - sprite.rect.y - sprite.rect.height) / frameHeight);
            string key = GetCellKey(frameIndex, rowIndex);
            if (!spritesByCell.ContainsKey(key))
                spritesByCell.Add(key, sprite);
        }

        List<Sprite> ordered = new List<Sprite>();
        if (animation.frames != null && animation.frames.Count > 0)
        {
            IEnumerable<FrameData> sourceFrames = animation.frames.Where(frame => frame != null);
            if (directionRow.HasValue)
                sourceFrames = sourceFrames.Where(frame => frame.rowIndex == directionRow.Value);

            foreach (FrameData frame in sourceFrames
                         .OrderBy(frame => frame.rowIndex)
                         .ThenBy(frame => frame.frameIndex))
            {
                if (spritesByCell.TryGetValue(GetCellKey(frame.frameIndex, frame.rowIndex), out Sprite sprite))
                    ordered.Add(sprite);
            }
        }

        if (ordered.Count > 0)
            return ordered.ToArray();

        IEnumerable<Sprite> fallbackSprites = allSprites;
        if (directionRow.HasValue)
        {
            fallbackSprites = fallbackSprites.Where(sprite =>
                Mathf.RoundToInt((textureHeight - sprite.rect.y - sprite.rect.height) / frameHeight)
                == directionRow.Value);
        }

        return fallbackSprites
            .OrderBy(sprite => Mathf.RoundToInt((textureHeight - sprite.rect.y - sprite.rect.height) / frameHeight))
            .ThenBy(sprite => Mathf.RoundToInt(sprite.rect.x / frameWidth))
            .ToArray();
    }

    static string GetCellKey(int frameIndex, int rowIndex)
    {
        return $"{frameIndex}:{rowIndex}";
    }

    static bool IsLoopingAction(string actionName)
    {
        return LoopingActionNames.Contains(actionName);
    }

    static void AddClipAlias(
        IDictionary<string, AnimationClip> lookup,
        string key,
        AnimationClip clip)
    {
        if (lookup == null || string.IsNullOrWhiteSpace(key) || clip == null)
            return;

        foreach (string alias in GetMotionKeyAliases(key))
        {
            if (!string.IsNullOrWhiteSpace(alias) && !lookup.ContainsKey(alias))
                lookup.Add(alias, clip);
        }

        string actionAlias = ExtractActionAlias(key);
        if (!string.IsNullOrWhiteSpace(actionAlias) && !lookup.ContainsKey(actionAlias))
            lookup.Add(actionAlias, clip);
    }

    static string ExtractActionAlias(string key)
    {
        if (string.IsNullOrWhiteSpace(key))
            return null;

        string normalized = key.Replace('\\', '/');
        normalized = Path.GetFileNameWithoutExtension(normalized);
        normalized = StripDirectionSuffix(normalized);

        if (TryGetExplicitSpeciesSpriteAction(normalized, "Human", out string explicitAction))
            return explicitAction;

        string[] prefixes =
        {
            "Minifantasy_CreaturesHuman",
            "Minifantasy_CreaturesElf",
            "Minifantasy_CreaturesDwarf",
            "Minifantasy_CreaturesGoblin",
            "Minifantasy_CreaturesHalfling",
            "Minifantasy_CreaturesOrc",
            "HumanBase",
            "Human_",
            "Elf_",
            "Dwarf_",
            "Goblin_",
            "Halfling_",
            "Orc_",
        };

        foreach (string prefix in prefixes)
        {
            if (normalized.StartsWith(prefix, StringComparison.OrdinalIgnoreCase)
                && normalized.Length > prefix.Length)
            {
                return CanonicalizeActionName(normalized.Substring(prefix.Length));
            }
        }

        foreach (string action in PlayerActionAliases)
        {
            if (normalized.EndsWith(action, StringComparison.OrdinalIgnoreCase))
                return CanonicalizeActionName(action);
        }

        if (string.Equals(normalized, "HumanWalk", StringComparison.OrdinalIgnoreCase))
            return "Walk";

        return null;
    }

    static int GetPlayerActionSortKey(string actionName)
    {
        int index = Array.FindIndex(
            PlayerActionAliases,
            candidate => string.Equals(candidate, actionName, StringComparison.OrdinalIgnoreCase));
        return index >= 0 ? index : PlayerActionAliases.Length + 1000;
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
