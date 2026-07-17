using System;
using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// 换装工作台中的可选角色配置，聚合角色帧、动画库、初始外观、基础属性和默认装备。
/// </summary>
[Serializable]
public sealed class EquipmentWorkbenchCharacterOption
{
    [InspectorName("显示名称")]
    [Tooltip("工作台 UI 显示的角色名称。为空时使用角色帧资源名作为兜底。")]
    [SerializeField]
    string displayName;

    [InspectorName("角色帧数据")]
    [Tooltip("驱动工作台角色基础帧尺寸、锚点和方向信息的资源。")]
    [SerializeField]
    CharacterFrameData frameData;

    [InspectorName("动画库")]
    [Tooltip("该角色在工作台预览中使用的方向动画库集合。")]
    [SerializeField]
    DirectionalSpriteLibrarySet animationLibraries = new DirectionalSpriteLibrarySet();

    [InspectorName("角色外观")]
    [Tooltip("角色进入工作台时使用的基础外观配置。")]
    [SerializeField]
    CharacterAppearance appearance;

    [InspectorName("基础属性")]
    [Tooltip("工作台展示装备变化时使用的角色基础属性。")]
    [SerializeField]
    WorkbenchStatBlock baseStats = new WorkbenchStatBlock();

    [InspectorName("默认装备")]
    [Tooltip("角色进入工作台时默认穿戴的装备外观列表。")]
    [SerializeField]
    List<EquipmentRenderData> defaultEquipment = new List<EquipmentRenderData>();

    public string DisplayName => string.IsNullOrWhiteSpace(displayName)
        ? (frameData != null ? frameData.name : "Unnamed Character")
        : displayName;

    public CharacterFrameData FrameData => frameData;
    public DirectionalSpriteLibrarySet AnimationLibraries => animationLibraries;
    public CharacterAppearance Appearance => appearance;
    public WorkbenchStatBlock BaseStats => baseStats;
    public IReadOnlyList<EquipmentRenderData> DefaultEquipment => defaultEquipment;

#if UNITY_EDITOR
    public void SetAnimationLibraries(DirectionalSpriteLibrarySet libraries)
    {
        animationLibraries = libraries;
    }
#endif
}

/// <summary>
/// 换装工作台中的单个装备选项，负责把 UI 文案、图标、外观和属性加成绑定到一起。
/// </summary>
[Serializable]
public sealed class EquipmentWorkbenchEquipmentOption
{
    [InspectorName("显示名称")]
    [Tooltip("工作台 UI 显示的装备名称。为空时使用外观资源名作为兜底。")]
    [SerializeField]
    string displayName;

    [InspectorName("描述")]
    [Tooltip("工作台 UI 展示的装备说明文本。")]
    [SerializeField]
    string description;

    [InspectorName("图标")]
    [Tooltip("装备在工作台 UI 中显示的图标。为空时由 UI 侧自行兜底。")]
    [SerializeField]
    Sprite icon;

    [InspectorName("装备外观")]
    [Tooltip("该装备选项对应的渲染外观资源，同时决定装备类型。")]
    [SerializeField]
    EquipmentRenderData visual;

    [InspectorName("属性加成")]
    [Tooltip("装备被选中或穿戴时展示给工作台的属性变化。")]
    [SerializeField]
    WorkbenchStatBlock bonusStats = new WorkbenchStatBlock();

    public string DisplayName => string.IsNullOrWhiteSpace(displayName)
        ? (visual != null ? visual.name : "Unnamed Equipment")
        : displayName;

    public string Description => description;
    public Sprite CustomIcon => icon;
    public Sprite Icon => icon;
    public EquipmentRenderData Visual => visual;
    public WorkbenchStatBlock BonusStats => bonusStats;
    public EquipmentType Type => visual != null ? visual.type : EquipmentType.Weapon;
}

/// <summary>
/// 换装工作台目录资产，集中提供可选角色、可选装备和按装备类型分组后的查询缓存。
/// </summary>
[CreateAssetMenu(
    fileName = "换装工作台目录",
    menuName = "Equipment System/Workbench/Catalog"
)]
public sealed class EquipmentWorkbenchCatalog : ScriptableObject
{
    [InspectorName("可选角色")]
    [Tooltip("工作台可切换的角色列表。")]
    [SerializeField]
    List<EquipmentWorkbenchCharacterOption> characters = new List<EquipmentWorkbenchCharacterOption>();

    [InspectorName("可选装备")]
    [Tooltip("工作台可展示和切换的装备列表。")]
    [SerializeField]
    List<EquipmentWorkbenchEquipmentOption> equipments = new List<EquipmentWorkbenchEquipmentOption>();

    readonly Dictionary<EquipmentType, List<EquipmentWorkbenchEquipmentOption>> _optionsByType =
        new Dictionary<EquipmentType, List<EquipmentWorkbenchEquipmentOption>>();

    readonly Dictionary<EquipmentRenderData, EquipmentWorkbenchEquipmentOption> _optionsByVisual =
        new Dictionary<EquipmentRenderData, EquipmentWorkbenchEquipmentOption>();

    readonly List<EquipmentType> _availableCategories = new List<EquipmentType>();

    bool _cacheBuilt;

    public IReadOnlyList<EquipmentWorkbenchCharacterOption> Characters => characters;

    /// <summary>
    /// 返回当前目录中实际有装备选项的装备类型列表。
    /// </summary>
    public IReadOnlyList<EquipmentType> GetAvailableCategories()
    {
        EnsureCache();
        return _availableCategories;
    }

    /// <summary>
    /// 按装备类型填充可选装备结果列表；调用方负责传入可复用列表以减少临时分配。
    /// </summary>
    public void GetEquipmentOptionsForType(
        EquipmentType type,
        List<EquipmentWorkbenchEquipmentOption> results)
    {
        if (results == null)
            return;

        EnsureCache();
        results.Clear();

        if (_optionsByType.TryGetValue(type, out List<EquipmentWorkbenchEquipmentOption> bucket))
            results.AddRange(bucket);
    }

    /// <summary>
    /// 根据装备外观资源反查工作台装备选项。
    /// </summary>
    public bool TryGetEquipmentOption(
        EquipmentRenderData visual,
        out EquipmentWorkbenchEquipmentOption option)
    {
        EnsureCache();
        option = null;
        return visual != null && _optionsByVisual.TryGetValue(visual, out option);
    }

    void OnEnable()
    {
        InvalidateCache();
    }

#if UNITY_EDITOR
    void OnValidate()
    {
        InvalidateCache();
    }
#endif

    void InvalidateCache()
    {
        _cacheBuilt = false;
        _optionsByType.Clear();
        _optionsByVisual.Clear();
        _availableCategories.Clear();
    }

    void EnsureCache()
    {
        if (_cacheBuilt)
        {
            bool cacheLooksStale = equipments.Count > 0
                && _optionsByType.Count > 0
                && _availableCategories.Count == 0
                && EquipTypeRegistry.All.Count > 0;
            if (!cacheLooksStale)
                return;
        }

        InvalidateCache();

        for (int i = 0; i < equipments.Count; i++)
        {
            EquipmentWorkbenchEquipmentOption option = equipments[i];
            if (option == null || option.Visual == null)
                continue;

            if (!_optionsByType.TryGetValue(option.Type, out List<EquipmentWorkbenchEquipmentOption> bucket))
            {
                bucket = new List<EquipmentWorkbenchEquipmentOption>();
                _optionsByType.Add(option.Type, bucket);
            }

            bucket.Add(option);

            if (!_optionsByVisual.ContainsKey(option.Visual))
                _optionsByVisual.Add(option.Visual, option);
        }

        for (int i = 0; i < EquipTypeRegistry.All.Count; i++)
        {
            EquipTypeConfig config = EquipTypeRegistry.All[i];
            if (config != null && _optionsByType.ContainsKey(config.Type))
                _availableCategories.Add(config.Type);
        }

        _cacheBuilt = true;
    }
}
