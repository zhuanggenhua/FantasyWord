using System;
using System.Threading.Tasks;
using Unity.Mathematics;
using UnityEngine;

namespace FantasyWord.GameCore
{
    [Serializable]
    public class HealOrDamagePlayer : IContextualCommand
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
                    target.Heal(m_amount);
                    break;

                case EAction.Remove:
                    target.Damage(new DamageOutputDescriptor
                    {
                        source = new UnknownDamageSource(),
                        damage = math.abs(m_amount),
                        flags = EDamageFlag.None,
                        type = EDamageType.None,
                    });
                    break;
            }

            return Task.CompletedTask;
        }
    }
}

