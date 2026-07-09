using System;
using System.Threading.Tasks;
using UnityEngine;

namespace FantasyWord.GameCore
{
    [Serializable]
    public class OpenShopMenu : IContextualCommand
    {
        [SerializeField] private Shop m_shop = null;

        public async Task Execute()
        {
            await Execute(GameCommandContext.Script());
        }

        public async Task Execute(GameCommandContext context)
        {
            Debug.Assert(m_shop != null, "Missing Shop reference!");
            var taskCompletionSource = new TaskCompletionSource<bool>();
            GameRuntimeEvents.RequestShop(m_shop, context, taskCompletionSource);
            await taskCompletionSource.Task;
        }
    }
}

