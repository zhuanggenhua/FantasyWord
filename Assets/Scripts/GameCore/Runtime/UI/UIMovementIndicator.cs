using Sirenix.OdinInspector;
using UnityEngine;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 点击移动目标点的轻量表现组件。
    /// 它只根据目标角色是否还能更新朝向来淡入淡出 Sprite，不拥有移动命令、路径或目标点真相。
    /// </summary>
    public class UIMovementIndicator : MonoBehaviour
    {
        [SerializeField]
        [LabelText("目标移动体")]
        [Tooltip("提供朝向更新状态的角色移动体。为空时本组件无法判断是否自动隐藏。")]
        private Movable m_target = null;

        [SerializeField]
        [LabelText("指示器 Sprite")]
        [Tooltip("需要淡入淡出的目标点 SpriteRenderer。颜色会在运行时被本组件写入。")]
        private SpriteRenderer m_sprite = null;

        [SerializeField]
        [LabelText("自动隐藏")]
        [Tooltip("启用后，角色锁定朝向或不能更新目标方向时会把指示器淡出。")]
        private bool m_autoHide = true;

        [SerializeField, Min(0f)]
        [LabelText("淡入淡出速度")]
        [Tooltip("颜色插值速度。数值越大，显示/隐藏切换越快。")]
        private float m_transitionSpeed = 20.0f;

        private Color m_initialColor;
        private Color m_hiddenColor;

        /// <summary>缓存初始颜色，并构造同色透明目标，后续只改 alpha，不改变美术设定色。</summary>
        private void Start()
        {
            m_initialColor = m_sprite.color;
            m_hiddenColor = new(m_initialColor.r, m_initialColor.g, m_initialColor.b, 0);
        }

        /// <summary>按角色朝向锁定状态平滑切换显示；这里不提交移动命令，也不干预角色控制权。</summary>
        private void Update()
        {
            if (m_autoHide)
            {
                Color targetColor = m_target.CanUpdateTargetDirection() ? m_initialColor : m_hiddenColor;
                m_sprite.color = Color.Lerp(m_sprite.color, targetColor, Time.unscaledDeltaTime * m_transitionSpeed);
            }
        }
    }
}
