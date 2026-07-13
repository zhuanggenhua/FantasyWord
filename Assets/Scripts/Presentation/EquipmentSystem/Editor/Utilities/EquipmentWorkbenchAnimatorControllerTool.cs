using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using UnityEditor;
using UnityEditor.Animations;
using UnityEngine;
using UnityEngine.U2D.Animation;

/// <summary>
/// 构建换装系统唯一动画链：纯动作 Animator + 每角色四向 SpriteLibraryAsset。
/// </summary>
public static class EquipmentWorkbenchAnimatorControllerTool
{
    const string AnimationDatabasePath =
        "Assets/GameData/EquipmentSystem/AnimationType/AnimationTypeDatabase.asset";
    const string WorkbenchCatalogPath =
        "Assets/GameData/EquipmentSystem/Data/Workbench/换装工作台目录.asset";
    const string AnimationRoot = "Assets/GameData/EquipmentSystem/Animations";
    const string ControllerPath = AnimationRoot + "/换装共享动画状态机.controller";
    const string SharedClipRoot = AnimationRoot + "/SharedClips";
    const string SpriteLibraryRoot = AnimationRoot + "/SpriteLibraries";
    const float FrameRate = 8f;

    static readonly string[] DirectionSuffixes = { "SE", "SW", "NE", "NW" };

    static readonly HashSet<string> LoopingActions = new HashSet<string>(
        new[]
        {
            "Idle", "Wait", "Walk", "Run", "AnvilWorking", "Chopping", "Harvest",
            "JewelryWorkshopWorking", "LaboratoryWorking", "Mining", "WoodworkBenchWorking"
        },
        StringComparer.OrdinalIgnoreCase);

    static readonly MethodInfo SpriteKeyMethod = typeof(SpriteLibrary).GetMethod(
        "GetHashForCategoryAndEntry",
        BindingFlags.Static | BindingFlags.NonPublic);

    sealed class ActionSpec
    {
        public string Action;
        public int FrameCount;
    }

    [MenuItem("Tools/Equipment System/Rebuild SpriteLibrary Animation Framework")]
    public static void Rebuild()
    {
        EquipmentWorkbenchCatalog catalog =
            AssetDatabase.LoadAssetAtPath<EquipmentWorkbenchCatalog>(WorkbenchCatalogPath);
        AnimationTypeDatabase animationDatabase =
            AssetDatabase.LoadAssetAtPath<AnimationTypeDatabase>(AnimationDatabasePath);

        if (catalog == null)
            throw new InvalidOperationException($"找不到换装工作台目录：{WorkbenchCatalogPath}");
        if (animationDatabase == null)
            throw new InvalidOperationException($"找不到动画类型数据库：{AnimationDatabasePath}");

        EnsureFolder(AnimationRoot);
        EnsureFolder(SharedClipRoot);
        EnsureFolder(SpriteLibraryRoot);

        List<ActionSpec> actionSpecs = BuildActionSpecs(catalog, animationDatabase);
        if (actionSpecs.Count == 0)
            throw new InvalidOperationException("角色帧数据中没有可用于 SpriteLibrary 的动画帧。");

        HashSet<string> desiredLibraryPaths = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        for (int i = 0; i < catalog.Characters.Count; i++)
        {
            EquipmentWorkbenchCharacterOption character = catalog.Characters[i];
            if (character?.FrameData == null)
                throw new InvalidOperationException($"角色选项 {i} 缺少 CharacterFrameData。");

            DirectionalSpriteLibrarySet libraries = BuildCharacterLibraries(
                character,
                actionSpecs,
                desiredLibraryPaths);
            character.FrameData.animationSpriteLibraries = libraries;
            EditorUtility.SetDirty(character.FrameData);
        }

        HashSet<string> desiredClipPaths = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        BuildSharedController(actionSpecs, desiredClipPaths);
        PruneGeneratedAssets(desiredClipPaths, desiredLibraryPaths);
        ReserializeCatalog(catalog);
        AssetDatabase.SaveAssets();
        AssetDatabase.Refresh();

        Debug.Log(
            $"[EquipmentWorkbenchAnimatorControllerTool] SpriteLibrary 动画框架重建完成："
            + $"{actionSpecs.Count} 个动作片段，{catalog.Characters.Count * DirectionSuffixes.Length} 个方向库。 ");
    }

    static List<ActionSpec> BuildActionSpecs(
        EquipmentWorkbenchCatalog catalog,
        AnimationTypeDatabase animationDatabase)
    {
        List<ActionSpec> specs = new List<ActionSpec>();
        for (int itemIndex = 0; itemIndex < animationDatabase.Count; itemIndex++)
        {
            if (!animationDatabase.TryGetByIndex(itemIndex, out AnimationTypeItem item) || item == null)
                continue;

            int maxFrameCount = 0;
            for (int characterIndex = 0; characterIndex < catalog.Characters.Count; characterIndex++)
            {
                CharacterFrameData frameData = catalog.Characters[characterIndex]?.FrameData;
                AnimationData animation = frameData != null ? frameData.GetAnimationByKey(item.name) : null;
                for (int direction = 0; direction < DirectionSuffixes.Length; direction++)
                    maxFrameCount = Mathf.Max(maxFrameCount, BuildSprites(animation, direction).Length);
            }

            if (maxFrameCount > 0)
                specs.Add(new ActionSpec { Action = item.name, FrameCount = maxFrameCount });
        }

        return specs;
    }

    static DirectionalSpriteLibrarySet BuildCharacterLibraries(
        EquipmentWorkbenchCharacterOption character,
        IReadOnlyList<ActionSpec> actionSpecs,
        ISet<string> desiredPaths)
    {
        DirectionalSpriteLibrarySet libraries = new DirectionalSpriteLibrarySet();
        for (int direction = 0; direction < DirectionSuffixes.Length; direction++)
        {
            string assetName = SanitizeAssetName(character.DisplayName)
                + "_" + DirectionSuffixes[direction] + "动画精灵库";
            string assetPath = $"{SpriteLibraryRoot}/{assetName}.asset";
            desiredPaths.Add(assetPath);

            SpriteLibraryAsset library = AssetDatabase.LoadAssetAtPath<SpriteLibraryAsset>(assetPath);
            if (library == null)
            {
                library = ScriptableObject.CreateInstance<SpriteLibraryAsset>();
                library.name = assetName;
                AssetDatabase.CreateAsset(library, assetPath);
            }

            ClearLibrary(library);
            PopulateDirectionLibrary(character.FrameData, direction, actionSpecs, library);
            libraries.Set(direction, library);
            EditorUtility.SetDirty(library);
        }

        return libraries;
    }

    static void PopulateDirectionLibrary(
        CharacterFrameData frameData,
        int direction,
        IReadOnlyList<ActionSpec> actionSpecs,
        SpriteLibraryAsset library)
    {
        for (int i = 0; i < actionSpecs.Count; i++)
        {
            ActionSpec spec = actionSpecs[i];
            AnimationData animation = frameData.GetAnimationByKey(spec.Action);
            Sprite[] sprites = BuildSprites(animation, direction);
            if (sprites.Length == 0)
                sprites = BuildFirstAvailableDirection(animation);
            if (sprites.Length == 0)
                continue;

            for (int frame = 0; frame < spec.FrameCount; frame++)
            {
                Sprite sprite = sprites[Mathf.Min(frame, sprites.Length - 1)];
                library.AddCategoryLabel(sprite, spec.Action, frame.ToString());
            }
        }
    }

    static Sprite[] BuildFirstAvailableDirection(AnimationData animation)
    {
        for (int direction = 0; direction < DirectionSuffixes.Length; direction++)
        {
            Sprite[] sprites = BuildSprites(animation, direction);
            if (sprites.Length > 0)
                return sprites;
        }

        return Array.Empty<Sprite>();
    }

    static void ClearLibrary(SpriteLibraryAsset library)
    {
        string[] categories = library.GetCategoryNames().ToArray();
        for (int categoryIndex = 0; categoryIndex < categories.Length; categoryIndex++)
        {
            string category = categories[categoryIndex];
            string[] labels = library.GetCategoryLabelNames(category).ToArray();
            for (int labelIndex = 0; labelIndex < labels.Length; labelIndex++)
                library.RemoveCategoryLabel(category, labels[labelIndex], true);
        }
    }

    static AnimatorController BuildSharedController(
        IReadOnlyList<ActionSpec> actionSpecs,
        ISet<string> desiredClipPaths)
    {
        AnimatorController controller = AssetDatabase.LoadAssetAtPath<AnimatorController>(ControllerPath);
        if (controller == null)
            controller = AnimatorController.CreateAnimatorControllerAtPath(ControllerPath);

        while (controller.parameters.Length > 0)
            controller.RemoveParameter(controller.parameters[0]);
        while (controller.layers.Length > 1)
            controller.RemoveLayer(controller.layers.Length - 1);

        AnimatorStateMachine stateMachine = controller.layers[0].stateMachine;
        ChildAnimatorState[] oldStates = stateMachine.states;
        for (int i = 0; i < oldStates.Length; i++)
        {
            AnimatorState state = oldStates[i].state;
            stateMachine.RemoveState(state);
            if (state != null)
                UnityEngine.Object.DestroyImmediate(state, true);
        }

        AnimatorState defaultState = null;
        for (int i = 0; i < actionSpecs.Count; i++)
        {
            ActionSpec spec = actionSpecs[i];
            AnimationClip clip = BuildResolverClip(spec, desiredClipPaths);
            AnimatorState state = stateMachine.AddState(
                spec.Action,
                new Vector3((i % 6) * 220f, (i / 6) * 70f));
            state.motion = clip;
            state.writeDefaultValues = true;
            if (defaultState == null || string.Equals(spec.Action, "Idle", StringComparison.Ordinal))
                defaultState = state;
        }

        stateMachine.defaultState = defaultState;
        EditorUtility.SetDirty(stateMachine);
        EditorUtility.SetDirty(controller);
        return controller;
    }

    static AnimationClip BuildResolverClip(ActionSpec spec, ISet<string> desiredPaths)
    {
        string clipPath = $"{SharedClipRoot}/{SanitizeAssetName(spec.Action)}.anim";
        desiredPaths.Add(clipPath);
        AnimationClip clip = AssetDatabase.LoadAssetAtPath<AnimationClip>(clipPath);
        if (clip == null)
        {
            clip = new AnimationClip { name = spec.Action };
            AssetDatabase.CreateAsset(clip, clipPath);
        }

        clip.name = spec.Action;
        clip.frameRate = FrameRate;
        EditorCurveBinding resolverBinding = new EditorCurveBinding
        {
            path = string.Empty,
            type = typeof(SpriteResolver),
            propertyName = "m_SpriteKey"
        };

        Keyframe[] keys = new Keyframe[spec.FrameCount];
        for (int frame = 0; frame < spec.FrameCount; frame++)
        {
            keys[frame] = new Keyframe(
                frame / FrameRate,
                GetSpriteKeyAsFloat(spec.Action, frame.ToString()),
                float.PositiveInfinity,
                float.PositiveInfinity);
        }

        AnimationCurve curve = new AnimationCurve(keys);
        for (int i = 0; i < curve.length; i++)
        {
            AnimationUtility.SetKeyLeftTangentMode(curve, i, AnimationUtility.TangentMode.Constant);
            AnimationUtility.SetKeyRightTangentMode(curve, i, AnimationUtility.TangentMode.Constant);
        }

        AnimationUtility.SetEditorCurve(clip, resolverBinding, curve);
        AnimationUtility.SetObjectReferenceCurve(
            clip,
            new EditorCurveBinding
            {
                path = string.Empty,
                type = typeof(SpriteRenderer),
                propertyName = "m_Sprite"
            },
            null);

        AnimationClipSettings settings = AnimationUtility.GetAnimationClipSettings(clip);
        settings.loopTime = LoopingActions.Contains(spec.Action);
        AnimationUtility.SetAnimationClipSettings(clip, settings);
        EditorUtility.SetDirty(clip);
        return clip;
    }

    static float GetSpriteKeyAsFloat(string category, string label)
    {
        if (SpriteKeyMethod == null)
            throw new MissingMethodException("Unity 2D Animation 未提供 SpriteLibrary 帧键生成入口。");

        int hash = (int)SpriteKeyMethod.Invoke(null, new object[] { category, label });
        return BitConverter.Int32BitsToSingle(hash);
    }

    static Sprite[] BuildSprites(AnimationData animation, int direction)
    {
        if (animation?.spritesheet == null || direction < 0 || direction >= animation.rowCount)
            return Array.Empty<Sprite>();

        string path = AssetDatabase.GetAssetPath(animation.spritesheet);
        int frameWidth = Mathf.Max(1, animation.frameSize.x);
        int frameHeight = Mathf.Max(1, animation.frameSize.y);
        int textureHeight = animation.spritesheet.height;
        Dictionary<int, Sprite> spritesByFrame = new Dictionary<int, Sprite>();

        foreach (Sprite sprite in AssetDatabase.LoadAllAssetRepresentationsAtPath(path).OfType<Sprite>())
        {
            if (Mathf.RoundToInt(sprite.rect.width) != frameWidth
                || Mathf.RoundToInt(sprite.rect.height) != frameHeight)
            {
                continue;
            }

            int row = Mathf.RoundToInt(
                (textureHeight - sprite.rect.y - sprite.rect.height) / frameHeight);
            if (row != direction)
                continue;

            int frame = Mathf.RoundToInt(sprite.rect.x / frameWidth);
            if (!spritesByFrame.ContainsKey(frame))
                spritesByFrame.Add(frame, sprite);
        }

        if (animation.frames != null && animation.frames.Count > 0)
        {
            int[] authoredFrames = animation.frames
                .Where(frame => frame != null && frame.rowIndex == direction)
                .Select(frame => frame.frameIndex)
                .Distinct()
                .OrderBy(frame => frame)
                .ToArray();
            Sprite[] authoredSprites = authoredFrames
                .Where(spritesByFrame.ContainsKey)
                .Select(frame => spritesByFrame[frame])
                .ToArray();
            if (authoredSprites.Length > 0)
                return authoredSprites;
        }

        return spritesByFrame.OrderBy(pair => pair.Key).Select(pair => pair.Value).ToArray();
    }

    static void PruneGeneratedAssets(
        ISet<string> desiredClipPaths,
        ISet<string> desiredLibraryPaths)
    {
        PruneFolderFiles(SharedClipRoot, new[] { ".anim" }, desiredClipPaths);
        PruneFolderFiles(SpriteLibraryRoot, new[] { ".asset", ".spriteLib" }, desiredLibraryPaths);
    }

    static void PruneFolderFiles(string folder, IReadOnlyCollection<string> extensions, ISet<string> desiredPaths)
    {
        string absoluteFolder = Path.GetFullPath(folder);
        if (!Directory.Exists(absoluteFolder))
            return;

        string[] files = Directory.GetFiles(absoluteFolder, "*", SearchOption.TopDirectoryOnly);
        for (int i = 0; i < files.Length; i++)
        {
            string extension = Path.GetExtension(files[i]);
            if (!extensions.Contains(extension, StringComparer.OrdinalIgnoreCase))
                continue;

            string projectPath = files[i].Replace('\\', '/');
            int assetsIndex = projectPath.IndexOf("Assets/", StringComparison.OrdinalIgnoreCase);
            if (assetsIndex < 0)
                continue;

            projectPath = projectPath.Substring(assetsIndex);
            if (!desiredPaths.Contains(projectPath))
                AssetDatabase.DeleteAsset(projectPath);
        }
    }

    static void ReserializeCatalog(EquipmentWorkbenchCatalog catalog)
    {
        EditorUtility.SetDirty(catalog);
        List<string> paths = new List<string> { WorkbenchCatalogPath };
        for (int i = 0; i < catalog.Characters.Count; i++)
        {
            CharacterFrameData frameData = catalog.Characters[i]?.FrameData;
            string path = AssetDatabase.GetAssetPath(frameData);
            if (!string.IsNullOrWhiteSpace(path))
                paths.Add(path);
        }

        AssetDatabase.ForceReserializeAssets(paths);
    }

    static void EnsureFolder(string path)
    {
        string[] parts = path.Split('/');
        string current = parts[0];
        for (int i = 1; i < parts.Length; i++)
        {
            string next = current + "/" + parts[i];
            if (!AssetDatabase.IsValidFolder(next))
                AssetDatabase.CreateFolder(current, parts[i]);
            current = next;
        }
    }

    static string SanitizeAssetName(string value)
    {
        if (string.IsNullOrWhiteSpace(value))
            return "Unnamed";

        foreach (char invalid in Path.GetInvalidFileNameChars())
            value = value.Replace(invalid, '_');
        return value.Trim();
    }
}
