using System.Collections.Generic;
using FantasyWord.GameCore;
using UnityEngine;

/// <summary>
/// 角色装备表现层：将角色装备的玩法数据同步到换装渲染器
///
/// 职责：
/// - 监听 CharacterEquipment 的装备变化事件
/// - 将装备数据转换为渲染数据（EquipmentRenderData）
/// - 驱动 EquipmentRenderer 更新外观
/// - 管理坐骑表现（MountedCharacterPresentation）
///
/// 设计原则：
/// - 装备资产（CharacterEquipment）是唯一真相
/// - 本类不保存第二份装备配置，只做同步
/// - 只关注表现层，不处理装备的玩法逻辑
///
/// 注意事项：
/// - 同时装备多个坐骑时，只保留第一个
/// - 装备必须配置 EquipmentRenderData 才能正确渲染
/// </summary>
[DisallowMultipleComponent]
[RequireComponent(typeof(CharacterEquipment))]
public sealed class CharacterEquipmentPresentation : MonoBehaviour
{
    [SerializeField] private CharacterEquipment characterEquipment;         // 装备玩法组件（数据源）
    [SerializeField] private EquipmentRenderer equipmentRenderer;           // 装备渲染器（表现层）
    [SerializeField] private MountedCharacterPresentation mountedPresentation;  // 坐骑表现组件

    // 当前已应用的装备视觉数据（用于清理旧装备）
    private readonly HashSet<EquipmentRenderData> appliedVisuals = new();

    private void Awake()
    {
        ResolveReferences();
    }

    private void OnEnable()
    {
        ResolveReferences();
        if (characterEquipment != null)
        {
            characterEquipment.EquipmentLoadoutChanged += RefreshFromEquipment;
        }

        RefreshFromEquipment();
    }

    private void OnDisable()
    {
        if (characterEquipment != null)
        {
            characterEquipment.EquipmentLoadoutChanged -= RefreshFromEquipment;
        }
    }

    public void RefreshFromEquipment()
    {
        if (characterEquipment == null || equipmentRenderer == null)
        {
            Debug.LogError(
                "角色装备表现缺少 CharacterEquipment 或 EquipmentRenderer 引用，"
                + "请在统一角色 Prefab 的表现组件中完成配置。",
                this);
            return;
        }

        foreach (EquipmentRenderData visual in appliedVisuals)
        {
            if (visual != null)
            {
                equipmentRenderer.Unequip(visual, false);
            }
        }

        appliedVisuals.Clear();
        MountRenderData nextMount = null;
        List<EquipmentRenderData> pendingVisuals = new();
        foreach (Equipment equipment in characterEquipment.GetEquippedItems())
        {
            if (!equipment)
            {
                continue;
            }

            if (equipment.visual is MountRenderData mountVisual)
            {
                if (nextMount != null && nextMount != mountVisual)
                {
                    Debug.LogWarning(
                        $"角色同时装备了多个坐骑表现，保留“{nextMount.DisplayName}”，忽略“{mountVisual.DisplayName}”。",
                        this);
                    continue;
                }

                nextMount = mountVisual;
                continue;
            }

            if (equipment.visual is not EquipmentRenderData visual)
            {
                Debug.LogError(
                    $"装备“{equipment.name}”没有配置正式装备表现资源，"
                    + "请在该 Equipment 资产的“Visual”字段引用 EquipmentRenderData。",
                    equipment);
                continue;
            }

            pendingVisuals.Add(visual);
        }

        if (nextMount != null && mountedPresentation == null)
        {
            Debug.LogError(
                $"装备了坐骑“{nextMount.DisplayName}”，但角色缺少 MountedCharacterPresentation 引用，不能切换骑乘表现。",
                this);
        }
        else if (mountedPresentation != null)
        {
            mountedPresentation.SetMount(nextMount);
        }

        foreach (EquipmentRenderData visual in pendingVisuals)
        {
            equipmentRenderer.Equip(visual, false);
            appliedVisuals.Add(visual);
        }

        equipmentRenderer.Refresh();
        RefreshMountedRiderEquipmentOverlay();
    }

    public void RefreshMountedRiderEquipmentOverlay()
    {
        mountedPresentation?.RefreshRiderEquipmentOverlayFromRenderer();
    }

    private void ResolveReferences()
    {
        if (characterEquipment == null)
        {
            characterEquipment = GetComponent<CharacterEquipment>();
        }
    }
}
