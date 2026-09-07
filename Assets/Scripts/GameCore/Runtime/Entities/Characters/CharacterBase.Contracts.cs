using System;
using System.Collections.Generic;
using UnityEngine;
using MackySoft.SerializeReferenceExtensions;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 角色阵营语义。
    /// 当前主要服务敌我、交互和条件判断，不等同于存档身份或队伍所有权。
    /// </summary>
    public enum EAlignment
    {
        Good,
        Evil,
        Neutral,
        Default = Neutral
    }

    /// <summary>
    /// 角色资源扣减或校验的结果。
    /// 调用方用它区分是生命、法力还是资源条件本身失败。
    /// </summary>
    public enum EResourceValidationResult
    {
        Valid,
        HealthBelowMinimum,
        ManaBelowMinimum
    }

    /// <summary>
    /// 当前角色可执行动作的位标记。
    /// 控制层和状态效果通过它临时禁用移动、交互、技能和装备变更等入口。
    /// </summary>
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

    /// <summary>
    /// 角色获得正式 EX-GAS 能力的来源类型。
    /// 该来源用于叠加、移除和存档恢复，不直接代表 UI 显示分组。
    /// </summary>
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

    /// <summary>
    /// 一个能力来源的稳定键。
    /// 同类来源通过 SourceId 区分具体装备、状态、召唤物或脚本入口，避免只靠能力编号判断叠加关系。
    /// </summary>
    [Serializable]
    public readonly struct CharacterAbilitySourceKey : IEquatable<CharacterAbilitySourceKey>
    {
        public static readonly CharacterAbilitySourceKey Script = new(ECharacterAbilitySourceKind.Script, "script");

        /// <summary>
        /// 创建能力来源键。
        /// sourceId 为空时会归一化为 default，确保旧调用不会生成不可比较的空来源。
        /// </summary>
        public CharacterAbilitySourceKey(ECharacterAbilitySourceKind kind, string sourceId)
        {
            Kind = kind;
            SourceId = NormalizeSourceId(sourceId);
        }

        /// <summary>
        /// 来源大类，用于区分脚本、装备、状态、变形和感染等撤回桶。
        /// </summary>
        public ECharacterAbilitySourceKind Kind { get; }
        /// <summary>
        /// 来源稳定 ID，同类来源内用它区分具体资产或入口。
        /// </summary>
        public string SourceId { get; }

        public bool Equals(CharacterAbilitySourceKey other) =>
            Kind == other.Kind &&
            string.Equals(SourceId, other.SourceId, StringComparison.Ordinal);

        public override bool Equals(object obj) => obj is CharacterAbilitySourceKey other && Equals(other);
        public override int GetHashCode() => HashCode.Combine((int)Kind, SourceId);
        public override string ToString() => $"{Kind}:{SourceId}";

        /// <summary>
        /// 归一化来源 ID。
        /// 空来源统一落到 default，避免字典里出现 null、空串和空白串三种等价状态。
        /// </summary>
        private static string NormalizeSourceId(string sourceId)
        {
            return string.IsNullOrWhiteSpace(sourceId) ? "default" : sourceId;
        }
    }

    /// <summary>
    /// 运行时能力来源条目。
    /// 它记录某个正式能力编号来自哪条来源以及当前叠加层数。
    /// </summary>
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

        /// <summary>
        /// 正式 EX-GAS ability code，0 表示无效条目。
        /// </summary>
        public int FormalGasAbilityCode { get; }
        /// <summary>
        /// 贡献这层能力来源的稳定键。
        /// </summary>
        public CharacterAbilitySourceKey Source { get; }
        /// <summary>
        /// 当前来源贡献的叠层数，存档恢复时必须大于 0 才有意义。
        /// </summary>
        public int StackCount { get; }
        /// <summary>
        /// 该条目是否指向有效正式能力。
        /// </summary>
        public bool HasFormalGasAbility => FormalGasAbilityCode > 0;
    }

    /// <summary>
    /// 存档中的能力来源记录。
    /// 字段保持简单可序列化，读取后再恢复为运行时来源键和叠加状态。
    /// </summary>
    [Serializable]
    public class CharacterAbilitySourceData
    {
        /// <summary>
        /// 正式 EX-GAS ability code。读档时小于等于 0 的条目会被视为无效来源。
        /// </summary>
        public int formalGasAbilityCode;
        /// <summary>
        /// 来源大类，和 sourceId 一起恢复为 CharacterAbilitySourceKey。
        /// </summary>
        public ECharacterAbilitySourceKind sourceKind;
        /// <summary>
        /// 来源稳定 ID。装备、状态、变形和感染都依赖它撤回对应来源。
        /// </summary>
        public string sourceId;
        /// <summary>
        /// 该来源在此能力上的叠层数。
        /// </summary>
        public int stackCount;
    }

    /// <summary>
    /// 角色尝试释放能力后的只读结果。
    /// UI、输入和自动化验证用它判断是技能检查失败，还是某个正式能力被成功接收。
    /// </summary>
    public readonly struct CharacterAbilityFireResult
    {
        public CharacterAbilityFireResult(EAbilityFireCheckResult result, int formalGasAbilityCode)
        {
            Result = result;
            FormalGasAbilityCode = Math.Max(0, formalGasAbilityCode);
        }

        /// <summary>
        /// 能力释放检查结果，Valid 才表示正式能力被接收。
        /// </summary>
        public EAbilityFireCheckResult Result { get; }
        /// <summary>
        /// 本次尝试涉及的正式 ability code。
        /// </summary>
        public int FormalGasAbilityCode { get; }
        /// <summary>
        /// 是否携带有效正式能力编号。
        /// </summary>
        public bool HasFormalGasAbility => FormalGasAbilityCode > 0;
        /// <summary>
        /// 兼容旧 UI 命名，当前等价于 HasFormalGasAbility。
        /// </summary>
        public bool HasAbilitySource => HasFormalGasAbility;
    }

    /// <summary>
    /// 主动技能槽的展示快照。
    /// 它延迟解析图标和文案，避免 UI 直接持有角色内部能力实例。
    /// </summary>
    public readonly struct CharacterEquippedAbilitySlotView
    {
        public CharacterEquippedAbilitySlotView(int slotIndex, int formalGasAbilityCode)
        {
            SlotIndex = slotIndex;
            FormalGasAbilityCode = formalGasAbilityCode;
        }

        /// <summary>
        /// 主动技能槽索引。
        /// </summary>
        public int SlotIndex { get; }
        /// <summary>
        /// 槽位绑定的正式 ability code。
        /// </summary>
        public int FormalGasAbilityCode { get; }
        /// <summary>
        /// 当前槽位是否绑定了有效正式能力。
        /// </summary>
        public bool HasFormalGasAbility => FormalGasAbilityCode > 0;
        /// <summary>
        /// UI 兼容命名，当前展示来源就是正式能力编号。
        /// </summary>
        public bool HasDisplaySource => HasFormalGasAbility;

        /// <summary>
        /// 懒加载能力图标。解析失败返回 null，由 UI 决定是否显示占位图。
        /// </summary>
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

        /// <summary>
        /// 懒解析显示名。正式身份表缺失时回退到 ability code，方便调试缺配置。
        /// </summary>
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

        /// <summary>
        /// 懒解析能力描述。缺失时返回空字符串，不在数据合同层拼接占位文案。
        /// </summary>
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

        /// <summary>
        /// 尝试解析正式运行时配置。
        /// 失败说明 ability code 没有对应正式配置，调用方应按缺配置处理。
        /// </summary>
        public bool TryResolveFormalRuntimeConfig(out FormalGasAbilityRuntimeConfig config)
        {
            config = default;
            return FormalGasAbilityCode > 0 &&
                FormalGasAbilityRuntimeConfigResolver.TryResolveRuntimeConfig(FormalGasAbilityCode, out config);
        }
    }

    /// <summary>
    /// 能力菜单中的可装备条目。
    /// 它只暴露 UI 需要的正式能力编号、图标、名称和描述，不暴露能力来源容器。
    /// </summary>
    public readonly struct CharacterAbilityMenuEntry
    {
        public CharacterAbilityMenuEntry(int formalGasAbilityCode)
        {
            FormalGasAbilityCode = formalGasAbilityCode;
        }

        /// <summary>
        /// 菜单条目对应的正式 ability code。
        /// </summary>
        public int FormalGasAbilityCode { get; }
        /// <summary>
        /// 当前条目是否有有效能力编号。
        /// </summary>
        public bool HasFormalGasAbility => FormalGasAbilityCode > 0;
        /// <summary>
        /// UI 兼容命名，当前展示来源就是正式能力编号。
        /// </summary>
        public bool HasDisplaySource => HasFormalGasAbility;
        /// <summary>
        /// 是否可以装备到主动技能槽；当前只要求 ability code 有效。
        /// </summary>
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

        /// <summary>
        /// 追加菜单详情里的派生描述行。
        /// 当前只从正式能力伤害配置生成附加行，调用方传 null 时直接跳过。
        /// </summary>
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

    /// <summary>
    /// 角色运行时资源状态。
    /// 存档只保存生命/法力这类可损耗资源，不再保存整份正式属性 CurrentValue。
    /// </summary>
    [Serializable]
    public class CharacterResourceStateData
    {
        /// <summary>当前生命值。</summary>
        public int health;

        /// <summary>当前法力值。</summary>
        public int mana;
    }
    /// <summary>
    /// 角色持久化数据块。
    /// 它承接 Movable 的基础保存内容，并追加等级、属性、能力来源和持续效果恢复数据。
    /// </summary>
    [Serializable]
    public class CharacterBaseDataBlock : MovableDataBlock
    {
        /// <summary>
        /// 角色等级。读档后由 CharacterBase 负责重建等级相关属性和资源。
        /// </summary>
        public int level;
        /// <summary>
        /// 当前资源状态，只保存受伤和耗蓝这类运行时资源缺口。
        /// </summary>
        [SerializeReference, SubclassSelector] public CharacterResourceStateData currentResources;
        /// <summary>
        /// 当前激活的变身/感染规则引用。可叠层规则会重复写入多条引用。
        /// </summary>
        public DatabaseEntryReference<CharacterAlterationRule>[] activeAlterationRules;
        /// <summary>
        /// 正式能力实例运行时状态，包含冷却、执行状态和 extra state。
        /// </summary>
        public CharacterAbilityRuntimeStateData[] abilityRuntimeStates;
        /// <summary>
        /// 来源化临时授予能力记录。
        /// </summary>
        public CharacterAbilitySourceData[] abilitySources;
        /// <summary>
        /// 来源化能力压制记录。
        /// </summary>
        public CharacterAbilitySourceData[] abilitySuppressions;
        /// <summary>
        /// 正式持续效果运行时状态。
        /// </summary>
        public CharacterTemporalEffectRuntimeStateData[] temporalEffectRuntimeStates;
    }

    /// <summary>
    /// 角色局部运行时快照。
    /// 它只服务能力 extra state 等局部恢复，不再夹带 PersistableDataBlock.info 这类持久化身份壳。
    /// </summary>
    [Serializable]
    public class CharacterRuntimeStateData
    {
        /// <summary>
        /// 运行时对象稳定标识，用于恢复局部状态时匹配同一角色。
        /// </summary>
        public string identifier;
        /// <summary>
        /// Persistable 状态，决定恢复后对象是否处于正常、禁用或销毁语义。
        /// </summary>
        public EPersistableObjectState state;
        /// <summary>
        /// 运行时位置快照。
        /// </summary>
        public Vector3 position;
        /// <summary>
        /// 运行时旋转快照。
        /// </summary>
        public Quaternion rotation;
        /// <summary>
        /// 运行时缩放快照。
        /// </summary>
        public Vector3 scale;
        /// <summary>
        /// 当前目标朝向，用于恢复技能和表现层朝向。
        /// </summary>
        public Vector2 lookAtDirection;
        /// <summary>
        /// 当前控制器自己的存档块。
        /// </summary>
        [SerializeReference, SubclassSelector] public IControllerDataBlock controllerData;
        /// <summary>
        /// 角色等级快照。
        /// </summary>
        public int level;
        /// <summary>
        /// 当前资源状态。
        /// </summary>
        [SerializeReference, SubclassSelector] public CharacterResourceStateData currentResources;
        /// <summary>
        /// 当前激活的变身/感染规则引用。
        /// </summary>
        public DatabaseEntryReference<CharacterAlterationRule>[] activeAlterationRules;
        /// <summary>
        /// 正式能力实例运行时状态。
        /// </summary>
        public CharacterAbilityRuntimeStateData[] abilityRuntimeStates;
        /// <summary>
        /// 来源化临时授予能力记录。
        /// </summary>
        public CharacterAbilitySourceData[] abilitySources;
        /// <summary>
        /// 来源化能力压制记录。
        /// </summary>
        public CharacterAbilitySourceData[] abilitySuppressions;
        /// <summary>
        /// 正式持续效果运行时状态。
        /// </summary>
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
        /// <summary>
        /// 正式 EX-GAS ability code。
        /// </summary>
        public int formalGasAbilityCode;
        /// <summary>
        /// 能力实例自己的 Persistable 状态。
        /// </summary>
        public EPersistableObjectState state;
        /// <summary>
        /// 剩余冷却时间。
        /// </summary>
        public float remainingCooldownTimer;
        /// <summary>
        /// 输入门运行时状态。
        /// </summary>
        public FormalAbilityInputGateData inputGate;
        /// <summary>
        /// 能力实现自定义的额外运行时状态。
        /// </summary>
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
        /// <summary>
        /// 持续效果类型的程序集限定名。读档时用它重建 live effect 实例。
        /// </summary>
        public string effectTypeName;
        /// <summary>
        /// 持续效果自己的持久化运行时状态。
        /// </summary>
        [SerializeReference, SubclassSelector] public TemporalEffectPersistedState runtimeState;

        /// <summary>
        /// 从效果类型和持久化状态创建持续效果恢复快照。
        /// effectType 为空时返回 null，调用方应跳过该条无效状态。
        /// </summary>
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

        /// <summary>
        /// 从 live effect 创建持续效果恢复快照。
        /// 这里只记录类型和持久化状态，不保存 live effect 引用本身。
        /// </summary>
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

        /// <summary>
        /// 根据保存的类型名创建 live effect 实例。
        /// 类型缺失或不实现 ITemporalEffect 时返回 false，避免读档生成不完整效果。
        /// </summary>
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

        /// <summary>
        /// 把持久化状态灌回 live effect。
        /// 只有实现 ITemporalEffectRuntimeStateCarrier 的效果才能恢复正式运行时状态。
        /// </summary>
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

            if (runtimeStateCarrier.TryRestorePersistedState(runtimeState))
            {
                return true;
            }

            Debug.LogWarning(
                $"Temporal effect type [{effect.GetType().AssemblyQualifiedName}] rejected persisted runtime state [{runtimeState.GetType().AssemblyQualifiedName}] during load.");
            return false;
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

        /// <summary>
        /// 正式 EX-GAS ability code。
        /// </summary>
        public int FormalGasAbilityCode { get; }
        /// <summary>
        /// 当前快照是否指向有效正式能力。
        /// </summary>
        public bool HasFormalGasAbility => FormalGasAbilityCode > 0;
        /// <summary>
        /// 剩余冷却时间。
        /// </summary>
        public float RemainingCooldown { get; }
        /// <summary>
        /// 总冷却时间。
        /// </summary>
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

        /// <summary>
        /// 持续效果运行时 key，用于 UI 点击或刷新时对应回 live effect。
        /// </summary>
        public int RuntimeKey { get; }
        /// <summary>
        /// 是否携带可展示信息。
        /// </summary>
        public bool HasPresentation { get; }
        /// <summary>
        /// 效果类型，用于 UI 分类和排序。
        /// </summary>
        public EEffectType EffectType { get; }
        /// <summary>
        /// 图标、名称等基础展示信息。
        /// </summary>
        public EffectPresentationInfo Info { get; }
        /// <summary>
        /// 运行时详情文本。
        /// </summary>
        public string Details { get; }
    }
}
