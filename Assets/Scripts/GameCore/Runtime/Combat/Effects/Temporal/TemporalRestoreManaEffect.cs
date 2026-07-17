using System;
using Unity.Mathematics;
using UnityEngine;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 持续回蓝效果的存档快照，记录回蓝数值、tick 间隔和当前计时器。
    /// </summary>
    [Serializable]
    public class TemporalRestoreManaEffectPersistedState : TemporalEffectPersistedState
    {
        /// <summary>
        /// 每次 tick 恢复的法力值。
        /// </summary>
        public int amount;

        /// <summary>
        /// 两次回蓝 tick 之间的间隔秒数。
        /// </summary>
        public float interval;

        /// <summary>
        /// 是否在效果首次生效后等待一个完整间隔再回蓝。
        /// </summary>
        public bool delayFirstTick;

        /// <summary>
        /// 当前距离下一次回蓝 tick 的剩余秒数。
        /// </summary>
        public float timer;
    }

    /// <summary>
    /// 按固定间隔恢复目标法力值的持续效果，适合药水、光环或区域增益这类状态。
    /// </summary>
    [Serializable]
    public class TemporalRestoreManaEffect : ATemporalEffect, ITemporalEffectRuntimeStateCarrier
    {
        /// <summary>
        /// 持续回蓝的设计时和运行时数据；timer 是运行期状态，不应由策划直接编辑。
        /// </summary>
        [Serializable]
        protected struct RestoreManaData
        {
            [InspectorName("回蓝量")]
            [Tooltip("每次回蓝 tick 恢复的法力值。")]
            public int amount;

            [InspectorName("触发间隔")]
            [Tooltip("两次回蓝 tick 之间的秒数；为 0 时会每帧触发，通常不应这样配置。")]
            public float interval;

            [InspectorName("延迟首次触发")]
            [Tooltip("开启后，效果生效时不会立刻回蓝，而是等待一个完整触发间隔。")]
            public bool delayFirstTick;

            /// <summary>
            /// 距离下一次回蓝 tick 的剩余秒数，由持续效果运行时维护。
            /// </summary>
            [HideInInspector] public float timer;
        }

        [InspectorName("持续回蓝配置")]
        [Tooltip("配置持续恢复法力值的数值、触发间隔和首次触发策略。")]
        [SerializeField] protected RestoreManaData m_restoreManaData;

        protected override void OnInit()
        {
            m_restoreManaData.timer =
                m_restoreManaData.delayFirstTick ?
                m_restoreManaData.interval :
                0.0f;
        }

        protected override void OnUpdate()
        {
            m_restoreManaData.timer = math.max(0.0f, m_restoreManaData.timer - Time.deltaTime);

            if (m_restoreManaData.timer <= 0.0f)
            {
                m_restoreManaData.timer = m_restoreManaData.interval;
                targetCharacter?.RecoverMana(m_restoreManaData.amount, visualFlags);
            }
        }

        public override ITemporalEffect Clone()
        {
            TemporalRestoreManaEffect clone = new()
            {
                m_restoreManaData = m_restoreManaData
            };

            CopySharedTemporalStateTo(clone);
            return clone;
        }

        protected override TemporalEffectPresentationState BuildPresentationState()
        {
            return CreatePresentationState(
                GameManager.Config.GetTermDefinition("add_mana_over_time"),
                GetRestoreManaDetails());
        }

        protected override bool TryResolvePresentationEffectType(out EEffectType effectType)
        {
            effectType = EEffectType.Buff;
            return true;
        }

        private string GetRestoreManaDetails()
        {
            return $"{m_restoreManaData.amount} {GameManager.Config.GetTermDefinition(EStat.Mana).shortName}/{m_restoreManaData.interval:0.#}s";
        }

        public bool TryCapturePersistedState(out TemporalEffectPersistedState persistedState)
        {
            TemporalRestoreManaEffectPersistedState state = new()
            {
                amount = m_restoreManaData.amount,
                interval = m_restoreManaData.interval,
                delayFirstTick = m_restoreManaData.delayFirstTick,
                timer = m_restoreManaData.timer
            };

            state.CaptureSharedStateFrom(this);
            persistedState = state;
            return true;
        }

        public bool TryRestorePersistedState(TemporalEffectPersistedState persistedState)
        {
            if (persistedState is not TemporalRestoreManaEffectPersistedState state)
            {
                return false;
            }

            state.RestoreSharedStateTo(this);
            m_restoreManaData.amount = state.amount;
            m_restoreManaData.interval = state.interval;
            m_restoreManaData.delayFirstTick = state.delayFirstTick;
            m_restoreManaData.timer = state.timer;
            return true;
        }
    }
}

