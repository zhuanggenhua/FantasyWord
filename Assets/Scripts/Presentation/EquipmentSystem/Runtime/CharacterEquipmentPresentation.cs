using System.Collections.Generic;
using FantasyWord.GameCore;
using UnityEngine;

/// <summary>
/// 把角色玩法装备的正式槽位状态同步到换装渲染器。
/// 装备资产是唯一真相；这里不保存第二份装备配置。
/// </summary>
[DisallowMultipleComponent]
[RequireComponent(typeof(CharacterEquipment))]
public sealed class CharacterEquipmentPresentation : MonoBehaviour
{
    [SerializeField] private CharacterEquipment characterEquipment;
    [SerializeField] private EquipmentRenderer equipmentRenderer;
    [SerializeField] private MountedCharacterPresentation mountedPresentation;

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
