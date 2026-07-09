using System;
using System.Threading.Tasks;
using UnityEngine;

namespace FantasyWord.GameCore
{
    [Serializable]
    public class UnlockQuest : IContextualCommand
    {
        [SerializeField] private Quest m_quest = null;

        public Task Execute()
        {
            return Execute(GameCommandContext.Script());
        }

        public Task Execute(GameCommandContext context)
        {
            Debug.Assert(m_quest != null, "Missing Quest reference!");
            GameManager.JournalSystem.UnlockQuest(m_quest);
            return Task.CompletedTask;
        }
    }
}

