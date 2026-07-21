using System;
using System.Collections.Generic;
using azixMcAze.SerializableDictionary;
using Sirenix.OdinInspector;
using UnityEngine;
using UnityEngine.UI;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 背包物品格面板，按物品分类显示当前背包 owner 的物品，并负责分类按钮高亮。
    /// 它不拥有背包数据，只从 `InventorySystem` 读取当前 owner 的条目快照。
    /// </summary>
    public class UIInventoryBag : MonoBehaviour
    {
        [SerializeField]
        [LabelText("分类按钮表"), Tooltip("按物品分类绑定分类按钮；缺少分类时选择该分类会被拒绝并输出警告。")]
        private SerializableDictionary<EItemCategory, UIInventoryBagCategory> m_categories = null;

        /// <summary>背包格子缓存；初始化时按显示顺序反转，保证填充顺序符合界面布局。</summary>
        private UIInventoryBagSlot[] m_slots = null;

        /// <summary>当前选中的物品分类，用于过滤背包条目。</summary>
        private EItemCategory m_category = 0;

        /// <summary>当前展示的背包 owner；切换分类时用它重新填充格子。</summary>
        private InventoryOwnerHandle m_currentOwner = default;

        #region 初始化与显隐

        /// <summary>
        /// 缓存所有子格子并初始化分类按钮。
        /// 格子视觉上从右下到左上排列，所以这里反转数组，让数据仍从左上到右下填充。
        /// </summary>
        public void Init()
        {
            m_slots = GetComponentsInChildren<UIInventoryBagSlot>();
            Array.Reverse(m_slots);

            foreach (var category in m_categories)
            {
                category.Value.SetCategory(category.Key);
            }
        }

        /// <summary>每次显示背包时重置到第一个分类，避免保留上一次菜单打开的分类状态。</summary>
        private void OnEnable() => SetCategory(0);

        #endregion

        #region 格子刷新

        /// <summary>按角色解析背包 owner 后刷新格子。</summary>
        public void UpdateSlots(CharacterBase owner)
        {
            UpdateSlots(GameManager.InventorySystem.GetOwner(owner));
        }

        /// <summary>按指定背包 owner 刷新当前分类下的物品格。</summary>
        public void UpdateSlots(InventoryOwnerHandle owner)
        {
            m_currentOwner = owner;
            if (m_slots == null)
            {
                return;
            }

            ClearSlots();
            if (!owner.IsValid || !GameManager.TryGetSystem(out InventorySystem inventorySystem))
            {
                return;
            }

            FillSlots(owner, inventorySystem);
        }

        /// <summary>清空所有格子，避免切换 owner 或分类时残留旧物品图标。</summary>
        private void ClearSlots()
        {
            foreach (UIInventoryBagSlot slot in m_slots)
            {
                slot.Clear();
            }
        }

        /// <summary>
        /// 从 InventorySystem 读取当前 owner 的背包条目，只填入当前选中分类。
        /// UI 格子不足时停止填充并输出警告，防止数组越界影响菜单。
        /// </summary>
        private void FillSlots(InventoryOwnerHandle owner, InventorySystem inventorySystem)
        {
            int usedSlots = 0;

            foreach (KeyValuePair<Item, int> entry in inventorySystem.GetBagEntries(owner))
            {
                if (entry.Key.category == m_category)
                {
                    if (usedSlots >= m_slots.Length)
                    {
                        Debug.LogWarning($"背包 UI 格子不足，无法显示 {owner} 的所有 {m_category} 物品。", this);
                        break;
                    }

                    UIInventoryBagSlot slot = m_slots[usedSlots++];
                    slot.SetItem(entry.Key, entry.Value);
                }
            }
        }

        #endregion

        #region 导航与分类

        /// <summary>返回首个背包格的 Selectable，供装备栏和菜单导航寻找邻近目标。</summary>
        internal Selectable GetFirstSlotSelectable()
        {
            return m_slots.Length > 0 ? m_slots[0].GetNavigationSelectable() : null;
        }

        /// <summary>返回首个背包格中的导航目标，供菜单打开时设置默认焦点。</summary>
        public UINavigationCursorTarget FindNavigationTarget()
        {
            if (m_slots.Length > 0)
            {
                return m_slots[0].gameObject.GetComponentInChildren<UINavigationCursorTarget>();
            }

            return null;
        }

        /// <summary>
        /// 切换当前物品分类并刷新高亮。
        /// 分类必须存在于 `m_categories`，否则说明 Prefab 配置和物品分类枚举没有对齐。
        /// </summary>
        public void SetCategory(EItemCategory category)
        {
            if (!m_categories.ContainsKey(category))
            {
                Debug.LogWarning($"背包分类 {category} 未配置对应按钮。", this);
                return;
            }

            foreach (var entry in m_categories)
            {
                entry.Value.SetHighlight(false);
            }

            m_category = category;
            m_categories[m_category].SetHighlight(true);

            UpdateSlots(m_currentOwner);
        }

        /// <summary>分类按钮点击回调入口。</summary>
        public void HandleBagCategorySelected(EItemCategory category) => SetCategory(category);

        #endregion
    }
}
