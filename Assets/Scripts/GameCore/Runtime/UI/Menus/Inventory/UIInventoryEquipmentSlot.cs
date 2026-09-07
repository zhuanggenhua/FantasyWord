using Sirenix.OdinInspector;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 背包菜单中的单个装备格，按装备类型显示占位图或当前装备图标。
    /// 点击行为交给父级 `UIInventory`，当前组件只负责装备格表现和详情浮层事件。
    /// </summary>
    public class UIInventoryEquipmentSlot : MonoBehaviour, IPointerEnterHandler, ISelectHandler, IDeselectHandler
    {
        [SerializeField]
        [LabelText("装备槽类型"), Tooltip("该格子展示的装备槽类型，必须和写入的装备类型一致。")]
        private EEquipmentType m_equipmentType = EEquipmentType.Head;

        [Header("装备格引用")]
        [SerializeField]
        [LabelText("空槽占位图"), Tooltip("没有装备时显示的占位 Image。")]
        private Image m_placeholder = null;

        [SerializeField]
        [LabelText("装备图标"), Tooltip("有装备时显示装备图标的 Image。")]
        private Image m_content = null;

        [SerializeField]
        [LabelText("格子按钮"), Tooltip("用于导航、选择和点击的 Button。")]
        private Button m_button = null;

        /// <summary>该装备格对应的装备类型，供装备栏容器按槽位读取装备。</summary>
        public EEquipmentType equipmentType => m_equipmentType;

        /// <summary>当前格子显示的装备；为空表示该槽未装备。</summary>
        private Equipment m_equipment = null;

        /// <summary>当前格子是否被 UI 导航系统选中，用于同步详情浮层。</summary>
        private bool m_selected = false;

        /// <summary>父级背包菜单；装备点击后由父级处理卸下或使用反馈。</summary>
        private UIInventory m_inventoryMenu = null;

        #region 选择与详情

        /// <summary>鼠标移入时同步选择按钮，让鼠标和手柄/键盘导航共享同一套焦点状态。</summary>
        public void OnPointerEnter(PointerEventData eventData)
        {
            m_button.Select();
        }

        /// <summary>装备格获得焦点时打开装备详情；空槽会沿用现有事件语义传入空装备。</summary>
        public void OnSelect(BaseEventData eventData)
        {
            m_selected = true;
            GameRuntimeEvents.NotifyItemDetailsOpened(m_equipment);
        }

        /// <summary>装备格失去焦点时关闭详情浮层。</summary>
        public void OnDeselect(BaseEventData eventData)
        {
            m_selected = false;
            GameRuntimeEvents.NotifyItemDetailsClosed();
        }

        #endregion

        #region 装备显示

        /// <summary>
        /// 写入当前装备显示。
        /// 装备类型必须匹配当前格子的 `m_equipmentType`，否则说明装备栏配置或读取链路错位。
        /// </summary>
        public void SetEquipment(Equipment equipment)
        {
            m_equipment = equipment;

            if (equipment)
            {
                Debug.Assert(equipment.type == m_equipmentType, "装备格收到的装备类型和格子类型不一致。");

                m_placeholder.enabled = false;
                m_content.enabled = true;
                m_content.sprite = equipment.icon;
            }
            else
            {
                m_placeholder.enabled = true;
                m_content.enabled = false;
                m_content.sprite = null;
            }

            if (m_selected)
            {
                GameRuntimeEvents.NotifyItemDetailsOpened(m_equipment);
            }
        }

        #endregion

        #region 生命周期与点击

        /// <summary>缓存父级背包菜单并注册点击事件；缺父级时说明 Prefab 层级配置错误。</summary>
        private void Awake()
        {
            m_inventoryMenu = GetComponentInParent<UIInventory>();
            Debug.Assert(m_inventoryMenu != null, $"{nameof(UIInventoryEquipmentSlot)} 需要挂在 {nameof(UIInventory)} 子物体下。");
            m_button.onClick.AddListener(OnSlotClicked);
        }

        /// <summary>销毁时移除按钮监听，避免菜单卸载后按钮事件持有旧对象。</summary>
        private void OnDestroy()
        {
            if (m_button)
            {
                m_button.onClick.RemoveListener(OnSlotClicked);
            }
        }

        /// <summary>点击非空装备格时交给父级背包菜单处理。</summary>
        private void OnSlotClicked()
        {
            if (m_equipment != null)
            {
                m_inventoryMenu.HandleEquipmentItemClicked(m_equipment);
            }
        }

        #endregion
    }
}
