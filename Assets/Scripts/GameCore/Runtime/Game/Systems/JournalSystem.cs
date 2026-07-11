using System;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using YokiFrame;

namespace FantasyWord.GameCore
{
    [Serializable]
    public class JournalDataBlock : DataBlock
    {
        public DatabaseEntryReference<Quest>[] unlockedQuests;
        public QuestProgressDataBlock[] activeQuests;
        public DatabaseEntryReference<Quest>[] fullfilledQuests;
        public DatabaseEntryReference<Quest>[] completedQuests;
    }

    public class JournalSystem : AGameSystem, IDataBlockHandler<JournalDataBlock>
    {
        [Header("Audio")]
        [SerializeField] private AudioClipResolver m_questStartedSound;
        [SerializeField] private AudioClipResolver m_questCompletedSound;

        private readonly List<Quest> m_unlockedQuests = new();
        private readonly List<Quest> m_availableQuests = new();
        private readonly List<QuestProgress> m_activeQuests = new();
        private readonly List<Quest> m_fullfilledQuests = new();
        private readonly List<Quest> m_completedQuests = new();

        // 对外只暴露快照，避免 UI 或交互层把系统内部列表当成自己的可变真相。
        public Quest[] GetUnlockedQuests() => m_unlockedQuests.ToArray();
        public Quest[] GetAvailableQuests() => m_availableQuests.ToArray();
        public QuestProgress[] GetActiveQuests() => m_activeQuests.ToArray();
        public Quest[] GetFullfilledQuests() => m_fullfilledQuests.ToArray();
        public Quest[] GetCompletedQuests() => m_completedQuests.ToArray();

        public bool IsQuestUnlocked(Quest quest) => m_unlockedQuests.Contains(quest);
        public bool IsQuestAvailable(Quest quest) => m_availableQuests.Contains(quest);
        public bool IsQuestActive(Quest quest) => m_activeQuests.Find(progress => progress.quest == quest) != null;
        public bool IsQuestFullfilled(Quest quest) => m_fullfilledQuests.Contains(quest);
        public bool IsQuestCompleted(Quest quest) => m_completedQuests.Contains(quest);

        public bool IsTaskActive(QuestTask task)
        {
            foreach (QuestProgress progress in m_activeQuests)
            {
                if (progress.HasCurrentTask(task))
                {
                    return true;
                }
            }

            return false;
        }

        public bool IsTaskCompleted(QuestTask task)
        {
            foreach (QuestProgress progress in m_activeQuests)
            {
                if (progress.HasCompletedTask(task))
                {
                    return true;
                }
            }

            foreach (Quest quest in m_fullfilledQuests.Union(m_completedQuests))
            {
                if (quest.GetTasks().Contains(task))
                {
                    return true;
                }
            }

            return false;
        }

        public void StartQuest(Quest quest)
        {
            StartQuest(quest, GameCommandContext.Script());
        }

        public void StartQuest(Quest quest, GameCommandContext context)
        {
            QuestProgress instance = new(quest, OnQuestFullfilled);
            m_unlockedQuests.Remove(quest);
            m_availableQuests.Remove(quest);
            m_activeQuests.Add(instance);
            instance.Initialize();
            GameRuntimeEvents.NotifyQuestStarted(quest, context);
            GameRuntimeEvents.RequestAudioPlayback(m_questStartedSound);
        }

        private void OnQuestFullfilled(QuestProgress instance)
        {
            m_fullfilledQuests.Add(instance.quest);
            m_activeQuests.Remove(instance);
            GameRuntimeEvents.NotifyQuestFullfilled(instance.quest);
        }

        public void CompleteQuest(Quest quest)
        {
            CompleteQuest(quest, GameCommandContext.Script());
        }

        public void CompleteQuest(Quest quest, GameCommandContext context)
        {
            m_fullfilledQuests.Remove(quest);
            m_completedQuests.Add(quest);

            GameRuntimeEvents.NotifyQuestCompleted(quest);
            GameRuntimeEvents.RequestAudioPlayback(m_questCompletedSound);

            if (quest.repeatable)
            {
                UnlockQuest(quest);
            }

            quest.ExecuteOnQuestCompletion(context);
        }

        public void UnlockQuest(Quest quest)
        {
            m_unlockedQuests.Add(quest);

            if (!m_availableQuests.Contains(quest) && CheckIfQuestRequirementsAreMet(quest))
            {
                m_availableQuests.Add(quest);
                GameRuntimeEvents.NotifyQuestAvailabilityChanged(quest, true);
            }

            GameRuntimeEvents.NotifyQuestUnlocked(quest);
        }

        public QuestProgress GetNonFullfilledQuestToReportTo(CharacterActor character)
        {
            return m_activeQuests.Find(quest => quest.quest.reportTo == character.characterSheet);
        }

        public Quest GetQuestToComplete(CharacterActor character)
        {
            return m_fullfilledQuests.Find(quest => quest.reportTo == character.characterSheet);
        }

        public TalkToCharacterTaskProgress GetTaskToComplete(CharacterActor character)
        {
            foreach (QuestProgress quest in m_activeQuests)
            {
                foreach (IQuestTaskProgress task in quest.GetCurrentTasks())
                {
                    if (task is TalkToCharacterTaskProgress progress && progress.talkToCharacterTask.target == character.characterSheet)
                    {
                        return progress;
                    }
                }
            }

            return null;
        }

        public Quest GetQuestToStart(CharacterActor character)
        {
            return m_availableQuests.Find(quest => quest.offeredBy == character.characterSheet);
        }

        public Quest GetStartedQuest(CharacterActor character)
        {
            List<QuestProgress> results = m_activeQuests.FindAll(quest => quest.quest.offeredBy == character.characterSheet);
            return results.Count > 0 ? results[0].quest : null;
        }

        public Quest GetFullfilledQuest(CharacterActor character)
        {
            List<Quest> results = m_fullfilledQuests.FindAll(quest => quest.offeredBy == character.characterSheet);
            return results.Count > 0 ? results[0] : null;
        }

        private void UpdateQuestsAvailability()
        {
            foreach (Quest quest in m_unlockedQuests)
            {
                bool requirementsMet = CheckIfQuestRequirementsAreMet(quest);

                if (!m_availableQuests.Contains(quest) && requirementsMet)
                {
                    m_availableQuests.Add(quest);
                    GameRuntimeEvents.NotifyQuestAvailabilityChanged(quest, true);
                }
                else if (m_availableQuests.Contains(quest) && !requirementsMet)
                {
                    m_availableQuests.Remove(quest);
                    GameRuntimeEvents.NotifyQuestAvailabilityChanged(quest, false);
                }
            }
        }

        public override void OnSystemStart()
        {
            EventKit.Type.Register<CharacterLevelUpEvent>(OnCharacterLevelUp);
        }

        public override void OnSystemStop()
        {
            EventKit.Type.UnRegister<CharacterLevelUpEvent>(OnCharacterLevelUp);
        }

        public override void OnSaveFileLoaded()
        {
            UpdateQuestsAvailability();
        }

        private void OnCharacterLevelUp(CharacterLevelUpEvent characterLevelUpEvent)
        {
            UpdateQuestsAvailability();
        }

        public void LoadDataBlock(JournalDataBlock block)
        {
            DatabaseRegistry database = GameManager.Database;

            m_unlockedQuests.Clear();
            m_availableQuests.Clear();
            m_activeQuests.Clear();
            m_fullfilledQuests.Clear();
            m_completedQuests.Clear();

            if (block == null)
            {
                UpdateQuestsAvailability();
                return;
            }

            if (block.unlockedQuests != null)
            {
                m_unlockedQuests.AddRange(block.unlockedQuests.Select(database.LoadFromReference));
            }

            if (block.fullfilledQuests != null)
            {
                m_fullfilledQuests.AddRange(block.fullfilledQuests.Select(database.LoadFromReference));
            }

            if (block.completedQuests != null)
            {
                m_completedQuests.AddRange(block.completedQuests.Select(database.LoadFromReference));
            }

            QuestProgressDataBlock[] activeQuestBlocks = block.activeQuests ?? Array.Empty<QuestProgressDataBlock>();
            foreach (QuestProgressDataBlock progressDataBlock in activeQuestBlocks)
            {
                QuestProgress progress = new(progressDataBlock, OnQuestFullfilled);
                m_activeQuests.Add(progress);
                progress.CheckFullfillment();
            }

            UpdateQuestsAvailability();
        }

        public JournalDataBlock CreateDataBlock()
        {
            DatabaseRegistry database = GameManager.Database;
            return new JournalDataBlock
            {
                unlockedQuests = m_unlockedQuests.Select(database.CreateReference).ToArray(),
                activeQuests = m_activeQuests.Select(progress => progress.CreateDataBlock()).ToArray(),
                fullfilledQuests = m_fullfilledQuests.Select(database.CreateReference).ToArray(),
                completedQuests = m_completedQuests.Select(database.CreateReference).ToArray()
            };
        }

        private bool CheckIfQuestRequirementsAreMet(Quest quest)
        {
            return quest.requiredLevel <= GameManager.PlayerSystem.GetPrimaryPlayerCharacter().level;
        }
    }
}
