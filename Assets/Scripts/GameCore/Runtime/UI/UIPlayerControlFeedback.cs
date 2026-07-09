using UnityEngine;

namespace FantasyWord.GameCore
{
    public class UIPlayerControlFeedback : MonoBehaviour
    {
        [SerializeField] private UIControllerButton m_interactionButtonFeedback = null;
        [SerializeField] private SpriteRenderer m_spriteRenderer = null;
        [SerializeField] private Vector3 m_offset = Vector3.up;
        [SerializeField] private float m_showAnimationSpeed = 20.0f;
        [SerializeField] private float m_hideAnimationSpeed = 20.0f;

        private Color m_initialSpriteColor = Color.white;
        private CharacterPlayerControl m_playerControl = null;

        private void Start()
        {
            m_initialSpriteColor = m_spriteRenderer.color;
            GameManager.PlayerSystem.AddCurrentControlledCharacterChangedListener(OnCurrentControlledCharacterChanged);
            OnCurrentControlledCharacterChanged(GameManager.PlayerSystem.GetCurrentControlledCharacterOrPlayerInstance());
        }

        private void OnDestroy()
        {
            if (GameManager.Exists() && GameManager.HasSystem<PlayerSystem>())
            {
                GameManager.PlayerSystem.RemoveCurrentControlledCharacterChangedListener(OnCurrentControlledCharacterChanged);
            }
        }

        private void OnCurrentControlledCharacterChanged(CharacterBase character)
        {
            m_playerControl = character != null
                ? character.GetComponent<CharacterPlayerControl>()
                : null;
        }

        private void Update()
        {
            if (m_playerControl == null)
            {
                m_interactionButtonFeedback.gameObject.SetActive(false);
                return;
            }

            if (m_playerControl.TryGetCurrentInteractionTargetPosition(out Vector3 targetPosition))
            {
                if (!m_interactionButtonFeedback.isActiveAndEnabled)
                {
                    m_interactionButtonFeedback.gameObject.SetActive(true);
                }

                m_interactionButtonFeedback.transform.position = targetPosition + m_offset;
                m_spriteRenderer.color = Color.Lerp(m_spriteRenderer.color, m_initialSpriteColor, m_showAnimationSpeed * Time.unscaledDeltaTime);
            }
            else
            {
                m_spriteRenderer.color = Color.Lerp(m_spriteRenderer.color, new Color(1.0f, 1.0f, 1.0f, 0.0f), m_hideAnimationSpeed * Time.unscaledDeltaTime);
            }
        }
    }
}
