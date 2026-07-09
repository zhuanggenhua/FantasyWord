using System;
using Unity.Mathematics;
using UnityEngine;

namespace FantasyWord.GameCore
{
    [Serializable]
    public class TemporalHealEffectPersistedState : TemporalEffectPersistedState
    {
        public int amount;
        public float interval;
        public bool delayFirstTick;
        public float timer;
    }

    [Serializable]
    public class TemporalHealEffect : ATemporalEffect, ITemporalEffectRuntimeStateCarrier
    {
        [Serializable]
        internal struct HealData
        {
            public int amount;
            public float interval;
            public bool delayFirstTick;
            [HideInInspector] public float timer;
        }

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

        public void RestorePersistedState(TemporalEffectPersistedState persistedState)
        {
            if (persistedState is not TemporalHealEffectPersistedState state)
            {
                return;
            }

            state.RestoreSharedStateTo(this);
            m_healData.amount = state.amount;
            m_healData.interval = state.interval;
            m_healData.delayFirstTick = state.delayFirstTick;
            m_healData.timer = state.timer;
        }
    }
}

