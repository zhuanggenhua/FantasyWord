using Sirenix.OdinInspector;
using TMPro;
using UnityEngine;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 通用属性数值行，负责把一个正式属性定义映射到文本显示。
    /// 子类可以复用 `m_stat` 和 `definition`，但具体加点、按钮或临时值展示由子类自己处理。
    /// </summary>
    public class UIStat : MonoBehaviour
    {
        [SerializeField]
        [LabelText("数值文本"), Tooltip("显示当前属性数值的 TMP 文本。")]
        protected TextMeshProUGUI m_value = null;

        [SerializeField]
        [LabelText("属性类型"), Tooltip("该行绑定的正式属性类型。")]
        protected EStat m_stat;

        /// <summary>当前属性行绑定的属性枚举，供外层 UI 查找或排序。</summary>
        public EStat stat => m_stat;

        /// <summary>正式属性定义入口，所有数值读取都应通过属性目录解析。</summary>
        protected FormalAttributeDefinition definition => FormalAttributeCatalog.Get(m_stat);

        /// <summary>按目标角色刷新数值；目标为空时显示 0，保持 UI 行可安全复用。</summary>
        public void UpdateUI(CharacterBase target)
        {
            UpdateValue(target != null ? target.GetStatValue(definition) : 0);
        }

        /// <summary>写入最终显示数值，子类可以在计算后复用该入口。</summary>
        protected void UpdateValue(int value)
        {
            m_value.text = value.ToString();
        }
    }
}
