using GAS.Runtime;
using Unity.Entities;
using UnityEngine;
using UEntity = Unity.Entities.Entity;

namespace FantasyWord.GameCore
{
    [DisableAutoCreation]
    [UpdateInGroup(typeof(SGInstantEffect))]
    [UpdateAfter(typeof(SExecuteInstantEffectModifiers))]
    [UpdateBefore(typeof(SExecuteInstantEffectEnd))]
    internal sealed partial class SExecuteFormalDamageEffectsManaged : SystemBase
    {
        protected override void OnCreate()
        {
            RequireForUpdate<CEffectInstance>();
            RequireForUpdate<CEffectInUsage>();
            RequireForUpdate<WipApplyEffect>();
        }

        protected override void OnUpdate()
        {
            foreach (var (_, formalDamage, inUsage) in SystemAPI
                         .Query<RefRO<CEffectInstance>, MCFormalDamageEffect, RefRO<CEffectInUsage>>()
                         .WithNone<CDuration>()
                         .WithAll<WipApplyEffect>())
            {
                if (!TryResolveCharacters(inUsage.ValueRO, out CharacterBase sourceCharacter, out CharacterBase targetCharacter))
                {
                    continue;
                }

                FormalDamageEffectPayload payload = formalDamage.Payload;
                if (!payload.isConfigured || targetCharacter == null)
                {
                    continue;
                }

                FormalDamageExecutor.TryExecuteDamage(sourceCharacter, targetCharacter, payload);
            }

            foreach (var (_, conditionalDamage, inUsage) in SystemAPI
                         .Query<RefRO<CEffectInstance>, MCFormalConditionalDamageEffect, RefRO<CEffectInUsage>>()
                         .WithNone<CDuration>()
                         .WithAll<WipApplyEffect>())
            {
                if (!TryResolveCharacters(inUsage.ValueRO, out CharacterBase sourceCharacter, out CharacterBase targetCharacter))
                {
                    continue;
                }

                FormalConditionalDamageEffectPayload payload = conditionalDamage.Payload;
                if (!payload.isConfigured || targetCharacter == null)
                {
                    continue;
                }

                if (!IsConditionMatched(payload.Condition, sourceCharacter, targetCharacter))
                {
                    continue;
                }

                FormalDamageExecutor.TryExecuteDamage(sourceCharacter, targetCharacter, payload.Damage);
            }

            foreach (var (_, resolvedDamage, inUsage) in SystemAPI
                         .Query<RefRO<CEffectInstance>, MCFormalResolvedDamageEffect, RefRO<CEffectInUsage>>()
                         .WithNone<CDuration>()
                         .WithAll<WipApplyEffect>())
            {
                if (!TryResolveCharacters(inUsage.ValueRO, out CharacterBase sourceCharacter, out CharacterBase targetCharacter))
                {
                    continue;
                }

                FormalResolvedDamageEffectPayload payload = resolvedDamage.Payload;
                if (!payload.IsConfigured || targetCharacter == null)
                {
                    continue;
                }

                FormalDamageExecutor.TryExecuteResolvedDamage(sourceCharacter, targetCharacter, payload);
            }
        }

        private static bool TryResolveCharacters(
            CEffectInUsage inUsage,
            out CharacterBase sourceCharacter,
            out CharacterBase targetCharacter)
        {
            sourceCharacter = ResolveCharacter(inUsage.Source);
            targetCharacter = ResolveCharacter(inUsage.Target);
            return targetCharacter != null;
        }

        private static CharacterBase ResolveCharacter(UEntity ascEntity)
        {
            AbilitySystemCell abilitySystemCell = GASManager.GetAscFromEntity(ascEntity);
            if (abilitySystemCell == null)
            {
                return null;
            }

            GameObject owner = abilitySystemCell.GameObject;
            if (owner == null)
            {
                return null;
            }

            return owner.GetComponent<CharacterBase>();
        }

        private static bool IsConditionMatched(
            FormalDamageConditionPayload condition,
            CharacterBase sourceCharacter,
            CharacterBase targetCharacter)
        {
            return condition.Kind switch
            {
                EFormalDamageConditionKind.None => true,
                EFormalDamageConditionKind.Backstab => IsBackstab(sourceCharacter, targetCharacter, condition.FacingDotThreshold),
                _ => false
            };
        }

        private static bool IsBackstab(
            CharacterBase sourceCharacter,
            CharacterBase targetCharacter,
            float facingDotThreshold)
        {
            if (sourceCharacter == null || targetCharacter == null)
            {
                return false;
            }

            Vector2 targetFacing = targetCharacter.GetTargetDirection();
            if (targetFacing.sqrMagnitude <= 0.0001f)
            {
                targetFacing = Vector2.right;
            }

            Vector2 targetToAttacker = (Vector2)(sourceCharacter.transform.position - targetCharacter.transform.position);
            if (targetToAttacker.sqrMagnitude <= 0.0001f)
            {
                return false;
            }

            targetFacing.Normalize();
            targetToAttacker.Normalize();
            return Vector2.Dot(targetFacing, targetToAttacker) <= facingDotThreshold;
        }

        internal static Vector2? ResolveImpactVelocity(
            FormalDamageEffectPayload payload,
            CharacterBase sourceCharacter,
            CharacterBase targetCharacter)
        {
            return payload.impactDataType switch
            {
                EEffectImpactDataType.Velocity => payload.impactData,
                EEffectImpactDataType.SourcePosition => (Vector2)targetCharacter.transform.position -
                                                       (sourceCharacter != null ? (Vector2)sourceCharacter.transform.position : payload.impactData),
                _ => null
            };
        }

        internal static Vector2? ResolveImpactVelocity(
            FormalResolvedDamageEffectPayload payload,
            CharacterBase sourceCharacter,
            CharacterBase targetCharacter)
        {
            return payload.ImpactDataType switch
            {
                EEffectImpactDataType.Velocity => payload.ImpactData,
                EEffectImpactDataType.SourcePosition => (Vector2)targetCharacter.transform.position -
                                                       (sourceCharacter != null ? (Vector2)sourceCharacter.transform.position : payload.ImpactData),
                _ => null
            };
        }
    }

    /// <summary>
    /// 正式 GAS 伤害执行器。
    /// 这里拥有伤害链路的目标校验、攻防结算和资源 Modifier 提交；CharacterBase 只处理目标侧表现和生命周期钩子。
    /// </summary>
    internal static class FormalDamageExecutor
    {
        public static bool TryExecuteDamage(
            CharacterBase sourceCharacter,
            CharacterBase targetCharacter,
            FormalDamageEffectPayload payload)
        {
            if (targetCharacter == null || !payload.isConfigured)
            {
                return false;
            }

            DamageOutputDescriptor output = DamageSolver.SolveDamageOutput(sourceCharacter, payload.damageDescriptor);
            Vector2? impactVelocity = SExecuteFormalDamageEffectsManaged.ResolveImpactVelocity(
                payload,
                sourceCharacter,
                targetCharacter);

            return TryExecuteDamageOutput(
                sourceCharacter,
                targetCharacter,
                output,
                payload.visualFlags,
                impactVelocity,
                payload.damageImpact);
        }

        public static bool TryExecuteResolvedDamage(
            CharacterBase sourceCharacter,
            CharacterBase targetCharacter,
            FormalResolvedDamageEffectPayload payload)
        {
            if (targetCharacter == null || !payload.IsConfigured)
            {
                return false;
            }

            if (sourceCharacter == null)
            {
                payload.DamageOutput.TryGetSourceCharacter(out sourceCharacter);
            }

            Vector2? impactVelocity = SExecuteFormalDamageEffectsManaged.ResolveImpactVelocity(
                payload,
                sourceCharacter,
                targetCharacter);

            return TryExecuteDamageOutput(
                sourceCharacter,
                targetCharacter,
                payload.DamageOutput,
                payload.VisualFlags,
                impactVelocity,
                payload.DamageImpact);
        }

        public static bool TryExecuteDamageOutput(
            CharacterBase sourceCharacter,
            CharacterBase targetCharacter,
            DamageOutputDescriptor damageOutput,
            EEffectVisualFlags visualFlags,
            Vector2? impactVelocity,
            DamageImpactSettings damageImpact)
        {
            if (targetCharacter == null)
            {
                return false;
            }

            if (sourceCharacter == null)
            {
                damageOutput.TryGetSourceCharacter(out sourceCharacter);
            }

            if (!CombatSolver.CanTarget(damageOutput, targetCharacter))
            {
                return false;
            }

            DamageInputDescriptor damageInput = DamageSolver.SolveDamageInput(targetCharacter, damageOutput);
            if (impactVelocity.HasValue)
            {
                targetCharacter.ApplyFormalDamageImpact(damageInput, impactVelocity.Value, damageImpact);
            }

            targetCharacter.NotifyFormalDamageProvoked(sourceCharacter);

            if (damageInput.damage > 0)
            {
                if (!targetCharacter.TryGetFormalAbilitySystem(out _))
                {
                    return false;
                }

                int previousHealthBeforeDamage = targetCharacter.GetCurrentHealth();
                targetCharacter.PrepareFormalDamageHit(sourceCharacter, damageInput);

                bool damageApplied = FormalGameplayEffectResourceModifier.TryApplyCurrentStatDelta(
                    targetCharacter,
                    EStat.Health,
                    -damageInput.damage,
                    minValue: 0,
                    maxValue: null,
                    sourceCharacter,
                    out _,
                    out int currentHealthAfterDamage);
                if (!damageApplied)
                {
                    return false;
                }

                int appliedDamage = Mathf.Max(0, previousHealthBeforeDamage - currentHealthAfterDamage);
                targetCharacter.CompleteFormalDamageHit(
                    sourceCharacter,
                    damageInput,
                    visualFlags,
                    damageImpact,
                    previousHealthBeforeDamage,
                    appliedDamage);
            }

            return !damageInput.IsMissed;
        }
    }
}
