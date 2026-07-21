using Sirenix.OdinInspector;
using TMPro;
using UnityEngine;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 持续效果详情浮层。
    /// 它只负责把效果快照的说明文本显示在指定屏幕高度，不拥有持续效果生命周期。
    /// </summary>
    public class UIEffectDescription : MonoBehaviour
    {
        [SerializeField]
        [LabelText("说明文本")]
        [Tooltip("显示持续效果详情说明的 TMP 文本。")]
        private TextMeshProUGUI m_text = null;

        [SerializeField, Min(1)]
        [LabelText("最大行数")]
        [Tooltip("详情面板布局可容纳的最大文本行数，供父级列表计算浮层位置。")]
        private int m_maxLineCount = 1;

        /// <summary>详情面板可显示的最大行数，供父级根据条目位置避让边界。</summary>
        public int maxLineCount => m_maxLineCount;

        /// <summary>在指定 Y 坐标显示效果详情；说明文本来自效果表现快照。</summary>
        public void Show(CharacterTemporalEffectPresentationSnapshot effect, float positionY)
        {
            transform.position = new(transform.position.x, positionY, transform.position.z);
            m_text.text = GenerateDescription(effect);
            gameObject.SetActive(true);
        }

        /// <summary>隐藏详情面板，不清空快照真相。</summary>
        public void Hide()
        {
            gameObject.SetActive(false);
        }

        /// <summary>把持续效果快照转换成详情文本；当前直接使用表现层提供的详情字符串。</summary>
        private static string GenerateDescription(CharacterTemporalEffectPresentationSnapshot effect)
        {
            return effect.Details;
        }
    }
}
