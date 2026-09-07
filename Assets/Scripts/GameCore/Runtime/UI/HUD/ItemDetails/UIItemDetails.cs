using Sirenix.OdinInspector;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

namespace FantasyWord.GameCore
{
    using YokiFrame;

    /// <summary>
    /// HUD 物品详情浮层，响应物品详情打开/关闭事件并写入图标、名称、说明和装备属性加成。
    /// 它只负责展示当前请求的物品，不保存选中状态，也不直接修改背包或装备数据。
    /// </summary>
    public class UIItemDetails : MonoBehaviour
    {
        [Header("详情框引用")]
        [SerializeField]
        [LabelText("详情框根节点"), Tooltip("承载物品详情内容的根节点；关闭详情时会整体隐藏。")]
        private GameObject m_itemDetailsBox = null;

        [SerializeField]
        [LabelText("物品图标"), Tooltip("显示当前物品图标的 Image。")]
        private Image m_itemIcon = null;

        [SerializeField]
        [LabelText("物品名称文本"), Tooltip("显示当前物品名称的 TMP 文本。")]
        private TextMeshProUGUI m_itemName = null;

        [SerializeField]
        [LabelText("物品说明文本"), Tooltip("显示物品描述，并在装备物品后追加非零属性加成。")]
        private TextMeshProUGUI m_itemDescription = null;

        /// <summary>启动时默认隐藏详情框，等待背包或装备界面发出打开事件。</summary>
        private void Awake()
        {
            m_itemDetailsBox.SetActive(false);
        }

        /// <summary>
        /// 物品详情框只在可见期间监听打开/关闭请求，避免场景切换或 UI 复用后保留脏监听。
        /// </summary>
        private void OnEnable()
        {
            EventKit.Type.Register<ItemDetailsOpenedEvent>(OnDetailsOpened);
            EventKit.Type.Register<ItemDetailsClosedEvent>(OnDetailsClosed);
        }

        /// <summary>禁用时退订事件并强制关闭详情框，避免下次启用时残留上一件物品内容。</summary>
        private void OnDisable()
        {
            EventKit.Type.UnRegister<ItemDetailsOpenedEvent>(OnDetailsOpened);
            EventKit.Type.UnRegister<ItemDetailsClosedEvent>(OnDetailsClosed);
            OnDetailsClosed();
        }

        /// <summary>
        /// 写入物品详情内容。
        /// 装备类物品会遍历正式属性目录，只把非零加成追加到描述末尾。
        /// </summary>
        private void OnDetailsOpened(ItemDetailsOpenedEvent itemDetailsOpenedEvent)
        {
            Item item = itemDetailsOpenedEvent.Item;
            if (item)
            {
                m_itemDetailsBox.SetActive(true);
                m_itemIcon.sprite = item.icon;
                m_itemName.text = item.displayName;
                m_itemDescription.text = item.description;

                if (item is Equipment)
                {
                    Equipment equipment = (Equipment)item;

                    foreach (FormalAttributeDefinition attribute in FormalAttributeCatalog.Definitions)
                    {
                        int value = equipment.GetBonusStatValue(attribute);

                        if (value != 0)
                        {
                            // 使用不换行空格把数值和属性短名绑在一起，避免详情文本自动换行时拆散属性项。
                            m_itemDescription.text += $" <u>{(value > 0 ? '+' : string.Empty)}{value}\u00A0{GameManager.Config.GetTermDefinition(attribute.Stat).shortName}</u>";
                        }
                    }
                }
            }
            else
            {
                OnDetailsClosed();
            }
        }

        /// <summary>事件系统关闭入口，参数只用于匹配事件签名。</summary>
        private void OnDetailsClosed(ItemDetailsClosedEvent _)
        {
            OnDetailsClosed();
        }

        /// <summary>隐藏详情框；文本内容保留到下次打开时覆盖，不在关闭路径重复清空。</summary>
        private void OnDetailsClosed()
        {
            m_itemDetailsBox.SetActive(false);
        }
    }
}
