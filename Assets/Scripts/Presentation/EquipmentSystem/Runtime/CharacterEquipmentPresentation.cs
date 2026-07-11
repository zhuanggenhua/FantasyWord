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
        foreach (Equipment equipment in characterEquipment.GetEquippedItems())
        {
            if (!equipment)
            {
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

            equipmentRenderer.Equip(visual, false);
            appliedVisuals.Add(visual);
        }

        equipmentRenderer.Refresh();
    }

    private void ResolveReferences()
    {
        if (characterEquipment == null)
        {
            characterEquipment = GetComponent<CharacterEquipment>();
        }

        if (equipmentRenderer == null)
        {
            equipmentRenderer = GetComponentInChildren<EquipmentRenderer>(true);
        }
    }
}
