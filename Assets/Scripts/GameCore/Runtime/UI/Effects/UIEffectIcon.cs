using Sirenix.OdinInspector;
using UnityEngine;
using UnityEngine.UI;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 单个持续效果图标显示器。
    /// 它只负责写入 Sprite 并切换显隐，效果来源和对象池生命周期由父级 UI 管理。
    /// </summary>
    public class UIEffectIcon : MonoBehaviour
    {
        [SerializeField]
        [LabelText("图标 Image")]
        [Tooltip("实际显示持续效果图标的 Image。")]
        private Image m_icon = null;

        /// <summary>显示指定图标。传入 Sprite 应来自持续效果表现配置。</summary>
        public void Show(Sprite sprite)
        {
            gameObject.SetActive(true);
            m_icon.sprite = sprite;
        }

        /// <summary>隐藏图标节点；不修改父级列表中的效果数据。</summary>
        public void Hide()
        {
            gameObject.SetActive(false);
        }
    }
}
