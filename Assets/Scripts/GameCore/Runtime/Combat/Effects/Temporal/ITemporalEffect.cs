using System;
using UnityEngine;

namespace FantasyWord.GameCore
{

    public enum EEffectType
    {
        Buff,
        Debuff
    }

    /// <summary>
    /// 持续效果运行时壳当前还剩哪些本地职责。
    /// 这不是第二套规则系统，只是明确 live effect 壳到底还要不要自己扣寿命、跑 tick 回调。
    /// </summary>
    [Flags]
    public enum TemporalEffectRuntimeTraits
    {
        None = 0,
        NeedsLocalLifetimeAdvance = 1 << 0,
        NeedsTickCallbacks = 1 << 1
    }

    /// <summary>
    /// 持续效果专用展示信息。
    /// 只保留名称和图标这类会被多处表现层复用的字段。
    /// 说明正文单独走 snapshot.details，避免名字/描述在多份合同里重复存放。
    /// </summary>
    public readonly struct EffectPresentationInfo
    {
        public EffectPresentationInfo(string fullName, string shortName, Sprite icon)
        {
            FullName = fullName ?? string.Empty;
            ShortName = shortName ?? string.Empty;
            Icon = icon;
        }

        public string FullName { get; }
        public string ShortName { get; }
        public Sprite Icon { get; }

        public static EffectPresentationInfo Empty => new(string.Empty, string.Empty, null);

        public static EffectPresentationInfo FromTermDefinition(TermDefinition definition)
        {
            return new EffectPresentationInfo(
                definition.fullName,
                definition.shortName,
                definition.icon);
        }
    }

    /// <summary>
    /// 持续效果当前允许保留的最小展示语义。
    /// 分类已经改走独立的 `TryGetPresentationEffectType(...)` 最小口，
    /// 这里不再把净化分类和展示数据继续绑成同一份共享对象。
    /// </summary>
    [Serializable]
    public readonly struct TemporalEffectPresentationState
    {
        public readonly EffectPresentationInfo info;
        public readonly string details;

        public TemporalEffectPresentationState(EffectPresentationInfo info, string details)
        {
            this.info = info;
            this.details = details ?? string.Empty;
        }
    }

    internal readonly struct TemporalEffectSharedPersistedFields
    {
        public TemporalEffectSharedPersistedFields(
            PersistableReference<CharacterBase> source,
            EEffectVisualFlags visualFlags,
            Vector2 velocity,
            DamageImpactSettings damageImpact,
            int runtimeKey,
            float duration,
            string stackableEffectId,
            EInitialStackBehavior stackBehavior,
            float remainingDuration)
        {
            Source = source;
            VisualFlags = visualFlags;
            Velocity = velocity;
            DamageImpact = damageImpact;
            RuntimeKey = runtimeKey;
            Duration = duration;
            StackableEffectId = stackableEffectId;
            StackBehavior = stackBehavior;
            RemainingDuration = remainingDuration;
        }

        public PersistableReference<CharacterBase> Source { get; }
        public EEffectVisualFlags VisualFlags { get; }
        public Vector2 Velocity { get; }
        public DamageImpactSettings DamageImpact { get; }
        public int RuntimeKey { get; }
        public float Duration { get; }
        public string StackableEffectId { get; }
        public EInitialStackBehavior StackBehavior { get; }
        public float RemainingDuration { get; }
    }

    /// <summary>
    /// 持续效果正式持久化状态基类。
    /// 这里只保留恢复 live effect 必需的最小共享状态，不再默认把整份旧效果对象直接写进角色存档。
    /// </summary>
    [Serializable]
    public abstract class TemporalEffectPersistedState
    {
        public PersistableReference<CharacterBase> source;
        public EEffectVisualFlags visualFlags;
        public Vector2 velocity;
        public DamageImpactSettings damageImpact;
        public int runtimeKey;
        public float duration;
        public string stackableEffectId;
        public EInitialStackBehavior stackBehavior;
        public float remainingDuration;

        internal void CaptureSharedStateFrom(ATemporalEffect effect)
        {
            if (effect == null)
            {
                return;
            }

            ApplySharedFields(effect.CreateSharedPersistedFields());
        }

        internal void RestoreSharedStateTo(ATemporalEffect effect)
        {
            if (effect == null)
            {
                return;
            }

            effect.RestoreSharedPersistedFields(CreateSharedPersistedFields());
        }

        private void ApplySharedFields(TemporalEffectSharedPersistedFields fields)
        {
            source = fields.Source;
            visualFlags = fields.VisualFlags;
            velocity = fields.Velocity;
            damageImpact = fields.DamageImpact;
            runtimeKey = fields.RuntimeKey;
            duration = fields.Duration;
            stackableEffectId = fields.StackableEffectId;
            stackBehavior = fields.StackBehavior;
            remainingDuration = fields.RemainingDuration;
        }

        private TemporalEffectSharedPersistedFields CreateSharedPersistedFields()
        {
            return new TemporalEffectSharedPersistedFields(
                source,
                visualFlags,
                velocity,
                damageImpact,
                runtimeKey,
                duration,
                stackableEffectId,
                stackBehavior,
                remainingDuration);
        }
    }

    /// <summary>
    /// 需要持久化最小 runtime 状态的持续效果，由效果自己声明并恢复这份状态。
    /// CharacterBase 只负责汇总和还原，不再保留每种效果的私有数据细节。
    /// </summary>
    public interface ITemporalEffectRuntimeStateCarrier
    {
        bool TryCapturePersistedState(out TemporalEffectPersistedState persistedState);

        void RestorePersistedState(TemporalEffectPersistedState persistedState);
    }

    public interface ITemporalEffect : IEffect
    {
        public bool completed { get; }
        public int runtimeKey { get; }
        public string stackableEffectId { get; }
        public float duration { get; }
        public float remainingDuration { get; }
        public void Update();
        public void Update(float deltaTime);
        public void Complete();
        public void BindRuntimeOwner(CharacterBase owner);
        public void RestoreRuntimeState(CharacterBase owner);
        public bool TryStack(ITemporalEffect effect);
        public ITemporalEffect Clone();

        /// <summary>
        /// 告诉角色容器：这个 live effect 壳现在还剩哪些本地推进职责。
        /// 目的是把 tick 壳、起止壳之类的差异写成代码合同，而不是继续靠容器猜。
        /// </summary>
        public TemporalEffectRuntimeTraits GetRuntimeTraits();

        /// <summary>
        /// 只推进 live effect 壳自己的寿命，不触发额外的 tick 回调。
        /// 用于那些仍要本地完成计时、但已经不该继续跑 OnUpdate 逻辑的效果。
        /// </summary>
        public void AdvanceRuntimeLifetime(float deltaTime);
    }
}
