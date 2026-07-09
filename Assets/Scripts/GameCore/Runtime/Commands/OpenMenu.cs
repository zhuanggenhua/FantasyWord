using System;
using System.Threading.Tasks;
using UnityEngine;

namespace FantasyWord.GameCore
{
    public enum EMenu
    {
        Pause,
        Character,
        Abilities,
        Inventory,
        Journal,
        Save,
        Settings,
        Death
    }

    [Serializable]
    public class OpenMenu : IContextualCommand
    {
        [SerializeField] private EMenu m_menuToOpen;

        public async Task Execute()
        {
            await Execute(GameCommandContext.Script());
        }

        public async Task Execute(GameCommandContext context)
        {
            var taskCompletionSource = new TaskCompletionSource<bool>();
            GameRuntimeEvents.RequestMenu(m_menuToOpen, taskCompletionSource);
            await taskCompletionSource.Task;
        }
    }
}

