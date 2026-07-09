using System;
using UnityEngine;
using UnityEngine.Serialization;

namespace FantasyWord.GameCore
{
    [Serializable]
    public class TalkToNPCTaskProgressDataBlock : QuestTaskProgressDataBlock
    {
        public bool completed;

        public override IQuestTaskProgress CreateInstance() => new TalkToNPCTaskProgress(this);
    }

    public class TalkToNPCTaskProgress : QuestTaskProgress<TalkToNPCTaskProgressDataBlock>
    {
        private bool m_completed = false;

        public TalkToNPCTask talkToNPCTask => (TalkToNPCTask)m_task;

        public TalkToNPCTaskProgress(TalkToNPCTask task) : base(task) { }

        public TalkToNPCTaskProgress(TalkToNPCTaskProgressDataBlock block) : base(block) { }

        public void MarkAsCompleted()
        {
            m_completed = true;
            UpdateProgression();
        }

        public override bool IsCompleted() => m_completed;

        public override void OnProgressTrackingStarted() { }
        public override void OnProgressTrackingStopped() { }

        public override TalkToNPCTaskProgressDataBlock CreateDataBlock()
        {
            TalkToNPCTaskProgressDataBlock block = base.CreateDataBlock();
            block.completed = m_completed;
            return block;
        }

        public override void LoadDataBlock(TalkToNPCTaskProgressDataBlock block)
        {
            base.LoadDataBlock(block);
            m_completed = block.completed;
        }
    }

    [CreateAssetMenu(menuName = AssetMenuIndexer.FantasyWord_Quests_Tasks + nameof(TalkToNPCTask))]
    public class TalkToNPCTask : QuestTask
    {
        [FormerlySerializedAs("target")]
        [SerializeField] private NPCSheet m_target = null;
        [FormerlySerializedAs("dialogue")]
        [SerializeField] private DialogueSequence m_dialogue = null;

        public NPCSheet target => m_target;
        public DialogueSequence dialogue => m_dialogue;

        public TalkToNPCTask()
        {
            m_title = "Talk to {0}";
        }

        public override IQuestTaskProgress CreateTaskProgress() => new TalkToNPCTaskProgress(this);

        public override string GetCompletedTitle()
        {
            return StringFormatter.Format(m_title, target.displayName);
        }

        public override string GetInProgressTitle(IQuestTaskProgress progress) => GetCompletedTitle();
    }
}
