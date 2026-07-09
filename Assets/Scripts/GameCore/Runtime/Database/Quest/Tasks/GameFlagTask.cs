using System;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using azixMcAze.SerializableDictionary;
using YokiFrame;

namespace FantasyWord.GameCore
{
    [Serializable]
    public class GameFlagTaskProgressDataBlock : QuestTaskProgressDataBlock
    {
        public override IQuestTaskProgress CreateInstance() => new GameFlagTaskProgress(this);
    }

    public class GameFlagTaskProgress : QuestTaskProgress<GameFlagTaskProgressDataBlock>
    {
        private GameFlagTask m_gameFlagTask => (GameFlagTask)m_task;

        public GameFlagTaskProgress(GameFlagTask task) : base(task) { }

        public GameFlagTaskProgress(GameFlagTaskProgressDataBlock block) : base(block) { }

        public override void OnProgressTrackingStarted()
        {
            EventKit.Type.Register<GameFlagChangedEvent>(OnGameFlagChanged);
        }

        public override void OnProgressTrackingStopped()
        {
            EventKit.Type.UnRegister<GameFlagChangedEvent>(OnGameFlagChanged);
        }

        public int CountCompleted()
        {
            int count = 0;

            foreach (var flag in m_gameFlagTask.GetRequiredFlags())
            {
                if (GameManager.GameFlagSystem.Get(flag.Key) == flag.Value)
                {
                    count++;
                }
            }

            return count;
        }

        public override bool IsCompleted()
        {
            return CountCompleted() == m_gameFlagTask.requiredFlagCount;
        }

        private void OnGameFlagChanged(GameFlagChangedEvent gameFlagChangedEvent) => UpdateProgression();
    }

    [CreateAssetMenu(menuName = AssetMenuIndexer.FantasyWord_Quests_Tasks + nameof(GameFlagTask))]
    public class GameFlagTask : QuestTask
    {
        [SerializeField] private SerializableDictionary<string, bool> m_gameFlags = new();

        public GameFlagTask()
        {
            m_title = "{0}/{1} conditions are met";
        }

        public KeyValuePair<string, bool>[] GetRequiredFlags() => m_gameFlags != null ? m_gameFlags.ToArray() : Array.Empty<KeyValuePair<string, bool>>();
        public int requiredFlagCount => m_gameFlags?.Count ?? 0;

        public override IQuestTaskProgress CreateTaskProgress() => new GameFlagTaskProgress(this);

        public override string GetCompletedTitle()
        {
            return StringFormatter.Format(m_title, requiredFlagCount, requiredFlagCount);
        }

        public override string GetInProgressTitle(IQuestTaskProgress progress)
        {
            return StringFormatter.Format(m_title, (progress as GameFlagTaskProgress).CountCompleted(), requiredFlagCount);
        }
    }
}

