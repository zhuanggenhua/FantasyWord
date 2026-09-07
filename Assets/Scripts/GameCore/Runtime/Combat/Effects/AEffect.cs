using System;
using Sirenix.OdinInspector;
using UnityEngine;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 效果允许作用的目标分组。
    /// 目标筛选先看 CombatSolver 的基础可命中规则，再叠加这些分组限制。
    /// </summary>
    [Flags]
    public enum EEffectTargetFlags
    {
        [HideInInspector] None = 0,
        Self = 1 << 0,
        Allies = 1 << 1,
        Enemies = 1 << 2,
        Anything = 1 << 3,
        [HideInInspector] All = ~None
    }

    /// <summary>
    /// 效果表现禁用标记。
    /// 用于在结算仍发生时屏蔽飘字、震屏或闪屏等表现。
    /// </summary>
    [Flags]
    public enum EEffectVisualFlags
    {
        [HideInInspector] None,
        NoFloatingText = 1 << 0,
        NoCameraShake = 1 << 1,
        NoScreenFlash = 1 << 2,
        [HideInInspector] All = ~None
    }


    /// <summary>
    /// 战斗效果基类。
    /// 它统一目标筛选、失败率、来源/目标引用和命中冲击数据，具体效果只实现 OnApply。
    /// </summary>
    [Serializable]
    public abstract class AEffect : IEffect
    {
        /// <summary>
        /// 效果运行时和存档所需的最小数据。
        /// source/target 是持久引用；运行时直接引用只作为当前帧加速入口。
        /// </summary>
        [Serializable]
        protected struct EffectData
        {
            [LabelText("目标分组")]
            [Tooltip("限制效果可以作用的目标关系；最终仍会经过 CombatSolver 的死亡和无敌判断。")]
            public EEffectTargetFlags targetFlags;

            [LabelText("打断策略")]
            [Tooltip("效果命中后对目标当前行动的打断语义，由角色行动状态系统消费。")]
            public EEffectInterruptionPolicy interruptionPolicy;

            [LabelText("表现屏蔽")]
            [Tooltip("只屏蔽飘字、震屏、闪屏等表现，不改变战斗结算本身。")]
            public EEffectVisualFlags visualFlags;

            [Range(0.0f, 1.0f)]
            [LabelText("失败概率")]
            [Tooltip("效果应用前的随机失败率；失败会让本次效果不生效，取值 0-1。")]
            public float failureRate;

            [HideInInspector] public bool initialized;
            [HideInInspector] public PersistableReference<CharacterBase> source;
            [HideInInspector] public PersistableReference<CharacterBase> target;
            [HideInInspector] public Vector2 velocity;
            [HideInInspector] public DamageImpactSettings damageImpact;
        }

        public bool initialized => m_effectData.initialized;
        public EEffectInterruptionPolicy interruptionPolicy => m_effectData.interruptionPolicy;
        public EEffectVisualFlags visualFlags => m_effectData.visualFlags;
        protected CharacterBase sourceCharacter => m_runtimeSourceCharacter != null ? m_runtimeSourceCharacter : m_effectData.source.ResolveOrNull();
        protected CharacterBase targetCharacter => m_runtimeTargetCharacter != null ? m_runtimeTargetCharacter : m_effectData.target.ResolveOrNull();

        [SerializeField]
        [LabelText("效果基础数据"), Tooltip("目标筛选、表现屏蔽、失败率和运行时来源/目标引用的共享数据。")]
        protected EffectData m_effectData;
        private CharacterBase m_runtimeSourceCharacter = null;
        private CharacterBase m_runtimeTargetCharacter = null;

        /// <summary>
        /// 根据作者配置的目标分组判断目标关系。
        /// 这里只处理阵营/自身这类业务分组，死亡和无敌状态由外层 CanTarget 统一判断。
        /// </summary>
        private bool IsTargetValidBasedOnFlags(CharacterBase target)
        {
            return
                m_effectData.targetFlags.HasFlag(EEffectTargetFlags.Anything) ||
                m_effectData.targetFlags.HasFlag(EEffectTargetFlags.Self) && target == sourceCharacter ||
                m_effectData.targetFlags.HasFlag(EEffectTargetFlags.Allies) && CombatSolver.AreAllies(sourceCharacter, target) ||
                m_effectData.targetFlags.HasFlag(EEffectTargetFlags.Enemies) && CombatSolver.AreEnemies(sourceCharacter, target);
        }

        /// <summary>
        /// 执行效果自身的随机失败判定。
        /// 这属于配置层手感，不应该被调用方吞掉后当作命中成功。
        /// </summary>
        private bool EvaluateFailure()
        {
            return UnityEngine.Random.value < m_effectData.failureRate;
        }

        /// <summary>
        /// 判断效果是否能应用到目标。
        /// 先验证目标存在和 CombatSolver 基础可命中，再套目标分组和随机失败率。
        /// </summary>
        public virtual bool IsApplicable(CharacterBase target) =>
            target != null &&
            CombatSolver.CanTarget(sourceCharacter, target) &&
            IsTargetValidBasedOnFlags(target) &&
            !EvaluateFailure();

        public virtual EffectDescription GenerateDescription() => new()
        {
            name = GetType().Name,
            details = string.Empty
        };

        protected virtual void OnInit() { }
        protected virtual bool OnApply() => true;
        protected virtual void OnDeinit() { }

        /// <summary>
        /// 绑定本次运行目标，同时写入可持久化引用。
        /// 持续效果读档恢复时会重新绑定 owner，因此运行时引用不能当长期真相。
        /// </summary>
        protected void BindRuntimeTarget(CharacterBase target)
        {
            m_runtimeTargetCharacter = target;
            m_effectData.target = target;
        }

        /// <summary>
        /// 初始化效果来源。
        /// 每个 live effect 实例只能初始化一次，重复初始化会暴露生命周期错误。
        /// </summary>
        public void Init(CharacterBase source)
        {
            if (initialized)
            {
                Debug.LogError($"Effect is already initialized");
            }

            Debug.Assert(!initialized, $"Effect is already initialized");
            m_runtimeSourceCharacter = source;
            m_effectData.source = source;
            OnInit();
            m_effectData.initialized = true;
        }

        /// <summary>
        /// 把命中参数中的冲击数据解析成目标实际接受的速度向量。
        /// SourcePosition 传入的是世界坐标，运行时转换成从来源点指向目标的方向。
        /// </summary>
        private Vector2 ExtractVelocityFromImpactSettings(EffectImpactSettings impactSettings)
        {
            return impactSettings.impactDataType switch
            {
                EEffectImpactDataType.Velocity => impactSettings.impactData,
                EEffectImpactDataType.SourcePosition => targetCharacter != null ? (Vector2)targetCharacter.transform.position - impactSettings.impactData : Vector2.zero,
                _ => Vector2.zero
            };
        }

        /// <summary>
        /// 应用效果到目标。
        /// 这里负责绑定目标、解析冲击方向和保存打击参数，具体规则由派生类 OnApply 实现。
        /// </summary>
        public virtual bool Apply(CharacterBase target, EffectImpactSettings? impactSettings = null)
        {
            BindRuntimeTarget(target);

            m_effectData.velocity = impactSettings.HasValue ?
                ExtractVelocityFromImpactSettings(impactSettings.Value) :
                (sourceCharacter != null && targetCharacter != null ? (Vector2)targetCharacter.transform.position - (Vector2)sourceCharacter.transform.position : Vector2.zero);
            m_effectData.damageImpact = impactSettings?.damageImpact ?? default;

            return OnApply();
        }

        public void Deinit()
        {
            OnDeinit();
            Cleanup();
        }

        protected void Cleanup()
        {
            Debug.Assert(initialized, $"Effect isn't initialized");
            m_effectData.source = null;
            m_effectData.target = null;
            m_runtimeSourceCharacter = null;
            m_runtimeTargetCharacter = null;
            m_effectData.velocity = Vector2.zero;
            m_effectData.damageImpact = default;
            m_effectData.initialized = false;
        }
    }
}

