using Sirenix.OdinInspector;
using UnityEngine;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 背包菜单中的属性摘要面板，把当前目标角色转发给每一行 `UIStat`。
    /// 具体属性文本和数值格式由 `UIStat` 负责，本组件只维护目标角色绑定。
    /// </summary>
    public class UIInventoryStats : MonoBehaviour
    {
        [SerializeField]
        [LabelText("属性行列表"), Tooltip("背包菜单中需要刷新的属性行。")]
        private UIStat[] m_stats = null;

        /// <summary>当前属性面板绑定的角色；面板重新启用时会用它重新刷新各行。</summary>
        private CharacterBase m_target = null;

        /// <summary>重新启用时刷新一次，避免菜单隐藏期间目标属性变化后显示旧值。</summary>
        private void OnEnable()
        {
            UpdateUI(m_target);
        }

        /// <summary>启动时补一次刷新，覆盖对象激活顺序早于父级菜单初始化的情况。</summary>
        private void Start()
        {
            UpdateUI(m_target);
        }

        /// <summary>绑定目标角色，并把目标转发给所有属性行。</summary>
        public void UpdateUI(CharacterBase target)
        {
            m_target = target;

            foreach (UIStat stat in m_stats)
            {
                stat.UpdateUI(m_target);
            }
        }
    }
}
