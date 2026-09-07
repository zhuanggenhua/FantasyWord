using Sirenix.OdinInspector;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 背包分类按钮，显示分类图标和短名，并把点击事件回调给父级背包面板。
    /// 具体分类由 `UIInventoryBag` 初始化时写入。
    /// </summary>
    public class UIInventoryBagCategory : MonoBehaviour
    {
        [SerializeField]
        [LabelText("选中背景"), Tooltip("当前分类被选中时按钮使用的背景 Sprite。")]
        private Sprite m_selectedSprite;

        [SerializeField]
        [LabelText("未选中背景"), Tooltip("当前分类未选中时按钮使用的背景 Sprite。")]
        private Sprite m_unselectedSprite;

        [Header("分类按钮引用")]
        [SerializeField]
        [LabelText("按钮"), Tooltip("分类按钮本体，targetGraphic 需要是 Image。")]
        private Button m_button = null;

        [SerializeField]
        [LabelText("分类图标"), Tooltip("显示当前物品分类图标的 Image。")]
        private Image m_icon = null;

        [SerializeField]
        [LabelText("分类文本"), Tooltip("显示当前物品分类短名的 TMP 文本。")]
        private TextMeshProUGUI m_text = null;

        /// <summary>当前按钮代表的物品分类。</summary>
        private EItemCategory m_category;

        /// <summary>父级背包面板；分类点击只通过父级切换分类和刷新格子。</summary>
        private UIInventoryBag m_inventoryBag = null;

        /// <summary>缓存父级背包面板，缺失时说明 Prefab 层级配置错误。</summary>
        private void Awake()
        {
            m_inventoryBag = GetComponentInParent<UIInventoryBag>();
            Debug.Assert(m_inventoryBag != null, $"{nameof(UIInventoryBagCategory)} 需要挂在 {nameof(UIInventoryBag)} 子物体下。");
        }

        /// <summary>写入按钮代表的物品分类，并从全局术语配置读取图标和短名。</summary>
        public void SetCategory(EItemCategory category)
        {
            m_category = category;
            m_icon.sprite = GameManager.Config.GetTermDefinition(m_category).icon;
            m_text.text = GameManager.Config.GetTermDefinition(m_category).shortName;
        }

        /// <summary>根据父级当前分类状态切换按钮背景。</summary>
        public void SetHighlight(bool value)
        {
            ((Image)m_button.targetGraphic).sprite = value ? m_selectedSprite : m_unselectedSprite;
        }

        /// <summary>按钮点击入口，把分类选择交回父级背包面板统一处理。</summary>
        public void SelectCategory()
        {
            m_inventoryBag.HandleBagCategorySelected(m_category);
        }
    }
}
