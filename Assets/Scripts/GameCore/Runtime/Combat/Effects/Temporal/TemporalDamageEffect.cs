using System;
using Unity.Mathematics;
using UnityEngine;

namespace FantasyWord.GameCore
{
    [Serializable]
    public class TemporalDamageEffectPersistedState : TemporalEffectPersistedState
    {
        public DamageDescriptor damage;
        public float interval;
        public bool delayFirstTick;
        public float timer;
        public DamageOutputDescriptor damageOutput;
    }

    [Serializable]
    public class TemporalDamageEffect : ATemporalEffect, ITemporalEffectRuntimeStateCarrier
    {
        [Serializable]
        protected struct DamageData
        {
            public DamageDescriptor damage;
            public float interval;
            public bool delayFirstTick;
            [HideInInspector] public float timer;
            [HideInInspector] public DamageOutputDescriptor damageOutput;
        }

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

        public void RestorePersistedState(TemporalEffectPersistedState persistedState)
        {
            if (persistedState is not TemporalDamageEffectPersistedState state)
            {
                return;
            }

            state.RestoreSharedStateTo(this);
            m_damageData.damage = state.damage;
            m_damageData.interval = state.interval;
            m_damageData.delayFirstTick = state.delayFirstTick;
            m_damageData.timer = state.timer;
            m_damageData.damageOutput = state.damageOutput;
        }

    }
}

