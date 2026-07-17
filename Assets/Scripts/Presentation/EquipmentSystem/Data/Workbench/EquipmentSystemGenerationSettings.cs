using System;
using UnityEngine;

/// <summary>
/// 换装动画派生资源生成设置。
/// 运行时不按这些路径加载装备；它们只约束 Editor 生成器产出位置和共享动作片段参数。
/// </summary>
[CreateAssetMenu(
    fileName = "换装动画生成设置",
    menuName = "Equipment System/Workbench/Animation Generation Settings"
)]
public sealed class EquipmentSystemGenerationSettings : ScriptableObject
{
    public const string DefaultSettingsAssetPath =
        "Assets/GameData/EquipmentSystem/Data/Workbench/换装动画生成设置.asset";
    public const string DefaultAnimationDatabasePath =
        "Assets/GameData/EquipmentSystem/AnimationType/AnimationTypeDatabase.asset";
    public const string DefaultWorkbenchCatalogPath =
        "Assets/GameData/EquipmentSystem/Data/Workbench/换装工作台目录.asset";
    public const string DefaultAnimationRoot =
        "Assets/GameData/EquipmentSystem/Animations";
    public const string DefaultControllerFileName =
        "换装共享动画状态机.controller";
    public const string DefaultSharedClipFolderName =
        "SharedClips";
    public const string DefaultSpriteLibraryFolderName =
        "SpriteLibraries";
    public const float DefaultFrameRate = 8f;

    [Header("源资产")]
    [SerializeField]
    string animationDatabasePath = DefaultAnimationDatabasePath;

    [SerializeField]
    string workbenchCatalogPath = DefaultWorkbenchCatalogPath;

    [Header("派生资源输出")]
    [SerializeField]
    string animationRoot = DefaultAnimationRoot;

    [SerializeField]
    string controllerFileName = DefaultControllerFileName;

    [SerializeField]
    string sharedClipFolderName = DefaultSharedClipFolderName;

    [SerializeField]
    string spriteLibraryFolderName = DefaultSpriteLibraryFolderName;

    [Header("片段参数")]
    [SerializeField]
    float frameRate = DefaultFrameRate;

    [SerializeField]
    bool fallbackMissingDirectionsToFirstAvailable = true;

    [SerializeField]
    string[] loopingActions =
    {
        "Idle",
        "Wait",
        "Walk",
        "Run",
        "AnvilWorking",
        "Chopping",
        "Harvest",
        "JewelryWorkshopWorking",
        "LaboratoryWorking",
        "Mining",
        "WoodworkBenchWorking"
    };

    public string AnimationDatabasePath => NormalizeAssetPath(
        animationDatabasePath,
        DefaultAnimationDatabasePath);

    public string WorkbenchCatalogPath => NormalizeAssetPath(
        workbenchCatalogPath,
        DefaultWorkbenchCatalogPath);

    public string AnimationRoot => NormalizeFolderPath(animationRoot, DefaultAnimationRoot);

    public string ControllerPath => CombineAssetPath(
        AnimationRoot,
        NormalizeFileName(controllerFileName, DefaultControllerFileName));

    public string SharedClipRoot => CombineAssetPath(
        AnimationRoot,
        NormalizeFileName(sharedClipFolderName, DefaultSharedClipFolderName));

    public string SpriteLibraryRoot => CombineAssetPath(
        AnimationRoot,
        NormalizeFileName(spriteLibraryFolderName, DefaultSpriteLibraryFolderName));

    public float FrameRate => Mathf.Max(1f, frameRate);
    public bool FallbackMissingDirectionsToFirstAvailable => fallbackMissingDirectionsToFirstAvailable;

    public bool IsLoopingAction(string actionKey)
    {
        if (string.IsNullOrWhiteSpace(actionKey) || loopingActions == null)
            return false;

        for (int i = 0; i < loopingActions.Length; i++)
        {
            if (string.Equals(actionKey, loopingActions[i], StringComparison.OrdinalIgnoreCase))
                return true;
        }

        return false;
    }

    static string NormalizeAssetPath(string value, string fallback)
    {
        string normalized = string.IsNullOrWhiteSpace(value) ? fallback : value;
        return normalized.Replace('\\', '/').Trim();
    }

    static string NormalizeFolderPath(string value, string fallback)
    {
        return NormalizeAssetPath(value, fallback).TrimEnd('/');
    }

    static string NormalizeFileName(string value, string fallback)
    {
        string normalized = string.IsNullOrWhiteSpace(value) ? fallback : value;
        return normalized.Replace('\\', '/').Trim().Trim('/');
    }

    static string CombineAssetPath(string root, string leaf)
    {
        return NormalizeFolderPath(root, DefaultAnimationRoot)
            + "/"
            + NormalizeFileName(leaf, string.Empty);
    }
}
