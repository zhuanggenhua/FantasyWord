using GAS.Runtime;
using Unity.Entities;
using UnityEngine;
using UEntity = Unity.Entities.Entity;

namespace FantasyWord.GameCore
{
    internal readonly struct FormalActiveAttributeModifierHandle
    {
        public FormalActiveAttributeModifierHandle(
            UEntity gameplayEffectEntity,
            UEntity targetAbilitySystemEntity,
            int attributeCode)
        {
            GameplayEffectEntity = gameplayEffectEntity;
            TargetAbilitySystemEntity = targetAbilitySystemEntity;
            AttributeCode = attributeCode;
        }

        internal UEntity GameplayEffectEntity { get; }
        internal UEntity TargetAbilitySystemEntity { get; }
        internal int AttributeCode { get; }

        public bool IsValid =>
            GameplayEffectEntity != UEntity.Null &&
            TargetAbilitySystemEntity != UEntity.Null &&
            AttributeCode != 0;
    }

    /// <summary>
    /// 正式资源修改入口。
    /// 伤害、治疗、耗蓝都通过 Instant GameplayEffect Modifier 修改资源属性 BaseValue，
    /// 再调用 EX-GAS 自己的 CurrentValue 重算，禁止项目侧直接写 CurrentValue。
    /// </summary>
    internal static class FormalGameplayEffectResourceModifier
    {
        public static bool TryApplyCurrentStatDelta(
            CharacterBase targetCharacter,
            EStat stat,
            int delta,
            int? minValue,
            int? maxValue,
            CharacterBase sourceCharacter,
            out int oldValue,
            out int newValue)
        {
            oldValue = 0;
            newValue = 0;

            if (targetCharacter == null ||
                !targetCharacter.TryGetFormalAbilitySystem(out AbilitySystemComponent targetAbilitySystem) ||
                targetAbilitySystem == null)
            {
                return false;
            }

            AbilitySystemComponent sourceAbilitySystem = null;
            if (sourceCharacter != null)
            {
                sourceCharacter.TryGetFormalAbilitySystem(out sourceAbilitySystem);
            }

            return TryApplyCurrentStatDelta(
                targetAbilitySystem,
                stat,
                delta,
                minValue,
                maxValue,
                sourceAbilitySystem,
                out oldValue,
                out newValue);
        }

        public static bool TryApplyCurrentStatDelta(
            AbilitySystemComponent targetAbilitySystem,
            EStat stat,
            int delta,
            int? minValue,
            int? maxValue,
            AbilitySystemComponent sourceAbilitySystem,
            out int oldValue,
            out int newValue)
        {
            oldValue = 0;
            newValue = 0;

            if (targetAbilitySystem == null)
            {
                return false;
            }

            int attributeCode = FormalGameplayAttributeSet.GetCurrentAttributeCode(stat);
            float oldCurrentValue = targetAbilitySystem.GetAttrCurrentValue(
                FormalGameplayAttributeSet.SetCode,
                attributeCode);

            float targetValue = oldCurrentValue + delta;
            if (minValue.HasValue)
            {
                targetValue = Mathf.Max(targetValue, minValue.Value);
            }

            if (maxValue.HasValue)
            {
                targetValue = Mathf.Min(targetValue, maxValue.Value);
            }

            float appliedDelta = targetValue - oldCurrentValue;
            oldValue = Mathf.RoundToInt(oldCurrentValue);
            if (Mathf.Abs(appliedDelta) <= 0.0001f)
            {
                newValue = oldValue;
                return true;
            }

            UEntity targetAscEntity = targetAbilitySystem.Cell.Entity;
            UEntity sourceAscEntity = sourceAbilitySystem != null
                ? sourceAbilitySystem.Cell.Entity
                : UEntity.Null;

            UEntity modifierEffect = GameplayEffectHelper.CreateGameplayEffectEntity(
                new GameplayEffectComponentConfig[]
                {
                    CreateModifierConfig(attributeCode, appliedDelta)
                });

            try
            {
                GameplayEffectHelper.ApplyGameplayEffectImmediate(
                    modifierEffect,
                    targetAscEntity,
                    sourceAscEntity);

                float recalculatedValue = AttributeHelper.RecalculateCurrentValue(
                    targetAscEntity,
                    FormalGameplayAttributeSet.SetCode,
                    attributeCode);

                newValue = Mathf.RoundToInt(recalculatedValue);
                return true;
            }
            finally
            {
                EntityManager entityManager = GASManager.EntityManager;
                if (modifierEffect != UEntity.Null && entityManager.Exists(modifierEffect))
                {
                    entityManager.DestroyEntity(modifierEffect);
                }
            }
        }

        public static bool TryAddActiveCurrentStatModifier(
            CharacterBase targetCharacter,
            EStat stat,
            int delta,
            CharacterBase sourceCharacter,
            out FormalActiveAttributeModifierHandle handle)
        {
            handle = default;
            if (delta == 0)
            {
                return true;
            }

            if (targetCharacter == null ||
                !targetCharacter.TryGetFormalAbilitySystem(out AbilitySystemComponent targetAbilitySystem) ||
                targetAbilitySystem == null)
            {
                return false;
            }

            AbilitySystemComponent sourceAbilitySystem = null;
            if (sourceCharacter != null)
            {
                sourceCharacter.TryGetFormalAbilitySystem(out sourceAbilitySystem);
            }

            return TryAddActiveCurrentStatModifier(
                targetAbilitySystem,
                stat,
                delta,
                sourceAbilitySystem,
                out handle);
        }

        public static bool TryAddActiveCurrentStatModifier(
            AbilitySystemComponent targetAbilitySystem,
            EStat stat,
            int delta,
            AbilitySystemComponent sourceAbilitySystem,
            out FormalActiveAttributeModifierHandle handle)
        {
            handle = default;
            if (delta == 0)
            {
                return true;
            }

            if (targetAbilitySystem == null || !GASManager.IsInitialized)
            {
                return false;
            }

            EntityManager entityManager = GASManager.EntityManager;
            UEntity targetAscEntity = targetAbilitySystem.Cell.Entity;
            if (targetAscEntity == UEntity.Null ||
                !entityManager.Exists(targetAscEntity) ||
                !entityManager.HasBuffer<BGameplayEffect>(targetAscEntity))
            {
                return false;
            }

            int attributeCode = FormalGameplayAttributeSet.GetCurrentAttributeCode(stat);
            UEntity sourceAscEntity = sourceAbilitySystem != null
                ? sourceAbilitySystem.Cell.Entity
                : targetAscEntity;

            UEntity modifierEffect = GameplayEffectHelper.CreateGameplayEffectEntity(
                new GameplayEffectComponentConfig[]
                {
                    CreateModifierConfig(attributeCode, delta),
                    CreateInfiniteDurationConfig()
                });

            entityManager.AddComponentData(modifierEffect, new CEffectInUsage
            {
                Source = sourceAscEntity,
                Target = targetAscEntity
            });
            entityManager.AddComponent<CEffectInstance>(modifierEffect);
            entityManager.AddComponent<CEffectApplied>(modifierEffect);

            CDuration duration = entityManager.GetComponentData<CDuration>(modifierEffect);
            duration.active = true;
            duration.activeTime = GASManager.CurrentFrame;
            entityManager.SetComponentData(modifierEffect, duration);

            DynamicBuffer<BGameplayEffect> gameplayEffects = entityManager.GetBuffer<BGameplayEffect>(targetAscEntity);
            bool alreadyRegistered = false;
            foreach (BGameplayEffect gameplayEffect in gameplayEffects)
            {
                if (gameplayEffect.GameplayEffect == modifierEffect)
                {
                    alreadyRegistered = true;
                    break;
                }
            }

            if (!alreadyRegistered)
            {
                gameplayEffects.Add(new BGameplayEffect { GameplayEffect = modifierEffect });
            }

            AttributeHelper.RecalculateCurrentValue(
                targetAscEntity,
                FormalGameplayAttributeSet.SetCode,
                attributeCode);

            handle = new FormalActiveAttributeModifierHandle(
                modifierEffect,
                targetAscEntity,
                attributeCode);
            return true;
        }

        public static bool TryRemoveActiveCurrentStatModifier(FormalActiveAttributeModifierHandle handle)
        {
            if (!handle.IsValid)
            {
                return true;
            }

            if (!GASManager.IsInitialized)
            {
                return false;
            }

            EntityManager entityManager = GASManager.EntityManager;
            bool targetExists = entityManager.Exists(handle.TargetAbilitySystemEntity);
            if (targetExists && entityManager.HasBuffer<BGameplayEffect>(handle.TargetAbilitySystemEntity))
            {
                DynamicBuffer<BGameplayEffect> gameplayEffects =
                    entityManager.GetBuffer<BGameplayEffect>(handle.TargetAbilitySystemEntity);
                for (int i = gameplayEffects.Length - 1; i >= 0; --i)
                {
                    if (gameplayEffects[i].GameplayEffect == handle.GameplayEffectEntity)
                    {
                        gameplayEffects.RemoveAt(i);
                        break;
                    }
                }
            }

            if (entityManager.Exists(handle.GameplayEffectEntity))
            {
                entityManager.DestroyEntity(handle.GameplayEffectEntity);
            }

            if (targetExists)
            {
                AttributeHelper.RecalculateCurrentValue(
                    handle.TargetAbilitySystemEntity,
                    FormalGameplayAttributeSet.SetCode,
                    handle.AttributeCode);
            }

            return true;
        }

        private static MCConfModifiers CreateModifierConfig(int attributeCode, float delta)
        {
            return new MCConfModifiers
            {
                modifierSettings = new[]
                {
                    new ModifierSetting
                    {
                        AttrSetCode = FormalGameplayAttributeSet.SetCode,
                        AttrCode = attributeCode,
                        Operation = GEOperation.Add,
                        Magnitude = delta,
                        MMC = new MMCConfig
                        {
                            MmcType = typeof(MMCNone),
                            MmcParameter = new XParamNone()
                        }
                    }
                }
            };
        }

        private static ConfDuration CreateInfiniteDurationConfig()
        {
            return new ConfDuration
            {
                duration = 0,
                timeUnit = TimeUnit.Frame,
                ResetStartTimeWhenActivated = false,
                StopTickWhenDeactivated = false
            };
        }
    }
}
