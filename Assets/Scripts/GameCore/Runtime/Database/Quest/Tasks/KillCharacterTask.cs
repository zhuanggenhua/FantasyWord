using System;
using UnityEngine;
using UnityEngine.Serialization;
using YokiFrame;

namespace FantasyWord.GameCore
{
    [Serializable]
    public class KillCharacterTaskProgressDataBlock : QuestTaskProgressDataBlock
    {
        public int charactersKilled;

        public override IQuestTaskProgress CreateInstance() => new KillCharacterTaskProgress(this);
    }

    public class KillCharacterTaskProgress : QuestTaskProgress<KillCharacterTaskProgressDataBlock>
    {
        public int charactersKilled { get; private set; } = 0;

        private KillCharacterTask m_killCharacterTask => (KillCharacterTask)m_task;

        public KillCharacterTaskProgress(KillCharacterTask task) : base(task) { }

        public KillCharacterTaskProgress(KillCharacterTaskProgressDataBlock block) : base(block) { }

        public override void OnProgressTrackingStarted()
        {
            EventKit.Type.Register<CharacterKilledEvent>(OnCharacterKilled);
        }

        public override void OnProgressTrackingStopped()
        {
            EventKit.Type.UnRegister<CharacterKilledEvent>(OnCharacterKilled);
        }

        public override bool IsCompleted()
        {
            return charactersKilled >= m_killCharacterTask.charactersToKill;
        }

        private void OnCharacterKilled(CharacterSheet character)
        {
            if (character == m_killCharacterTask.character)
            {
                ++charactersKilled;
                UpdateProgression();
            }
        }

        private void OnCharacterKilled(CharacterKilledEvent evt)
        {
            OnCharacterKilled(evt.Character);
        }

        public override KillCharacterTaskProgressDataBlock CreateDataBlock()
        {
            KillCharacterTaskProgressDataBlock block = base.CreateDataBlock();
            block.charactersKilled = charactersKilled;
            return block;
        }

        public override void LoadDataBlock(KillCharacterTaskProgressDataBlock block)
        {
            base.LoadDataBlock(block);
            charactersKilled = block.charactersKilled;
        }
    }

    [CreateAssetMenu(menuName = AssetMenuIndexer.FantasyWord_Quests_Tasks + nameof(KillCharacterTask))]
    public class KillCharacterTask : QuestTask
    {
        [SerializeField, FormerlySerializedAs("monster"), FormerlySerializedAs("m_monster")]
        private CharacterSheet m_character = null;

        [SerializeField, FormerlySerializedAs("monstersToKill"), FormerlySerializedAs("m_monstersToKill")]
        private int m_charactersToKill = 1;

        public CharacterSheet character => m_character;
        public int charactersToKill => m_charactersToKill;

        public KillCharacterTask()
        {
            m_title = "Kill {0} ({1}/{2})";
        }

        public override IQuestTaskProgress CreateTaskProgress() => new KillCharacterTaskProgress(this);

        public override string GetCompletedTitle()
        {
            return StringFormatter.Format(m_title, character.displayName, charactersToKill, charactersToKill);
        }

        public override string GetInProgressTitle(IQuestTaskProgress progress)
        {
            return StringFormatter.Format(m_title, character.displayName, ((KillCharacterTaskProgress)progress).charactersKilled, charactersToKill);
        }
    }
}
