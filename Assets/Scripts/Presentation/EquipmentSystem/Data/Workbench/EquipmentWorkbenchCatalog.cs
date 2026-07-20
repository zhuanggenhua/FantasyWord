using System;
using System.Collections.Generic;
using FantasyWord.GameCore;
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
/// 换装工作台中的坐骑装备选项。
/// 坐骑占用玩法装备的 Mount 槽，不进入普通 EquipmentType 的 UV 合成分类。
/// </summary>
[Serializable]
public sealed class EquipmentWorkbenchMountOption
{
    [InspectorName("显示名称")]
    [Tooltip("工作台 UI 显示的坐骑名称。为空时优先使用装备名称，再使用坐骑表现资源名。")]
    [SerializeField]
    string displayName;

    [InspectorName("描述")]
    [Tooltip("工作台 UI 展示的坐骑说明文本。为空时使用装备资产描述。")]
    [SerializeField]
    string description;

    [InspectorName("图标")]
    [Tooltip("坐骑在工作台 UI 中显示的图标。为空时由 UI 从坐骑原版帧里取首帧兜底。")]
    [SerializeField]
    Sprite icon;

    [InspectorName("坐骑装备")]
    [Tooltip("正式玩法装备资产，必须占用 Mount 槽并引用 MountRenderData。")]
    [SerializeField]
    Equipment equipment;

    [InspectorName("属性加成")]
    [Tooltip("坐骑被选中或穿戴时展示给工作台的属性变化。")]
    [SerializeField]
    WorkbenchStatBlock bonusStats = new WorkbenchStatBlock();

    public string DisplayName
    {
        get
        {
            if (!string.IsNullOrWhiteSpace(displayName))
                return displayName;

            if (equipment != null && !string.IsNullOrWhiteSpace(equipment.displayName))
                return equipment.displayName;

            return MountVisual != null ? MountVisual.DisplayName : "未命名坐骑";
        }
    }

    public string Description => !string.IsNullOrWhiteSpace(description)
        ? description
        : equipment != null ? equipment.description : string.Empty;
    public Sprite CustomIcon => icon != null ? icon : equipment != null ? equipment.icon : null;
    public Sprite Icon => CustomIcon;
    public Equipment Equipment => equipment;
    public MountRenderData MountVisual => equipment != null ? equipment.visual as MountRenderData : null;
    public WorkbenchStatBlock BonusStats => bonusStats;
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

    [InspectorName("可选坐骑")]
    [Tooltip("工作台可展示和切换的坐骑装备列表。坐骑走玩法 Mount 槽，不走普通换装 UV 合成分类。")]
    [SerializeField]
    List<EquipmentWorkbenchMountOption> mounts = new List<EquipmentWorkbenchMountOption>();

    readonly Dictionary<EquipmentType, List<EquipmentWorkbenchEquipmentOption>> _optionsByType =
        new Dictionary<EquipmentType, List<EquipmentWorkbenchEquipmentOption>>();

    readonly Dictionary<EquipmentRenderData, EquipmentWorkbenchEquipmentOption> _optionsByVisual =
        new Dictionary<EquipmentRenderData, EquipmentWorkbenchEquipmentOption>();

    readonly Dictionary<Equipment, EquipmentWorkbenchMountOption> _mountOptionsByEquipment =
        new Dictionary<Equipment, EquipmentWorkbenchMountOption>();

    readonly List<EquipmentType> _availableCategories = new List<EquipmentType>();

    readonly List<EquipmentWorkbenchMountOption> _validMountOptions = new List<EquipmentWorkbenchMountOption>();

    bool _cacheBuilt;

    public IReadOnlyList<EquipmentWorkbenchCharacterOption> Characters => characters;
    public bool HasMountOptions
    {
        get
        {
            EnsureCache();
            return _validMountOptions.Count > 0;
        }
    }

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

    /// <summary>
    /// 填充可选坐骑结果列表；调用方负责传入可复用列表以减少临时分配。
    /// </summary>
    public void GetMountOptions(List<EquipmentWorkbenchMountOption> results)
    {
        if (results == null)
            return;

        EnsureCache();
        results.Clear();
        results.AddRange(_validMountOptions);
    }

    /// <summary>
    /// 根据正式玩法装备反查工作台坐骑选项。
    /// </summary>
    public bool TryGetMountOption(Equipment equipment, out EquipmentWorkbenchMountOption option)
    {
        EnsureCache();
        option = null;
        return equipment != null && _mountOptionsByEquipment.TryGetValue(equipment, out option);
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
        _mountOptionsByEquipment.Clear();
        _availableCategories.Clear();
        _validMountOptions.Clear();
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

        for (int i = 0; i < mounts.Count; i++)
        {
            EquipmentWorkbenchMountOption option = mounts[i];
            if (option == null || option.Equipment == null)
                continue;

            if (option.Equipment.type != EEquipmentType.Mount || option.MountVisual == null)
                continue;

            _validMountOptions.Add(option);
            if (!_mountOptionsByEquipment.ContainsKey(option.Equipment))
                _mountOptionsByEquipment.Add(option.Equipment, option);
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
