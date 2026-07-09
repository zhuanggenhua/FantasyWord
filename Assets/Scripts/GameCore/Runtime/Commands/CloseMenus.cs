using System;
using System.Threading.Tasks;

namespace FantasyWord.GameCore
{
    [Serializable]
    public class CloseMenus : IContextualCommand
    {
        public Task Execute()
        {
            return Execute(GameCommandContext.Script());
        }

        public Task Execute(GameCommandContext context)
        {
            GameRuntimeEvents.RequestCloseAllMenus();
            return Task.CompletedTask;
        }
    }
}

