using Sirenix.OdinInspector;
using TMPro;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 背包物品格，负责显示一个物品图标和数量，并把选择、悬停、点击反馈交给背包菜单。
    /// 它只保存当前格子的展示物品，不拥有背包数据，也不直接执行物品使用或转移。
    /// </summary>
    public class UIInventoryBagSlot : MonoBehaviour, IItemSlotHandler, IPointerEnterHandler, ISelectHandler, IDeselectHandler
    {
        #region Inspector 配置

        [Header("背包格引用")]
        [SerializeField]
        [LabelText("物品图标"), Tooltip("显示当前格子物品图标的 Image；空格子会关闭该 Image。")]
        private Image m_image = null;

        [SerializeField]
        [LabelText("数量文本"), Tooltip("显示当前格子物品数量的 TMP 文本；空格子会清空文本。")]
        private TextMeshProUGUI m_quantity = null;

        [SerializeField]
        [LabelText("格子按钮"), Tooltip("用于导航、选择和点击的 Button。")]
        private Button m_button = null;

        #endregion

        /// <summary>当前格子展示的物品；为空表示空格子。</summary>
        private Item m_item = null;

        /// <summary>当前格子是否被 UI 导航系统选中，用于刷新详情浮层。</summary>
        private bool m_selected = false;

        /// <summary>父级背包菜单点击处理器；点击后由父级决定使用、装备或转移。</summary>
        private IInventoryBagItemClickHandler m_clickHandler = null;

        #region 格子内容

        /// <summary>清空当前格子展示。</summary>
        public void Clear() => SetItem(null, 0);

        /// <summary>返回当前格子物品，供拖拽、快捷操作或测试代码读取。</summary>
        public Item GetItem()
        {
            return m_item;
        }

        /// <summary>
        /// 写入当前格子物品和数量。
        /// 如果格子正被选中，会同步刷新详情浮层，避免分类切换后仍显示旧物品。
        /// </summary>
        public void SetItem(Item item, int quantity)
        {
            if (item != null)
            {
                m_item = item;
                m_quantity.text = quantity.ToString();
                m_image.enabled = true;
                m_image.sprite = item.icon;
            }
            else
            {
                m_image.enabled = false;
                m_quantity.text = string.Empty;
                m_item = null;
            }

            if (m_selected)
            {
                GameRuntimeEvents.NotifyItemDetailsOpened(m_item);
            }
        }

        #endregion

        #region 选择与详情

        /// <summary>鼠标移入时同步选择按钮，让鼠标和手柄/键盘导航共享同一套焦点状态。</summary>
        public void OnPointerEnter(PointerEventData eventData)
        {
            m_button.Select();
        }

        /// <summary>格子获得焦点时打开物品详情；空格子会沿用现有事件语义传入空物品。</summary>
        public void OnSelect(BaseEventData eventData)
        {
            m_selected = true;
            GameRuntimeEvents.NotifyItemDetailsOpened(m_item);
        }

        /// <summary>格子失去焦点时关闭物品详情，避免详情浮层停留在非当前格子上。</summary>
        public void OnDeselect(BaseEventData eventData)
        {
            m_selected = false;
            GameRuntimeEvents.NotifyItemDetailsClosed();
        }

        #endregion

        #region 生命周期与点击

        /// <summary>缓存父级点击处理器并注册按钮点击；缺父级时说明 Prefab 层级配置错误。</summary>
        private void Awake()
        {
            m_clickHandler = GetComponentInParent<IInventoryBagItemClickHandler>();
            Debug.Assert(m_clickHandler != null, $"{nameof(UIInventoryBagSlot)} 需要挂在实现 {nameof(IInventoryBagItemClickHandler)} 的父级菜单下。");
            m_button.onClick.AddListener(OnSlotClicked);
        }

        /// <summary>销毁时移除按钮监听，避免 UI 对象池或菜单卸载后保留旧回调。</summary>
        private void OnDestroy()
        {
            if (m_button)
            {
                m_button.onClick.RemoveListener(OnSlotClicked);
            }
        }

        /// <summary>点击非空格子时交给父级菜单处理，当前格子不直接执行物品逻辑。</summary>
        private void OnSlotClicked()
        {
            if (m_item != null)
            {
                m_clickHandler?.HandleBagItemClicked(m_item);
            }
        }

        /// <summary>返回格子的导航 Selectable，供相邻 UI 查找焦点目标。</summary>
        internal Selectable GetNavigationSelectable()
        {
            return m_button;
        }

        #endregion
    }
}
