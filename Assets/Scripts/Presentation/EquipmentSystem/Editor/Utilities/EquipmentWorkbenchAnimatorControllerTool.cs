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
/// 装备工作台动画控制器工具
/// 负责从角色帧数据生成 SpriteLibrary 动画框架，支持换装系统的四向动画
/// </summary>
public static class EquipmentWorkbenchAnimatorControllerTool
{
    // 通过反射访问 Unity 2D Animation 内部的 Sprite 哈希生成方法
    // 这个方法是私有的，但我们需要用它来生成 SpriteResolver 的帧键
    static readonly MethodInfo SpriteKeyMethod = typeof(SpriteLibrary).GetMethod(
        "GetHashForCategoryAndEntry",
        BindingFlags.Static | BindingFlags.NonPublic);

    /// <summary>
    /// 动作规格：描述一个动作的基本信息
    /// </summary>
    sealed class ActionSpec
    {
        /// <summary>动作名称（如 Idle、Walk、Attack）</summary>
        public string Action;

        /// <summary>
        /// 该动作的最大帧数
        /// 从所有角色的所有方向中取最大值，确保动画片段足够长
        /// </summary>
        public int FrameCount;
    }

    /// <summary>
    /// 重建整个 SpriteLibrary 动画框架
    /// 这个方法会：
    /// 1. 为每个角色的每个方向生成 SpriteLibraryAsset（4个方向）
    /// 2. 生成共享的 AnimatorController 和 AnimationClip
    /// 3. 清理不再使用的旧资源
    /// </summary>
    [MenuItem("工具/装备系统/重建 SpriteLibrary 动画框架")]
    public static void Rebuild()
    {
        // 加载生成配置
        EquipmentSystemGenerationSettings settings = LoadSettings();

        // 加载角色目录（包含所有角色的帧数据）
        EquipmentWorkbenchCatalog catalog =
            AssetDatabase.LoadAssetAtPath<EquipmentWorkbenchCatalog>(settings.WorkbenchCatalogPath);

        // 加载动画类型数据库（定义了哪些动作可用）
        AnimationTypeDatabase animationDatabase =
            AssetDatabase.LoadAssetAtPath<AnimationTypeDatabase>(settings.AnimationDatabasePath);

        // 验证必需资源是否存在
        if (catalog == null)
            throw new InvalidOperationException($"找不到换装工作台目录：{settings.WorkbenchCatalogPath}");
        if (animationDatabase == null)
            throw new InvalidOperationException($"找不到动画类型数据库：{settings.AnimationDatabasePath}");

        // 确保输出目录存在
        EnsureFolder(settings.AnimationRoot);
        EnsureFolder(settings.SharedClipRoot);
        EnsureFolder(settings.SpriteLibraryRoot);

        // 构建动作规格列表（每个动作的帧数信息）
        List<ActionSpec> actionSpecs = BuildActionSpecs(catalog, animationDatabase);
        if (actionSpecs.Count == 0)
            throw new InvalidOperationException("角色帧数据中没有可用于 SpriteLibrary 的动画帧。");

        // 记录需要保留的 SpriteLibrary 资源路径（用于后续清理旧资源）
        HashSet<string> desiredLibraryPaths = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        // 为每个角色生成四向 SpriteLibraryAsset
        for (int i = 0; i < catalog.Characters.Count; i++)
        {
            EquipmentWorkbenchCharacterOption character = catalog.Characters[i];
            if (character?.FrameData == null)
                throw new InvalidOperationException($"角色选项 {i} 缺少 CharacterFrameData。");

            DirectionalSpriteLibrarySet libraries = BuildCharacterLibraries(
                settings,
                character,
                actionSpecs,
                desiredLibraryPaths);

            // 将生成的库保存到角色配置中
            character.SetAnimationLibraries(libraries);
        }

        // 记录需要保留的 AnimationClip 资源路径
        HashSet<string> desiredClipPaths = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        // 生成共享的 AnimatorController（所有角色共用）
        BuildSharedController(settings, actionSpecs, desiredClipPaths);

        // 删除不再使用的旧资源
        PruneGeneratedAssets(settings, desiredClipPaths, desiredLibraryPaths);

        // 强制重新序列化 Catalog，确保引用关系正确
        ReserializeCatalog(settings, catalog);

        // 保存所有改动并刷新资源数据库
        AssetDatabase.SaveAssets();
        AssetDatabase.Refresh();

        Debug.Log(
            $"[EquipmentWorkbenchAnimatorControllerTool] SpriteLibrary 动画框架重建完成："
            + $"{actionSpecs.Count} 个动作片段，{catalog.Characters.Count * CharacterAnimationDirections.Count} 个方向库。 ");
    }

    /// <summary>
    /// 创建动画生成设置资源
    /// 如果已存在则选中它，不会重复创建
    /// </summary>
    [MenuItem("工具/装备系统/创建动画生成设置")]
    public static void CreateSettingsAsset()
    {
        string defaultPath = EquipmentSystemGenerationSettings.DefaultSettingsAssetPath;

        // 查找是否有重复的设置资源（不允许有多个设置资源存在）
        string[] duplicatePaths = FindGenerationSettingsPaths()
            .Where(path => !string.Equals(path, defaultPath, StringComparison.OrdinalIgnoreCase))
            .ToArray();
        if (duplicatePaths.Length > 0)
        {
            throw new InvalidOperationException(
                "换装动画生成设置必须只有一个正式 owner："
                + defaultPath
                + "。创建默认设置前，请先迁移或删除这些非默认设置资产："
                + string.Join(", ", duplicatePaths));
        }

        // 如果已存在，直接选中它
        EquipmentSystemGenerationSettings existing =
            AssetDatabase.LoadAssetAtPath<EquipmentSystemGenerationSettings>(defaultPath);
        if (existing != null)
        {
            Selection.activeObject = existing;
            return;
        }

        // 创建输出目录和新资源
        string folder = Path.GetDirectoryName(defaultPath)?.Replace('\\', '/');
        if (!string.IsNullOrEmpty(folder))
            EnsureFolder(folder);

        EquipmentSystemGenerationSettings settings =
            ScriptableObject.CreateInstance<EquipmentSystemGenerationSettings>();
        AssetDatabase.CreateAsset(settings, defaultPath);
        AssetDatabase.SaveAssets();
        Selection.activeObject = settings;
    }

    /// <summary>
    /// 加载动画生成设置
    /// 确保只有一个正式的设置资源存在，避免配置冲突
    /// </summary>
    /// <returns>动画生成设置</returns>
    /// <exception cref="InvalidOperationException">当找不到设置或存在重复设置时抛出</exception>
    static EquipmentSystemGenerationSettings LoadSettings()
    {
        string defaultPath = EquipmentSystemGenerationSettings.DefaultSettingsAssetPath;
        string[] settingPaths = FindGenerationSettingsPaths();
        EquipmentSystemGenerationSettings settings =
            AssetDatabase.LoadAssetAtPath<EquipmentSystemGenerationSettings>(defaultPath);

        string[] duplicatePaths = settingPaths
            .Where(path => !string.Equals(path, defaultPath, StringComparison.OrdinalIgnoreCase))
            .ToArray();

        if (settings == null)
        {
            string foundSettings = settingPaths.Length > 0
                ? " 当前找到的非默认设置资产：" + string.Join(", ", settingPaths)
                : string.Empty;
            throw new InvalidOperationException(
                "找不到正式换装动画生成设置："
                + defaultPath
                + "。请通过 Tools/Equipment System/Create Animation Generation Settings 创建或迁移。"
                + foundSettings);
        }

        if (duplicatePaths.Length > 0)
        {
            throw new InvalidOperationException(
                "找到多个 EquipmentSystemGenerationSettings。换装动画生成设置必须只有一个正式 owner："
                + defaultPath
                + "。请删除或迁移这些重复设置资产："
                + string.Join(", ", duplicatePaths));
        }

        return settings;
    }

    static string[] FindGenerationSettingsPaths()
    {
        return AssetDatabase.FindAssets("t:EquipmentSystemGenerationSettings")
            .Select(AssetDatabase.GUIDToAssetPath)
            .Where(path => !string.IsNullOrWhiteSpace(path))
            .OrderBy(path => path, StringComparer.OrdinalIgnoreCase)
            .ToArray();
    }

    /// <summary>
    /// 构建动作规格列表
    /// 遍历动画数据库，为每个动作找到所有角色所有方向中的最大帧数
    /// </summary>
    /// <param name="catalog">角色目录</param>
    /// <param name="animationDatabase">动画类型数据库</param>
    /// <returns>动作规格列表，每个规格包含动作名和最大帧数</returns>
    static List<ActionSpec> BuildActionSpecs(
        EquipmentWorkbenchCatalog catalog,
        AnimationTypeDatabase animationDatabase)
    {
        List<ActionSpec> specs = new List<ActionSpec>();

        // 遍历动画数据库中的每个动作类型
        for (int itemIndex = 0; itemIndex < animationDatabase.Count; itemIndex++)
        {
            if (!animationDatabase.TryGetByIndex(itemIndex, out AnimationTypeItem item) || item == null)
                continue;

            // 在所有角色的所有方向中找到这个动作的最大帧数
            int maxFrameCount = 0;
            for (int characterIndex = 0; characterIndex < catalog.Characters.Count; characterIndex++)
            {
                CharacterFrameData frameData = catalog.Characters[characterIndex]?.FrameData;
                AnimationData animation = frameData != null ? frameData.GetAnimationByKey(item.name) : null;

                // 遍历四个方向（SE、SW、NE、NW）
                for (int direction = 0; direction < CharacterAnimationDirections.Count; direction++)
                    maxFrameCount = Mathf.Max(maxFrameCount, BuildSprites(animation, direction).Length);
            }

            // 只添加有帧数据的动作
            if (maxFrameCount > 0)
                specs.Add(new ActionSpec { Action = item.name, FrameCount = maxFrameCount });
        }

        return specs;
    }

    static DirectionalSpriteLibrarySet BuildCharacterLibraries(
        EquipmentSystemGenerationSettings settings,
        EquipmentWorkbenchCharacterOption character,
        IReadOnlyList<ActionSpec> actionSpecs,
        ISet<string> desiredPaths)
    {
        DirectionalSpriteLibrarySet libraries = new DirectionalSpriteLibrarySet();
        for (int direction = 0; direction < CharacterAnimationDirections.Count; direction++)
        {
            string assetName = SanitizeAssetName(character.DisplayName)
                + "_" + CharacterAnimationDirections.GetName(direction) + "动画精灵库";
            string assetPath = $"{settings.SpriteLibraryRoot}/{assetName}.asset";
            desiredPaths.Add(assetPath);

            SpriteLibraryAsset library = AssetDatabase.LoadAssetAtPath<SpriteLibraryAsset>(assetPath);
            if (library == null)
            {
                library = ScriptableObject.CreateInstance<SpriteLibraryAsset>();
                library.name = assetName;
                AssetDatabase.CreateAsset(library, assetPath);
            }

            ClearLibrary(library);
            PopulateDirectionLibrary(settings, character.FrameData, direction, actionSpecs, library);
            libraries.Set(direction, library);
            EditorUtility.SetDirty(library);
        }

        return libraries;
    }

    static void PopulateDirectionLibrary(
        EquipmentSystemGenerationSettings settings,
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
            if (sprites.Length == 0 && settings.FallbackMissingDirectionsToFirstAvailable)
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
        for (int direction = 0; direction < CharacterAnimationDirections.Count; direction++)
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
        EquipmentSystemGenerationSettings settings,
        IReadOnlyList<ActionSpec> actionSpecs,
        ISet<string> desiredClipPaths)
    {
        AnimatorController controller = AssetDatabase.LoadAssetAtPath<AnimatorController>(settings.ControllerPath);
        if (controller == null)
            controller = AnimatorController.CreateAnimatorControllerAtPath(settings.ControllerPath);

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
            AnimationClip clip = BuildResolverClip(settings, spec, desiredClipPaths);
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

    static AnimationClip BuildResolverClip(
        EquipmentSystemGenerationSettings settings,
        ActionSpec spec,
        ISet<string> desiredPaths)
    {
        string clipPath = $"{settings.SharedClipRoot}/{SanitizeAssetName(spec.Action)}.anim";
        desiredPaths.Add(clipPath);
        AnimationClip clip = AssetDatabase.LoadAssetAtPath<AnimationClip>(clipPath);
        if (clip == null)
        {
            clip = new AnimationClip { name = spec.Action };
            AssetDatabase.CreateAsset(clip, clipPath);
        }

        clip.name = spec.Action;
        clip.frameRate = settings.FrameRate;
        EditorCurveBinding resolverBinding = EditorCurveBinding.DiscreteCurve(
            string.Empty,
            typeof(SpriteResolver),
            "m_SpriteHash");

        Keyframe[] keys = new Keyframe[spec.FrameCount + 1];
        for (int frame = 0; frame < spec.FrameCount; frame++)
        {
            keys[frame] = new Keyframe(
                frame / settings.FrameRate,
                GetSpriteHashAsFloat(spec.Action, frame.ToString()),
                float.PositiveInfinity,
                float.PositiveInfinity);
        }
        keys[spec.FrameCount] = new Keyframe(
            spec.FrameCount / settings.FrameRate,
            GetSpriteHashAsFloat(spec.Action, (spec.FrameCount - 1).ToString()),
            float.PositiveInfinity,
            float.PositiveInfinity);

        AnimationCurve curve = new AnimationCurve(keys);
        for (int i = 0; i < curve.length; i++)
        {
            AnimationUtility.SetKeyLeftTangentMode(curve, i, AnimationUtility.TangentMode.Constant);
            AnimationUtility.SetKeyRightTangentMode(curve, i, AnimationUtility.TangentMode.Constant);
        }

        AnimationUtility.SetEditorCurve(clip, resolverBinding, curve);
        AnimationUtility.SetEditorCurve(
            clip,
            EditorCurveBinding.DiscreteCurve(string.Empty, typeof(SpriteResolver), "m_SpriteKey"),
            null);
        AnimationUtility.SetObjectReferenceCurve(
            clip,
            new EditorCurveBinding
            {
                path = string.Empty,
                type = typeof(SpriteRenderer),
                propertyName = "m_Sprite"
            },
            null);

        AnimationClipSettings clipSettings = AnimationUtility.GetAnimationClipSettings(clip);
        clipSettings.loopTime = settings.IsLoopingAction(spec.Action);
        AnimationUtility.SetAnimationClipSettings(clip, clipSettings);
        EditorUtility.SetDirty(clip);
        return clip;
    }

    static float GetSpriteHashAsFloat(string category, string label)
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
        EquipmentSystemGenerationSettings settings,
        ISet<string> desiredClipPaths,
        ISet<string> desiredLibraryPaths)
    {
        PruneFolderFiles(settings.SharedClipRoot, new[] { ".anim" }, desiredClipPaths);
        PruneFolderFiles(settings.SpriteLibraryRoot, new[] { ".asset", ".spriteLib" }, desiredLibraryPaths);
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

    static void ReserializeCatalog(
        EquipmentSystemGenerationSettings settings,
        EquipmentWorkbenchCatalog catalog)
    {
        EditorUtility.SetDirty(catalog);
        AssetDatabase.ForceReserializeAssets(new[] { settings.WorkbenchCatalogPath });
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
