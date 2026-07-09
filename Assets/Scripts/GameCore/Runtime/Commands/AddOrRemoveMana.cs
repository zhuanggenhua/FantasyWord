using System;
using System.Threading.Tasks;
using UnityEngine;

namespace FantasyWord.GameCore
{
    [Serializable]
    public class AddOrRemoveMana : IContextualCommand
    {
        [SerializeField] private EAction m_action = EAction.Add;
        [SerializeField][Min(0)] private int m_amount = 0;

        public Task Execute()
        {
            return Execute(GameCommandContext.Script());
        }

        public Task Execute(GameCommandContext context)
        {
            CharacterBase target = context.ResolveActorOrCurrentControlledCharacter();
            if (target == null)
            {
                return Task.CompletedTask;
            }

            switch (m_action)
            {
                case EAction.Add:
                    target.RecoverMana(m_amount);
                    break;

                case EAction.Remove:
                    target.ConsumeMana(m_amount);
                    break;
            }

            return Task.CompletedTask;
        }
    }
}

