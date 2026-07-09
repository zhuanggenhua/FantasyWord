using System;
using UnityEngine;
using YokiFrame;

namespace FantasyWord.GameCore
{
    [Flags]
    public enum EQuestTaskStateFlags
    {
        [HideInInspector] None = 0,
        InProgress = 1 << 0,
        Completed = 1 << 1,
        [HideInInspector] All = ~None
    }

    [Serializable]
    public class IsQuestTaskInState : ABaseCondition
    {
        [SerializeField] private QuestTask m_task = null;
        [SerializeField] private EQuestTaskStateFlags m_stateFlags = EQuestTaskStateFlags.None;

        public override bool Evaluate()
        {
            return
                (m_stateFlags.HasFlag(EQuestTaskStateFlags.InProgress) && GameManager.JournalSystem.IsTaskActive(m_task)) ||
                (m_stateFlags.HasFlag(EQuestTaskStateFlags.Completed) && GameManager.JournalSystem.IsTaskCompleted(m_task));
        }

        protected override void OnStartListening()
        {
            EventKit.Type.Register<QuestStartedEvent>(OnQuestStarted);
            EventKit.Type.Register<QuestProgressionUpdatedEvent>(OnQuestProgressionUpdated);
        }

        protected override void OnStopListening()
        {
            EventKit.Type.UnRegister<QuestStartedEvent>(OnQuestStarted);
            EventKit.Type.UnRegister<QuestProgressionUpdatedEvent>(OnQuestProgressionUpdated);
        }

        private void OnQuestStarted(QuestStartedEvent questStartedEvent) => NotifyStateChange();
        private void OnQuestProgressionUpdated(QuestProgressionUpdatedEvent questProgressionUpdatedEvent) => NotifyStateChange();
    }
}
