using System;
using UnityEngine;

namespace FantasyWord.GameCore
{
    [Serializable]
    public class TemporalSpeedModifierEffectPersistedState : TemporalEffectPersistedState
    {
        public float factor;
        public AnimationCurve customCurve;
    }

    [Serializable]
    public class TemporalSpeedModifierEffect : ATemporalEffect, ITemporalEffectRuntimeStateCarrier
    {
        [Serializable]
        public struct SpeedModifierData
        {
            public float factor;
            public AnimationCurve customCurve;
        }

        [SerializeField] private SpeedModifierData m_speedModifierData;

        public override TemporalEffectRuntimeTraits GetRuntimeTraits()
        {
            TemporalEffectRuntimeTraits traits = TemporalEffectRuntimeTraits.NeedsLocalLifetimeAdvance;
            if (HasCustomCurve())
            {
                traits |= TemporalEffectRuntimeTraits.NeedsTickCallbacks;
            }

            return traits;
        }

        private bool HasCustomCurve() => HasCustomCurve(m_speedModifierData.customCurve);

        private float GetSpeed()
        {
            if (!HasCustomCurve() ||
                m_temporalData.duration <= 0.0f ||
                float.IsInfinity(m_temporalData.duration) ||
                float.IsNaN(m_temporalData.duration))
            {
                return GetResolvedSpeedFactor();
            }

            float progress = 1.0f - m_temporalData.remainingDuration / m_temporalData.duration;
            return Mathf.Lerp(
                GetResolvedSpeedFactor(),
                1.0f,
                m_speedModifierData.customCurve.Evaluate(Mathf.Clamp01(progress)));
        }

        protected override bool OnApply()
        {
            targetCharacter?.ApplyTemporalMoveSpeedRule(runtimeKey, GetSpeed());
            return true;
        }

        protected override void OnRuntimeStateRestored()
        {
            targetCharacter?.ApplyTemporalMoveSpeedRule(runtimeKey, GetSpeed());
        }

        protected override void OnUpdate()
        {
            if (HasCustomCurve())
            {
                targetCharacter?.UpdateTemporalMoveSpeedRule(runtimeKey, GetSpeed());
            }
        }

        protected override void OnCompleted()
        {
            targetCharacter?.RemoveTemporalMoveSpeedRule(runtimeKey);
        }

        public override ITemporalEffect Clone()
        {
            TemporalSpeedModifierEffect clone = new()
            {
                m_speedModifierData = m_speedModifierData
            };

            CopySharedTemporalStateTo(clone);
            return clone;
        }

        protected override TemporalEffectPresentationState BuildPresentationState()
        {
            TermDefinition speedModifierTermDefinition = GameManager.Config.GetTermDefinition(
                GetResolvedSpeedFactor() > 1.0f ?
                    "accelerated" :
                    "slowed");
            return CreatePresentationState(
                speedModifierTermDefinition,
                GetMoveSpeedDetails());
        }

        protected override bool TryResolvePresentationEffectType(out EEffectType effectType)
        {
            effectType = GetResolvedSpeedFactor() < 1.0f ? EEffectType.Debuff : EEffectType.Buff;
            return true;
        }

        private string GetMoveSpeedDetails()
        {
            return $"{GameManager.Config.GetTermDefinition("move_speed").shortName} x{GetResolvedSpeedFactor():0.#}";
        }

        public bool TryCapturePersistedState(out TemporalEffectPersistedState persistedState)
        {
            TemporalSpeedModifierEffectPersistedState state = new()
            {
                factor = m_speedModifierData.factor,
                customCurve = m_speedModifierData.customCurve
            };

            state.CaptureSharedStateFrom(this);
            persistedState = state;
            return true;
        }

        public void RestorePersistedState(TemporalEffectPersistedState persistedState)
        {
            if (persistedState is not TemporalSpeedModifierEffectPersistedState state)
            {
                return;
            }

            state.RestoreSharedStateTo(this);
            m_speedModifierData.factor = state.factor;
            m_speedModifierData.customCurve = state.customCurve;
        }

        private float GetResolvedSpeedFactor()
        {
            return m_speedModifierData.factor;
        }

        internal static bool HasCustomCurve(AnimationCurve customCurve)
        {
            return customCurve != null && customCurve.length > 1;
        }
    }
}

