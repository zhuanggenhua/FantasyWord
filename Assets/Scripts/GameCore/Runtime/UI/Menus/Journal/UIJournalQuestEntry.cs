using TMPro;
using UnityEngine;
using UnityEngine.EventSystems;

namespace FantasyWord.GameCore
{
    public struct JournalQuestEntry
    {
        public Quest quest;
        public QuestProgress instance;
    }

    public class UIJournalQuestEntry : MonoBehaviour, ISelectHandler
    {
        [Header("References")]
        [SerializeField] private TextMeshProUGUI m_text = null;

        // Private Members
        private Quest m_targetQuest = null;
        private QuestProgress m_targetQuestProgress = null;
        private UIJournal m_journalMenu = null;

        public void SetTargetQuest(Quest quest, QuestProgress progress = null)
        {
            m_journalMenu = GetComponentInParent<UIJournal>();
            Debug.Assert(m_journalMenu != null, $"{nameof(UIJournalQuestEntry)} 需要父级 {nameof(UIJournal)} 作为任务日志菜单。");
            m_targetQuest = quest;
            m_targetQuestProgress = progress;

            if (quest)
            {
                m_text.text = StringFormatter.Format("[Lvl. {0}] {1}", quest.recommendedLevel, quest.title);
                gameObject.SetActive(true);
            }
            else
            {
                gameObject.SetActive(false);
            }
        }

        public void Hide()
        {
            SetTargetQuest(null);
        }

        public void OnSelect(BaseEventData eventData)
        {
            m_journalMenu.HandleQuestDescriptionUpdate(new JournalQuestEntry
            {
                quest = m_targetQuest,
                instance = m_targetQuestProgress
            });
        }
    }
}

