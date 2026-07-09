using System;
using System.Threading.Tasks;
using UnityEngine;

namespace FantasyWord.GameCore
{
    [Serializable]
    public class OpenCraftMenu : IContextualCommand
    {
        [SerializeField] private CraftingStation m_craftingStation = null;

        public async Task Execute()
        {
            await Execute(GameCommandContext.Script());
        }

        public async Task Execute(GameCommandContext context)
        {
            Debug.Assert(m_craftingStation != null, "Missing CraftingStation reference!");
            var taskCompletionSource = new TaskCompletionSource<bool>();
            GameRuntimeEvents.RequestCraft(m_craftingStation, context, taskCompletionSource);
            await taskCompletionSource.Task;
        }
    }
}

