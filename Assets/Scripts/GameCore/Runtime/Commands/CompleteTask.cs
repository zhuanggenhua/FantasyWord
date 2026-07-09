using System;
using System.Threading.Tasks;
using UnityEngine;

namespace FantasyWord.GameCore
{
    [Serializable]
    public class CompleteTask : IContextualCommand
    {
        [SerializeField] private QuestTask m_task = null;

        public Task Execute()
        {
            return Execute(GameCommandContext.Script());
        }

        public Task Execute(GameCommandContext context)
        {
            foreach (QuestProgress progress in GameManager.JournalSystem.GetActiveQuests())
            {
                progress.CompleteTask(m_task);
            }

            return Task.CompletedTask;
        }
    }
}

