using Sirenix.OdinInspector;
using UnityEngine;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 背包菜单中的装备栏面板，按装备槽类型刷新各个装备格。
    /// 装备数据仍由 `InventorySystem` 和 `CharacterEquipment` 持有，本组件只做 UI 展示和导航入口。
    /// </summary>
    public class UIInventoryEquipment : MonoBehaviour
    {
        [SerializeField]
        [LabelText("装备格列表"), Tooltip("背包菜单中展示的装备格，顺序也作为默认导航目标顺序。")]
        private UIInventoryEquipmentSlot[] m_slots = null;

        /// <summary>按角色查找装备组件后刷新装备格；没有角色或装备组件时清空所有装备显示。</summary>
        public void UpdateSlots(CharacterBase targetCharacter)
        {
            UpdateSlots(
                targetCharacter != null &&
                targetCharacter.TryGetComponent(out CharacterEquipment targetEquipment) &&
                targetEquipment != null
                    ? targetEquipment
                    : null);
        }

        /// <summary>从 InventorySystem 读取每个装备槽当前装备，并写入对应装备格。</summary>
        public void UpdateSlots(CharacterEquipment targetEquipment)
        {
            InventorySystem inventorySystem = GameManager.GetSystem<InventorySystem>();

            foreach (UIInventoryEquipmentSlot slot in m_slots)
            {
                slot.SetEquipment(inventorySystem.GetEquipment(targetEquipment, slot.equipmentType));
            }
        }

        /// <summary>返回第一个装备格中的导航目标，作为背包格不可用时的默认焦点兜底。</summary>
        public UINavigationCursorTarget FindNavigationTarget()
        {
            if (m_slots != null && m_slots.Length > 0)
            {
                return m_slots[0].gameObject.GetComponentInChildren<UINavigationCursorTarget>();
            }

            return null;
        }
    }
}
