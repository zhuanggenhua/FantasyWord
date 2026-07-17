using System;
using Unity.Mathematics;
using UnityEngine;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 持续伤害效果的存档快照，包含原始伤害配置、 tick 计时器和已结算的伤害输出。
    /// </summary>
    [Serializable]
    public class TemporalDamageEffectPersistedState : TemporalEffectPersistedState
    {
        /// <summary>
        /// 原始伤害配置，用于读档后保留伤害类型、固定值和缩放系数。
        /// </summary>
        public DamageDescriptor damage;

        /// <summary>
        /// 两次伤害 tick 之间的间隔秒数。
        /// </summary>
        public float interval;

        /// <summary>
        /// 是否在效果首次生效后等待一个完整间隔再造成第一次伤害。
        /// </summary>
        public bool delayFirstTick;

        /// <summary>
        /// 当前剩余到下一次 tick 的计时器。
        /// </summary>
        public float timer;

        /// <summary>
        /// 初始化时根据来源角色结算出的最终伤害输出，读档后沿用同一份快照。
        /// </summary>
        public DamageOutputDescriptor damageOutput;
    }

    /// <summary>
    /// 按固定间隔对目标造成持续伤害，伤害输出在初始化时结算，后续 tick 复用同一结果。
    /// </summary>
    [Serializable]
    public class TemporalDamageEffect : ATemporalEffect, ITemporalEffectRuntimeStateCarrier
    {
        /// <summary>
        /// 持续伤害的设计时和运行时数据；timer 与 damageOutput 只由运行时维护。
        /// </summary>
        [Serializable]
        protected struct DamageData
        {
            [InspectorName("伤害配置")]
            [Tooltip("持续伤害每次 tick 使用的基础伤害描述，包含伤害类型、固定伤害和缩放系数。")]
            public DamageDescriptor damage;

            [InspectorName("触发间隔")]
            [Tooltip("两次伤害 tick 之间的秒数；为 0 时会每帧触发，通常不应这样配置。")]
            public float interval;

            [InspectorName("延迟首次触发")]
            [Tooltip("开启后，效果生效时不会立刻造成伤害，而是等待一个完整触发间隔。")]
            public bool delayFirstTick;

            /// <summary>
            /// 距离下一次伤害 tick 的剩余秒数，由持续效果运行时递减。
            /// </summary>
            [HideInInspector] public float timer;

            /// <summary>
            /// 根据来源角色属性预先结算出的伤害结果，避免每次 tick 重复结算来源状态。
            /// </summary>
            [HideInInspector] public DamageOutputDescriptor damageOutput;
        }

        [InspectorName("持续伤害配置")]
        [Tooltip("配置持续伤害的数值、触发间隔和首次触发策略。")]
        [SerializeField] private DamageData m_damageData;

        protected override void OnInit()
        {
            m_damageData.damageOutput = DamageSolver.SolveDamageOutput(sourceCharacter, m_damageData.damage);
        }

        protected override void OnDeinit()
        {
            m_damageData.damageOutput = default;
        }

        protected override bool OnApply()
        {
            m_damageData.timer =
                m_damageData.delayFirstTick ?
                m_damageData.interval :
                0.0f;

            return true;
        }

        protected override void OnUpdate()
        {
            m_damageData.timer = math.max(0.0f, m_damageData.timer - Time.deltaTime);

            if (m_damageData.timer <= 0.0f)
            {
                m_damageData.timer = m_damageData.interval;
                targetCharacter?.Damage(m_damageData.damageOutput, visualFlags, m_effectData.velocity, m_effectData.damageImpact);
            }
        }

        public override ITemporalEffect Clone()
        {
            TemporalDamageEffect clone = new()
            {
                m_damageData = m_damageData
            };

            CopySharedTemporalStateTo(clone);
            return clone;
        }

        protected override TemporalEffectPresentationState BuildPresentationState()
        {
            return CreatePresentationState(
                GameManager.Config.GetTermDefinition("damage_over_time"),
                GetDamageDetails());
        }

        protected override bool TryResolvePresentationEffectType(out EEffectType effectType)
        {
            effectType = EEffectType.Debuff;
            return true;
        }

        private string GetDamageDetails()
        {
            string flatDamage = m_damageData.damage.flatDamages != 0.0f
                ? $"{m_damageData.damage.flatDamages:0.#} {GameManager.Config.GetTermDefinition("flat_damage").shortName}"
                : string.Empty;
            string scaledDamage = m_damageData.damage.scalingFactor != 0.0f
                ? $"{m_damageData.damage.scalingFactor:0.#} {GameManager.Config.GetTermDefinition("scaled_damage").shortName}"
                : string.Empty;
            string separator = string.IsNullOrEmpty(flatDamage) || string.IsNullOrEmpty(scaledDamage)
                ? string.Empty
                : "+";
            return $"{flatDamage}{separator}{scaledDamage} {GameManager.Config.GetTermDefinition(m_damageData.damage.damageType).shortName}/{m_damageData.interval:0.#}s";
        }

        public bool TryCapturePersistedState(out TemporalEffectPersistedState persistedState)
        {
            TemporalDamageEffectPersistedState state = new()
            {
                damage = m_damageData.damage,
                interval = m_damageData.interval,
                delayFirstTick = m_damageData.delayFirstTick,
                timer = m_damageData.timer,
                damageOutput = m_damageData.damageOutput
            };

            state.CaptureSharedStateFrom(this);
            persistedState = state;
            return true;
        }

        public bool TryRestorePersistedState(TemporalEffectPersistedState persistedState)
        {
            if (persistedState is not TemporalDamageEffectPersistedState state)
            {
                return false;
            }

            state.RestoreSharedStateTo(this);
            m_damageData.damage = state.damage;
            m_damageData.interval = state.interval;
            m_damageData.delayFirstTick = state.delayFirstTick;
            m_damageData.timer = state.timer;
            m_damageData.damageOutput = state.damageOutput;
            return true;
        }

    }
}

