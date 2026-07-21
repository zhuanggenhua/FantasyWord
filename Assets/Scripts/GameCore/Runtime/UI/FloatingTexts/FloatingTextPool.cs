using System.Collections.Generic;
using Sirenix.OdinInspector;
using UnityEngine;
using YokiFrame;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 浮动文字的排队播放请求。队列存在的原因是同一帧大量战斗事件需要按最小间隔错开发出。
    /// </summary>
    public struct FloatingTextAnimation
    {
        /// <summary>要显示的浮字文本。</summary>
        public string text;

        /// <summary>浮字生成的世界坐标。</summary>
        public Vector2 position;

        /// <summary>浮字显示颜色。</summary>
        public Color color;

        /// <summary>传给浮字 Animator 的触发参数。</summary>
        public string animationTrigger;
    }

    /// <summary>
    /// 战斗浮字对象池入口。
    /// 它只负责排队、节流和从 YokiFrame 对象池租用实例，不决定战斗事件是否应该显示。
    /// </summary>
    public class FloatingTextPool : MonoBehaviour
    {
        [Header("浮字对象池")]
        [SerializeField]
        [LabelText("浮字预制体")]
        [Tooltip("浮动文字预制体，必须带有 FloatingText 组件。")]
        private GameObject m_floatingTextPrefab = null;

        [SerializeField, Min(0)]
        [LabelText("对象池容量")]
        [Tooltip("预热数量和最大同时存活数量。容量不足时新浮字会继续留在队列中等待。")]
        private int m_poolSize = 3;

        [SerializeField, Min(0f)]
        [LabelText("最小播放间隔")]
        [Tooltip("两条浮动文字之间的最小播放间隔，用于避免同一帧伤害数字堆叠。")]
        private float m_minimumDelayBetweenTexts = 0.15f;

        private float m_cooldown = 0.0f;
        private float m_poolExhaustedWarningCooldown = 0.0f;
        private readonly Queue<FloatingTextAnimation> m_queue = new();

        /// <summary>按 Inspector 配置预热并限制浮字对象池容量。</summary>
        private void Awake()
        {
            ConfigureFloatingTextPool();
        }

        /// <summary>
        /// 按最小间隔从队列播放浮字。
        /// 对象池暂时没有实例时保留队列，等待后续帧继续租用。
        /// </summary>
        private void Update()
        {
            if (m_queue.Count > 0 && m_cooldown <= 0.0f)
            {
                FloatingTextAnimation animation = m_queue.Peek();

                FloatingText floatingText = RentFloatingText();

                if (floatingText)
                {
                    floatingText.Play(animation.text, animation.position, animation.color, animation.animationTrigger);
                    m_queue.Dequeue();
                    m_cooldown = m_minimumDelayBetweenTexts;
                }
                else
                {
                    if (m_poolExhaustedWarningCooldown <= 0.0f)
                    {
                        Debug.LogWarning("没有可用的浮动文字实例，已排队的浮字会继续等待对象池归还实例。");
                        m_poolExhaustedWarningCooldown = 1.0f;
                    }
                }
            }

            m_cooldown = Mathf.Max(0.0f, m_cooldown - Time.deltaTime);
            m_poolExhaustedWarningCooldown = Mathf.Max(
                0.0f,
                m_poolExhaustedWarningCooldown - Time.deltaTime);
        }

        /// <summary>从对象池租用浮字实例，并验证预制体上是否带有 FloatingText 组件。</summary>
        private FloatingText RentFloatingText()
        {
            if (m_floatingTextPrefab == null)
            {
                return null;
            }

            GameObject instance = GameObjectPoolService.Rent(m_floatingTextPrefab, transform);
            if (instance == null)
            {
                return null;
            }

            if (instance.TryGetComponent(out FloatingText floatingText))
            {
                return floatingText;
            }

            Debug.LogError("浮动文字预制体配置无效，请确认预制体带有 FloatingText 组件。", instance);
            GameObjectPoolService.Return(instance);
            return null;
        }

        /// <summary>配置并预热浮字对象池；预制体缺失时延后到租用阶段暴露为空队列。</summary>
        private void ConfigureFloatingTextPool()
        {
            if (m_floatingTextPrefab == null)
            {
                return;
            }

            int capacity = Mathf.Max(0, m_poolSize);
            GameObjectPoolService.SetMaxCapacity(m_floatingTextPrefab, capacity);
            GameObjectPoolService.Prewarm(m_floatingTextPrefab, capacity);
        }

        /// <summary>把一个浮字播放请求加入队列，实际播放时间由最小间隔和对象池可用状态决定。</summary>
        public void ShowText(string text, Vector2 position, Color color, string animationTrigger)
        {
            m_queue.Enqueue(new()
            {
                text = text,
                position = position,
                color = color,
                animationTrigger = animationTrigger
            });
        }
    }
}
