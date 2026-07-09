using System;
using System.Collections.Generic;
using UnityEngine;
using MackySoft.SerializeReferenceExtensions;

namespace FantasyWord.GameCore
{
    public enum EAlignment
    {
        Good,
        Evil,
        Neutral,
        Default = Neutral
    }

    public enum EResourceValidationResult
    {
        Valid,
        HealthBelowMinimum,
        ManaBelowMinimum
    }

    [Flags]
    public enum EActionFlags
    {
        [HideInInspector] None = 0,
        Move = 1 << 0,
        Interact = 1 << 1,
        UseAbility = 1 << 2,
        UpdateTargetDirection = 1 << 3,
        ManageInventory = 1 << 4,
        ChangeEquipment = 1 << 5,
        [HideInInspector] All = ~None
    }

    public enum ECharacterAbilitySourceKind
    {
        Script,
        ItemUse,
        Equipment,
        Summon,
        StatusEffect,
        Transformation,
        Infection
    }

    [Serializable]
    public readonly struct CharacterAbilitySourceKey : IEquatable<CharacterAbilitySourceKey>
    {
        public static readonly CharacterAbilitySourceKey Script = new(ECharacterAbilitySourceKind.Script, "script");

        public CharacterAbilitySourceKey(ECharacterAbilitySourceKind kind, string sourceId)
        {
            Kind = kind;
            SourceId = NormalizeSourceId(sourceId);
        }

        public ECharacterAbilitySourceKind Kind { get; }
        public string SourceId { get; }

        public bool Equals(CharacterAbilitySourceKey other) =>
            Kind == other.Kind &&
            string.Equals(SourceId, other.SourceId, StringComparison.Ordinal);

        public override bool Equals(object obj) => obj is CharacterAbilitySourceKey other && Equals(other);
        public override int GetHashCode() => HashCode.Combine((int)Kind, SourceId);
        public override string ToString() => $"{Kind}:{SourceId}";

        private static string NormalizeSourceId(string sourceId)
        {
            return string.IsNullOrWhiteSpace(sourceId) ? "default" : sourceId;
        }
    }

    public readonly struct CharacterAbilitySourceRuntimeEntry
    {
        public CharacterAbilitySourceRuntimeEntry(
            int formalGasAbilityCode,
            CharacterAbilitySourceKey source,
            int stackCount)
        {
            FormalGasAbilityCode = Math.Max(0, formalGasAbilityCode);
            Source = source;
            StackCount = stackCount;
        }

        public int FormalGasAbilityCode { get; }
        public CharacterAbilitySourceKey Source { get; }
        public int StackCount { get; }
        public bool HasFormalGasAbility => FormalGasAbilityCode > 0;

    }

    [Serializable]
    public class CharacterAbilitySourceData
    {
        public int formalGasAbilityCode;
        public ECharacterAbilitySourceKind sourceKind;
        public string sourceId;
        public int stackCount;
    }

    public readonly struct CharacterAbilityFireResult
    {
        public CharacterAbilityFireResult(EAbilityFireCheckResult result, int formalGasAbilityCode)
        {
            Result = result;
            FormalGasAbilityCode = Math.Max(0, formalGasAbilityCode);
        }

        public EAbilityFireCheckResult Result { get; }
        public int FormalGasAbilityCode { get; }
        public bool HasFormalGasAbility => FormalGasAbilityCode > 0;
        public bool HasAbilitySource => HasFormalGasAbility;
    }

    public readonly struct CharacterEquippedAbilitySlotView
    {
        public CharacterEquippedAbilitySlotView(int slotIndex, int formalGasAbilityCode)
        {
            SlotIndex = slotIndex;
            FormalGasAbilityCode = formalGasAbilityCode;
        }

        public int SlotIndex { get; }
        public int FormalGasAbilityCode { get; }
        public bool HasFormalGasAbility => FormalGasAbilityCode > 0;
        public bool HasDisplaySource => HasFormalGasAbility;

        public Sprite Icon
        {
            get
            {
                if (HasFormalGasAbility &&
                    TryResolveFormalRuntimeConfig(out FormalGasAbilityRuntimeConfig config) &&
                    config.TryLoadIcon(out Sprite icon))
                {
                    return icon;
                }

                return null;
            }
        }

        public string DisplayName
        {
            get
            {
                if (HasFormalGasAbility &&
                    FormalGasAbilityIdentityResolver.TryResolveAbilityIdentity(
                    FormalGasAbilityCode,
                    out FormalGasAbilityIdentity identity))
                {
                    return identity.DisplayName;
                }

                return HasFormalGasAbility ? $"EX-GAS Ability {FormalGasAbilityCode}" : string.Empty;
            }
        }

        public string Description
        {
            get
            {
                if (HasFormalGasAbility &&
                    FormalGasAbilityIdentityResolver.TryResolveAbilityIdentity(
                    FormalGasAbilityCode,
                    out FormalGasAbilityIdentity identity))
                {
                    return identity.Description;
                }

                return string.Empty;
            }
        }

        public bool TryResolveFormalRuntimeConfig(out FormalGasAbilityRuntimeConfig config)
        {
            config = default;
            return FormalGasAbilityCode > 0 &&
                FormalGasAbilityRuntimeConfigResolver.TryResolveRuntimeConfig(FormalGasAbilityCode, out config);
        }
    }

    public readonly struct CharacterAbilityMenuEntry
    {
        public CharacterAbilityMenuEntry(int formalGasAbilityCode)
        {
            FormalGasAbilityCode = formalGasAbilityCode;
        }

        public int FormalGasAbilityCode { get; }
        public bool HasFormalGasAbility => FormalGasAbilityCode > 0;
        public bool HasDisplaySource => HasFormalGasAbility;
        public bool CanEquipToActiveSlot => HasFormalGasAbility;

        public Sprite Icon
        {
            get
            {
                if (HasFormalGasAbility &&
                    FormalGasAbilityRuntimeConfigResolver.TryResolveRuntimeConfig(FormalGasAbilityCode, out FormalGasAbilityRuntimeConfig config) &&
                    config.TryLoadIcon(out Sprite icon))
                {
                    return icon;
                }

                return null;
            }
        }

        public string DisplayName
        {
            get
            {
                if (HasFormalGasAbility &&
                    FormalGasAbilityIdentityResolver.TryResolveAbilityIdentity(
                        FormalGasAbilityCode,
                        out FormalGasAbilityIdentity identity) &&
                    !string.IsNullOrWhiteSpace(identity.DisplayName))
                {
                    return identity.DisplayName;
                }

                return HasFormalGasAbility ? $"EX-GAS Ability {FormalGasAbilityCode}" : string.Empty;
            }
        }

        public string Description
        {
            get
            {
                if (HasFormalGasAbility &&
                    FormalGasAbilityIdentityResolver.TryResolveAbilityIdentity(
                        FormalGasAbilityCode,
                        out FormalGasAbilityIdentity identity))
                {
                    return identity.Description;
                }

                return string.Empty;
            }
        }

        public void GenerateAdditionalDescriptionLines(List<AbilityDescriptionLine> lines)
        {
            if (lines == null)
            {
                return;
            }

            if (HasFormalGasAbility)
            {
                FormalGasAbilityDescriptionResolver.TryAppendFormalDamageLines(FormalGasAbilityCode, lines);
            }
        }
    }

    [Serializable]
    public class CharacterBaseDataBlock : MovableDataBlock
    {
        public int level;
        /// <summary>
        /// 当前值快照只用于正式属性恢复和迁移兜底，不作为另一套运行时真相源。
        /// </summary>
        [SerializeReference, SubclassSelector] public Stats currentStats;
        public DatabaseEntryReference<CharacterAlterationRule>[] activeAlterationRules;
        public CharacterAbilityRuntimeStateData[] abilityRuntimeStates;
        public CharacterAbilitySourceData[] abilitySources;
        public CharacterAbilitySourceData[] abilitySuppressions;
        public CharacterTemporalEffectRuntimeStateData[] temporalEffectRuntimeStates;
    }

    /// <summary>
    /// 角色局部运行时快照。
    /// 它只服务能力 extra state 等局部恢复，不再夹带 PersistableDataBlock.info 这类持久化身份壳。
    /// </summary>
    [Serializable]
    public class CharacterRuntimeStateData
    {
        public string identifier;
        public EPersistableObjectState state;
        public Vector3 position;
        public Quaternion rotation;
        public Vector3 scale;
        public Vector2 lookAtDirection;
        [SerializeReference, SubclassSelector] public IControllerDataBlock controllerData;
        public int level;
        [SerializeReference, SubclassSelector] public Stats currentStats;
        public DatabaseEntryReference<CharacterAlterationRule>[] activeAlterationRules;
        public CharacterAbilityRuntimeStateData[] abilityRuntimeStates;
        public CharacterAbilitySourceData[] abilitySources;
        public CharacterAbilitySourceData[] abilitySuppressions;
        public CharacterTemporalEffectRuntimeStateData[] temporalEffectRuntimeStates;
    }

    /// <summary>
    /// 正式能力恢复快照。
    /// 顶层只保存稳定能力表引用、通用冷却/执行状态和正式 extra state；
    /// 能力运行时恢复统一走这一份正式状态。
    /// </summary>
    [Serializable]
    public class CharacterAbilityRuntimeStateData
    {
        public int formalGasAbilityCode;
        public EPersistableObjectState state;
        public float remainingCooldownTimer;
        public FormalAbilityInputGateData inputGate;
        [SerializeReference, SubclassSelector] public AbilityRuntimeExtraState extraRuntimeState;
    }

    /// <summary>
    /// 正式持续效果恢复快照。
    /// 当前优先保存可重建 live effect 的最小正式状态；
    /// 持续效果恢复统一走这一份正式状态。
    /// </summary>
    [Serializable]
    public class CharacterTemporalEffectRuntimeStateData
    {
        public string effectTypeName;
        [SerializeReference, SubclassSelector] public TemporalEffectPersistedState runtimeState;

        internal static CharacterTemporalEffectRuntimeStateData Create(
            Type effectType,
            TemporalEffectPersistedState persistedState)
        {
            if (effectType == null)
            {
                return null;
            }

            return new CharacterTemporalEffectRuntimeStateData
            {
                effectTypeName = effectType.AssemblyQualifiedName,
                runtimeState = persistedState
            };
        }

        internal static CharacterTemporalEffectRuntimeStateData Create(
            ATemporalEffect effect,
            TemporalEffectPersistedState persistedState)
        {
            if (effect == null)
            {
                return null;
            }

            return Create(effect.GetType(), persistedState);
        }

        /// <summary>
        /// 把 persisted runtime state 重新装配成 live effect。
        /// formal runtime state 已经走统一恢复，不再额外并行第二条入口。
        /// </summary>
        internal bool TryCreateRuntimeEffect(out ITemporalEffect effect)
        {
            effect = null;
            if (runtimeState == null)
            {
                Debug.LogWarning(
                    $"Temporal effect runtime state [{effectTypeName}] does not carry persisted state. " +
                    "Temporal-effect restore requires a persisted runtime state.");
                return false;
            }

            if (!TryCreateRuntimeEffectInstance(out effect))
            {
                return false;
            }

            return TryRestoreRuntimeEffectState(effect);
        }

        private bool TryCreateRuntimeEffectInstance(out ITemporalEffect effect)
        {
            effect = null;
            if (string.IsNullOrWhiteSpace(effectTypeName))
            {
                return false;
            }

            Type effectType = Type.GetType(effectTypeName);
            if (effectType == null || !typeof(ITemporalEffect).IsAssignableFrom(effectType))
            {
                Debug.LogWarning(
                    $"Could not restore temporal effect runtime state because type [{effectTypeName}] is unavailable.");
                return false;
            }

            if (Activator.CreateInstance(effectType) is not ITemporalEffect createdEffect)
            {
                Debug.LogWarning($"Could not instantiate temporal effect runtime type [{effectTypeName}] during load.");
                return false;
            }

            effect = createdEffect;
            return true;
        }

        private bool TryRestoreRuntimeEffectState(ITemporalEffect effect)
        {
            if (effect == null)
            {
                return false;
            }

            if (runtimeState == null)
            {
                Debug.LogWarning(
                    $"Temporal effect runtime state [{effectTypeName}] does not carry persisted state. " +
                    "Temporal-effect restore is no longer possible without persisted runtime state.");
                return false;
            }

            if (effect is not ITemporalEffectRuntimeStateCarrier runtimeStateCarrier)
            {
                Debug.LogWarning(
                    $"Temporal effect type [{effect.GetType().AssemblyQualifiedName}] does not implement " +
                    $"{nameof(ITemporalEffectRuntimeStateCarrier)}. Formal runtime state cannot restore it.");
                return false;
            }

            runtimeStateCarrier.RestorePersistedState(runtimeState);
            return true;
        }
    }

    /// <summary>
    /// 主动能力展示快照。
    /// UI 只读这份正式查询结果，不直接依赖角色内部能力实例集合。
    /// </summary>
    public readonly struct CharacterAbilityCooldownSnapshot
    {
        public CharacterAbilityCooldownSnapshot(int formalGasAbilityCode, float remainingCooldown, float cooldown)
        {
            FormalGasAbilityCode = Math.Max(0, formalGasAbilityCode);
            RemainingCooldown = remainingCooldown;
            Cooldown = cooldown;
        }

        public int FormalGasAbilityCode { get; }
        public bool HasFormalGasAbility => FormalGasAbilityCode > 0;
        public float RemainingCooldown { get; }
        public float Cooldown { get; }
    }

    /// <summary>
    /// 持续效果展示快照。
    /// 它只承载 UI 和提示层需要的只读数据，不把内部 live effect 容器直接暴露出去。
    /// </summary>
    public readonly struct CharacterTemporalEffectPresentationSnapshot
    {
        public CharacterTemporalEffectPresentationSnapshot(
            int runtimeKey,
            bool hasPresentation,
            EEffectType effectType,
            EffectPresentationInfo info,
            string details)
        {
            RuntimeKey = runtimeKey;
            HasPresentation = hasPresentation;
            EffectType = effectType;
            Info = info;
            Details = details ?? string.Empty;
        }

        public int RuntimeKey { get; }
        public bool HasPresentation { get; }
        public EEffectType EffectType { get; }
        public EffectPresentationInfo Info { get; }
        public string Details { get; }
    }
}

