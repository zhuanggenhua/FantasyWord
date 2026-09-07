using System.Collections;
using Sirenix.OdinInspector;
using TMPro;
using Unity.Mathematics;
using UnityEngine;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 单条 HUD 事件日志行，负责逐字播放文本并在停留结束后自动隐藏。
    /// 父级 `UIEventLog` 负责对象池和日志内容选择，本组件只处理一行的表现生命周期。
    /// </summary>
    public class UIEventLogLine : MonoBehaviour
    {
        [SerializeField]
        [LabelText("日志文本"), Tooltip("用于显示事件日志内容的 TMP 文本；未配置时会在 Awake 中尝试读取同物体组件。")]
        private TextMeshProUGUI m_text = null;

        /// <summary>当前逐字播放协程；重复显示或禁用时必须先停止，避免旧文本继续写入复用后的行。</summary>
        private Coroutine m_animationCoroutine = null;

        /// <summary>允许日志行预制体把 TMP 文本直接挂在同一个 GameObject 上，减少手动配置成本。</summary>
        private void Awake()
        {
            m_text = GetComponent<TextMeshProUGUI>();
        }

        /// <summary>对象池归还或父级隐藏时清理文本，下一次租用从空行开始播放。</summary>
        private void OnDisable()
        {
            StopAnimation();
            ResetLine();
        }

        /// <summary>销毁前停止协程，避免 Unity 生命周期末尾继续访问已释放的文本组件。</summary>
        private void OnDestroy()
        {
            StopAnimation();
        }

        /// <summary>
        /// 从头播放一条日志。
        /// 调用方传入的是最终格式化文本，本方法只负责颜色、层级顺序、逐字速度和停留时间。
        /// </summary>
        public void Show(Color color, string text, float characterAnimationDuration, float displayDuration)
        {
            StopAnimation();

            gameObject.SetActive(true);
            m_text.color = color;
            m_text.text = string.Empty;

            // 重新挂到父级末尾，让最新日志显示在日志列表最下方。
            Transform previousParent = transform.parent;
            transform.SetParent(null);
            transform.SetParent(previousParent);

            m_animationCoroutine = StartCoroutine(Animate(text, characterAnimationDuration, displayDuration));
        }

        /// <summary>
        /// 逐字写入日志文本；空白字符不消耗打字等待时间，使句子排版不会拖慢整体节奏。
        /// 停留时间会扣除打字耗时，保证长短文本的总展示时长更接近配置值。
        /// </summary>
        private IEnumerator Animate(string text, float characterAnimationDuration, float displayDuration)
        {
            float durationOffset = 0.0f;

            while (text.Length > 0)
            {
                char c = text[0];
                m_text.text += c;
                text = text.Substring(1, text.Length - 1);

                if (!char.IsWhiteSpace(c))
                {
                    durationOffset += characterAnimationDuration;
                    yield return new WaitForSecondsRealtime(characterAnimationDuration);
                }
            }

            yield return new WaitForSecondsRealtime(math.max(displayDuration - durationOffset, 0.0f));

            m_animationCoroutine = null;
            gameObject.SetActive(false);
        }

        /// <summary>停止当前播放协程；重复停止是安全的，用于对象池复用和 UI 禁用路径。</summary>
        private void StopAnimation()
        {
            if (m_animationCoroutine == null)
            {
                return;
            }

            StopCoroutine(m_animationCoroutine);
            m_animationCoroutine = null;
        }

        /// <summary>清空上一条日志内容，避免对象池复用时短暂显示旧文本。</summary>
        private void ResetLine()
        {
            if (m_text != null)
            {
                m_text.text = string.Empty;
            }
        }
    }
}
