using System;
using System.Collections.Generic;
using UnityEngine;

[Serializable]
public sealed class EquipmentWorkbenchCharacterOption
{
    [SerializeField]
    string displayName;

    [SerializeField]
    CharacterFrameData frameData;

    [SerializeField]
    DirectionalSpriteLibrarySet animationLibraries = new DirectionalSpriteLibrarySet();

    [SerializeField]
    CharacterAppearance appearance;

    [SerializeField]
    WorkbenchStatBlock baseStats = new WorkbenchStatBlock();

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

[Serializable]
public sealed class EquipmentWorkbenchEquipmentOption
{
    [SerializeField]
    string displayName;

    [SerializeField]
    string description;

    [SerializeField]
    Sprite icon;

    [SerializeField]
    EquipmentRenderData visual;

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

[CreateAssetMenu(
    fileName = "换装工作台目录",
    menuName = "Equipment System/Workbench/Catalog"
)]
public sealed class EquipmentWorkbenchCatalog : ScriptableObject
{
    [SerializeField]
    List<EquipmentWorkbenchCharacterOption> characters = new List<EquipmentWorkbenchCharacterOption>();

    [SerializeField]
    List<EquipmentWorkbenchEquipmentOption> equipments = new List<EquipmentWorkbenchEquipmentOption>();

    readonly Dictionary<EquipmentType, List<EquipmentWorkbenchEquipmentOption>> _optionsByType =
        new Dictionary<EquipmentType, List<EquipmentWorkbenchEquipmentOption>>();

    readonly Dictionary<EquipmentRenderData, EquipmentWorkbenchEquipmentOption> _optionsByVisual =
        new Dictionary<EquipmentRenderData, EquipmentWorkbenchEquipmentOption>();

    readonly List<EquipmentType> _availableCategories = new List<EquipmentType>();

    bool _cacheBuilt;

    public IReadOnlyList<EquipmentWorkbenchCharacterOption> Characters => characters;

    public IReadOnlyList<EquipmentType> GetAvailableCategories()
    {
        EnsureCache();
        return _availableCategories;
    }

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
