using System;
using System.Threading.Tasks;
using UnityEngine;

namespace FantasyWord.GameCore
{
    [Serializable]
    public class ExecuteCommandHandler : IContextualCommand
    {
        [SerializeField] private CommandHandler m_commandHandler = null;

        public Task Execute()
        {
            return Execute(GameCommandContext.Script());
        }

        public Task Execute(GameCommandContext context)
        {
            return m_commandHandler != null
                ? m_commandHandler.Execute(context)
                : Task.CompletedTask;
        }
    }
}

