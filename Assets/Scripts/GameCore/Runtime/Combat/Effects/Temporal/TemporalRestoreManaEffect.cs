using System;
using Unity.Mathematics;
using UnityEngine;

namespace FantasyWord.GameCore
{
    [Serializable]
    public class TemporalRestoreManaEffectPersistedState : TemporalEffectPersistedState
    {
        public int amount;
        public float interval;
        public bool delayFirstTick;
        public float timer;
    }

    [Serializable]
    public class TemporalRestoreManaEffect : ATemporalEffect, ITemporalEffectRuntimeStateCarrier
    {
        [Serializable]
        protected struct RestoreManaData
        {
            public int amount;
            public float interval;
            public bool delayFirstTick;
            [HideInInspector] public float timer;
        }

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

        public void RestorePersistedState(TemporalEffectPersistedState persistedState)
        {
            if (persistedState is not TemporalRestoreManaEffectPersistedState state)
            {
                return;
            }

            state.RestoreSharedStateTo(this);
            m_restoreManaData.amount = state.amount;
            m_restoreManaData.interval = state.interval;
            m_restoreManaData.delayFirstTick = state.delayFirstTick;
            m_restoreManaData.timer = state.timer;
        }
    }
}

