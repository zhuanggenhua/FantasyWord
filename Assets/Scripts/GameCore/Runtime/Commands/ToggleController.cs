using System;
using System.Threading.Tasks;
using UnityEngine;

namespace FantasyWord.GameCore
{
    [Serializable]
    public class ToggleController : IContextualCommand
    {
        [SerializeField] private CharacterBase m_character = null;
        [SerializeField] private bool m_enabled = true;

        public Task Execute()
        {
            return Execute(GameCommandContext.Script());
        }

        public Task Execute(GameCommandContext context)
        {
            if (m_enabled)
            {
                m_character?.StartController();
            }
            else
            {
                m_character?.StopController();
            }

            return Task.CompletedTask;
        }
    }
}

