using System;
using UnityEngine;
using UnityEngine.Serialization;

namespace FantasyWord.GameCore
{
    [Serializable]
    public class TalkToCharacterTaskProgressDataBlock : QuestTaskProgressDataBlock
    {
        public bool completed;

        public override IQuestTaskProgress CreateInstance() => new TalkToCharacterTaskProgress(this);
    }

    public class TalkToCharacterTaskProgress : QuestTaskProgress<TalkToCharacterTaskProgressDataBlock>
    {
        private bool m_completed = false;

        public TalkToCharacterTask talkToCharacterTask => (TalkToCharacterTask)m_task;

        public TalkToCharacterTaskProgress(TalkToCharacterTask task) : base(task) { }

        public TalkToCharacterTaskProgress(TalkToCharacterTaskProgressDataBlock block) : base(block) { }

        public void MarkAsCompleted()
        {
            m_completed = true;
            UpdateProgression();
        }

        public override bool IsCompleted() => m_completed;

        public override void OnProgressTrackingStarted() { }
        public override void OnProgressTrackingStopped() { }

        public override TalkToCharacterTaskProgressDataBlock CreateDataBlock()
        {
            TalkToCharacterTaskProgressDataBlock block = base.CreateDataBlock();
            block.completed = m_completed;
            return block;
        }

        public override void LoadDataBlock(TalkToCharacterTaskProgressDataBlock block)
        {
            base.LoadDataBlock(block);
            m_completed = block.completed;
        }
    }

    [CreateAssetMenu(menuName = AssetMenuIndexer.FantasyWord_Quests_Tasks + nameof(TalkToCharacterTask))]
    public class TalkToCharacterTask : QuestTask
    {
        [FormerlySerializedAs("target")]
        [SerializeField] private CharacterSheet m_target = null;
        [FormerlySerializedAs("dialogue")]
        [SerializeField] private DialogueSequence m_dialogue = null;

        public CharacterSheet target => m_target;
        public DialogueSequence dialogue => m_dialogue;

        public TalkToCharacterTask()
        {
            m_title = "Talk to {0}";
        }

        public override IQuestTaskProgress CreateTaskProgress() => new TalkToCharacterTaskProgress(this);

        public override string GetCompletedTitle()
        {
            return StringFormatter.Format(m_title, target.displayName);
        }

        public override string GetInProgressTitle(IQuestTaskProgress progress) => GetCompletedTitle();
    }
}
