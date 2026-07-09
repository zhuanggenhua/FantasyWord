using UnityEngine;
using UnityEngine.U2D.Animation;

namespace FantasyWord.GameCore
{
    public enum EFloatingIcon
    {
        None,
        QuestAvailable,
        QuestCompleted,
        QuestTalkTo,
        QuestInProgress,
        Speech,
        Love,
        Exclamation
    }

    public class UIFloatingIcon : MonoBehaviour
    {
        [SerializeField] private SpriteResolver m_spriteResolver = null;

        private float? m_timer = null;

        private void Awake()
        {
            Debug.Assert(m_spriteResolver, ErrorMessages.InspectorMissingComponentReference<SpriteResolver>());
        }

        private void Update()
        {
            if (m_timer != null)
            {
                m_timer -= Time.deltaTime;

                if (m_timer <= 0.0f)
                {
                    SetIcon(EFloatingIcon.None);
                    m_timer = null;
                }
            }
        }

        public void SetIcon(EFloatingIcon icon, float? duration = null)
        {
            m_timer = duration;

            switch (icon)
            {
                case EFloatingIcon.None:
                    m_spriteResolver.SetCategoryAndLabel("None", "None");
                    break;

                case EFloatingIcon.QuestAvailable:
                    m_spriteResolver.SetCategoryAndLabel("Quest", "Available");
                    break;

                case EFloatingIcon.QuestCompleted:
                    m_spriteResolver.SetCategoryAndLabel("Quest", "Completed");
                    break;

                case EFloatingIcon.QuestTalkTo:
                    m_spriteResolver.SetCategoryAndLabel("Quest", "Talk To");
                    break;

                case EFloatingIcon.QuestInProgress:
                    m_spriteResolver.SetCategoryAndLabel("Quest", "In Progress");
                    break;

                case EFloatingIcon.Speech:
                    m_spriteResolver.SetCategoryAndLabel("Expression", "Speech");
                    break;

                case EFloatingIcon.Love:
                    m_spriteResolver.SetCategoryAndLabel("Expression", "Heart");
                    break;

                case EFloatingIcon.Exclamation:
                    m_spriteResolver.SetCategoryAndLabel("Expression", "Exclamation");
                    break;
            }
        }
    }
}

