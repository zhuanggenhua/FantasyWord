using System;
using System.Threading.Tasks;
using UnityEngine;

namespace FantasyWord.GameCore
{
    [Serializable]
    public abstract class MoveCharacterBase : IContextualCommand
    {
        protected abstract CharacterBase targetCharacter { get; }

        protected virtual CharacterBase ResolveTargetCharacter(GameCommandContext context)
        {
            return targetCharacter;
        }

        [SerializeField] private Vector2 m_movement;

        public async Task Execute()
        {
            await Execute(GameCommandContext.Script());
        }

        public async Task Execute(GameCommandContext context)
        {
            CharacterBase target = ResolveTargetCharacter(context);
            Debug.Assert(target != null, "Missing character reference!");
            if (!target)
            {
                return;
            }

            Vector3 initialPosition = target.transform.position;
            Vector3 targetPosition = initialPosition + (Vector3)m_movement;
            await target.MoveTo(targetPosition).Task;
        }
    }
}

