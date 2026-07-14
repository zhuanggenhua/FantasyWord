using System;
using System.Collections.Generic;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

/// <summary>
/// 换装预览入口的正式运行时 UI 宿主。
/// 结构由预制体提供，这里只负责数据绑定与条目刷新。
/// </summary>
[DisallowMultipleComponent]
public sealed class EquipmentWorkbenchRuntimeUI : MonoBehaviour
{
    [Header("Static Text")]
    [SerializeField] TextMeshProUGUI selectedCharacterLabel;
    [SerializeField] TextMeshProUGUI detailTitleLabel;

    [Header("Containers")]
    [SerializeField] RectTransform characterGrid;
    [SerializeField] RectTransform appearanceGrid;
    [SerializeField] RectTransform animationGrid;
    [SerializeField] RectTransform directionGrid;
    [SerializeField] RectTransform categoryGrid;
    [SerializeField] RectTransform equipmentGrid;

    [Header("Entry Prefabs")]
    [SerializeField] EquipmentWorkbenchChipButtonView chipButtonPrefab;
    [SerializeField] EquipmentWorkbenchIconSlotView characterSlotPrefab;
    [SerializeField] EquipmentWorkbenchIconSlotView equipmentSlotPrefab;

    EquipmentWorkbenchController _controller;
    TMP_FontAsset _font;
    TMP_FontAsset _readableFont;
    readonly List<UnityEngine.Object> _generatedPreviewSprites = new List<UnityEngine.Object>();
    readonly Dictionary<EquipmentWorkbenchCharacterOption, Sprite> _characterPreviewCache =
        new Dictionary<EquipmentWorkbenchCharacterOption, Sprite>();
    readonly Dictionary<EquipmentRenderData, Sprite> _equipmentFallbackPreviewCache =
        new Dictionary<EquipmentRenderData, Sprite>();
    readonly Dictionary<Sprite, Sprite> _trimmedPreviewCache =
        new Dictionary<Sprite, Sprite>();
    Sprite _emptySlotPreviewSprite;
    readonly List<EquipmentWorkbenchIconSlotView> _characterSlots =
        new List<EquipmentWorkbenchIconSlotView>();
    readonly List<EquipmentWorkbenchIconSlotView> _equipmentSlots =
        new List<EquipmentWorkbenchIconSlotView>();
    readonly List<EquipmentWorkbenchChipButtonView> _animationChips =
        new List<EquipmentWorkbenchChipButtonView>();
    readonly List<EquipmentWorkbenchChipButtonView> _directionChips =
        new List<EquipmentWorkbenchChipButtonView>();
    readonly List<EquipmentWorkbenchChipButtonView> _categoryChips =
        new List<EquipmentWorkbenchChipButtonView>();
    readonly List<int> _visibleCharacterIndices = new List<int>();
    bool _shellConfigured;
    int _layoutSignature = -1;
    RightListMode _rightListMode = RightListMode.Equipment;

    enum RightListMode
    {
        Equipment,
        Appearance,
    }

    static readonly Color SlotIdle = new Color(0.22f, 0.26f, 0.31f, 1f);
    static readonly Color SlotActive = new Color(0.34f, 0.46f, 0.33f, 1f);
    static readonly Color SlotEquipped = new Color(0.20f, 0.36f, 0.50f, 1f);
    static readonly Color SlotMuted = new Color(0.14f, 0.16f, 0.20f, 1f);
    static readonly Color IconPanel = new Color(0.09f, 0.11f, 0.14f, 0.94f);
    static readonly List<AnimationTypeItem> SupportedAnimationBuffer = new List<AnimationTypeItem>();
    static readonly Color Accent = new Color(0.87f, 0.80f, 0.58f, 1f);
    static readonly Color BadgeColor = new Color(0.89f, 0.82f, 0.59f, 1f);
    static readonly Color TextPrimary = new Color(0.96f, 0.98f, 1f, 1f);
    static readonly Color TextSecondary = new Color(0.77f, 0.83f, 0.88f, 1f);
    static readonly Color TextMuted = new Color(0.61f, 0.67f, 0.73f, 1f);
    static readonly Color TextOnBadge = new Color(0.15f, 0.17f, 0.21f, 1f);
    static readonly Color OutlineIdle = new Color(0f, 0f, 0f, 0.35f);
    static readonly Vector2 DefaultWorkbenchReferenceSize = new Vector2(1600f, 900f);
    static readonly Vector2 CompactChipSize = new Vector2(88f, 32f);
    static readonly Vector2 CompactCategoryChipSize = new Vector2(96f, 34f);
    static readonly Vector2 CharacterSlotSize = new Vector2(84f, 92f);
    static readonly Vector2 AppearanceSlotSize = new Vector2(84f, 94f);
    static readonly Vector2 EquipmentSlotSize = new Vector2(104f, 96f);
    const int AnimationGridColumns = 3;
    const int EquipmentGridColumns = 4;
    const float LeftPanelWidth = 316f;
    const float RightPanelWidth = 470f;
    const int PanelSidePadding = 12;
    const float PanelSectionSpacing = 6f;
    const float EquipmentGridSpacing = 4f;
    const float MinimumGridCellWidth = 42f;
    const float RightPanelContentWidth = RightPanelWidth - PanelSidePadding * 2f;
    const float AnimationScrollViewportHeight = 270f;
    const float RightListScrollViewportHeight = 340f;
    const int CharacterPreviewCanvasSize = 32;
    const int CharacterPreviewTargetSize = 30;
    const int CharacterPreviewBottomPadding = 1;
    const int EquipmentWornPreviewCanvasSize = 32;
    const int EquipmentWornPreviewTargetSize = 30;
    const int EquipmentWornPreviewBottomPadding = 1;

    public void Bind(EquipmentWorkbenchController controller, TMP_FontAsset font)
    {
        ConfigureRootRectForPreview();

        bool controllerChanged = _controller != controller;
        if (_controller != null)
            _controller.StateChanged -= Refresh;

        if (controllerChanged)
        {
            ClearGeneratedPreviewSprites();
            _layoutSignature = -1;
        }

        _controller = controller;
        _font = font;
        _readableFont = ResolveReadableFont(font);

        ApplyStaticFonts();

        if (_controller != null)
            _controller.StateChanged += Refresh;

        Refresh();
    }

    void OnValidate()
    {
        ConfigureRootRectForPreview();
    }

    void Reset()
    {
        ConfigureRootRectForPreview();
    }

    void ConfigureRootRectForPreview()
    {
        if (transform is not RectTransform root)
            return;

        root.localScale = Vector3.one;
        root.anchorMin = Vector2.zero;
        root.anchorMax = Vector2.one;
        root.offsetMin = Vector2.zero;
        root.offsetMax = Vector2.zero;
        root.pivot = new Vector2(0.5f, 0.5f);

        if (root.rect.width <= 1f || root.rect.height <= 1f)
            root.SetSizeWithCurrentAnchors(RectTransform.Axis.Horizontal, DefaultWorkbenchReferenceSize.x);
        if (root.rect.width <= 1f || root.rect.height <= 1f)
            root.SetSizeWithCurrentAnchors(RectTransform.Axis.Vertical, DefaultWorkbenchReferenceSize.y);
    }

    void OnDestroy()
    {
        if (_controller != null)
            _controller.StateChanged -= Refresh;

        ClearGeneratedPreviewSprites();
    }

    void ApplyStaticFonts()
    {
        ResolveMissingBindings();

        TextMeshProUGUI[] labels = GetComponentsInChildren<TextMeshProUGUI>(true);
        for (int i = 0; i < labels.Length; i++)
        {
            if (labels[i] != null)
                labels[i].font = _readableFont;
        }

        if (selectedCharacterLabel != null)
            selectedCharacterLabel.font = _readableFont;
        if (detailTitleLabel != null)
            detailTitleLabel.font = _readableFont;
    }

    void Refresh()
    {
        ResolveMissingBindings();

        if (_controller == null || !HasBindings())
            return;

        EnsureWorkbenchShellConfigured();
        EnsureSlotStructure();
        ConfigureTestWorkbenchLayoutIfNeeded();
        UpdateCharacterButtons();
        UpdateAnimationButtons();
        UpdateDirectionButtons();
        UpdateCategoryButtons();
        UpdateRightListButtons();
        UpdateDetailSection();
        UpdateRightPanelHeaderLabels();
        MarkLayoutForRebuild(transform as RectTransform);
    }

    bool HasBindings()
    {
        return detailTitleLabel != null
            && characterGrid != null
            && appearanceGrid != null
            && animationGrid != null
            && directionGrid != null
            && categoryGrid != null
            && equipmentGrid != null
            && chipButtonPrefab != null
            && characterSlotPrefab != null
            && equipmentSlotPrefab != null;
    }

    void ResolveMissingBindings()
    {
        if (selectedCharacterLabel == null)
            selectedCharacterLabel = FindTextByName("Selected Character Label");
        if (detailTitleLabel == null)
            detailTitleLabel = FindTextByName("Detail Title Label");

        if (characterGrid == null)
            characterGrid = FindRectTransformByName("Character Grid");
        if (appearanceGrid == null)
            appearanceGrid = FindRectTransformByName("形象 Grid", "Appearance Grid");
        if (animationGrid == null)
            animationGrid = FindRectTransformByName("Animation Grid");
        if (directionGrid == null)
            directionGrid = FindRectTransformByName("Direction Grid");
        if (categoryGrid == null)
            categoryGrid = FindRectTransformByName("Category Grid");
        if (equipmentGrid == null)
            equipmentGrid = FindRectTransformByName("Equipment Grid");

        if (chipButtonPrefab == null)
            chipButtonPrefab = FindTemplateInChildren<EquipmentWorkbenchChipButtonView>(
                animationGrid,
                categoryGrid,
                directionGrid);
        if (characterSlotPrefab == null)
            characterSlotPrefab = FindTemplateInChildren<EquipmentWorkbenchIconSlotView>(characterGrid);
        if (equipmentSlotPrefab == null)
            equipmentSlotPrefab = FindTemplateInChildren<EquipmentWorkbenchIconSlotView>(equipmentGrid);
    }

    TextMeshProUGUI FindTextByName(string targetName)
    {
        TextMeshProUGUI[] labels = GetComponentsInChildren<TextMeshProUGUI>(true);
        for (int i = 0; i < labels.Length; i++)
        {
            TextMeshProUGUI label = labels[i];
            if (label != null && string.Equals(label.name, targetName, StringComparison.OrdinalIgnoreCase))
                return label;
        }

        return null;
    }

    RectTransform FindRectTransformByName(params string[] names)
    {
        if (names == null || names.Length == 0)
            return null;

        RectTransform[] rects = GetComponentsInChildren<RectTransform>(true);
        for (int i = 0; i < rects.Length; i++)
        {
            RectTransform rect = rects[i];
            if (rect == null)
                continue;

            for (int j = 0; j < names.Length; j++)
            {
                if (string.Equals(rect.name, names[j], StringComparison.OrdinalIgnoreCase))
                    return rect;
            }
        }

        return null;
    }

    static T FindTemplateInChildren<T>(params RectTransform[] parents) where T : Component
    {
        if (parents == null)
            return null;

        for (int i = 0; i < parents.Length; i++)
        {
            RectTransform parent = parents[i];
            if (parent == null)
                continue;

            T template = parent.GetComponentInChildren<T>(true);
            if (template != null)
                return template;
        }

        return null;
    }

    void EnsureWorkbenchShellConfigured()
    {
        if (_shellConfigured)
            return;

        ConfigureWorkbenchShell();
        ConfigureTestWorkbenchLayoutIfNeeded();
        _shellConfigured = true;
    }

    void EnsureSlotStructure()
    {
        int rightListSlotCount = GetRightListSlotCount();
        bool changed = false;
        changed |= EnsureIconSlotCount(
            _characterSlots,
            characterGrid,
            characterSlotPrefab,
            GetVisibleCharacterCount());
        changed |= EnsureChipCount(
            _animationChips,
            animationGrid,
            chipButtonPrefab,
            GetAnimationOptionCount());
        changed |= EnsureChipCount(
            _directionChips,
            directionGrid,
            chipButtonPrefab,
            _controller.DirectionDriver != null ? _controller.DirectionDriver.GetDirectionNames().Length : 0);
        changed |= EnsureChipCount(
            _categoryChips,
            categoryGrid,
            chipButtonPrefab,
            GetCategoryChipCount());
        changed |= EnsureIconSlotCount(
            _equipmentSlots,
            equipmentGrid,
            equipmentSlotPrefab,
            rightListSlotCount);

        if (changed)
            ConfigureTestWorkbenchLayoutIfNeeded();
    }

    int GetRightListSlotCount()
    {
        if (_rightListMode == RightListMode.Appearance)
            return Mathf.Max(1, _controller.GetAppearanceOptions().Count);

        return GetEquipmentSlotCountForCurrentCategory();
    }

    int GetEquipmentSlotCountForCurrentCategory()
    {
        IReadOnlyList<EquipmentWorkbenchEquipmentOption> options = _controller.GetOptionsForCurrentCategory();
        int optionCount = 0;
        for (int i = 0; i < options.Count; i++)
        {
            if (options[i] != null)
                optionCount++;
        }

        return 1 + Mathf.Max(1, optionCount);
    }

    int GetCategoryChipCount()
    {
        return 1 + (_controller != null ? _controller.GetAvailableCategories().Count : 0);
    }

    bool EnsureIconSlotCount(
        List<EquipmentWorkbenchIconSlotView> slots,
        RectTransform parent,
        EquipmentWorkbenchIconSlotView prefab,
        int desiredCount)
    {
        if (parent == null || prefab == null)
            return false;

        desiredCount = Mathf.Max(0, desiredCount);
        bool changed = RemoveStaleGridEntries(parent, slots);
        changed |= HideUnexpectedGridChildren<EquipmentWorkbenchIconSlotView>(parent);
        changed |= AdoptExistingGridChildren(parent, slots);
        while (slots.Count < desiredCount)
        {
            EquipmentWorkbenchIconSlotView instance = Instantiate(prefab, parent);
            ApplyParentGridCellSize(parent, instance.transform as RectTransform);
            slots.Add(instance);
            changed = true;
        }

        for (int i = 0; i < slots.Count; i++)
        {
            bool shouldBeActive = i < desiredCount;
            if (slots[i] != null && slots[i].gameObject.activeSelf != shouldBeActive)
            {
                slots[i].gameObject.SetActive(shouldBeActive);
                changed = true;
            }
        }

        return changed;
    }

    bool EnsureChipCount(
        List<EquipmentWorkbenchChipButtonView> chips,
        RectTransform parent,
        EquipmentWorkbenchChipButtonView prefab,
        int desiredCount)
    {
        if (parent == null || prefab == null)
            return false;

        desiredCount = Mathf.Max(0, desiredCount);
        bool changed = RemoveStaleGridEntries(parent, chips);
        changed |= HideUnexpectedGridChildren<EquipmentWorkbenchChipButtonView>(parent);
        changed |= AdoptExistingGridChildren(parent, chips);
        while (chips.Count < desiredCount)
        {
            EquipmentWorkbenchChipButtonView instance = Instantiate(prefab, parent);
            ApplyParentGridCellSize(parent, instance.transform as RectTransform);
            chips.Add(instance);
            changed = true;
        }

        for (int i = 0; i < chips.Count; i++)
        {
            bool shouldBeActive = i < desiredCount;
            if (chips[i] != null && chips[i].gameObject.activeSelf != shouldBeActive)
            {
                chips[i].gameObject.SetActive(shouldBeActive);
                changed = true;
            }
        }

        return changed;
    }

    bool HideUnexpectedGridChildren<T>(RectTransform parent) where T : Component
    {
        bool changed = false;
        for (int i = 0; i < parent.childCount; i++)
        {
            Transform child = parent.GetChild(i);
            if (child.GetComponent<T>() != null)
                continue;

            if (child.gameObject.activeSelf)
            {
                child.gameObject.SetActive(false);
                changed = true;
            }
        }

        return changed;
    }

    static bool RemoveStaleGridEntries<T>(RectTransform parent, List<T> entries) where T : Component
    {
        bool changed = false;
        for (int i = entries.Count - 1; i >= 0; i--)
        {
            T entry = entries[i];
            if (entry != null && entry.transform.parent == parent)
                continue;

            entries.RemoveAt(i);
            changed = true;
        }

        return changed;
    }

    static bool AdoptExistingGridChildren<T>(RectTransform parent, List<T> entries) where T : Component
    {
        bool changed = false;
        for (int i = 0; i < parent.childCount; i++)
        {
            T entry = parent.GetChild(i).GetComponent<T>();
            if (entry != null && !entries.Contains(entry))
            {
                entries.Add(entry);
                changed = true;
            }
        }

        return changed;
    }

    void UpdateCharacterButtons()
    {
        if (_controller.Catalog == null)
            return;

        IReadOnlyList<int> visibleCharacterIndices = GetVisibleCharacterIndices();
        for (int i = 0; i < visibleCharacterIndices.Count; i++)
        {
            int index = visibleCharacterIndices[i];
            EquipmentWorkbenchCharacterOption character = _controller.Catalog.Characters[index];
            BindIconSlot(
                _characterSlots[i],
                character != null ? character.DisplayName : "空角色",
                CreateCharacterPreviewSprite(character),
                index == _controller.CurrentCharacterIndex,
                false,
                index == _controller.CurrentCharacterIndex ? "当前" : null,
                () => _controller.SelectCharacter(index));
        }
    }

    void UpdateAnimationButtons()
    {
        IReadOnlyList<AnimationTypeItem> animations = GetSupportedAnimationOptions();
        for (int i = 0; i < animations.Count; i++)
        {
            AnimationTypeItem animation = animations[i];
            int index = GetAnimationIndex(animation);
            bool selectable = animation != null && _controller.CanSelectAnimation(index);

            BindChip(
                _animationChips[i],
                GetAnimationButtonLabel(animation),
                index == _controller.CurrentAnimationIndex,
                () => _controller.SelectAnimation(index),
                selectable);
        }
    }

    void UpdateDirectionButtons()
    {
        string[] directions = _controller.DirectionDriver != null
            ? _controller.DirectionDriver.GetDirectionNames()
            : Array.Empty<string>();

        for (int i = 0; i < directions.Length; i++)
        {
            int index = i;
            BindChip(
                _directionChips[i],
                GetDirectionDisplayName(directions[i]),
                i == _controller.CurrentDirectionIndex,
                () => _controller.SelectDirection(index));
        }
    }

    void UpdateCategoryButtons()
    {
        IReadOnlyList<EquipmentType> categories = _controller.GetAvailableCategories();
        int chipIndex = 0;
        BindChip(
            _categoryChips[chipIndex++],
            "形象",
            _rightListMode == RightListMode.Appearance,
            SelectAppearanceListMode);

        for (int i = 0; i < categories.Count; i++)
        {
            EquipmentType category = categories[i];
            BindChip(
                _categoryChips[chipIndex++],
                EquipTypeRegistry.GetDisplayName(category),
                _rightListMode == RightListMode.Equipment && category == _controller.CurrentCategory,
                () => SelectEquipmentCategory(category));
        }
    }

    void UpdateRightListButtons()
    {
        if (_rightListMode == RightListMode.Appearance)
        {
            UpdateAppearanceListButtons();
            return;
        }

        UpdateEquipmentListButtons();
    }

    void UpdateAppearanceListButtons()
    {
        IReadOnlyList<CharacterAppearance> appearances = _controller.GetAppearanceOptions();
        if (appearances.Count == 0)
        {
            BindDisabledEquipmentSlot(_equipmentSlots[0], "暂无形象");
            return;
        }

        for (int i = 0; i < appearances.Count; i++)
        {
            CharacterAppearance appearance = appearances[i];
            int index = i;
            BindIconSlot(
                _equipmentSlots[i],
                GetAppearanceDisplayName(appearance),
                CreateAppearancePreviewSprite(appearance),
                i == _controller.CurrentAppearanceIndex,
                false,
                i == _controller.CurrentAppearanceIndex ? "当前" : null,
                () => _controller.SelectAppearance(index));
        }
    }

    void UpdateEquipmentListButtons()
    {
        EquipmentType currentCategory = _controller.CurrentCategory;
        int slotIndex = 0;
        BindIconSlot(
            _equipmentSlots[slotIndex++],
            "卸下",
            CreateEmptySlotPreviewSprite(),
            _controller.GetEquippedOption(currentCategory) == null,
            false,
            _controller.GetEquippedOption(currentCategory) == null ? "当前为空" : null,
            () => _controller.UnequipCategory(currentCategory));

        IReadOnlyList<EquipmentWorkbenchEquipmentOption> options = _controller.GetOptionsForCurrentCategory();
        int renderedOptions = 0;
        for (int i = 0; i < options.Count; i++)
        {
            EquipmentWorkbenchEquipmentOption option = options[i];
            if (option == null)
                continue;

            BindIconSlot(
                _equipmentSlots[slotIndex++],
                option.DisplayName,
                CreateEquipmentPreviewSprite(option),
                false,
                _controller.IsEquipped(option),
                _controller.IsEquipped(option) ? "已装备" : null,
                () => _controller.EquipOption(option));
            renderedOptions++;
        }

        if (renderedOptions == 0)
        {
            BindDisabledEquipmentSlot(_equipmentSlots[slotIndex], "该分类暂无更多装备");
        }
    }

    void SelectAppearanceListMode()
    {
        if (_rightListMode == RightListMode.Appearance)
            return;

        _rightListMode = RightListMode.Appearance;
        _layoutSignature = -1;
        Refresh();
    }

    void SelectEquipmentCategory(EquipmentType category)
    {
        bool modeChanged = _rightListMode != RightListMode.Equipment;
        _rightListMode = RightListMode.Equipment;
        _controller.SelectCategory(category);

        if (modeChanged)
        {
            _layoutSignature = -1;
            Refresh();
        }
    }

    void BindChip(
        EquipmentWorkbenchChipButtonView instance,
        string title,
        bool selected,
        UnityEngine.Events.UnityAction onClick,
        bool interactable = true)
    {
        instance.name = title;
        instance.Bind(
            title,
            _readableFont,
            interactable ? TextPrimary : TextMuted,
            selected ? SlotActive : interactable ? SlotIdle : SlotMuted,
            selected ? Accent : OutlineIdle,
            onClick,
            interactable);
    }

    void BindIconSlot(
        EquipmentWorkbenchIconSlotView instance,
        string title,
        Sprite icon,
        bool selected,
        bool equipped,
        string badgeText,
        UnityEngine.Events.UnityAction onClick)
    {
        instance.name = title;

        Color backgroundColor = equipped ? SlotEquipped : selected ? SlotActive : SlotIdle;
        Color outlineColor = (equipped || selected) ? Accent : OutlineIdle;
        instance.Bind(
            title,
            icon,
            _readableFont,
            TextPrimary,
            backgroundColor,
            outlineColor,
            IconPanel,
            TextMuted,
            badgeText,
            BadgeColor,
            TextOnBadge,
            onClick);
    }

    void BindDisabledEquipmentSlot(EquipmentWorkbenchIconSlotView instance, string title)
    {
        instance.name = title;
        instance.Bind(
            title,
            CreateEmptySlotPreviewSprite(),
            _readableFont,
            TextSecondary,
            SlotMuted,
            OutlineIdle,
            IconPanel,
            TextMuted,
            null,
            BadgeColor,
            TextOnBadge,
            null,
            false);
    }

    void UpdateDetailSection()
    {
        if (selectedCharacterLabel != null)
            selectedCharacterLabel.text = $"当前角色：{GetCurrentCharacterName()}";

        if (detailTitleLabel == null)
            return;

        string stateSummary =
            $"角色 {GetCurrentCharacterName()} | 形象 {GetCurrentAppearanceName()}\n"
            + $"动作 {GetCurrentAnimationName()} | 方向 {GetCurrentDirectionName()}\n"
            + $"身体动画 {GetCurrentBodyAnimationSummary()}";

        EquipmentWorkbenchEquipmentOption equipped = _controller.GetEquippedOption(_controller.CurrentCategory);
        if (_rightListMode == RightListMode.Appearance)
        {
            detailTitleLabel.text =
                $"{stateSummary}\n\n"
                + $"形象\n"
                + $"{GetCurrentAppearanceName()}";
            return;
        }

        if (equipped == null)
        {
            string categoryName = EquipTypeRegistry.GetDisplayName(_controller.CurrentCategory);
            detailTitleLabel.text =
                $"{stateSummary}\n\n"
                + $"{categoryName}\n"
                + "当前为空";
            return;
        }

        detailTitleLabel.text =
            $"{stateSummary}\n\n"
            + $"{equipped.DisplayName}\n"
            + $"{EquipTypeRegistry.GetDisplayName(equipped.Type)}\n"
            + BuildEquipmentStatSummary(equipped, true);
    }

    void UpdateRightPanelHeaderLabels()
    {
        SetHeaderLabelText("装备类型 Header", "类型");
        SetHeaderLabelText("装备列表 Header", _rightListMode == RightListMode.Appearance ? "形象列表" : "装备列表");
        SetHeaderLabelText("当前装备 Header", _rightListMode == RightListMode.Appearance ? "当前选择" : "当前装备");
    }

    void ConfigureTestWorkbenchLayoutIfNeeded()
    {
        int characterCount = Mathf.Max(1, GetVisibleCharacterCount());
        int animationCount = Mathf.Max(1, GetAnimationOptionCount());
        int directionCount = Mathf.Max(
            1,
            _controller.DirectionDriver != null ? _controller.DirectionDriver.GetDirectionNames().Length : 0);
        int categoryCount = Mathf.Max(1, GetCategoryChipCount());
        int rightListCount = Mathf.Max(1, GetRightListSlotCount());
        int signature = CalculateLayoutSignature(
            characterCount,
            animationCount,
            directionCount,
            categoryCount,
            rightListCount,
            _rightListMode);

        ConfigureFixedGrid(characterGrid, 3, CharacterSlotSize, characterCount);
        ConfigureFixedGrid(animationGrid, AnimationGridColumns, CompactChipSize, animationCount);
        ConfigureFixedGrid(
            directionGrid,
            2,
            CompactChipSize,
            directionCount);
        ConfigureFixedGrid(categoryGrid, 3, CompactCategoryChipSize, categoryCount);
        ConfigureFixedGrid(equipmentGrid, EquipmentGridColumns, EquipmentSlotSize, rightListCount);
        ConfigureScrollViewportHeight(animationGrid, AnimationScrollViewportHeight);
        ConfigureScrollViewportHeight(equipmentGrid, RightListScrollViewportHeight);
        _layoutSignature = signature;
        MarkLayoutForRebuild(transform as RectTransform);
    }

    int GetAnimationOptionCount()
    {
        return GetSupportedAnimationOptions().Count;
    }

    int GetVisibleCharacterCount()
    {
        return GetVisibleCharacterIndices().Count;
    }

    IReadOnlyList<int> GetVisibleCharacterIndices()
    {
        _visibleCharacterIndices.Clear();
        if (_controller == null || _controller.Catalog == null)
            return _visibleCharacterIndices;

        for (int i = 0; i < _controller.Catalog.Characters.Count; i++)
        {
            EquipmentWorkbenchCharacterOption character = _controller.Catalog.Characters[i];
            if (IsSelectableWorkbenchCharacter(character))
                _visibleCharacterIndices.Add(i);
        }

        if (_visibleCharacterIndices.Count == 0 && _controller.Catalog.Characters.Count > 0)
        {
            int fallbackIndex = Mathf.Clamp(
                _controller.CurrentCharacterIndex >= 0 ? _controller.CurrentCharacterIndex : 0,
                0,
                _controller.Catalog.Characters.Count - 1);
            _visibleCharacterIndices.Add(fallbackIndex);
        }

        return _visibleCharacterIndices;
    }

    static bool IsSelectableWorkbenchCharacter(EquipmentWorkbenchCharacterOption character)
    {
        if (character == null)
            return false;

        return character.FrameData != null
            && character.AnimationLibraries != null
            && character.AnimationLibraries.IsComplete;
    }

    static bool ContainsWorkbenchMarker(string value, string marker)
    {
        return !string.IsNullOrEmpty(value)
            && value.IndexOf(marker, StringComparison.OrdinalIgnoreCase) >= 0;
    }

    List<AnimationTypeItem> GetSupportedAnimationOptions()
    {
        SupportedAnimationBuffer.Clear();
        if (_controller == null)
            return SupportedAnimationBuffer;

        IReadOnlyList<AnimationTypeItem> allAnimations = _controller.GetAnimationOptions();
        for (int i = 0; i < allAnimations.Count; i++)
        {
            AnimationTypeItem animation = allAnimations[i];
            if (animation != null)
                SupportedAnimationBuffer.Add(animation);
        }

        return SupportedAnimationBuffer;
    }

    int GetAnimationIndex(AnimationTypeItem animation)
    {
        if (animation == null || _controller == null)
            return -1;

        IReadOnlyList<AnimationTypeItem> allAnimations = _controller.GetAnimationOptions();
        for (int i = 0; i < allAnimations.Count; i++)
        {
            if (allAnimations[i] == animation)
                return i;
        }

        return -1;
    }

    static int CalculateLayoutSignature(
        int characterCount,
        int animationCount,
        int directionCount,
        int categoryCount,
        int rightListCount,
        RightListMode rightListMode)
    {
        unchecked
        {
            int hash = 17;
            hash = hash * 31 + characterCount;
            hash = hash * 31 + animationCount;
            hash = hash * 31 + directionCount;
            hash = hash * 31 + categoryCount;
            hash = hash * 31 + rightListCount;
            hash = hash * 31 + (int)rightListMode;
            return hash;
        }
    }

    void ConfigureWorkbenchShell()
    {
        RectTransform root = transform as RectTransform;
        if (root != null)
        {
            root.anchorMin = Vector2.zero;
            root.anchorMax = Vector2.one;
            root.offsetMin = Vector2.zero;
            root.offsetMax = Vector2.zero;
            root.localScale = Vector3.one;
        }

        RectTransform leftPanel = FindAncestorByName(characterGrid, "Left Panel");
        RectTransform rightPanel = FindAncestorByName(categoryGrid, "Right Panel");
        RectTransform shell = FindCommonAncestor(leftPanel, rightPanel);

        if (shell != null)
        {
            shell.offsetMin = new Vector2(16f, 16f);
            shell.offsetMax = new Vector2(-16f, -16f);
        }

        ConfigurePanel(leftPanel, true, LeftPanelWidth);
        ConfigurePanel(rightPanel, false, RightPanelWidth);
        ConfigurePanelContent(
            characterGrid != null ? characterGrid.parent as RectTransform : null,
            PanelSidePadding,
            PanelSectionSpacing);
        ConfigurePanelContent(
            categoryGrid != null ? categoryGrid.parent as RectTransform : null,
            PanelSidePadding,
            PanelSectionSpacing);
        EnsureAnimationScroll();
        ConfigurePanelSectionOrder();
        ConfigureRootTitle();
        ConfigureAnimationScroll();
        ConfigureEquipmentScroll();
        ConfigureDetailLabel();
    }

    void ConfigureFixedGrid(RectTransform target, int columns, Vector2 cellSize, int itemCount)
    {
        if (target == null)
            return;

        GridLayoutGroup grid = target.GetComponent<GridLayoutGroup>();
        if (grid == null)
            grid = target.gameObject.AddComponent<GridLayoutGroup>();

        ContentSizeFitter contentSizeFitter = target.GetComponent<ContentSizeFitter>();
        if (contentSizeFitter != null)
            contentSizeFitter.enabled = false;

        grid.constraint = GridLayoutGroup.Constraint.FixedColumnCount;
        grid.constraintCount = Mathf.Max(1, columns);
        if (target == equipmentGrid)
            ConfigureEquipmentGrid(grid);

        float fallbackWidth = target == equipmentGrid ? RightPanelContentWidth : 0f;
        bool isEquipmentGrid = target == equipmentGrid;
        Vector2 resolvedCellSize = ResolveGridCellSize(target, grid, columns, cellSize, fallbackWidth, isEquipmentGrid);
        grid.cellSize = resolvedCellSize;
        grid.startAxis = GridLayoutGroup.Axis.Horizontal;
        grid.startCorner = GridLayoutGroup.Corner.UpperLeft;
        grid.childAlignment = TextAnchor.UpperLeft;
        ApplyParentGridCellSizeToChildren(target);
        ConfigureAdaptiveGridCellSizer(
            target,
            columns,
            resolvedCellSize.y,
            isEquipmentGrid ? EquipmentSlotSize.x : MinimumGridCellWidth);

        int rows = Mathf.Max(1, Mathf.CeilToInt(itemCount / (float)Mathf.Max(1, columns)));
        float height = grid.padding.top
            + grid.padding.bottom
            + rows * resolvedCellSize.y
            + Mathf.Max(0, rows - 1) * grid.spacing.y;

        target.anchorMin = new Vector2(0f, target.anchorMin.y);
        target.anchorMax = new Vector2(1f, target.anchorMax.y);
        target.offsetMin = new Vector2(0f, target.offsetMin.y);
        target.offsetMax = new Vector2(0f, target.offsetMax.y);
        target.SetSizeWithCurrentAnchors(RectTransform.Axis.Vertical, height);

        LayoutElement layoutElement = target.GetComponent<LayoutElement>();
        if (layoutElement != null)
        {
            layoutElement.minHeight = height;
            layoutElement.preferredHeight = height;
        }
    }

    static void ConfigureAdaptiveGridCellSizer(
        RectTransform target,
        int columns,
        float cellHeight,
        float minimumCellWidth)
    {
        AdaptiveGridCellSizer adaptiveSizer = target.GetComponent<AdaptiveGridCellSizer>();
        ScrollRect scrollRect = target.GetComponentInParent<ScrollRect>();
        if (scrollRect == null || scrollRect.content != target)
        {
            if (adaptiveSizer != null)
                adaptiveSizer.enabled = false;
            return;
        }

        if (adaptiveSizer == null)
            adaptiveSizer = target.gameObject.AddComponent<AdaptiveGridCellSizer>();

        adaptiveSizer.enabled = true;
        adaptiveSizer.Configure(columns, cellHeight, minimumCellWidth);
    }

    static void ConfigureEquipmentGrid(GridLayoutGroup grid)
    {
        if (grid == null)
            return;

        grid.padding.left = 0;
        grid.padding.right = 0;
        grid.spacing = new Vector2(
            grid.spacing.x > 0f ? Mathf.Min(grid.spacing.x, EquipmentGridSpacing) : EquipmentGridSpacing,
            grid.spacing.y > 0f ? grid.spacing.y : PanelSectionSpacing);
    }

    static Vector2 ResolveGridCellSize(
        RectTransform target,
        GridLayoutGroup grid,
        int columns,
        Vector2 requestedCellSize,
        float fallbackAvailableWidth = 0f,
        bool isEquipmentGrid = false)
    {
        int columnCount = Mathf.Max(1, columns);
        float availableWidth = GetAvailableGridWidth(target);
        if (availableWidth <= 1f && fallbackAvailableWidth > 1f)
            availableWidth = fallbackAvailableWidth;

        if (availableWidth <= 1f)
            return requestedCellSize;

        float horizontalPadding = grid.padding.left
            + grid.padding.right
            + Mathf.Max(0, columnCount - 1) * grid.spacing.x;
        float maxCellWidth = Mathf.Floor((availableWidth - horizontalPadding) / columnCount);
        if (maxCellWidth <= 1f)
            return requestedCellSize;

        float minimumWidth = isEquipmentGrid ? requestedCellSize.x : MinimumGridCellWidth;
        float resolvedWidth = isEquipmentGrid
            ? Mathf.Max(minimumWidth, maxCellWidth)
            : Mathf.Clamp(requestedCellSize.x, minimumWidth, maxCellWidth);
        return new Vector2(resolvedWidth, requestedCellSize.y);
    }

    static float GetAvailableGridWidth(RectTransform target)
    {
        if (target == null)
            return 0f;

        ScrollRect scrollRect = target.GetComponentInParent<ScrollRect>();
        RectTransform widthSource = scrollRect != null && scrollRect.viewport != null
            ? scrollRect.viewport
            : target.parent as RectTransform;

        if (widthSource == null)
            widthSource = target;

        float width = widthSource.rect.width;
        if (width > 1f)
            return width;

        RectTransform parent = target.parent as RectTransform;
        return parent != null ? parent.rect.width : 0f;
    }

    void ConfigureScrollViewportHeight(RectTransform target, float minHeight)
    {
        ScrollRect scrollRect = target != null ? target.GetComponentInParent<ScrollRect>() : null;
        if (scrollRect == null)
            return;

        if (scrollRect.transform is RectTransform scrollRectTransform)
        {
            scrollRectTransform.SetSizeWithCurrentAnchors(RectTransform.Axis.Vertical, minHeight);

            LayoutElement layoutElement = scrollRectTransform.GetComponent<LayoutElement>();
            if (layoutElement == null)
                layoutElement = scrollRectTransform.gameObject.AddComponent<LayoutElement>();

            layoutElement.minHeight = minHeight;
            layoutElement.preferredHeight = minHeight;
            layoutElement.flexibleHeight = 0f;
            layoutElement.layoutPriority = 10;
        }

        if (scrollRect.viewport != null)
        {
            scrollRect.viewport.anchorMin = Vector2.zero;
            scrollRect.viewport.anchorMax = Vector2.one;
            scrollRect.viewport.offsetMin = Vector2.zero;
            scrollRect.viewport.offsetMax = Vector2.zero;
            scrollRect.viewport.SetSizeWithCurrentAnchors(RectTransform.Axis.Vertical, minHeight);

            LayoutElement viewportLayout = scrollRect.viewport.GetComponent<LayoutElement>();
            if (viewportLayout == null)
                viewportLayout = scrollRect.viewport.gameObject.AddComponent<LayoutElement>();

            viewportLayout.ignoreLayout = true;
        }

        RectTransform parent = scrollRect.transform.parent as RectTransform;
        if (parent != null && parent.GetComponent<LayoutGroup>() != null)
            MarkLayoutForRebuild(parent);
    }

    string BuildEquipmentStatSummary(EquipmentWorkbenchEquipmentOption option, bool multiline)
    {
        if (option?.BonusStats?.Values == null || option.BonusStats.Values.Count == 0)
            return "无加成";

        List<string> parts = new List<string>();
        for (int i = 0; i < option.BonusStats.Values.Count; i++)
        {
            WorkbenchStatValue stat = option.BonusStats.Values[i];
            parts.Add($"{GetStatLabel(stat.stat)} {(stat.value >= 0 ? "+" : string.Empty)}{stat.value}");
        }

        return string.Join(multiline ? "\n" : "  ", parts);
    }

    string GetCurrentAnimationName()
    {
        IReadOnlyList<AnimationTypeItem> animations = _controller.GetAnimationOptions();
        int index = _controller.CurrentAnimationIndex;
        if (index < 0 || index >= animations.Count || animations[index] == null)
            return "未设置";

        return GetAnimationDisplayName(animations[index]);
    }

    string GetCurrentDirectionName()
    {
        string[] directions = _controller.DirectionDriver != null
            ? _controller.DirectionDriver.GetDirectionNames()
            : Array.Empty<string>();
        int index = _controller.CurrentDirectionIndex;
        if (index < 0 || index >= directions.Length)
            return "未设置";

        return GetDirectionDisplayName(directions[index]);
    }

    string GetCurrentBodyAnimationSummary()
    {
        EquipmentRenderer renderer = _controller != null ? _controller.Renderer : null;
        if (renderer == null)
            return "未绑定";

        string requested = renderer.RequestedAnimationKey;
        string resolved = renderer.ResolvedBodyAnimationKey;
        if (string.IsNullOrWhiteSpace(requested))
            return "未设置";
        if (string.IsNullOrWhiteSpace(resolved))
            return $"{GetAnimationDisplayName(requested)} 无身体帧数据";
        if (renderer.IsUsingBodyAnimationFallback)
        {
            string requestedDisplayName = GetAnimationDisplayName(requested);
            string resolvedDisplayName = GetAnimationDisplayName(resolved);
            if (IsFarmPromptAnimation(requested))
                return $"{requestedDisplayName} 提示动作，角色预览保持 {resolvedDisplayName}";

            return $"{requestedDisplayName} 使用 {resolvedDisplayName} 身体预览";
        }

        return $"{GetAnimationDisplayName(resolved)}";
    }

    string GetCurrentCharacterName()
    {
        return _controller.CurrentCharacter != null ? _controller.CurrentCharacter.DisplayName : "未选择";
    }

    string GetCurrentAppearanceName()
    {
        return GetAppearanceDisplayName(_controller.CurrentAppearance);
    }

    Sprite CreateCharacterPreviewSprite(EquipmentWorkbenchCharacterOption character)
    {
        if (character == null)
            return null;

        if (_characterPreviewCache.TryGetValue(character, out Sprite cachedSprite))
            return cachedSprite;

        AnimationData animation = FindCharacterIdleAnimation(character);
        if (animation == null || animation.spritesheet == null)
            return null;

        Sprite previewSprite = CreateNormalizedCharacterPreviewSprite(animation);
        _characterPreviewCache[character] = previewSprite;
        return previewSprite;
    }

    Sprite CreateCharacterFirstFramePreviewSprite(AnimationData animation)
    {
        Texture2D source = CreateReadablePreviewTexture(animation.spritesheet);
        if (source == null)
            return null;

        int frameWidth = Mathf.Max(1, animation.frameSize.x);
        int frameHeight = Mathf.Max(1, animation.frameSize.y);
        int startX = 0;
        int startY = Mathf.Clamp(source.height - frameHeight, 0, Mathf.Max(0, source.height - 1));

        Texture2D texture = new Texture2D(frameWidth, frameHeight, TextureFormat.RGBA32, false)
        {
            name = $"{source.name}_CharacterFirstFrameIcon",
            filterMode = FilterMode.Point,
            wrapMode = TextureWrapMode.Clamp,
            hideFlags = HideFlags.DontSaveInEditor | HideFlags.DontSaveInBuild,
        };

        Color clear = new Color(0f, 0f, 0f, 0f);
        for (int y = 0; y < frameHeight; y++)
        {
            for (int x = 0; x < frameWidth; x++)
            {
                int sourceX = startX + x;
                int sourceY = startY + y;
                texture.SetPixel(
                    x,
                    y,
                    sourceX >= 0 && sourceX < source.width && sourceY >= 0 && sourceY < source.height
                        ? source.GetPixel(sourceX, sourceY)
                        : clear);
            }
        }

        texture.Apply(false, true);

        Sprite sprite = Sprite.Create(
            texture,
            new Rect(0f, 0f, frameWidth, frameHeight),
            new Vector2(0.5f, 0.5f),
            frameHeight,
            0,
            SpriteMeshType.FullRect);
        sprite.name = texture.name;
        sprite.hideFlags = HideFlags.DontSaveInEditor | HideFlags.DontSaveInBuild;
        _generatedPreviewSprites.Add(texture);
        _generatedPreviewSprites.Add(sprite);
        return sprite;
    }

    Sprite CreateNormalizedCharacterPreviewSprite(AnimationData animation)
    {
        Texture2D source = CreateReadablePreviewTexture(animation.spritesheet);
        if (source == null)
            return null;

        int frameWidth = Mathf.Max(1, animation.frameSize.x);
        int frameHeight = Mathf.Max(1, animation.frameSize.y);
        int framesPerRow = Mathf.Max(1, animation.framesPerRow);
        int rowCount = Mathf.Max(1, animation.rowCount);
        CharacterFrameCandidate candidate = FindCharacterPreviewFrame(source, frameWidth, frameHeight, framesPerRow, rowCount);
        Texture2D texture = new Texture2D(CharacterPreviewCanvasSize, CharacterPreviewCanvasSize, TextureFormat.RGBA32, false)
        {
            name = $"{source.name}_CharacterPreview",
            filterMode = FilterMode.Point,
            wrapMode = TextureWrapMode.Clamp,
            hideFlags = HideFlags.DontSaveInEditor | HideFlags.DontSaveInBuild,
        };

        Color clear = new Color(0f, 0f, 0f, 0f);
        for (int y = 0; y < CharacterPreviewCanvasSize; y++)
        {
            for (int x = 0; x < CharacterPreviewCanvasSize; x++)
                texture.SetPixel(x, y, clear);
        }

        int visibleWidth = Mathf.Max(1, candidate.MaxX - candidate.MinX + 1);
        int visibleHeight = Mathf.Max(1, candidate.MaxY - candidate.MinY + 1);
        float scale = Mathf.Min(
            CharacterPreviewTargetSize / (float)visibleWidth,
            CharacterPreviewTargetSize / (float)visibleHeight);
        int drawWidth = Mathf.Max(1, Mathf.RoundToInt(visibleWidth * scale));
        int drawHeight = Mathf.Max(1, Mathf.RoundToInt(visibleHeight * scale));
        int offsetX = (CharacterPreviewCanvasSize - drawWidth) / 2;
        int offsetY = Mathf.Clamp(
            CharacterPreviewBottomPadding,
            0,
            Mathf.Max(0, CharacterPreviewCanvasSize - drawHeight));

        for (int y = 0; y < drawHeight; y++)
        {
            for (int x = 0; x < drawWidth; x++)
            {
                int sourceX = candidate.MinX + Mathf.Clamp(Mathf.FloorToInt(x / scale), 0, visibleWidth - 1);
                int sourceY = candidate.MinY + Mathf.Clamp(Mathf.FloorToInt(y / scale), 0, visibleHeight - 1);
                texture.SetPixel(offsetX + x, offsetY + y, source.GetPixel(sourceX, sourceY));
            }
        }

        texture.Apply(false, true);

        Sprite sprite = Sprite.Create(
            texture,
            new Rect(0f, 0f, CharacterPreviewCanvasSize, CharacterPreviewCanvasSize),
            new Vector2(0.5f, 0.5f),
            CharacterPreviewCanvasSize,
            0,
            SpriteMeshType.FullRect);
        sprite.name = texture.name;
        sprite.hideFlags = HideFlags.DontSaveInEditor | HideFlags.DontSaveInBuild;
        _generatedPreviewSprites.Add(texture);
        _generatedPreviewSprites.Add(sprite);
        return sprite;
    }

    static Color ApplyCharacterPreviewAppearance(
        Color sourceColor,
        int sourceX,
        int sourceY,
        int frameHeight,
        CharacterFrameCandidate candidate,
        FrameData frame,
        CharacterAppearance appearance)
    {
        if (appearance == null || frame?.limbMask == null)
            return sourceColor;

        int localX = sourceX - candidate.FrameX;
        int localY = frameHeight - 1 - (sourceY - candidate.FrameY);
        Vector2Int framePosition = new Vector2Int(localX, localY);
        if (!frame.leftEyeClosed && ContainsPixel(frame.limbMask.leftEye, framePosition))
            return PreserveSourceAlpha(appearance.leftEyeColor, sourceColor);
        if (!frame.rightEyeClosed && ContainsPixel(frame.limbMask.rightEye, framePosition))
            return PreserveSourceAlpha(appearance.rightEyeColor, sourceColor);

        return sourceColor;
    }

    static bool ContainsPixel(List<Vector2Int> pixels, Vector2Int position)
    {
        if (pixels == null)
            return false;

        for (int i = 0; i < pixels.Count; i++)
        {
            if (pixels[i] == position)
                return true;
        }

        return false;
    }

    static Color PreserveSourceAlpha(Color color, Color source)
    {
        color.a = source.a;
        return color;
    }

    static CharacterFrameCandidate FindCharacterPreviewFrame(
        Texture2D texture,
        int frameWidth,
        int frameHeight,
        int framesPerRow,
        int rowCount)
    {
        int startX = 0;
        int startY = texture.height - frameHeight;
        CharacterFrameCandidate firstIdleFrame = MeasureDominantVisiblePixels(
            texture,
            startX,
            startY,
            frameWidth,
            frameHeight);
        if (firstIdleFrame.VisiblePixelCount > 0)
            return firstIdleFrame;

        return MeasureVisiblePixels(texture, startX, startY, frameWidth, frameHeight);
    }

    Texture2D CreateReadablePreviewTexture(Texture2D source)
    {
        if (source == null)
            return null;

        RenderTexture previousActive = RenderTexture.active;
        RenderTexture temporary = RenderTexture.GetTemporary(
            source.width,
            source.height,
            0,
            RenderTextureFormat.ARGB32,
            RenderTextureReadWrite.Default);

        try
        {
            Graphics.Blit(source, temporary);
            RenderTexture.active = temporary;

            Texture2D readable = new Texture2D(source.width, source.height, TextureFormat.RGBA32, false)
            {
                name = $"{source.name}_ReadablePreviewSource",
                filterMode = FilterMode.Point,
                wrapMode = TextureWrapMode.Clamp,
                hideFlags = HideFlags.DontSaveInEditor | HideFlags.DontSaveInBuild,
            };
            readable.ReadPixels(new Rect(0f, 0f, source.width, source.height), 0, 0);
            readable.Apply(false, false);
            _generatedPreviewSprites.Add(readable);
            return readable;
        }
        finally
        {
            RenderTexture.active = previousActive;
            RenderTexture.ReleaseTemporary(temporary);
        }
    }

    static CharacterFrameCandidate MeasureVisiblePixels(
        Texture2D texture,
        int startX,
        int startY,
        int width,
        int height)
    {
        int minX = startX + width - 1;
        int minY = startY + height - 1;
        int maxX = startX;
        int maxY = startY;
        int count = 0;

        try
        {
            for (int y = startY; y < startY + height; y++)
            {
                for (int x = startX; x < startX + width; x++)
                {
                    if (x < 0 || x >= texture.width || y < 0 || y >= texture.height)
                        continue;
                    if (texture.GetPixel(x, y).a <= 0.01f)
                        continue;

                    count++;
                    minX = Mathf.Min(minX, x);
                    minY = Mathf.Min(minY, y);
                    maxX = Mathf.Max(maxX, x);
                    maxY = Mathf.Max(maxY, y);
                }
            }
        }
        catch (UnityException)
        {
            return CharacterFrameCandidate.Empty(width, height);
        }

        if (count <= 0)
            return CharacterFrameCandidate.Empty(width, height);

        return new CharacterFrameCandidate(startX, startY, minX, minY, maxX, maxY, count);
    }

    static CharacterFrameCandidate MeasureDominantVisiblePixels(
        Texture2D texture,
        int startX,
        int startY,
        int width,
        int height)
    {
        try
        {
            bool[] visited = new bool[Mathf.Max(1, width * height)];
            CharacterFrameCandidate best = CharacterFrameCandidate.Empty(width, height);
            Stack<Vector2Int> pending = new Stack<Vector2Int>();

            for (int localY = 0; localY < height; localY++)
            {
                for (int localX = 0; localX < width; localX++)
                {
                    int index = localY * width + localX;
                    if (visited[index])
                        continue;

                    int x = startX + localX;
                    int y = startY + localY;
                    if (!IsVisiblePreviewPixel(texture, x, y))
                    {
                        visited[index] = true;
                        continue;
                    }

                    int minX = x;
                    int minY = y;
                    int maxX = x;
                    int maxY = y;
                    int count = 0;
                    pending.Clear();
                    pending.Push(new Vector2Int(localX, localY));
                    visited[index] = true;

                    while (pending.Count > 0)
                    {
                        Vector2Int current = pending.Pop();
                        int currentX = startX + current.x;
                        int currentY = startY + current.y;
                        count++;
                        minX = Mathf.Min(minX, currentX);
                        minY = Mathf.Min(minY, currentY);
                        maxX = Mathf.Max(maxX, currentX);
                        maxY = Mathf.Max(maxY, currentY);

                        VisitPreviewNeighbor(texture, startX, startY, width, height, current.x + 1, current.y, visited, pending);
                        VisitPreviewNeighbor(texture, startX, startY, width, height, current.x - 1, current.y, visited, pending);
                        VisitPreviewNeighbor(texture, startX, startY, width, height, current.x, current.y + 1, visited, pending);
                        VisitPreviewNeighbor(texture, startX, startY, width, height, current.x, current.y - 1, visited, pending);
                    }

                    if (count > best.VisiblePixelCount)
                        best = new CharacterFrameCandidate(startX, startY, minX, minY, maxX, maxY, count);
                }
            }

            return best.VisiblePixelCount > 0 ? best : CharacterFrameCandidate.Empty(width, height);
        }
        catch (UnityException)
        {
            return MeasureVisiblePixels(texture, startX, startY, width, height);
        }
    }

    static void VisitPreviewNeighbor(
        Texture2D texture,
        int startX,
        int startY,
        int width,
        int height,
        int localX,
        int localY,
        bool[] visited,
        Stack<Vector2Int> pending)
    {
        if (localX < 0 || localX >= width || localY < 0 || localY >= height)
            return;

        int index = localY * width + localX;
        if (visited[index])
            return;

        visited[index] = true;
        int x = startX + localX;
        int y = startY + localY;
        if (IsVisiblePreviewPixel(texture, x, y))
            pending.Push(new Vector2Int(localX, localY));
    }

    static bool IsVisiblePreviewPixel(Texture2D texture, int x, int y)
    {
        return x >= 0
            && x < texture.width
            && y >= 0
            && y < texture.height
            && texture.GetPixel(x, y).a > 0.01f;
    }

    Sprite CreateAppearancePreviewSprite(CharacterAppearance appearance)
    {
        return FindAppearancePreviewSource(appearance);
    }

    Sprite CreateEquipmentPreviewSprite(EquipmentWorkbenchEquipmentOption option)
    {
        EquipmentRenderData visual = option?.Visual;
        if (visual != null)
        {
            Sprite sequenceSource = FindFirstConfiguredEquipmentSequenceSprite(visual);
            if (IsUsablePreviewSprite(sequenceSource))
                return GetSequenceFramePreviewSprite(sequenceSource);

            Sprite source = FindFirstDirectionalEquipmentSprite(visual);
            if (IsUsablePreviewSprite(source))
                return GetSequenceFramePreviewSprite(source);
        }

        Sprite customIcon = option?.CustomIcon;
        if (IsUsablePreviewSprite(customIcon))
            return customIcon;

        return null;
    }

    static bool IsUsablePreviewSprite(Sprite sprite)
    {
        if (sprite == null)
            return false;

        try
        {
            return sprite.texture != null;
        }
        catch (UnityException)
        {
            return false;
        }
        catch (MissingReferenceException)
        {
            return false;
        }
    }

    Sprite GetSequenceFramePreviewSprite(Sprite source)
    {
        if (source == null)
            return null;

        if (_trimmedPreviewCache.TryGetValue(source, out Sprite cachedSprite))
            return cachedSprite;

        Texture2D texture = EquipmentWornPreviewComposer.CreateSpritePreviewTexture(
            source,
            EquipmentWornPreviewCanvasSize,
            EquipmentWornPreviewTargetSize);
        if (texture == null)
            return source;

        texture.name = $"{source.name}_UIFirstFrameIcon";
        texture.filterMode = FilterMode.Point;
        texture.wrapMode = TextureWrapMode.Clamp;
        texture.hideFlags = HideFlags.DontSaveInEditor | HideFlags.DontSaveInBuild;
        texture.Apply(false, true);

        Sprite sprite = Sprite.Create(
            texture,
            new Rect(0f, 0f, EquipmentWornPreviewCanvasSize, EquipmentWornPreviewCanvasSize),
            new Vector2(0.5f, 0.5f),
            EquipmentWornPreviewCanvasSize,
            0,
            SpriteMeshType.FullRect);
        sprite.name = texture.name;
        sprite.hideFlags = HideFlags.DontSaveInEditor | HideFlags.DontSaveInBuild;
        _generatedPreviewSprites.Add(texture);
        _generatedPreviewSprites.Add(sprite);
        _trimmedPreviewCache[source] = sprite;
        return sprite;
    }

    Sprite CreateEmptySlotPreviewSprite()
    {
        if (_emptySlotPreviewSprite != null)
            return _emptySlotPreviewSprite;

        Texture2D texture = new Texture2D(16, 16, TextureFormat.RGBA32, false)
        {
            name = "EquipmentWorkbenchEmptySlotIcon",
            filterMode = FilterMode.Point,
            wrapMode = TextureWrapMode.Clamp,
            hideFlags = HideFlags.DontSaveInEditor | HideFlags.DontSaveInBuild,
        };

        Color clear = new Color(0f, 0f, 0f, 0f);
        Color frame = new Color(0.57f, 0.64f, 0.70f, 0.95f);
        Color mark = new Color(0.35f, 0.41f, 0.48f, 0.95f);
        for (int y = 0; y < texture.height; y++)
        {
            for (int x = 0; x < texture.width; x++)
                texture.SetPixel(x, y, clear);
        }

        FillRect(texture, 4, 4, 11, 4, frame);
        FillRect(texture, 3, 5, 4, 11, frame);
        FillRect(texture, 11, 5, 12, 11, frame);
        FillRect(texture, 4, 12, 11, 12, frame);
        FillRect(texture, 6, 7, 9, 8, mark);
        texture.Apply(false, true);

        _emptySlotPreviewSprite = Sprite.Create(texture, new Rect(0f, 0f, 16f, 16f), new Vector2(0.5f, 0.5f), 16f);
        _emptySlotPreviewSprite.name = "EquipmentWorkbenchEmptySlotIcon";
        _emptySlotPreviewSprite.hideFlags = HideFlags.DontSaveInEditor | HideFlags.DontSaveInBuild;
        _generatedPreviewSprites.Add(_emptySlotPreviewSprite);
        _generatedPreviewSprites.Add(texture);
        return _emptySlotPreviewSprite;
    }

    Sprite GetTrimmedPreviewSprite(Sprite source)
    {
        if (source == null)
            return null;

        if (_trimmedPreviewCache.TryGetValue(source, out Sprite cachedSprite))
            return cachedSprite;

        Sprite trimmedSprite = TryCreateTrimmedPreviewSprite(source);
        _trimmedPreviewCache[source] = trimmedSprite;
        if (trimmedSprite != source)
            _generatedPreviewSprites.Add(trimmedSprite);

        return trimmedSprite;
    }

    static Sprite TryCreateTrimmedPreviewSprite(Sprite source)
    {
        Texture2D texture = source.texture;
        if (texture == null)
            return source;

        Rect sourceRect;
        try
        {
            sourceRect = source.textureRect;
        }
        catch (UnityException)
        {
            return source;
        }

        int startX = Mathf.Clamp(Mathf.FloorToInt(sourceRect.x), 0, texture.width - 1);
        int startY = Mathf.Clamp(Mathf.FloorToInt(sourceRect.y), 0, texture.height - 1);
        int endX = Mathf.Clamp(Mathf.CeilToInt(sourceRect.xMax) - 1, 0, texture.width - 1);
        int endY = Mathf.Clamp(Mathf.CeilToInt(sourceRect.yMax) - 1, 0, texture.height - 1);
        int minX = endX;
        int minY = endY;
        int maxX = startX;
        int maxY = startY;
        bool foundVisiblePixel = false;

        try
        {
            for (int y = startY; y <= endY; y++)
            {
                for (int x = startX; x <= endX; x++)
                {
                    if (texture.GetPixel(x, y).a <= 0.01f)
                        continue;

                    foundVisiblePixel = true;
                    minX = Mathf.Min(minX, x);
                    minY = Mathf.Min(minY, y);
                    maxX = Mathf.Max(maxX, x);
                    maxY = Mathf.Max(maxY, y);
                }
            }
        }
        catch (UnityException)
        {
            return source;
        }

        if (!foundVisiblePixel)
            return source;

        minX = Mathf.Max(startX, minX - 1);
        minY = Mathf.Max(startY, minY - 1);
        maxX = Mathf.Min(endX, maxX + 1);
        maxY = Mathf.Min(endY, maxY + 1);

        int trimmedWidth = maxX - minX + 1;
        int trimmedHeight = maxY - minY + 1;
        if (trimmedWidth >= Mathf.RoundToInt(sourceRect.width) && trimmedHeight >= Mathf.RoundToInt(sourceRect.height))
            return source;

        Sprite trimmedSprite = Sprite.Create(
            texture,
            new Rect(minX, minY, trimmedWidth, trimmedHeight),
            new Vector2(0.5f, 0.5f),
            source.pixelsPerUnit,
            0,
            SpriteMeshType.FullRect,
            source.border);
        trimmedSprite.name = $"{source.name}_UITrim";
        return trimmedSprite;
    }

    static Sprite FindEquipmentPreviewSource(EquipmentWorkbenchEquipmentOption option)
    {
        EquipmentRenderData visual = option?.Visual;
        if (visual == null)
            return null;

        Sprite sequenceSprite = FindFirstConfiguredEquipmentSequenceSprite(visual);
        if (sequenceSprite != null)
            return sequenceSprite;

        return FindFirstDirectionalEquipmentSprite(visual);
    }

    static bool ShouldUseGeneratedEquipmentIcon(EquipmentWorkbenchEquipmentOption option)
    {
        EquipmentRenderData visual = option?.Visual;
        if (visual == null)
            return false;

        switch (visual.type)
        {
            case EquipmentType.Clothing:
            case EquipmentType.Cloak:
            case EquipmentType.Helmet:
            case EquipmentType.Hat:
            case EquipmentType.Mask:
            case EquipmentType.Bag:
            case EquipmentType.Gloves:
            case EquipmentType.Shoes:
            case EquipmentType.Pants:
                return true;
            default:
                return false;
        }
    }

    static bool HasAnyEquipmentSequenceSprite(EquipmentRenderData visual)
    {
        if (visual == null)
            return false;

        if (visual.animSequences == null || visual.animSequences.Count == 0)
            return false;

        for (int actionIndex = 0; actionIndex < visual.animSequences.Count; actionIndex++)
        {
            AnimSequenceEntry entry = visual.animSequences[actionIndex];
            string key = entry != null && entry.animationType != null ? entry.animationType.name : null;
            if (!visual.HasSequenceForKey(key))
                continue;

            for (int row = 0; row < 4; row++)
            {
                for (int frame = 0; frame < 16; frame++)
                {
                    if (visual.TryGetSequenceSpriteByKey(key, row, frame) != null)
                        return true;
                }
            }
        }

        return false;
    }

    static bool IsUsableEquipmentListIcon(Sprite sprite)
    {
        return sprite != null && !IsCharacterOrProfessionFrameSprite(sprite);
    }

    static bool IsCharacterOrProfessionFrameSprite(Sprite sprite)
    {
        string textureName = sprite != null && sprite.texture != null ? sprite.texture.name : string.Empty;
        if (IsKnownEquipmentOverlayTexture(textureName))
            return false;

        string path = GetEditorAssetPath(sprite);
        if (IsEquipmentArtSpritePath(path))
            return false;

        if (ContainsPathSegment(path, "/Sprites/Animations/Human/")
            || ContainsPathSegment(path, "/Sprites/Humanoids/")
            || ContainsPathSegment(path, "/Sprites/Crafting Professions/")
            || ContainsPathSegment(path, "/Sprites/Gathering Professions/")
            || ContainsPathSegment(path, "/Sprites/FarmingActions/"))
        {
            return true;
        }

        return ContainsIgnoreCase(textureName, "HumanBase")
            || ContainsIgnoreCase(textureName, "CreaturesHuman")
            || ContainsIgnoreCase(textureName, "Human_")
            || ContainsIgnoreCase(textureName, "Dwarf")
            || ContainsIgnoreCase(textureName, "Elf")
            || ContainsIgnoreCase(textureName, "Goblin")
            || ContainsIgnoreCase(textureName, "Orc");
    }

    static bool IsEquipmentArtSpritePath(string path)
    {
        return ContainsPathSegment(path, "/Art/equip/")
            || ContainsPathSegment(path, "/ImportedSource/Art/equip/");
    }

    static bool IsKnownEquipmentOverlayTexture(string textureName)
    {
        return ContainsIgnoreCase(textureName, "Slash_sword_f")
            || ContainsIgnoreCase(textureName, "Slash_sword_b");
    }

    static bool ContainsPathSegment(string source, string marker)
    {
        return !string.IsNullOrEmpty(source)
            && source.IndexOf(marker, StringComparison.OrdinalIgnoreCase) >= 0;
    }

    static bool ContainsIgnoreCase(string source, string marker)
    {
        return !string.IsNullOrEmpty(source)
            && source.IndexOf(marker, StringComparison.OrdinalIgnoreCase) >= 0;
    }

    static string GetEditorAssetPath(Sprite sprite)
    {
#if UNITY_EDITOR
        if (sprite == null)
            return string.Empty;

        string path = UnityEditor.AssetDatabase.GetAssetPath(sprite);
        return string.IsNullOrEmpty(path) ? string.Empty : path.Replace('\\', '/');
#else
        return string.Empty;
#endif
    }

    Sprite CreateEquipmentWornPreviewSprite(EquipmentWorkbenchEquipmentOption option)
    {
        EquipmentRenderData visual = option?.Visual;
        if (visual == null)
            return null;

        if (_equipmentFallbackPreviewCache.TryGetValue(visual, out Sprite cachedSprite))
            return cachedSprite;

        EquipmentWorkbenchCharacterOption character = _controller != null ? _controller.CurrentCharacter : null;
        AnimationData animation = FindCharacterIdleAnimation(character);
        if (animation == null || animation.spritesheet == null)
            return null;

        Texture2D source = CreateReadablePreviewTexture(animation.spritesheet);
        if (source == null)
            return null;

        Texture2D texture = EquipmentWornPreviewComposer.CreatePreviewTexture(
            source,
            animation,
            character != null ? character.FrameData : null,
            visual,
            EquipmentWornPreviewCanvasSize,
            EquipmentWornPreviewTargetSize,
            EquipmentWornPreviewBottomPadding);
        if (texture == null)
            return null;

        texture.name = visual.name + "_UIWornIcon";
        texture.filterMode = FilterMode.Point;
        texture.wrapMode = TextureWrapMode.Clamp;
        texture.hideFlags = HideFlags.DontSaveInEditor | HideFlags.DontSaveInBuild;
        texture.Apply(false, true);

        Sprite sprite = Sprite.Create(
            texture,
            new Rect(0f, 0f, EquipmentWornPreviewCanvasSize, EquipmentWornPreviewCanvasSize),
            new Vector2(0.5f, 0.5f),
            EquipmentWornPreviewCanvasSize,
            0,
            SpriteMeshType.FullRect);
        sprite.name = texture.name;
        sprite.hideFlags = HideFlags.DontSaveInEditor | HideFlags.DontSaveInBuild;
        _generatedPreviewSprites.Add(texture);
        _generatedPreviewSprites.Add(sprite);
        _equipmentFallbackPreviewCache.Add(visual, sprite);
        return sprite;
    }

    Sprite CreateEquipmentFallbackPreviewSprite(EquipmentWorkbenchEquipmentOption option)
    {
        if (option?.Visual == null)
            return null;

        if (_equipmentFallbackPreviewCache.TryGetValue(option.Visual, out Sprite cachedSprite))
            return cachedSprite;

        Texture2D texture = new Texture2D(16, 16, TextureFormat.RGBA32, false)
        {
            name = option.Visual.name + "_UIFallbackIcon",
            filterMode = FilterMode.Point,
            wrapMode = TextureWrapMode.Clamp,
            hideFlags = HideFlags.DontSaveInEditor | HideFlags.DontSaveInBuild,
        };

        Color body = ResolveEquipmentFallbackColor(option.Visual);
        Color trim = Color.Lerp(body, Color.black, 0.38f);
        Color clear = new Color(0f, 0f, 0f, 0f);

        for (int y = 0; y < texture.height; y++)
        {
            for (int x = 0; x < texture.width; x++)
                texture.SetPixel(x, y, clear);
        }

        DrawFallbackIcon(texture, option.Visual.type, body, trim);
        texture.Apply(false, true);

        Sprite sprite = Sprite.Create(texture, new Rect(0f, 0f, 16f, 16f), new Vector2(0.5f, 0.5f), 16f);
        sprite.name = option.Visual.name + "_UIFallbackIcon";
        sprite.hideFlags = HideFlags.DontSaveInEditor | HideFlags.DontSaveInBuild;
        _generatedPreviewSprites.Add(sprite);
        _generatedPreviewSprites.Add(texture);
        _equipmentFallbackPreviewCache.Add(option.Visual, sprite);
        return sprite;
    }

    static Color ResolveEquipmentFallbackColor(EquipmentRenderData visual)
    {
        if (visual == null)
            return new Color(0.72f, 0.76f, 0.82f, 1f);

        Color left = visual.leftColor;
        Color right = visual.rightColor;
        Color mixed = Color.Lerp(left, right, 0.5f);
        if (mixed.a <= 0.01f)
            mixed.a = 1f;

        return mixed;
    }

    static void DrawFallbackIcon(Texture2D texture, EquipmentType type, Color body, Color trim)
    {
        switch (type)
        {
            case EquipmentType.Helmet:
            case EquipmentType.Hat:
                FillRect(texture, 4, 4, 11, 5, trim);
                FillRect(texture, 5, 5, 10, 10, body);
                FillRect(texture, 3, 9, 12, 10, trim);
                break;
            case EquipmentType.Mask:
                FillRect(texture, 4, 6, 11, 10, body);
                FillRect(texture, 6, 8, 7, 8, trim);
                FillRect(texture, 9, 8, 10, 8, trim);
                break;
            case EquipmentType.Cloak:
                FillRect(texture, 6, 3, 9, 4, trim);
                FillRect(texture, 4, 5, 11, 13, body);
                FillRect(texture, 3, 13, 12, 14, trim);
                break;
            case EquipmentType.Bag:
                FillRect(texture, 5, 5, 10, 12, body);
                FillRect(texture, 6, 4, 9, 5, trim);
                FillRect(texture, 4, 7, 5, 11, trim);
                FillRect(texture, 10, 7, 11, 11, trim);
                break;
            case EquipmentType.Gloves:
                FillRect(texture, 3, 7, 6, 11, body);
                FillRect(texture, 9, 7, 12, 11, body);
                FillRect(texture, 3, 11, 6, 12, trim);
                FillRect(texture, 9, 11, 12, 12, trim);
                break;
            case EquipmentType.Shoes:
                FillRect(texture, 3, 10, 6, 12, body);
                FillRect(texture, 9, 10, 12, 12, body);
                FillRect(texture, 2, 12, 6, 13, trim);
                FillRect(texture, 9, 12, 13, 13, trim);
                break;
            case EquipmentType.Pants:
                FillRect(texture, 5, 4, 10, 7, body);
                FillRect(texture, 5, 8, 7, 13, body);
                FillRect(texture, 8, 8, 10, 13, body);
                FillRect(texture, 5, 13, 10, 14, trim);
                break;
            case EquipmentType.Clothing:
            default:
                FillRect(texture, 5, 3, 10, 5, trim);
                FillRect(texture, 4, 5, 11, 12, body);
                FillRect(texture, 3, 7, 4, 10, body);
                FillRect(texture, 11, 7, 12, 10, body);
                FillRect(texture, 5, 12, 10, 13, trim);
                break;
        }
    }

    static void FillRect(Texture2D texture, int minX, int minY, int maxX, int maxY, Color color)
    {
        if (texture == null)
            return;

        for (int y = Mathf.Max(0, minY); y <= Mathf.Min(texture.height - 1, maxY); y++)
        {
            for (int x = Mathf.Max(0, minX); x <= Mathf.Min(texture.width - 1, maxX); x++)
                texture.SetPixel(x, y, color);
        }
    }

    static Sprite FindFirstConfiguredEquipmentSequenceSprite(EquipmentRenderData visual)
    {
        if (visual?.animSequences == null)
            return null;

        for (int actionIndex = 0; actionIndex < visual.animSequences.Count; actionIndex++)
        {
            AnimSequenceEntry entry = visual.animSequences[actionIndex];
            if (entry?.strips == null)
                continue;

            for (int stripIndex = 0; stripIndex < entry.strips.Count; stripIndex++)
            {
                DirectionalStrip strip = entry.strips[stripIndex];
                if (strip?.frames == null)
                    continue;

                for (int frameIndex = 0; frameIndex < strip.frames.Count; frameIndex++)
                {
                    Sprite sprite = strip.frames[frameIndex];
                    if (sprite != null)
                        return sprite;
                }
            }
        }

        return null;
    }

    static Sprite FindFirstDirectionalEquipmentSprite(EquipmentRenderData visual)
    {
        if (visual == null)
            return null;

        Sprite sprite = visual.GetSprite(CharacterFacing.SouthEast);
        if (sprite != null)
            return sprite;

        sprite = visual.GetSprite(CharacterFacing.SouthWest);
        if (sprite != null)
            return sprite;

        sprite = visual.GetSprite(CharacterFacing.NorthEast);
        if (sprite != null)
            return sprite;

        return visual.GetSprite(CharacterFacing.NorthWest);
    }

    static Sprite FindAppearancePreviewSource(CharacterAppearance appearance)
    {
        if (appearance == null)
            return null;

        if (appearance.hairSE != null)
            return appearance.hairSE;
        if (appearance.faceAccessorySE != null)
            return appearance.faceAccessorySE;
        if (appearance.beardSE != null)
            return appearance.beardSE;
        if (appearance.eyeDecorationEast != null)
            return appearance.eyeDecorationEast;
        if (appearance.hairSW != null)
            return appearance.hairSW;
        if (appearance.beardSW != null)
            return appearance.beardSW;

        return null;
    }

    static AnimationData FindCharacterIdleAnimation(EquipmentWorkbenchCharacterOption character)
    {
        if (character?.FrameData == null)
            return null;

        AnimationData idle = character.FrameData.GetAnimationByKey("Idle");
        if (idle != null && idle.spritesheet != null)
            return idle;

        List<AnimationData> animations = character.FrameData.animations;
        if (animations == null)
            return null;

        for (int i = 0; i < animations.Count; i++)
        {
            AnimationData animation = animations[i];
            if (animation != null && animation.spritesheet != null)
                return animation;
        }

        return null;
    }

    void ClearGeneratedPreviewSprites()
    {
        for (int i = 0; i < _generatedPreviewSprites.Count; i++)
        {
            if (_generatedPreviewSprites[i] != null)
                DestroyUnityObject(_generatedPreviewSprites[i]);
        }

        _generatedPreviewSprites.Clear();
        _characterPreviewCache.Clear();
        _equipmentFallbackPreviewCache.Clear();
        _trimmedPreviewCache.Clear();
        _emptySlotPreviewSprite = null;
    }

    public static class EquipmentWornPreviewComposer
    {
        public static Texture2D CreateSpritePreviewTexture(Sprite sprite, int canvasSize, int targetSize)
        {
            if (sprite == null || sprite.texture == null)
                return null;

            Rect rect;
            try
            {
                rect = sprite.textureRect;
            }
            catch (UnityException)
            {
                rect = sprite.rect;
            }

            int startX = Mathf.Clamp(Mathf.FloorToInt(rect.xMin), 0, sprite.texture.width - 1);
            int startY = Mathf.Clamp(Mathf.FloorToInt(rect.yMin), 0, sprite.texture.height - 1);
            int endX = Mathf.Clamp(Mathf.CeilToInt(rect.xMax) - 1, 0, sprite.texture.width - 1);
            int endY = Mathf.Clamp(Mathf.CeilToInt(rect.yMax) - 1, 0, sprite.texture.height - 1);

            int frameWidth = Mathf.Max(1, endX - startX + 1);
            int frameHeight = Mathf.Max(1, endY - startY + 1);
            CharacterFrameCandidate visibleRegion = MeasureVisiblePixels(
                sprite.texture,
                startX,
                startY,
                frameWidth,
                frameHeight);
            if (visibleRegion.VisiblePixelCount <= 0)
                return null;

            Texture2D output = CreateClearTexture(canvasSize, canvasSize);
            output.hideFlags = HideFlags.DontSaveInEditor | HideFlags.DontSaveInBuild;
            int visibleWidth = Mathf.Max(1, visibleRegion.MaxX - visibleRegion.MinX + 1);
            int visibleHeight = Mathf.Max(1, visibleRegion.MaxY - visibleRegion.MinY + 1);
            float scale = Mathf.Min(targetSize / (float)visibleWidth, targetSize / (float)visibleHeight);
            int drawWidth = Mathf.Max(1, Mathf.RoundToInt(visibleWidth * scale));
            int drawHeight = Mathf.Max(1, Mathf.RoundToInt(visibleHeight * scale));
            int offsetX = (canvasSize - drawWidth) / 2;
            int offsetY = (canvasSize - drawHeight) / 2;

            for (int y = 0; y < drawHeight; y++)
            {
                for (int x = 0; x < drawWidth; x++)
                {
                    int sx = visibleRegion.MinX + Mathf.Clamp(Mathf.FloorToInt(x / scale), 0, visibleWidth - 1);
                    int sy = visibleRegion.MinY + Mathf.Clamp(Mathf.FloorToInt(y / scale), 0, visibleHeight - 1);
                    Color color;
                    try
                    {
                        color = sprite.texture.GetPixel(sx, sy);
                    }
                    catch (UnityException)
                    {
                        return null;
                    }

                    if (color.a > 0.01f)
                        output.SetPixel(offsetX + x, offsetY + y, color);
                }
            }

            return output;
        }

        public static Texture2D CreatePreviewTexture(
            Texture2D characterSource,
            AnimationData animation,
            CharacterFrameData frameData,
            EquipmentRenderData visual,
            int canvasSize,
            int targetSize,
            int bottomPadding)
        {
            if (characterSource == null || animation == null || visual == null)
                return null;

            int frameWidth = Mathf.Max(1, animation.frameSize.x);
            int frameHeight = Mathf.Max(1, animation.frameSize.y);
            int startX = 0;
            int startY = Mathf.Clamp(characterSource.height - frameHeight, 0, Mathf.Max(0, characterSource.height - 1));
            Texture2D frameTexture = CopyFrame(characterSource, startX, startY, frameWidth, frameHeight);
            if (frameTexture == null)
                return null;

            FrameData frame = animation.GetFrame(0, 0) ?? frameData?.GetFrameDataByKey("Idle", 0, 0);
            ApplyEquipment(frameTexture, frame, visual);

            CharacterFrameCandidate candidate = FindCharacterPreviewFrame(frameTexture, frameWidth, frameHeight, 1, 1);
            Texture2D output = CreateClearTexture(canvasSize, canvasSize);
            output.hideFlags = HideFlags.DontSaveInEditor | HideFlags.DontSaveInBuild;

            int visibleWidth = Mathf.Max(1, candidate.MaxX - candidate.MinX + 1);
            int visibleHeight = Mathf.Max(1, candidate.MaxY - candidate.MinY + 1);
            float scale = Mathf.Min(targetSize / (float)visibleWidth, targetSize / (float)visibleHeight);
            int drawWidth = Mathf.Max(1, Mathf.RoundToInt(visibleWidth * scale));
            int drawHeight = Mathf.Max(1, Mathf.RoundToInt(visibleHeight * scale));
            int offsetX = (canvasSize - drawWidth) / 2;
            int offsetY = Mathf.Clamp(bottomPadding, 0, Mathf.Max(0, canvasSize - drawHeight));

            for (int y = 0; y < drawHeight; y++)
            {
                for (int x = 0; x < drawWidth; x++)
                {
                    int sourceX = candidate.MinX + Mathf.Clamp(Mathf.FloorToInt(x / scale), 0, visibleWidth - 1);
                    int sourceY = candidate.MinY + Mathf.Clamp(Mathf.FloorToInt(y / scale), 0, visibleHeight - 1);
                    output.SetPixel(offsetX + x, offsetY + y, frameTexture.GetPixel(sourceX, sourceY));
                }
            }

            DestroyUnityObject(frameTexture);
            return output;
        }

        static Texture2D CreateClearTexture(int width, int height)
        {
            Texture2D texture = new Texture2D(width, height, TextureFormat.RGBA32, false)
            {
                filterMode = FilterMode.Point,
                wrapMode = TextureWrapMode.Clamp,
            };

            Color clear = new Color(0f, 0f, 0f, 0f);
            for (int y = 0; y < height; y++)
            {
                for (int x = 0; x < width; x++)
                    texture.SetPixel(x, y, clear);
            }

            return texture;
        }

        static Texture2D CopyFrame(Texture2D source, int startX, int startY, int width, int height)
        {
            Texture2D texture = new Texture2D(width, height, TextureFormat.RGBA32, false)
            {
                filterMode = FilterMode.Point,
                wrapMode = TextureWrapMode.Clamp,
            };

            Color clear = new Color(0f, 0f, 0f, 0f);
            for (int y = 0; y < height; y++)
            {
                for (int x = 0; x < width; x++)
                {
                    int sx = startX + x;
                    int sy = startY + y;
                    texture.SetPixel(
                        x,
                        y,
                        sx >= 0 && sx < source.width && sy >= 0 && sy < source.height
                            ? source.GetPixel(sx, sy)
                            : clear);
                }
            }

            texture.Apply(false, false);
            return texture;
        }

        static void ApplyEquipment(Texture2D frameTexture, FrameData frame, EquipmentRenderData visual)
        {
            EquipTypeConfig config = EquipTypeRegistry.Get(visual.type);
            if (config == null)
                return;

            switch (config.RenderMode)
            {
                case EquipRenderMode.Sprite:
                    ApplySpriteEquipment(frameTexture, frame, visual, config);
                    break;
                case EquipRenderMode.Color:
                    ApplyColorEquipment(frameTexture, frame, visual);
                    break;
                case EquipRenderMode.Weapon:
                    ApplyWeaponEquipment(frameTexture, visual);
                    break;
            }
        }

        static void ApplySpriteEquipment(
            Texture2D frameTexture,
            FrameData frame,
            EquipmentRenderData visual,
            EquipTypeConfig config)
        {
            BodyPartRegion region = frame?.GetRegion(config.BodyPart);
            if (region == null || region.pixels == null || region.pixels.Count == 0)
                return;

            Sprite sprite = visual.GetSprite(region.GetSpriteFacing(0), region.variant);
            if (sprite == null || sprite.texture == null)
                return;

            Rect rect = sprite.textureRect;
            for (int i = 0; i < region.pixels.Count; i++)
            {
                BodyPartPixel pixel = region.pixels[i];
                if (pixel == null || !pixel.HasUV)
                    continue;

                Color color = SampleSprite(sprite, rect, pixel.uv);
                if (color.a <= 0.01f)
                    continue;

                SetFramePixel(frameTexture, pixel.position, color);
            }
        }

        static void ApplyColorEquipment(Texture2D frameTexture, FrameData frame, EquipmentRenderData visual)
        {
            if (frame?.limbMask == null)
                return;

            ApplyLimbColor(frameTexture, frame.limbMask.leftHand, visual.leftColor);
            ApplyLimbColor(frameTexture, frame.limbMask.rightHand, visual.rightColor);
            ApplyLimbColor(frameTexture, frame.limbMask.leftFoot, visual.leftColor);
            ApplyLimbColor(frameTexture, frame.limbMask.rightFoot, visual.rightColor);
        }

        static void ApplyLimbColor(Texture2D frameTexture, List<Vector2Int> pixels, Color color)
        {
            if (pixels == null)
                return;

            for (int i = 0; i < pixels.Count; i++)
                SetFramePixel(frameTexture, pixels[i], color);
        }

        static void ApplyWeaponEquipment(Texture2D frameTexture, EquipmentRenderData visual)
        {
            Sprite sprite = FindFirstConfiguredEquipmentSequenceSprite(visual);
            if (sprite == null)
                sprite = visual.GetSprite(CharacterFacing.SouthEast);
            if (sprite == null || sprite.texture == null)
                return;

            DrawSpriteOverlay(frameTexture, sprite);
        }

        static void DrawSpriteOverlay(Texture2D frameTexture, Sprite sprite)
        {
            Rect rect = sprite.textureRect;
            int width = Mathf.Max(1, Mathf.RoundToInt(rect.width));
            int height = Mathf.Max(1, Mathf.RoundToInt(rect.height));
            float scale = Mathf.Min(frameTexture.width / (float)width, frameTexture.height / (float)height);
            int drawWidth = Mathf.Max(1, Mathf.RoundToInt(width * scale));
            int drawHeight = Mathf.Max(1, Mathf.RoundToInt(height * scale));
            int offsetX = (frameTexture.width - drawWidth) / 2;
            int offsetY = (frameTexture.height - drawHeight) / 2;

            for (int y = 0; y < drawHeight; y++)
            {
                for (int x = 0; x < drawWidth; x++)
                {
                    int sx = Mathf.Clamp(Mathf.FloorToInt(x / scale), 0, width - 1);
                    int sy = Mathf.Clamp(Mathf.FloorToInt(y / scale), 0, height - 1);
                    Color color = sprite.texture.GetPixel(
                        Mathf.Clamp(Mathf.FloorToInt(rect.xMin) + sx, 0, sprite.texture.width - 1),
                        Mathf.Clamp(Mathf.FloorToInt(rect.yMin) + sy, 0, sprite.texture.height - 1));
                    if (color.a > 0.01f)
                        frameTexture.SetPixel(offsetX + x, offsetY + y, color);
                }
            }
        }

        static Color SampleSprite(Sprite sprite, Rect rect, Vector2 uv)
        {
            int x = Mathf.Clamp(
                Mathf.FloorToInt(rect.xMin + Mathf.Clamp01(uv.x) * rect.width),
                0,
                sprite.texture.width - 1);
            int y = Mathf.Clamp(
                Mathf.FloorToInt(rect.yMin + Mathf.Clamp01(uv.y) * rect.height),
                0,
                sprite.texture.height - 1);
            return sprite.texture.GetPixel(x, y);
        }

        static void SetFramePixel(Texture2D texture, Vector2Int position, Color color)
        {
            if (position.x < 0 || position.x >= texture.width || position.y < 0 || position.y >= texture.height)
                return;

            texture.SetPixel(position.x, position.y, color);
        }
    }

    static void MarkLayoutForRebuild(RectTransform target)
    {
        if (target != null)
            LayoutRebuilder.MarkLayoutForRebuild(target);
    }

    static void ApplyParentGridCellSize(RectTransform parent, RectTransform target)
    {
        if (parent == null || target == null)
            return;

        GridLayoutGroup grid = parent.GetComponent<GridLayoutGroup>();
        if (grid == null)
            return;

        target.SetSizeWithCurrentAnchors(RectTransform.Axis.Horizontal, grid.cellSize.x);
        target.SetSizeWithCurrentAnchors(RectTransform.Axis.Vertical, grid.cellSize.y);

        LayoutElement layoutElement = target.GetComponent<LayoutElement>();
        if (layoutElement != null)
        {
            layoutElement.minWidth = grid.cellSize.x;
            layoutElement.preferredWidth = grid.cellSize.x;
            layoutElement.minHeight = grid.cellSize.y;
            layoutElement.preferredHeight = grid.cellSize.y;
            layoutElement.flexibleWidth = 0f;
            layoutElement.flexibleHeight = 0f;
        }
    }

    static void ApplyParentGridCellSizeToChildren(RectTransform parent)
    {
        if (parent == null)
            return;

        for (int i = 0; i < parent.childCount; i++)
            ApplyParentGridCellSize(parent, parent.GetChild(i) as RectTransform);
    }

    static void DestroyUnityObject(UnityEngine.Object target)
    {
        if (target == null)
            return;

        if (Application.isPlaying)
            UnityEngine.Object.Destroy(target);
        else
            UnityEngine.Object.DestroyImmediate(target);
    }

    static TMP_FontAsset ResolveReadableFont(TMP_FontAsset primaryFont)
    {
        if (primaryFont != null)
            return primaryFont;

        TMP_FontAsset silver = Resources.Load<TMP_FontAsset>("Fonts/Silver SDF");
        if (silver != null)
            return silver;

        return Resources.Load<TMP_FontAsset>("Fonts/Silver CJK Fallback SDF");
    }

    static string GetStatLabel(WorkbenchStatType stat)
    {
        switch (stat)
        {
            case WorkbenchStatType.Constitution:
                return "体质";
            case WorkbenchStatType.Health:
                return "生命";
            case WorkbenchStatType.Strength:
                return "力量";
            case WorkbenchStatType.Intelligence:
                return "智力";
            case WorkbenchStatType.Mana:
                return "魔力";
            default:
                return stat.ToString();
        }
    }

    static string GetAnimationDisplayName(AnimationTypeItem animation)
    {
        if (animation == null || string.IsNullOrWhiteSpace(animation.name))
            return "空动作";

        return GetAnimationDisplayName(animation.name);
    }

    string GetAnimationButtonLabel(AnimationTypeItem animation)
    {
        string displayName = GetAnimationDisplayName(animation);
        if (animation == null)
            return displayName;

        EquipmentRenderer renderer = _controller != null ? _controller.Renderer : null;
        if (renderer == null)
            return displayName;

        if (renderer.HasExactBodyAnimation(animation))
            return displayName;

        return IsFarmPromptAnimation(animation.name)
            ? displayName + "·无真人帧"
            : displayName + "·缺帧";
    }

    static bool IsFarmPromptAnimation(string animationName)
    {
        switch (animationName)
        {
            case "Butchering":
            case "Digging":
            case "FillingBucket":
            case "Harvesting":
            case "Milking":
            case "Shearing":
            case "SowingSeeds":
            case "TillingSoil":
            case "Watering":
                return true;
            default:
                return false;
        }
    }

    static string GetAnimationDisplayName(string animationName)
    {
        if (string.IsNullOrWhiteSpace(animationName))
            return "空动作";

        switch (animationName)
        {
            case "Idle":
                return "待机";
            case "Walk":
                return "行走";
            case "Attack":
                return "攻击";
            case "SlashAttack":
                return "挥砍";
            case "ChargedAttack":
                return "蓄力";
            case "Jump":
                return "跳跃";
            case "Dmg":
                return "受击";
            case "Die":
                return "死亡";
            case "SoulDie":
                return "灵魂消散";
            case "SpinDie":
                return "旋转死亡";
            case "Activation":
                return "激活";
            case "IdleActivation":
                return "待机激活";
            case "BaseIdleActivation":
                return "基础待机激活";
            case "BaseAttack":
                return "基础攻击";
            case "BaseWalk":
                return "基础行走";
            case "BaseDmg":
                return "基础受击";
            case "BaseDie":
                return "基础死亡";
            case "JumpAttack":
                return "跳跃攻击";
            case "Fly":
                return "飞行";
            case "FlyIdle":
                return "飞行待机";
            case "Sleep":
                return "睡眠";
            case "Chopping":
                return "砍伐";
            case "Harvest":
                return "采集";
            case "Mining":
                return "挖矿";
            case "Working":
                return "工作";
            case "AnvilWorking":
                return "铁砧工作";
            case "LaboratoryWorking":
                return "炼金工作";
            case "JewelryWorkshopWorking":
                return "珠宝工作";
            case "WoodworkBenchWorking":
                return "木工台工作";
            case "Melting":
                return "熔炼";
            case "Pouring":
                return "浇铸";
            case "Hit":
                return "命中";
            case "Work":
                return "作业";
            case "Walking":
                return "行走";
            case "Dead":
                return "死亡";
            case "Butchering":
            case "isButchering":
                return "屠宰";
            case "Digging":
            case "isDigging":
                return "挖掘";
            case "FillingBucket":
            case "isFillingBucket":
                return "装水";
            case "Harvesting":
            case "isHarvesting":
                return "收获";
            case "Milking":
            case "isMilking":
                return "挤奶";
            case "Shearing":
            case "isShearing":
                return "剪毛";
            case "SowingSeeds":
            case "isSowingSeeds":
                return "播种";
            case "TillingSoil":
            case "isTillingSoil":
                return "耕地";
            case "Watering":
            case "isWatering":
                return "浇水";
            default:
                return animationName;
        }
    }

    static string GetDirectionDisplayName(string direction)
    {
        switch (direction)
        {
            case "SE":
                return "东南";
            case "SW":
                return "西南";
            case "NE":
                return "东北";
            case "NW":
                return "西北";
            default:
                return string.IsNullOrWhiteSpace(direction) ? "未设置" : direction;
        }
    }

    static string GetAppearanceDisplayName(CharacterAppearance appearance)
    {
        if (appearance == null)
            return "未设置";

        string displayName = appearance.name;
        return string.IsNullOrWhiteSpace(displayName) ? "未命名形象" : displayName;
    }

    void ConfigurePanel(RectTransform panel, bool leftAligned, float width)
    {
        if (panel == null)
            return;

        panel.anchorMin = new Vector2(leftAligned ? 0f : 1f, 0f);
        panel.anchorMax = new Vector2(leftAligned ? 0f : 1f, 1f);
        panel.pivot = new Vector2(leftAligned ? 0f : 1f, 0.5f);
        panel.anchoredPosition = new Vector2(0f, 0f);
        panel.offsetMin = new Vector2(0f, 0f);
        panel.offsetMax = new Vector2(0f, 0f);
        panel.SetSizeWithCurrentAnchors(RectTransform.Axis.Horizontal, width);

        Image image = panel.GetComponent<Image>();
        if (image != null)
        {
            image.color = new Color(0.09f, 0.11f, 0.14f, 0.74f);
            image.raycastTarget = false;
        }

        LayoutElement layoutElement = panel.GetComponent<LayoutElement>();
        if (layoutElement != null)
        {
            layoutElement.minWidth = width;
            layoutElement.preferredWidth = width;
            layoutElement.flexibleWidth = 0f;
        }
    }

    void ConfigurePanelContent(RectTransform content, int sidePadding, float spacing)
    {
        if (content == null)
            return;

        VerticalLayoutGroup layoutGroup = content.GetComponent<VerticalLayoutGroup>();
        if (layoutGroup != null)
        {
            layoutGroup.padding.left = sidePadding;
            layoutGroup.padding.right = sidePadding;
            layoutGroup.padding.top = 12;
            layoutGroup.padding.bottom = 12;
            layoutGroup.spacing = spacing;
            layoutGroup.childForceExpandWidth = true;
            layoutGroup.childForceExpandHeight = false;
        }
    }

    void ConfigurePanelSectionOrder()
    {
        RectTransform leftContent = characterGrid != null ? characterGrid.parent as RectTransform : null;
        if (leftContent != null)
        {
            RectTransform animationSection = GetAnimationSectionRoot(leftContent);

            SetNamedChildSiblingIndex(leftContent, "角色 Header", 0);
            SetChildSiblingIndex(leftContent, characterGrid, 1);
            SetNamedChildActive(leftContent, "形象 Header", false);
            if (appearanceGrid != null)
                appearanceGrid.gameObject.SetActive(false);
            SetNamedChildSiblingIndex(leftContent, "动作 Header", 2);
            SetChildSiblingIndex(leftContent, animationSection, 3);
            SetNamedChildSiblingIndex(leftContent, "方向 Header", 4);
            SetChildSiblingIndex(leftContent, directionGrid, 5);
        }
    }

    RectTransform GetAnimationSectionRoot(RectTransform leftContent)
    {
        if (animationGrid == null)
            return null;

        Transform current = animationGrid;
        while (current != null && current.parent != leftContent)
            current = current.parent;

        return current as RectTransform;
    }

    void ConfigureRootTitle()
    {
        TextMeshProUGUI[] labels = GetComponentsInChildren<TextMeshProUGUI>(true);
        for (int i = 0; i < labels.Length; i++)
        {
            TextMeshProUGUI label = labels[i];
            if (label == null || label.name != "Title")
                continue;

            label.font = _readableFont;
            label.fontSize = 22f;
            label.enableAutoSizing = false;
            label.text = "换装预览";
            return;
        }
    }

    void ConfigureEquipmentScroll()
    {
        ScrollRect equipmentScroll = equipmentGrid != null ? equipmentGrid.GetComponentInParent<ScrollRect>() : null;
        if (equipmentScroll != null)
        {
            ConfigureScrollViewportHeight(equipmentGrid, RightListScrollViewportHeight);
            equipmentScroll.horizontal = false;
            equipmentScroll.vertical = true;
            equipmentScroll.movementType = ScrollRect.MovementType.Clamped;
            equipmentScroll.scrollSensitivity = 28f;
            equipmentScroll.inertia = true;

            Image image = equipmentScroll.GetComponent<Image>();
            if (image != null)
            {
                image.color = new Color(0.08f, 0.1f, 0.12f, 0.38f);
                image.raycastTarget = true;
            }

            Image viewportImage = equipmentScroll.viewport != null
                ? equipmentScroll.viewport.GetComponent<Image>()
                : null;
            if (viewportImage != null)
                viewportImage.raycastTarget = true;
        }
    }

    void EnsureAnimationScroll()
    {
        if (animationGrid == null)
            return;

        ScrollRect existingScroll = animationGrid.GetComponentInParent<ScrollRect>();
        if (existingScroll != null)
        {
            if (existingScroll.content == null)
                existingScroll.content = animationGrid;
            ConfigureAnimationScroll();
            return;
        }

        Debug.LogWarning("动作列表缺少预制体内置 ScrollRect，已跳过运行时重挂节点。请修复 UIEquipmentWorkbench 预制体结构。", this);
    }

    void ConfigureAnimationScroll()
    {
        ScrollRect animationScroll = animationGrid != null ? animationGrid.GetComponentInParent<ScrollRect>() : null;
        if (animationScroll == null)
            return;

        animationScroll.horizontal = false;
        animationScroll.vertical = true;
        animationScroll.movementType = ScrollRect.MovementType.Clamped;
        animationScroll.scrollSensitivity = 28f;
        animationScroll.inertia = true;
        ConfigureAdaptiveGridCellSizer(animationGrid, AnimationGridColumns, CompactChipSize.y, MinimumGridCellWidth);

        RectTransform scrollTransform = animationScroll.transform as RectTransform;
        if (scrollTransform != null)
        {
            scrollTransform.SetSizeWithCurrentAnchors(RectTransform.Axis.Vertical, AnimationScrollViewportHeight);

            LayoutElement layoutElement = scrollTransform.GetComponent<LayoutElement>();
            if (layoutElement == null)
                layoutElement = scrollTransform.gameObject.AddComponent<LayoutElement>();

            layoutElement.minHeight = AnimationScrollViewportHeight;
            layoutElement.preferredHeight = AnimationScrollViewportHeight;
            layoutElement.flexibleHeight = 0f;
        }

        if (animationScroll.viewport != null)
        {
            animationScroll.viewport.anchorMin = Vector2.zero;
            animationScroll.viewport.anchorMax = Vector2.one;
            animationScroll.viewport.offsetMin = Vector2.zero;
            animationScroll.viewport.offsetMax = Vector2.zero;
            animationScroll.viewport.SetSizeWithCurrentAnchors(RectTransform.Axis.Vertical, AnimationScrollViewportHeight);
        }

        Image image = animationScroll.GetComponent<Image>();
        if (image != null)
        {
            image.color = new Color(0.08f, 0.1f, 0.12f, 0.38f);
            image.raycastTarget = true;
        }

        Image viewportImage = animationScroll.viewport != null
            ? animationScroll.viewport.GetComponent<Image>()
            : null;
        if (viewportImage != null)
            viewportImage.raycastTarget = true;
    }

    void ConfigureDetailLabel()
    {
        if (detailTitleLabel == null)
            return;

        detailTitleLabel.font = _readableFont;
        detailTitleLabel.fontSize = 14f;
        detailTitleLabel.enableAutoSizing = true;
        detailTitleLabel.fontSizeMin = 9f;
        detailTitleLabel.fontSizeMax = 14f;
        detailTitleLabel.color = TextPrimary;
        detailTitleLabel.textWrappingMode = TextWrappingModes.Normal;
        detailTitleLabel.overflowMode = TextOverflowModes.Ellipsis;
        detailTitleLabel.alignment = TextAlignmentOptions.TopLeft;
        detailTitleLabel.raycastTarget = false;
    }

    static RectTransform FindAncestorByName(RectTransform source, string name)
    {
        if (source == null)
            return null;

        Transform current = source;
        while (current != null)
        {
            if (current.name == name)
                return current as RectTransform;

            current = current.parent;
        }

        return null;
    }

    static RectTransform FindCommonAncestor(RectTransform a, RectTransform b)
    {
        if (a == null || b == null)
            return null;

        HashSet<Transform> ancestors = new HashSet<Transform>();
        Transform current = a;
        while (current != null)
        {
            ancestors.Add(current);
            current = current.parent;
        }

        current = b;
        while (current != null)
        {
            if (ancestors.Contains(current))
                return current as RectTransform;

            current = current.parent;
        }

        return null;
    }

    static void SetNamedChildSiblingIndex(RectTransform parent, string childName, int index)
    {
        if (parent == null)
            return;

        for (int i = 0; i < parent.childCount; i++)
        {
            Transform child = parent.GetChild(i);
            if (child.name != childName)
                continue;

            child.SetSiblingIndex(index);
            return;
        }
    }

    static void SetChildSiblingIndex(RectTransform parent, RectTransform child, int index)
    {
        if (parent == null || child == null || child.parent != parent)
            return;

        child.SetSiblingIndex(index);
    }

    static void SetNamedChildActive(RectTransform parent, string childName, bool active)
    {
        if (parent == null)
            return;

        for (int i = 0; i < parent.childCount; i++)
        {
            Transform child = parent.GetChild(i);
            if (child.name != childName)
                continue;

            child.gameObject.SetActive(active);
            return;
        }
    }

    void SetHeaderLabelText(string headerName, string text)
    {
        TextMeshProUGUI[] labels = GetComponentsInChildren<TextMeshProUGUI>(true);
        for (int i = 0; i < labels.Length; i++)
        {
            TextMeshProUGUI label = labels[i];
            if (label == null || !HasAncestorNamed(label.transform, headerName))
                continue;

            label.text = text;
            label.font = _readableFont;
            return;
        }
    }

    static bool HasAncestorNamed(Transform source, string ancestorName)
    {
        Transform current = source;
        while (current != null)
        {
            if (current.name == ancestorName)
                return true;

            current = current.parent;
        }

        return false;
    }

    readonly struct CharacterFrameCandidate
    {
        public readonly int FrameX;
        public readonly int FrameY;
        public readonly int MinX;
        public readonly int MinY;
        public readonly int MaxX;
        public readonly int MaxY;
        public readonly int VisiblePixelCount;

        public CharacterFrameCandidate(int minX, int minY, int maxX, int maxY, int visiblePixelCount)
            : this(minX, minY, minX, minY, maxX, maxY, visiblePixelCount)
        {
        }

        public CharacterFrameCandidate(int frameX, int frameY, int minX, int minY, int maxX, int maxY, int visiblePixelCount)
        {
            FrameX = frameX;
            FrameY = frameY;
            MinX = minX;
            MinY = minY;
            MaxX = maxX;
            MaxY = maxY;
            VisiblePixelCount = visiblePixelCount;
        }

        public static CharacterFrameCandidate Empty(int width, int height)
        {
            return new CharacterFrameCandidate(
                0,
                0,
                Mathf.Max(0, width - 1),
                Mathf.Max(0, height - 1),
                0);
        }
    }

}
