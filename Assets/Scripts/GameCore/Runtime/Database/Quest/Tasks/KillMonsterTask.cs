using System;
using UnityEngine;
using UnityEngine.Serialization;
using YokiFrame;

namespace FantasyWord.GameCore
{
    [Serializable]
    public class KillMonsterTaskProgressDataBlock : QuestTaskProgressDataBlock
    {
        public int monstersKilled;

        public override IQuestTaskProgress CreateInstance() => new KillMonsterTaskProgress(this);
    }

    public class KillMonsterTaskProgress : QuestTaskProgress<KillMonsterTaskProgressDataBlock>
    {
        public int monstersKilled { get; private set; } = 0;

        private KillMonsterTask m_killMonsterTask => (KillMonsterTask)m_task;

        public KillMonsterTaskProgress(KillMonsterTask task) : base(task) { }

        public KillMonsterTaskProgress(KillMonsterTaskProgressDataBlock block) : base(block) { }

        public override void OnProgressTrackingStarted()
        {
            EventKit.Type.Register<MonsterKilledEvent>(OnMonsterKilled);
        }

        public override void OnProgressTrackingStopped()
        {
            EventKit.Type.UnRegister<MonsterKilledEvent>(OnMonsterKilled);
        }

        public override bool IsCompleted()
        {
            return monstersKilled >= m_killMonsterTask.monstersToKill;
        }

        private void OnMonsterKilled(MonsterSheet monster)
        {
            if (monster == m_killMonsterTask.monster)
            {
                ++monstersKilled;
                UpdateProgression();
            }
        }

        private void OnMonsterKilled(MonsterKilledEvent evt)
        {
            OnMonsterKilled(evt.Monster);
        }

        public override KillMonsterTaskProgressDataBlock CreateDataBlock()
        {
            KillMonsterTaskProgressDataBlock block = base.CreateDataBlock();
            block.monstersKilled = monstersKilled;
            return block;
        }

        public override void LoadDataBlock(KillMonsterTaskProgressDataBlock block)
        {
            base.LoadDataBlock(block);
            monstersKilled = block.monstersKilled;
        }
    }

    [CreateAssetMenu(menuName = AssetMenuIndexer.FantasyWord_Quests_Tasks + nameof(KillMonsterTask))]
    public class KillMonsterTask : QuestTask
    {
        [SerializeField, FormerlySerializedAs("monster")]
        private MonsterSheet m_monster = null;

        [SerializeField, FormerlySerializedAs("monstersToKill")]
        private int m_monstersToKill = 1;

        public MonsterSheet monster => m_monster;
        public int monstersToKill => m_monstersToKill;

        public KillMonsterTask()
        {
            m_title = "Kill {0} ({1}/{2})";
        }

        public override IQuestTaskProgress CreateTaskProgress() => new KillMonsterTaskProgress(this);

        public override string GetCompletedTitle()
        {
            return StringFormatter.Format(m_title, monster.displayName, monstersToKill, monstersToKill);
        }

        public override string GetInProgressTitle(IQuestTaskProgress progress)
        {
            return StringFormatter.Format(m_title, monster.displayName, ((KillMonsterTaskProgress)progress).monstersKilled, monstersToKill);
        }
    }
}
