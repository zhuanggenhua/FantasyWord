using UnityEngine;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 喷火 GameplayCue 的纯表现组件。
    /// 只读取宿主的正式朝向并播放 Sprite 序列，不参与命中、元素反应或地表修改。
    /// </summary>
    [DisallowMultipleComponent]
    public sealed class FlamethrowerCueVisual : MonoBehaviour
    {
        private const float MinDirectionSqrMagnitude = 0.0001f;

        [SerializeField] private SpriteRenderer m_renderer;
        [SerializeField] private Sprite[] m_frames = System.Array.Empty<Sprite>();
        [SerializeField, Min(1f)] private float m_framesPerSecond = 12f;

        private Movable m_host;
        private int m_currentFrame = -1;
        private float m_animationTime;

        private void OnEnable()
        {
            if (!TryBindHost())
            {
                SetVisible(false);
                enabled = false;
                return;
            }

            SetVisible(true);
            ApplyDirection(m_host.GetTargetDirection());
            SetFrame(0);
        }

        private void OnDisable()
        {
            if (m_host != null)
            {
                m_host.RemoveTargetDirectionChangedListener(ApplyDirection);
                m_host = null;
            }
        }

        private void Update()
        {
            if (m_frames == null || m_frames.Length == 0 || m_renderer == null)
            {
                return;
            }

            m_animationTime += Time.deltaTime;
            int frame = Mathf.FloorToInt(m_animationTime * m_framesPerSecond) % m_frames.Length;
            SetFrame(frame);
        }

        private bool TryBindHost()
        {
            m_host = GetComponentInParent<Movable>();
            if (m_host == null)
            {
#if UNITY_EDITOR || DEVELOPMENT_BUILD
                Debug.LogError(
                    "喷火 GameplayCue 缺少父级 Movable，无法读取正式施法朝向。请确认 CueMountPrefab 挂载在施法者根节点。",
                    this);
#endif
                return false;
            }

            m_host.AddTargetDirectionChangedListener(ApplyDirection);
            return true;
        }

        private void ApplyDirection(Vector2 direction)
        {
            if (direction.sqrMagnitude <= MinDirectionSqrMagnitude)
            {
                return;
            }

            transform.localRotation = Quaternion.Euler(0f, 0f, CalculateRotationDegrees(direction));
        }

        private void SetFrame(int frame)
        {
            if (frame == m_currentFrame ||
                m_renderer == null ||
                m_frames == null ||
                frame < 0 ||
                frame >= m_frames.Length)
            {
                return;
            }

            m_currentFrame = frame;
            m_renderer.sprite = m_frames[frame];
        }

        private void SetVisible(bool visible)
        {
            if (m_renderer != null)
            {
                m_renderer.enabled = visible;
            }
        }

        internal static float CalculateRotationDegrees(Vector2 direction)
        {
            return Mathf.Atan2(direction.y, direction.x) * Mathf.Rad2Deg;
        }
    }
}
