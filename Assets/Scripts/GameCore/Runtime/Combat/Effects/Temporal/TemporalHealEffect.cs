using System;
using Sirenix.OdinInspector;
using Unity.Mathematics;
using UnityEngine;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 持续治疗效果的存档快照，记录治疗数值、tick 间隔和当前计时器。
    /// </summary>
    [Serializable]
    public class TemporalHealEffectPersistedState : TemporalEffectPersistedState
    {
        /// <summary>
        /// 每次 tick 恢复的生命值。
        /// </summary>
        public int amount;

        /// <summary>
        /// 两次治疗 tick 之间的间隔秒数。
        /// </summary>
        public float interval;

        /// <summary>
        /// 是否在效果首次生效后等待一个完整间隔再治疗。
        /// </summary>
        public bool delayFirstTick;

        /// <summary>
        /// 当前距离下一次治疗 tick 的剩余秒数。
        /// </summary>
        public float timer;
    }

    /// <summary>
    /// 按固定间隔恢复目标生命值的持续效果，读档时会保留当前 tick 计时进度。
    /// </summary>
    [Serializable]
    public class TemporalHealEffect : ATemporalEffect, ITemporalEffectRuntimeStateCarrier
    {
        /// <summary>
        /// 持续治疗的设计时和运行时数据；timer 是运行期状态，不应由策划直接编辑。
        /// </summary>
        [Serializable]
        internal struct HealData
        {
            [LabelText("治疗量")]
            [Tooltip("每次治疗 tick 恢复的生命值。")]
            public int amount;

            [LabelText("触发间隔")]
            [Tooltip("两次治疗 tick 之间的秒数；为 0 时会每帧触发，通常不应这样配置。")]
            public float interval;

            [LabelText("延迟首次触发")]
            [Tooltip("开启后，效果生效时不会立刻治疗，而是等待一个完整触发间隔。")]
            public bool delayFirstTick;

            /// <summary>
            /// 距离下一次治疗 tick 的剩余秒数，由持续效果运行时维护。
            /// </summary>
            [HideInInspector] public float timer;
        }

        [LabelText("持续治疗配置")]
        [Tooltip("配置持续恢复生命值的数值、触发间隔和首次触发策略。")]
        [SerializeField] private HealData m_healData;

        protected override void OnInit()
        {
            m_healData.timer =
                m_healData.delayFirstTick ?
                m_healData.interval :
                0.0f;
        }

        protected override void OnUpdate()
        {
            m_healData.timer = math.max(0.0f, m_healData.timer - Time.deltaTime);

            if (m_healData.timer <= 0.0f)
            {
                m_healData.timer = m_healData.interval;
                targetCharacter?.Heal(m_healData.amount, visualFlags);
            }
        }

        public override ITemporalEffect Clone()
        {
            TemporalHealEffect clone = new()
            {
                m_healData = m_healData
            };

            CopySharedTemporalStateTo(clone);
            return clone;
        }

        protected override TemporalEffectPresentationState BuildPresentationState()
        {
            return CreatePresentationState(
                GameManager.Config.GetTermDefinition("add_health_over_time"),
                GetHealDetails());
        }

        protected override bool TryResolvePresentationEffectType(out EEffectType effectType)
        {
            effectType = EEffectType.Buff;
            return true;
        }

        private string GetHealDetails()
        {
            return $"{m_healData.amount} {GameManager.Config.GetTermDefinition(EStat.Health).shortName}/{m_healData.interval:0.#}s";
        }

        public bool TryCapturePersistedState(out TemporalEffectPersistedState persistedState)
        {
            TemporalHealEffectPersistedState state = new()
            {
                amount = m_healData.amount,
                interval = m_healData.interval,
                delayFirstTick = m_healData.delayFirstTick,
                timer = m_healData.timer
            };

            state.CaptureSharedStateFrom(this);
            persistedState = state;
            return true;
        }

        public bool TryRestorePersistedState(TemporalEffectPersistedState persistedState)
        {
            if (persistedState is not TemporalHealEffectPersistedState state)
            {
                return false;
            }

            state.RestoreSharedStateTo(this);
            m_healData.amount = state.amount;
            m_healData.interval = state.interval;
            m_healData.delayFirstTick = state.delayFirstTick;
            m_healData.timer = state.timer;
            return true;
        }
    }
}

