using System;
using System.Threading.Tasks;
using UnityEngine;

namespace FantasyWord.GameCore
{
    [Serializable]
    public class DestroyEntity : IContextualCommand
    {
        [SerializeField] private Entity m_toDestroy = null;

        public Task Execute()
        {
            return Execute(GameCommandContext.Script());
        }

        public Task Execute(GameCommandContext context)
        {
            m_toDestroy?.Destroy(context);
            return Task.CompletedTask;
        }
    }
}

