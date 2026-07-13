using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Serialization;

/// <summary>
/// 换装工作台控制器：负责角色切换、装备切换和属性汇总。
/// </summary>
[DisallowMultipleComponent]
public sealed class EquipmentWorkbenchController : MonoBehaviour
{
    [SerializeField]
    [FormerlySerializedAs("configuration")]
    EquipmentWorkbenchCatalog catalog;

    [SerializeField]
    EquipmentRenderer equipmentRenderer;

    [SerializeField]
    AnimationController animationController;

    [SerializeField]
    DirectionalAnimationVariantDriver directionDriver;

    bool _initialized;
    int _currentCharacterIndex = -1;
    EquipmentType _currentCategory;

    readonly Dictionary<EquipmentType, EquipmentWorkbenchEquipmentOption> _equippedOptions =
        new Dictionary<EquipmentType, EquipmentWorkbenchEquipmentOption>();

    readonly List<EquipmentWorkbenchEquipmentOption> _currentOptions =
        new List<EquipmentWorkbenchEquipmentOption>();

    readonly List<CharacterAppearance> _appearanceOptions = new List<CharacterAppearance>();
    readonly Dictionary<CharacterAppearance, int> _appearanceIndices =
        new Dictionary<CharacterAppearance, int>();

    readonly Dictionary<WorkbenchStatType, int> _statTotals =
        new Dictionary<WorkbenchStatType, int>();

    public event Action StateChanged;

    public EquipmentWorkbenchCatalog Catalog => catalog;
    public EquipmentRenderer Renderer => equipmentRenderer;
    public AnimationController AnimationController => animationController;
    public DirectionalAnimationVariantDriver DirectionDriver => directionDriver;
    public int CurrentCharacterIndex => _currentCharacterIndex;
    public int CurrentAppearanceIndex { get; private set; } = -1;
    public EquipmentType CurrentCategory => _currentCategory;
    public int CurrentAnimationIndex => animationController != null ? animationController.CurrentAnimationIndex : 0;
    public int CurrentDirectionIndex => directionDriver != null ? directionDriver.CurrentDirectionIndex : 0;
    public EquipmentWorkbenchCharacterOption CurrentCharacter =>
        catalog != null
        && _currentCharacterIndex >= 0
        && _currentCharacterIndex < catalog.Characters.Count
            ? catalog.Characters[_currentCharacterIndex]
            : null;
    public CharacterAppearance CurrentAppearance =>
        GetAppearanceOptions().Count > 0 && CurrentAppearanceIndex >= 0 && CurrentAppearanceIndex < _appearanceOptions.Count
            ? _appearanceOptions[CurrentAppearanceIndex]
            : CurrentCharacter?.Appearance;

    public void Configure(
        EquipmentWorkbenchCatalog newCatalog,
        EquipmentRenderer newRenderer,
        AnimationController newAnimationController,
        DirectionalAnimationVariantDriver newDirectionDriver)
    {
        catalog = newCatalog;
        equipmentRenderer = newRenderer;
        animationController = newAnimationController;
        directionDriver = newDirectionDriver;
        _initialized = false;
    }

    public void InitializeIfNeeded()
    {
        if (_initialized)
            return;

        if (equipmentRenderer == null)
            equipmentRenderer = GetComponent<EquipmentRenderer>();
        if (animationController == null)
            animationController = GetComponent<AnimationController>();
        if (directionDriver == null)
            directionDriver = GetComponent<DirectionalAnimationVariantDriver>();

        if (catalog == null || equipmentRenderer == null || animationController == null || directionDriver == null)
            return;

        IReadOnlyList<EquipmentType> categories = catalog.GetAvailableCategories();
        _currentCategory = categories.Count > 0 ? categories[0] : EquipmentType.Clothing;

        int defaultCharacterIndex = FindDefaultCharacterIndex();
        if (defaultCharacterIndex >= 0)
            ApplyCharacter(defaultCharacterIndex, false);

        RebuildAppearanceOptions();
        SyncCurrentAppearanceFromCharacter(false);

        _initialized = true;
        NotifyStateChanged();
    }

    public IReadOnlyList<AnimationTypeItem> GetAnimationOptions()
    {
        if (animationController == null || animationController.AnimationDatabase == null)
            return Array.Empty<AnimationTypeItem>();

        return animationController.AnimationDatabase.ItemsReadOnly;
    }

    public IReadOnlyList<EquipmentType> GetAvailableCategories()
    {
        if (catalog == null)
            return Array.Empty<EquipmentType>();

        return catalog.GetAvailableCategories();
    }

    public IReadOnlyList<EquipmentWorkbenchEquipmentOption> GetOptionsForCurrentCategory()
    {
        _currentOptions.Clear();
        if (catalog != null)
            catalog.GetEquipmentOptionsForType(_currentCategory, _currentOptions);
        return _currentOptions;
    }

    public IReadOnlyList<CharacterAppearance> GetAppearanceOptions()
    {
        EnsureAppearanceOptions();
        return _appearanceOptions;
    }

    public EquipmentWorkbenchEquipmentOption GetEquippedOption(EquipmentType type)
    {
        return _equippedOptions.TryGetValue(type, out EquipmentWorkbenchEquipmentOption option)
            ? option
            : null;
    }

    public bool IsEquipped(EquipmentWorkbenchEquipmentOption option)
    {
        return option != null
            && _equippedOptions.TryGetValue(option.Type, out EquipmentWorkbenchEquipmentOption equipped)
            && equipped == option;
    }

    public int GetTotalStat(WorkbenchStatType stat)
    {
        RecalculateTotals();
        return _statTotals.TryGetValue(stat, out int value) ? value : 0;
    }

    public void SelectCharacter(int index)
    {
        InitializeIfNeeded();
        ApplyCharacter(index, true);
    }

    public void SelectAppearance(int index)
    {
        InitializeIfNeeded();
        ApplyAppearance(index, true);
    }

    public void SelectAnimation(int index)
    {
        InitializeIfNeeded();
        if (!CanSelectAnimation(index))
            return;

        animationController.AnimationDatabase.TryGetByIndex(index, out AnimationTypeItem animation);
        bool previewApplied = equipmentRenderer != null
            && animation != null
            && equipmentRenderer.TrySetPreviewAnimation(animation, false);

        if (!previewApplied)
            return;

        animationController.SetAnimation(index);
        equipmentRenderer.SyncCurrentSpriteAndRefresh();
        equipmentRenderer.SyncCurrentSpriteAndRefreshNextFrame();

        NotifyStateChanged();
    }

    public bool CanSelectAnimation(int index)
    {
        if (animationController == null
            || animationController.AnimationDatabase == null
            || index < 0
            || index >= animationController.AnimationDatabase.Count)
        {
            return false;
        }

        if (!animationController.AnimationDatabase.TryGetByIndex(index, out AnimationTypeItem animation)
            || animation == null)
            return false;

        return equipmentRenderer != null
            && (equipmentRenderer.HasExactBodyAnimation(animation)
                || equipmentRenderer.UsesBodyAnimationFallback(animation));
    }

    public void SelectDirection(int index)
    {
        InitializeIfNeeded();
        if (directionDriver == null)
            return;

        directionDriver.SetDirection(index);
        NotifyStateChanged();
    }

    public void SelectCategory(EquipmentType type)
    {
        InitializeIfNeeded();
        _currentCategory = type;
        NotifyStateChanged();
    }

    public void EquipOption(EquipmentWorkbenchEquipmentOption option)
    {
        InitializeIfNeeded();
        if (option == null || option.Visual == null || equipmentRenderer == null)
            return;

        equipmentRenderer.Equip(option.Visual);
        SyncEquippedOptionsFromRenderer();
        NotifyStateChanged();
    }

    public void UnequipCategory(EquipmentType type)
    {
        InitializeIfNeeded();
        if (equipmentRenderer == null)
            return;

        EquipmentRenderData current = equipmentRenderer.GetEquipped(type);
        if (current != null)
            equipmentRenderer.Unequip(current);

        SyncEquippedOptionsFromRenderer();
        NotifyStateChanged();
    }

    void ApplyCharacter(int index, bool notify)
    {
        if (catalog == null
            || index < 0
            || index >= catalog.Characters.Count
            || equipmentRenderer == null
            || animationController == null
            || directionDriver == null)
        {
            return;
        }

        EquipmentWorkbenchCharacterOption character = catalog.Characters[index];
        if (character == null || character.FrameData == null)
            return;

        _currentCharacterIndex = index;

        animationController.SetAnimationDatabase(character.FrameData.animDatabase, true);
        equipmentRenderer.SetFrameData(character.FrameData, false);
        if (!directionDriver.SetFrameData(character.FrameData, true))
            return;
        equipmentRenderer.SetAppearance(character.Appearance, false);
        SyncCurrentAppearanceFromCharacter(false);
        equipmentRenderer.UnequipAll();

        for (int i = 0; i < character.DefaultEquipment.Count; i++)
        {
            EquipmentRenderData visual = character.DefaultEquipment[i];
            if (visual != null)
                equipmentRenderer.Equip(visual, false);
        }

        equipmentRenderer.Refresh();
        SyncEquippedOptionsFromRenderer();

        if (notify)
            NotifyStateChanged();
    }

    int FindDefaultCharacterIndex()
    {
        if (catalog == null || catalog.Characters.Count == 0)
            return -1;

        for (int i = 0; i < catalog.Characters.Count; i++)
        {
            EquipmentWorkbenchCharacterOption character = catalog.Characters[i];
            if (character != null && IsHumanCharacter(character))
                return i;
        }

        return 0;
    }

    static bool IsHumanCharacter(EquipmentWorkbenchCharacterOption character)
    {
        if (character == null)
            return false;

        return ContainsIgnoreCase(character.DisplayName, "人类")
            || ContainsIgnoreCase(character.DisplayName, "Human")
            || ContainsIgnoreCase(character.FrameData != null ? character.FrameData.name : null, "Human");
    }

    static bool ContainsIgnoreCase(string value, string marker)
    {
        return !string.IsNullOrEmpty(value)
            && value.IndexOf(marker, StringComparison.OrdinalIgnoreCase) >= 0;
    }

    void ApplyAppearance(int index, bool notify)
    {
        EnsureAppearanceOptions();
        if (index < 0 || index >= _appearanceOptions.Count || equipmentRenderer == null)
            return;

        CharacterAppearance appearance = _appearanceOptions[index];
        if (appearance == null)
            return;

        CurrentAppearanceIndex = index;
        equipmentRenderer.SetAppearance(appearance, true);
        equipmentRenderer.Refresh();

        if (notify)
            NotifyStateChanged();
    }

    void RebuildAppearanceOptions()
    {
        _appearanceOptions.Clear();
        _appearanceIndices.Clear();

        if (catalog == null)
            return;

        for (int i = 0; i < catalog.Characters.Count; i++)
        {
            EquipmentWorkbenchCharacterOption character = catalog.Characters[i];
            CharacterAppearance appearance = character.Appearance;
            if (appearance == null || _appearanceIndices.ContainsKey(appearance))
                continue;

            _appearanceIndices.Add(appearance, _appearanceOptions.Count);
            _appearanceOptions.Add(appearance);
        }
    }

    void EnsureAppearanceOptions()
    {
        if (_appearanceOptions.Count == 0 && catalog != null)
            RebuildAppearanceOptions();
    }

    void SyncCurrentAppearanceFromCharacter(bool notify)
    {
        EnsureAppearanceOptions();

        CharacterAppearance appearance = CurrentCharacter != null ? CurrentCharacter.Appearance : null;
        if (appearance != null && _appearanceIndices.TryGetValue(appearance, out int index))
            CurrentAppearanceIndex = index;
        else if (_appearanceOptions.Count > 0 && CurrentAppearanceIndex < 0)
            CurrentAppearanceIndex = 0;

        if (equipmentRenderer != null && CurrentAppearanceIndex >= 0 && CurrentAppearanceIndex < _appearanceOptions.Count)
            equipmentRenderer.SetAppearance(_appearanceOptions[CurrentAppearanceIndex], false);

        if (notify)
            NotifyStateChanged();
    }

    void SyncEquippedOptionsFromRenderer()
    {
        _equippedOptions.Clear();
        if (catalog == null || equipmentRenderer == null)
            return;

        IReadOnlyList<EquipmentType> categories = catalog.GetAvailableCategories();
        for (int i = 0; i < categories.Count; i++)
        {
            EquipmentType category = categories[i];
            EquipmentRenderData equipped = equipmentRenderer.GetEquipped(category);
            if (equipped != null && catalog.TryGetEquipmentOption(equipped, out EquipmentWorkbenchEquipmentOption option))
                _equippedOptions[category] = option;
        }
    }

    void RecalculateTotals()
    {
        _statTotals.Clear();

        EquipmentWorkbenchCharacterOption character = CurrentCharacter;
        character?.BaseStats?.AddTo(_statTotals);

        foreach (EquipmentWorkbenchEquipmentOption option in _equippedOptions.Values)
        {
            option?.BonusStats?.AddTo(_statTotals);
        }
    }

    void NotifyStateChanged()
    {
        StateChanged?.Invoke();
    }
}
