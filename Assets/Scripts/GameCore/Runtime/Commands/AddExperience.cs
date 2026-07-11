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
            CharacterActor target = null;
            if (context.Actor is CharacterActor actor)
            {
                target = actor;
            }
            else if (context.Actor == null &&
                     GameManager.Exists() &&
                     GameManager.HasSystem<PlayerSystem>())
            {
                GameManager.PlayerSystem.TryGetCurrentControlledCharacter(out CharacterBase currentCharacter);
                target = currentCharacter as CharacterActor;
            }

            target?.AddExperience(m_experience);
            return Task.CompletedTask;
        }
    }
}

