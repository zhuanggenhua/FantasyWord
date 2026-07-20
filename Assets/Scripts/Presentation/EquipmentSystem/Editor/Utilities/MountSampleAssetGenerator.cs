using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using FantasyWord.GameCore;
using UnityEditor;
using UnityEngine;
using UnityEngine.U2D.Animation;

/// <summary>
/// 坐骑换装样板资产生成器。
/// 当前只生成 War 马 + 人类骑手的最小闭环，用来验证“坐骑底层 + 骑手基础层 + 现有换装”的接缝。
/// </summary>
public static class MountSampleAssetGenerator
{
    const string MenuRoot = "Tools/Equipment System/Mounts/";
    const string OutputRoot = "Assets/GameData/EquipmentSystem/Mounts";
    const string FrameDataPath = "Assets/GameData/EquipmentSystem/FrameData/人类战马骑乘帧数据.asset";
    const string MountAssetPath = OutputRoot + "/战马_人类骑乘表现.asset";
    const string MountEquipmentPath = "Assets/Database/Items/Equipment/战马.asset";
    const string CharacterActorPrefabPath = "Assets/Prefabs/Entities/Characters/0_CharacterActor_Base.prefab";
    const string GeneratedUvDirectory = "Assets/GameData/EquipmentSystem/GeneratedUV/Mounts/HumanWarHorse";
    const string AnimationDatabasePath = "Assets/GameData/EquipmentSystem/AnimationType/AnimationTypeDatabase.asset";
    const string IdleTypePath = "Assets/GameData/EquipmentSystem/AnimationType/Idle.asset";
    const string WalkTypePath = "Assets/GameData/EquipmentSystem/AnimationType/Walk.asset";
    const string MountRoot = "Assets/Art/坐骑/迷你幻想_坐骑_v1.0/迷你幻想_坐骑_素材/新 坐骑/War 马";
    const string MountIdlePath = MountRoot + "/War 马/War马待机/待机_stallion.png";
    const string MountWalkPath = MountRoot + "/War 马/War马行走/行走_stallion.png";
    const string RiderIdlePath = MountRoot + "/War 马 骑手/War马待机袭击者/War马待机袭击者_人类.png";
    const string RiderWalkPath = MountRoot + "/War 马 骑手/War马行走袭击者/War马行走袭击者_人类.png";
    const string MountLayerRootName = "坐骑表现层";
    const string MountBodyRendererName = "坐骑本体";
    const float StandCycleSeconds = 2.4f;
    const float MoveCycleSeconds = 0.8f;

    static readonly Vector2Int FrameSize = new(32, 32);

    [MenuItem(MenuRoot + "生成 War 马 + 人类骑手样板")]
    public static void CreateWarHorseHumanSample()
    {
        object result = CreateWarHorseHumanSampleForAutomation();
        Debug.Log($"坐骑样板生成完成: {JsonUtility.ToJson(result, true)}");
    }

    [MenuItem(MenuRoot + "安装统一角色坐骑表现层")]
    public static void InstallWarHorseMountPresentationOnCharacterActorPrefab()
    {
        object result = InstallWarHorseMountPresentationOnCharacterActorPrefabForAutomation();
        Debug.Log($"坐骑表现层安装完成: {JsonUtility.ToJson(result, true)}");
    }

    /// <summary>
    /// 给批处理/自动化验证使用的入口。
    /// </summary>
    public static object CreateWarHorseHumanSampleForAutomation()
    {
        EnsureDirectories();
        ApplySampleImportSettings();

        AnimationTypeDatabase animationDatabase = AssetDatabase.LoadAssetAtPath<AnimationTypeDatabase>(AnimationDatabasePath);
        AnimationTypeItem idleType = AssetDatabase.LoadAssetAtPath<AnimationTypeItem>(IdleTypePath);
        AnimationTypeItem walkType = AssetDatabase.LoadAssetAtPath<AnimationTypeItem>(WalkTypePath);
        if (animationDatabase == null || idleType == null || walkType == null)
            throw new InvalidOperationException("缺少 AnimationTypeDatabase / Idle / Walk 动作资产，不能生成坐骑样板。");

        CharacterFrameData frameData = LoadOrCreateFrameData(animationDatabase);
        MountRenderData mountData = LoadOrCreateMountData();

        Texture2D riderIdleTexture = AssetDatabase.LoadAssetAtPath<Texture2D>(RiderIdlePath);
        Texture2D riderWalkTexture = AssetDatabase.LoadAssetAtPath<Texture2D>(RiderWalkPath);
        if (riderIdleTexture == null || riderWalkTexture == null)
            throw new InvalidOperationException("缺少 War 马人类骑手 Idle/Walk 贴图，不能生成骑手帧数据。");

        EnsureFrameDataAnimation(frameData, idleType, riderIdleTexture, RiderIdlePath);
        EnsureFrameDataAnimation(frameData, walkType, riderWalkTexture, RiderWalkPath);
        EditorUtility.SetDirty(frameData);

        ConfigureMountAsset(mountData, frameData, idleType, walkType);
        EditorUtility.SetDirty(mountData);
        Equipment mountEquipment = LoadOrCreateMountEquipment(mountData);
        EditorUtility.SetDirty(mountEquipment);
        AssetDatabase.SaveAssets();
        AssetDatabase.Refresh();

        return new MountSampleAssetGenerationResult
        {
            frameData = FrameDataPath,
            mountData = MountAssetPath,
            equipment = MountEquipmentPath,
            uvDirectory = GeneratedUvDirectory,
            animations = mountData.Animations.Count,
        };
    }

    /// <summary>
    /// 给统一角色 Prefab 安装坐骑表现层和显式引用。
    /// 坐骑层是正式 Prefab 的表现接线，不承担生成坐骑素材本身。
    /// </summary>
    public static object InstallWarHorseMountPresentationOnCharacterActorPrefabForAutomation()
    {
        GameObject prefabRoot = PrefabUtility.LoadPrefabContents(CharacterActorPrefabPath);
        if (prefabRoot == null)
            throw new InvalidOperationException($"无法加载统一角色 Prefab：{CharacterActorPrefabPath}");

        try
        {
            EquipmentRenderer equipmentRenderer = prefabRoot.GetComponentInChildren<EquipmentRenderer>(true);
            CharacterActionAnimatorDriver actionDriver = prefabRoot.GetComponentInChildren<CharacterActionAnimatorDriver>(true);
            DirectionalSpriteLibraryDriver directionDriver = prefabRoot.GetComponentInChildren<DirectionalSpriteLibraryDriver>(true);
            CharacterEquipmentPresentation equipmentPresentation =
                prefabRoot.GetComponentInChildren<CharacterEquipmentPresentation>(true);

            if (equipmentRenderer == null)
                throw new InvalidOperationException("统一角色 Prefab 缺少 EquipmentRenderer，不能安装坐骑表现层。");
            if (actionDriver == null)
                throw new InvalidOperationException("统一角色 Prefab 缺少 CharacterActionAnimatorDriver，不能安装坐骑表现层。");
            if (directionDriver == null)
                throw new InvalidOperationException("统一角色 Prefab 缺少 DirectionalSpriteLibraryDriver，不能安装坐骑表现层。");
            if (equipmentPresentation == null)
                throw new InvalidOperationException("统一角色 Prefab 缺少 CharacterEquipmentPresentation，不能安装坐骑表现层。");

            SpriteRenderer riderRenderer = equipmentRenderer.GetComponent<SpriteRenderer>();
            if (riderRenderer == null)
                throw new InvalidOperationException("EquipmentRenderer 所在对象缺少骑手 SpriteRenderer。");

            Transform layerRoot = FindOrCreateChild(equipmentRenderer.transform, MountLayerRootName);
            SpriteRenderer mountRenderer = FindOrCreateSpriteRenderer(layerRoot, MountBodyRendererName);
            ConfigureMountedLayerRenderer(mountRenderer, riderRenderer, -1);

            MountedCharacterPresentation mountedPresentation =
                equipmentRenderer.GetComponent<MountedCharacterPresentation>()
                ?? equipmentRenderer.gameObject.AddComponent<MountedCharacterPresentation>();

            SetObjectReference(mountedPresentation, "actionDriver", actionDriver);
            SetObjectReference(mountedPresentation, "directionDriver", directionDriver);
            SetObjectReference(mountedPresentation, "riderRenderer", riderRenderer);
            SetObjectReference(mountedPresentation, "mountRenderer", mountRenderer);
            SetObjectReference(mountedPresentation, "riderEquipmentRenderer", equipmentRenderer);
            SetObjectReference(mountedPresentation, "defaultRiderFrameData", equipmentRenderer.frameData);
            SetObjectReference(equipmentPresentation, "mountedPresentation", mountedPresentation);

            EditorUtility.SetDirty(layerRoot.gameObject);
            EditorUtility.SetDirty(mountRenderer);
            EditorUtility.SetDirty(mountedPresentation);
            EditorUtility.SetDirty(equipmentPresentation);
            PrefabUtility.SaveAsPrefabAsset(prefabRoot, CharacterActorPrefabPath);
            AssetDatabase.SaveAssets();

            return new MountPrefabInstallationResult
            {
                prefabPath = CharacterActorPrefabPath,
                equipmentRendererPath = GetTransformPath(equipmentRenderer.transform),
                mountedPresentationPath = GetTransformPath(mountedPresentation.transform),
                mountRendererPath = GetTransformPath(mountRenderer.transform),
                characterEquipmentPresentationPath = GetTransformPath(equipmentPresentation.transform),
            };
        }
        finally
        {
            PrefabUtility.UnloadPrefabContents(prefabRoot);
        }
    }

    static void EnsureDirectories()
    {
        EnsureAssetFolder("Assets/GameData/EquipmentSystem", "Mounts");
        EnsureAssetFolder("Assets/GameData/EquipmentSystem/GeneratedUV", "Mounts");
        EnsureAssetFolder("Assets/GameData/EquipmentSystem/GeneratedUV/Mounts", "HumanWarHorse");
    }

    static void EnsureAssetFolder(string parent, string child)
    {
        string path = parent + "/" + child;
        if (!AssetDatabase.IsValidFolder(path))
            AssetDatabase.CreateFolder(parent, child);
    }

    static void ApplySampleImportSettings()
    {
        string[] required =
        {
            MountIdlePath,
            MountWalkPath,
            RiderIdlePath,
            RiderWalkPath,
        };

        HashSet<string> requiredSet = new(required.Select(NormalizePath), StringComparer.OrdinalIgnoreCase);
        MiniFantasyPixelImportTool.ApplyPixelImportSettings(
            new[] { MountRoot },
            path => requiredSet.Contains(NormalizePath(path)));
    }

    static CharacterFrameData LoadOrCreateFrameData(AnimationTypeDatabase animationDatabase)
    {
        CharacterFrameData frameData = AssetDatabase.LoadAssetAtPath<CharacterFrameData>(FrameDataPath);
        if (frameData == null)
        {
            frameData = ScriptableObject.CreateInstance<CharacterFrameData>();
            AssetDatabase.CreateAsset(frameData, FrameDataPath);
        }

        frameData.animDatabase = animationDatabase;
        frameData.paletteSize = new Vector2Int(32, 32);
        frameData.headUVRegion = new RectInt(0, 0, 4, 3);
        frameData.torsoUVRegion = new RectInt(0, 3, 3, 2);
        frameData.headDetectSize = new Vector2Int(4, 3);
        frameData.torsoDetectSize = new Vector2Int(3, 2);
        frameData.hasReferenceFrame = false;
        return frameData;
    }

    static MountRenderData LoadOrCreateMountData()
    {
        MountRenderData mountData = AssetDatabase.LoadAssetAtPath<MountRenderData>(MountAssetPath);
        if (mountData == null)
        {
            mountData = ScriptableObject.CreateInstance<MountRenderData>();
            AssetDatabase.CreateAsset(mountData, MountAssetPath);
        }

        return mountData;
    }

    static Equipment LoadOrCreateMountEquipment(MountRenderData mountData)
    {
        Equipment equipment = AssetDatabase.LoadAssetAtPath<Equipment>(MountEquipmentPath);
        if (equipment == null)
        {
            equipment = ScriptableObject.CreateInstance<Equipment>();
            AssetDatabase.CreateAsset(equipment, MountEquipmentPath);
        }

        SerializedObject serialized = new(equipment);
        serialized.FindProperty("m_category").enumValueIndex = (int)EItemCategory.Gear;
        serialized.FindProperty("m_displayName").stringValue = "战马";
        serialized.FindProperty("m_description").stringValue = "War 马骑乘样板，用于验证坐骑底层、骑手基础层和现有换装系统的接入。";
        serialized.FindProperty("m_price").intValue = 50;
        serialized.FindProperty("m_type").enumValueIndex = (int)EEquipmentType.Mount;
        serialized.FindProperty("m_visual").objectReferenceValue = mountData;
        serialized.ApplyModifiedPropertiesWithoutUndo();

        return equipment;
    }

    static void EnsureFrameDataAnimation(
        CharacterFrameData frameData,
        AnimationTypeItem animationType,
        Texture2D riderTexture,
        string riderTexturePath)
    {
        AnimationData existing = frameData.GetAnimation(animationType);
        if (existing != null)
        {
            if (existing.spritesheet == riderTexture
                && existing.bodyUVMap != null
                && existing.headUVMap != null
                && existing.frames != null
                && existing.frames.Count > 0)
            {
                return;
            }

            throw new InvalidOperationException(
                $"骑乘帧数据已存在但不完整：{animationType.name}。为避免覆盖人工标注，请在帧编辑器中修复该动作。");
        }

        AnimationData animation = new()
        {
            animationType = animationType,
            spritesheet = riderTexture,
            frameSize = FrameSize,
            framesPerRow = Mathf.Max(1, riderTexture.width / FrameSize.x),
            rowCount = Mathf.Max(1, riderTexture.height / FrameSize.y),
            frames = new List<FrameData>(),
        };

        TextureReadableScope.Execute(riderTexture, readableTexture =>
        {
            for (int row = 0; row < animation.rowCount; row++)
            {
                for (int frame = 0; frame < animation.framesPerRow; frame++)
                {
                    FrameData frameDataEntry = animation.GetOrCreateFrame(frame, row);
                    AutoPaintRiderFrame(frameData, readableTexture, frameDataEntry, row, frame);
                }
            }
        });

        frameData.animations.Add(animation);
        string uvPrefix = "HumanWarHorse_" + animationType.name;
        DualUVMapGenerator.GenerateDualUVMapsForAnimation(frameData, animation, GeneratedUvDirectory, uvPrefix);

        Debug.Log(
            $"坐骑骑手帧数据已生成: {animationType.name}, {riderTexturePath}, "
            + $"{animation.framesPerRow} 帧 x {animation.rowCount} 行。");
    }

    static void AutoPaintRiderFrame(
        CharacterFrameData data,
        Texture2D texture,
        FrameData frame,
        int row,
        int frameIndex)
    {
        frame.bodyRegions.Clear();
        frame.limbMask.Clear();
        frame.leftEyeClosed = false;
        frame.rightEyeClosed = false;

        FrameDataEditorTools.DetectParams p = FrameDataEditorTools.GetDetectParams(texture, row, frameIndex, FrameSize, data);
        if (p == null)
            return;

        Color32[] pixels = texture.GetPixels32();
        Dictionary<CharacterBodyPart, CharacterFacing> facings = new()
        {
            [CharacterBodyPart.Head] = (CharacterFacing)row,
            [CharacterBodyPart.Torso] = (CharacterFacing)row,
        };
        Dictionary<CharacterBodyPart, FrameVariant> variants = new();

        SaveUvRegion(data, texture, frame, CharacterBodyPart.Head, p.firstPixel, data.headDetectSize, data.headUVRegion, pixels, row, frameIndex, facings, variants);

        if (p.torsoStart.HasValue)
        {
            SaveUvRegion(data, texture, frame, CharacterBodyPart.Torso, p.torsoStart.Value, data.torsoDetectSize, data.torsoUVRegion, pixels, row, frameIndex, facings, variants);
        }

        frame.limbMask.SetPixels(
            CharacterBodyPart.LeftHand,
            FrameDataEditorTools.DetectLimb(p, CharacterBodyPart.LeftHand, p.GetLeftHandColor(), data));
        frame.limbMask.SetPixels(
            CharacterBodyPart.RightHand,
            FrameDataEditorTools.DetectLimb(p, CharacterBodyPart.RightHand, p.GetRightHandColor(), data));
        frame.limbMask.SetPixels(
            CharacterBodyPart.LeftFoot,
            FrameDataEditorTools.DetectLimb(p, CharacterBodyPart.LeftFoot, p.GetLeftFootColor(), data));
        frame.limbMask.SetPixels(
            CharacterBodyPart.RightFoot,
            FrameDataEditorTools.DetectLimb(p, CharacterBodyPart.RightFoot, p.GetRightFootColor(), data));

        FrameDataEditorTools.DetectEyes(
            p,
            data.headDetectSize,
            out HashSet<Vector2Int> leftEye,
            out HashSet<Vector2Int> rightEye,
            out bool leftEyeClosed,
            out bool rightEyeClosed);
        frame.limbMask.SetPixels(CharacterBodyPart.LeftEye, leftEye);
        frame.limbMask.SetPixels(CharacterBodyPart.RightEye, rightEye);
        frame.leftEyeClosed = leftEyeClosed;
        frame.rightEyeClosed = rightEyeClosed;
    }

    static void SaveUvRegion(
        CharacterFrameData data,
        Texture2D texture,
        FrameData frame,
        CharacterBodyPart part,
        Vector2Int start,
        Vector2Int detectSize,
        RectInt uvRegion,
        Color32[] pixels,
        int row,
        int frameIndex,
        Dictionary<CharacterBodyPart, CharacterFacing> facings,
        Dictionary<CharacterBodyPart, FrameVariant> variants)
    {
        HashSet<Vector2Int> regionPixels = new();
        Dictionary<Vector2Int, Vector2> regionUvs = new();
        FrameDataAlgorithms.FillPartWithUV(start, detectSize, uvRegion, FrameSize, data.paletteSize, regionPixels, regionUvs);
        HashSet<Vector2Int> corePixels = new(regionPixels);

        FrameDataPersistence.SaveUVPartToFrame(
            frame,
            part,
            regionPixels,
            regionUvs,
            corePixels,
            facings,
            variants,
            pixels,
            frameIndex,
            row,
            FrameSize,
            texture);
    }

    static void ConfigureMountAsset(
        MountRenderData mountData,
        CharacterFrameData frameData,
        AnimationTypeItem idleType,
        AnimationTypeItem walkType)
    {
        SerializedObject serialized = new(mountData);
        serialized.FindProperty("mountId").stringValue = "war_horse_human";
        serialized.FindProperty("displayName").stringValue = "战马（人类骑手）";
        serialized.FindProperty("riderFrameData").objectReferenceValue = frameData;
        serialized.FindProperty("fallbackAction").enumValueIndex = (int)MountActionSemantic.Stand;
        serialized.FindProperty("fallbackAnimationKey").stringValue = "Idle";

        SerializedProperty animations = serialized.FindProperty("animations");
        ConfigureAnimation(
            FindOrAppendAnimation(animations, MountActionSemantic.Stand),
            MountActionSemantic.Stand,
            idleType,
            StandCycleSeconds,
            true,
            MountIdlePath,
            RiderIdlePath);
        ConfigureAnimation(
            FindOrAppendAnimation(animations, MountActionSemantic.Move),
            MountActionSemantic.Move,
            walkType,
            MoveCycleSeconds,
            true,
            MountWalkPath,
            RiderWalkPath);
        serialized.ApplyModifiedPropertiesWithoutUndo();
    }

    static SerializedProperty FindOrAppendAnimation(
        SerializedProperty animations,
        MountActionSemantic action)
    {
        for (int i = 0; i < animations.arraySize; i++)
        {
            SerializedProperty candidate = animations.GetArrayElementAtIndex(i);
            if (candidate.FindPropertyRelative("mountAction").enumValueIndex == (int)action)
                return candidate;
        }

        int index = animations.arraySize;
        animations.arraySize++;
        return animations.GetArrayElementAtIndex(index);
    }

    static void ConfigureAnimation(
        SerializedProperty animation,
        MountActionSemantic mountAction,
        AnimationTypeItem animationType,
        float cycleDurationSeconds,
        bool loop,
        string mountPath,
        string riderPath)
    {
        Sprite[][] mountRows = LoadSpriteRows(mountPath);
        Sprite[][] riderRows = LoadSpriteRows(riderPath);
        int frameCount = EstimateSynchronizedFrameCount(mountRows, riderRows);

        animation.FindPropertyRelative("mountAction").enumValueIndex = (int)mountAction;
        animation.FindPropertyRelative("customActionKey").stringValue = string.Empty;
        animation.FindPropertyRelative("animationType").objectReferenceValue = animationType;
        animation.FindPropertyRelative("secondsPerFrame").floatValue =
            Mathf.Max(0.01f, cycleDurationSeconds / Mathf.Max(1, frameCount));
        animation.FindPropertyRelative("cycleDurationSeconds").floatValue = Mathf.Max(0.01f, cycleDurationSeconds);
        animation.FindPropertyRelative("loop").boolValue = loop;
        animation.FindPropertyRelative("completionBehavior").enumValueIndex =
            (int)MountActionCompletionBehavior.HoldLastFrame;
        animation.FindPropertyRelative("directionMode").enumValueIndex = (int)MountDirectionMode.FourDirections;
        animation.FindPropertyRelative("mountEmptyBehavior").enumValueIndex = (int)MountLayerEmptyBehavior.Required;
        animation.FindPropertyRelative("riderEmptyBehavior").enumValueIndex = (int)MountLayerEmptyBehavior.Required;

        SerializedProperty mountFrames = animation.FindPropertyRelative("mountFrames");
        SerializedProperty riderFrames = animation.FindPropertyRelative("riderFrames");
        if (!HasAnyDirectionalFrame(mountFrames) && !HasAnyDirectionalFrame(riderFrames))
        {
            ConfigureDirectionalFrames(mountFrames, mountRows);
            ConfigureDirectionalFrames(riderFrames, riderRows);
        }
    }

    static bool HasAnyDirectionalFrame(SerializedProperty frames)
    {
        return frames.FindPropertyRelative("southEast").arraySize > 0
            || frames.FindPropertyRelative("southWest").arraySize > 0
            || frames.FindPropertyRelative("northEast").arraySize > 0
            || frames.FindPropertyRelative("northWest").arraySize > 0;
    }

    static int EstimateSynchronizedFrameCount(Sprite[][] mountRows, Sprite[][] riderRows)
    {
        int frameCount = 0;
        for (int direction = 0; direction < CharacterAnimationDirections.Count; direction++)
        {
            int mountCount = GetRowFrameCount(mountRows, direction);
            int riderCount = GetRowFrameCount(riderRows, direction);
            if (mountCount <= 0 || riderCount <= 0 || mountCount != riderCount)
            {
                throw new InvalidOperationException(
                    $"坐骑本体与骑手层帧数不一致：{CharacterAnimationDirections.GetName(direction)}，"
                    + $"本体 {mountCount}，骑手 {riderCount}。");
            }

            frameCount = Mathf.Max(frameCount, mountCount);
        }

        return Mathf.Max(1, frameCount);
    }

    static int GetRowFrameCount(Sprite[][] rows, int directionIndex)
    {
        if (rows == null || rows.Length == 0)
            return 0;

        Sprite[] row = directionIndex >= 0 && directionIndex < rows.Length
            ? rows[directionIndex]
            : null;
        return row != null ? row.Length : 0;
    }

    static void ConfigureDirectionalFrames(SerializedProperty framesProperty, Sprite[][] rows)
    {
        SetSpriteArray(framesProperty.FindPropertyRelative("southEast"), rows, CharacterAnimationDirections.SouthEast);
        SetSpriteArray(framesProperty.FindPropertyRelative("southWest"), rows, CharacterAnimationDirections.SouthWest);
        SetSpriteArray(framesProperty.FindPropertyRelative("northEast"), rows, CharacterAnimationDirections.NorthEast);
        SetSpriteArray(framesProperty.FindPropertyRelative("northWest"), rows, CharacterAnimationDirections.NorthWest);
    }

    static void SetSpriteArray(SerializedProperty arrayProperty, Sprite[][] rows, int directionIndex)
    {
        Sprite[] sprites = rows != null && directionIndex >= 0 && directionIndex < rows.Length
            ? rows[directionIndex]
            : Array.Empty<Sprite>();

        arrayProperty.arraySize = sprites.Length;
        for (int i = 0; i < sprites.Length; i++)
            arrayProperty.GetArrayElementAtIndex(i).objectReferenceValue = sprites[i];
    }

    static Sprite[][] LoadSpriteRows(string texturePath)
    {
        Texture2D texture = AssetDatabase.LoadAssetAtPath<Texture2D>(texturePath);
        if (texture == null)
            throw new InvalidOperationException($"缺少坐骑样板贴图：{texturePath}");

        int rows = Mathf.Max(1, texture.height / FrameSize.y);
        Sprite[][] result = new Sprite[Mathf.Max(CharacterAnimationDirections.Count, rows)][];
        List<Sprite>[] buckets = new List<Sprite>[result.Length];
        for (int i = 0; i < buckets.Length; i++)
            buckets[i] = new List<Sprite>();

        Sprite[] sprites = AssetDatabase.LoadAllAssetsAtPath(texturePath)
            .OfType<Sprite>()
            .Where(sprite => Mathf.Approximately(sprite.rect.width, FrameSize.x)
                && Mathf.Approximately(sprite.rect.height, FrameSize.y))
            .ToArray();

        if (sprites.Length == 0)
            throw new InvalidOperationException($"贴图尚未按 32x32 Multiple 切片：{texturePath}");

        foreach (Sprite sprite in sprites)
        {
            int row = Mathf.FloorToInt((texture.height - sprite.rect.y - sprite.rect.height) / FrameSize.y);
            if (row < 0 || row >= buckets.Length)
                continue;

            buckets[row].Add(sprite);
        }

        for (int row = 0; row < buckets.Length; row++)
        {
            result[row] = buckets[row]
                .OrderBy(sprite => sprite.rect.x)
                .ToArray();
        }

        return result;
    }

    static string NormalizePath(string path)
    {
        return path?.Replace('\\', '/') ?? string.Empty;
    }

    static Transform FindOrCreateChild(Transform parent, string childName)
    {
        Transform child = parent.Find(childName);
        if (child != null)
            return child;

        GameObject childObject = new(childName);
        child = childObject.transform;
        child.SetParent(parent, false);
        child.localPosition = Vector3.zero;
        child.localRotation = Quaternion.identity;
        child.localScale = Vector3.one;
        return child;
    }

    static SpriteRenderer FindOrCreateSpriteRenderer(Transform parent, string childName)
    {
        Transform child = FindOrCreateChild(parent, childName);
        SpriteRenderer renderer = child.GetComponent<SpriteRenderer>();
        if (renderer == null)
            renderer = child.gameObject.AddComponent<SpriteRenderer>();

        return renderer;
    }

    static void ConfigureMountedLayerRenderer(SpriteRenderer renderer, SpriteRenderer riderRenderer, int sortingOffset)
    {
        renderer.sprite = null;
        renderer.enabled = false;
        renderer.color = Color.white;
        renderer.flipX = false;
        renderer.flipY = false;
        renderer.maskInteraction = SpriteMaskInteraction.None;
        renderer.sortingLayerID = riderRenderer.sortingLayerID;
        renderer.sortingOrder = riderRenderer.sortingOrder + sortingOffset;
        renderer.sharedMaterial = null;
        renderer.transform.localPosition = Vector3.zero;
        renderer.transform.localRotation = Quaternion.identity;
        renderer.transform.localScale = Vector3.one;
    }

    static void SetObjectReference(UnityEngine.Object target, string propertyName, UnityEngine.Object value)
    {
        SerializedObject serialized = new(target);
        SerializedProperty property = serialized.FindProperty(propertyName);
        if (property == null)
            throw new MissingFieldException(target.GetType().FullName, propertyName);

        property.objectReferenceValue = value;
        serialized.ApplyModifiedPropertiesWithoutUndo();
    }

    static string GetTransformPath(Transform target)
    {
        if (target == null)
            return string.Empty;

        string path = target.name;
        Transform current = target.parent;
        while (current != null)
        {
            path = current.name + "/" + path;
            current = current.parent;
        }

        return path;
    }

    [Serializable]
    sealed class MountSampleAssetGenerationResult
    {
        public string frameData;
        public string mountData;
        public string equipment;
        public string uvDirectory;
        public int animations;
    }

    [Serializable]
    sealed class MountPrefabInstallationResult
    {
        public string prefabPath;
        public string equipmentRendererPath;
        public string mountedPresentationPath;
        public string mountRendererPath;
        public string characterEquipmentPresentationPath;
    }
}
