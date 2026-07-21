using System;
using System.Threading;
using Sirenix.OdinInspector;
using Unity.Mathematics;
using UnityEngine;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 同类持续效果首次叠加时的处理方式。
    /// stackableEffectId 相同才会进入这些策略。
    /// </summary>
    public enum EInitialStackBehavior
    {
        None,
        RefreshDuration,
        AddDuration,
        Interrupt
    }

    /// <summary>
    /// 持续效果基类。
    /// 它统一持续时间、叠加、运行时 key、展示投影和最小存档共享字段。
    /// </summary>
    [Serializable]
    public abstract class ATemporalEffect : AEffect, ITemporalEffect
    {
        /// <summary>
        /// 持续效果共享配置和运行时计时数据。
        /// runtimeKey 用来成对移除角色上的临时规则。
        /// </summary>
        [Serializable]
        protected struct TemporalData
        {
            [HideInInspector] public int runtimeKey;
            [InfinityFloat]
            [LabelText("持续时间"), Tooltip("持续效果的基础时长，支持 InfinityFloat 表示无限持续。")]
            public float duration;

            [LabelText("可叠加效果 ID")]
            [Tooltip("非空时，同 ID 的持续效果会按叠加策略处理；留空表示每个实例独立存在。")]
            public string stackableEffectId;

            [LabelText("初次叠加策略")]
            [Tooltip("同 ID 效果再次进入时如何处理旧实例的剩余时间或生命周期。")]
            public EInitialStackBehavior stackBehavior;
            [HideInInspector] public float remainingDuration;
        }

        [SerializeField]
        [LabelText("持续效果数据"), Tooltip("持续时间、叠加 ID、叠加策略和运行时 key 的共享数据。")]
        protected TemporalData m_temporalData;
        private static int s_nextRuntimeKey = 0;

        public virtual bool completed => m_temporalData.remainingDuration <= 0.0f;
        public int runtimeKey => m_temporalData.runtimeKey;
        public string stackableEffectId => m_temporalData.stackableEffectId;
        public float duration => m_temporalData.duration;
        public float remainingDuration => m_temporalData.remainingDuration;

        protected override void OnInit() { }
        protected virtual void OnUpdate() { }
        protected virtual void OnCompleted() { }
        protected virtual void OnRuntimeStateRestored() { }
        protected virtual void OnStacked(ITemporalEffect effect) { }
        public abstract ITemporalEffect Clone();
        protected abstract TemporalEffectPresentationState BuildPresentationState();
        /// <summary>
        /// 返回展示分类。派生类不提供分类时，Cleanse 和效果栏只会拿到默认无分类结果。
        /// </summary>
        protected virtual bool TryResolvePresentationEffectType(out EEffectType effectType)
        {
            effectType = default;
            return false;
        }

        /// <summary>
        /// 应用持续效果并登记到目标角色。
        /// runtimeKey 在首次应用时生成；如果派生类应用失败，会回滚这次临时生成的 key。
        /// </summary>
        public override bool Apply(CharacterBase target, EffectImpactSettings? impactSettings = null)
        {
            int previousRuntimeKey = m_temporalData.runtimeKey;
            bool generatedRuntimeKeyForThisApply = previousRuntimeKey <= 0;
            if (generatedRuntimeKeyForThisApply)
            {
                m_temporalData.runtimeKey = CreateNextRuntimeKey();
            }

            if (base.Apply(target, impactSettings))
            {
                m_temporalData.remainingDuration = m_temporalData.duration > 0.0f ? m_temporalData.duration : float.PositiveInfinity;
                targetCharacter?.AddTemporalEffect(this);
                return true;
            }

            if (generatedRuntimeKeyForThisApply)
            {
                m_temporalData.runtimeKey = previousRuntimeKey;
            }

            return false;
        }

        /// <summary>
        /// 完成持续效果。
        /// 先调用 OnCompleted 让派生类撤销动作锁、速度规则或能力来源，再执行统一清理。
        /// </summary>
        public void Complete()
        {
            OnCompleted();
            Deinit();
        }

        /// <summary>
        /// 持续效果从存档恢复时，不会重新走一遍 Apply。
        /// 这里专门给需要重建动作锁、速度修饰等运行时句柄的效果一个正式恢复入口。
        /// </summary>
        public void RestoreRuntimeState(CharacterBase owner)
        {
            BindRuntimeTarget(owner);
            OnRuntimeStateRestored();
        }

        public void BindRuntimeOwner(CharacterBase owner)
        {
            BindRuntimeTarget(owner);
        }

        /// <summary>
        /// 尝试把同 ID 的新效果叠加到当前实例。
        /// 只处理持续时间/生命周期策略，具体叠层副作用留给 OnStacked。
        /// </summary>
        public virtual bool TryStack(ITemporalEffect effect)
        {
            if (!string.IsNullOrWhiteSpace(effect.stackableEffectId) && !string.IsNullOrWhiteSpace(m_temporalData.stackableEffectId))
            {
                if (effect.stackableEffectId == m_temporalData.stackableEffectId)
                {
                    switch (m_temporalData.stackBehavior)
                    {
                        case EInitialStackBehavior.RefreshDuration:
                            m_temporalData.remainingDuration = math.max(m_temporalData.remainingDuration, effect.duration);
                            break;
                        case EInitialStackBehavior.AddDuration:
                            m_temporalData.remainingDuration += effect.duration;
                            break;
                        case EInitialStackBehavior.Interrupt:
                            m_temporalData.remainingDuration = 0.0f;
                            break;
                    }

                    OnStacked(effect);
                    return true;
                }
            }

            return false;
        }

        public void Update()
        {
            Update(Time.deltaTime);
        }

        /// <summary>
        /// 推进持续效果一帧。
        /// deltaTime 会被裁剪为非负数，避免外部错误时间输入反向延长效果。
        /// </summary>
        public void Update(float deltaTime)
        {
            Debug.Assert(m_effectData.initialized, "Effect must be initialized before updating.");
            AdvanceRuntimeLifetime(Mathf.Max(0.0f, deltaTime));
            OnUpdate();
        }

        public override EffectDescription GenerateDescription()
        {
            if (TryGetPresentationState(out TemporalEffectPresentationState presentationState))
            {
                return CreatePresentationDescription(
                    m_temporalData.duration,
                    presentationState.info,
                    presentationState.details);
            }

            return base.GenerateDescription();
        }

        protected TemporalEffectPresentationState CreatePresentationState(
            string details)
        {
            return CreatePresentationStateCore(EffectPresentationInfo.Empty, details);
        }

        protected TemporalEffectPresentationState CreatePresentationState(
            TermDefinition presentationTermDefinition,
            string details)
        {
            return CreatePresentationStateCore(
                CreateEffectPresentationInfo(presentationTermDefinition),
                details);
        }

        protected TemporalEffectPresentationState CreatePresentationState(
            EffectPresentationInfo presentationInfo,
            string details)
        {
            return CreatePresentationStateCore(presentationInfo, details);
        }

        private static TemporalEffectPresentationState CreatePresentationStateCore(
            EffectPresentationInfo info,
            string details)
        {
            return new TemporalEffectPresentationState(info, details);
        }

        /// <summary>
        /// 持续效果展示描述的投影统一收在这里，
        /// 让能力描述和角色效果栏共用同一份名字/时长/细节拼装规则。
        /// </summary>
        internal static EffectDescription CreatePresentationDescription(
            float duration,
            EffectPresentationInfo presentationInfo,
            string details)
        {
            string displayName = !string.IsNullOrWhiteSpace(presentationInfo.ShortName)
                ? presentationInfo.ShortName
                : presentationInfo.FullName;

            return new EffectDescription
            {
                name = string.IsNullOrWhiteSpace(displayName)
                    ? $"{duration:0.#}s"
                    : $"{displayName} ({duration:0.#}s)",
                details = details ?? string.Empty
            };
        }

        protected static EffectPresentationInfo CreateEffectPresentationInfo(TermDefinition termDefinition)
        {
            return EffectPresentationInfo.FromTermDefinition(termDefinition);
        }

        public virtual TemporalEffectRuntimeTraits GetRuntimeTraits()
        {
            return TemporalEffectRuntimeTraits.NeedsLocalLifetimeAdvance |
                TemporalEffectRuntimeTraits.NeedsTickCallbacks;
        }

        public void AdvanceRuntimeLifetime(float deltaTime)
        {
            if (float.IsPositiveInfinity(m_temporalData.remainingDuration))
            {
                return;
            }

            m_temporalData.remainingDuration = math.max(0.0f, m_temporalData.remainingDuration - deltaTime);
        }

        internal TemporalEffectSharedPersistedFields CreateSharedPersistedFields()
        {
            return new TemporalEffectSharedPersistedFields(
                m_effectData.source,
                m_effectData.visualFlags,
                m_effectData.velocity,
                m_effectData.damageImpact,
                m_temporalData.runtimeKey,
                m_temporalData.duration,
                m_temporalData.stackableEffectId,
                m_temporalData.stackBehavior,
                m_temporalData.remainingDuration);
        }

        /// <summary>
        /// 从正式最小共享快照恢复 live effect 字段，
        /// 随后仍会继续走 RestoreRuntimeState(owner) 重建动作锁、速度修饰等运行时句柄。
        /// </summary>
        internal void RestoreSharedPersistedFields(TemporalEffectSharedPersistedFields fields)
        {
            m_effectData.source = fields.Source;
            m_effectData.target = null;
            m_effectData.visualFlags = fields.VisualFlags;
            m_effectData.velocity = fields.Velocity;
            m_effectData.damageImpact = fields.DamageImpact;
            m_effectData.initialized = true;
            m_temporalData.runtimeKey = fields.RuntimeKey > 0 ? fields.RuntimeKey : CreateNextRuntimeKey();
            m_temporalData.duration = fields.Duration;
            m_temporalData.stackableEffectId = fields.StackableEffectId;
            m_temporalData.stackBehavior = fields.StackBehavior;
            m_temporalData.remainingDuration = fields.RemainingDuration;
        }

        protected void CopySharedTemporalStateTo(ATemporalEffect target)
        {
            if (target == null)
            {
                return;
            }

            target.m_effectData = m_effectData;
            target.m_temporalData = m_temporalData;
        }

        /// <summary>
        /// 状态效果派生的能力来源不再直接把 live effect 对象当真相。
        /// 这里统一把 effect 类型名 + runtimeKey 收成稳定来源键，供能力账本消费。
        /// </summary>
        protected bool TryCreateStatusEffectAbilitySource(out CharacterAbilitySourceKey source)
        {
            return TryCreateStatusEffectAbilitySource(GetType().FullName, runtimeKey, out source);
        }

        internal static bool TryCreateStatusEffectAbilitySource(
            string effectTypeName,
            int runtimeKey,
            out CharacterAbilitySourceKey source)
        {
            source = default;
            if (runtimeKey <= 0)
            {
                return false;
            }

            string normalizedEffectTypeName = NormalizeStatusEffectAbilitySourceTypeName(effectTypeName);
            if (string.IsNullOrWhiteSpace(normalizedEffectTypeName))
            {
                return false;
            }

            source = new CharacterAbilitySourceKey(
                ECharacterAbilitySourceKind.StatusEffect,
                $"{normalizedEffectTypeName}:{runtimeKey}");
            return true;
        }

        private static string NormalizeStatusEffectAbilitySourceTypeName(string effectTypeName)
        {
            if (string.IsNullOrWhiteSpace(effectTypeName))
            {
                return string.Empty;
            }

            Type effectType = Type.GetType(effectTypeName);
            if (!string.IsNullOrWhiteSpace(effectType?.FullName))
            {
                return effectType.FullName;
            }

            int separatorIndex = effectTypeName.IndexOf(',');
            return separatorIndex >= 0
                ? effectTypeName[..separatorIndex].Trim()
                : effectTypeName.Trim();
        }

        /// <summary>
        /// 持续效果当前的最小分类口。
        /// `Cleanse` 之类只需要 Buff/Debuff 分类的语义，不再为了一个分类去触发整份展示 details 拼装。
        /// </summary>
        internal bool TryGetPresentationEffectType(out EEffectType effectType)
        {
            effectType = default;
            return TryResolvePresentationEffectType(out effectType);
        }

        /// <summary>
        /// 展示语义现在只允许按当前 effect 字段即时生成一份共享合同。
        /// 展示快照与净化筛选都在消费方完成，effect 自己不再额外投影第二层回答口。
        /// </summary>
        internal bool TryGetPresentationState(out TemporalEffectPresentationState presentationState)
        {
            presentationState = BuildPresentationState();
            return true;
        }

        private static int CreateNextRuntimeKey()
        {
            return Interlocked.Increment(ref s_nextRuntimeKey);
        }

    }
}
