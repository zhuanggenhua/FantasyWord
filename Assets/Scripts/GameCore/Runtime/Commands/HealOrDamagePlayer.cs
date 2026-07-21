using System;
using System.Threading.Tasks;
using UnityEngine;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 对上下文角色治疗或造成无来源伤害。
    /// </summary>
    [Serializable]
    public class HealOrDamagePlayer : IContextualCommand
    {
        [InspectorName("动作")]
        [Tooltip("Add 表示治疗，Remove 表示造成伤害。")]
        [SerializeField] private EAction m_action = EAction.Add;

        [InspectorName("数值")]
        [Tooltip("治疗或伤害的数值。")]
        [SerializeField][Min(0)] private int m_amount = 0;

        public Task Execute()
        {
            return Execute(GameCommandContext.Script());
        }

        public Task Execute(GameCommandContext context)
        {
            CharacterBase target =
                context.ResolveRequiredActorOrCurrentControlledCharacter(nameof(HealOrDamagePlayer));

            switch (m_action)
            {
                case EAction.Add:
                    target.Heal(m_amount);
                    break;

                case EAction.Remove:
                    FormalGameplayEffectDamageHelper.TryApplyDamage(
                        null,
                        target,
                        new FormalDamageEffectPayload(
                            new DamageDescriptor
                            {
                                damageType = EDamageType.None,
                                flatDamages = Mathf.Abs(m_amount),
                                scalingFactor = 0.0f,
                                criticalBehavior = EResolutionBehavior.Never,
                                missBehavior = EResolutionBehavior.Never,
                                ignoreDefense = true,
                                silent = false
                            },
                            EEffectVisualFlags.None,
                            default,
                            EEffectImpactDataType.Velocity,
                            Vector2.zero));
                    break;
            }

            return Task.CompletedTask;
        }
    }
}

