using System;
using System.Threading.Tasks;
using UnityEngine;

namespace FantasyWord.GameCore
{
    [Serializable]
    public class AddExperience : IContextualCommand
    {
        [SerializeField] private int m_experience;

        public Task Execute()
        {
            return Execute(GameCommandContext.Script());
        }

        public Task Execute(GameCommandContext context)
        {
            Hero target = null;
            if (context.Actor is Hero actorHero)
            {
                target = actorHero;
            }
            else if (context.Actor == null &&
                     GameManager.Exists() &&
                     GameManager.HasSystem<PlayerSystem>())
            {
                GameManager.PlayerSystem.TryGetCurrentControlledCharacter(out CharacterBase currentCharacter);
                target = currentCharacter as Hero;
            }

            target?.AddExperience(m_experience);
            return Task.CompletedTask;
        }
    }
}

