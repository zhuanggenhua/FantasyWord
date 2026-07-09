using System;
using UnityEngine;

namespace FantasyWord.GameCore
{
    public enum EControlType
    {
        Stun,
        Silence,
        Root,
    }

    [Serializable]
    public class TemporalControlEffectPersistedState : TemporalEffectPersistedState
    {
        public EControlType controlType;
    }

    [Serializable]
    public class TemporalControlEffect : ATemporalEffect, ITemporalEffectRuntimeStateCarrier
    {
        [Serializable]
        public struct ControlData
        {
            public EControlType controlType;
        }

        [SerializeField] private ControlData m_controlData;

        public override TemporalEffectRuntimeTraits GetRuntimeTraits() =>
            TemporalEffectRuntimeTraits.NeedsLocalLifetimeAdvance;

        protected EActionFlags GetActionFlags()
        {
            switch (GetResolvedControlType())
            {
                case EControlType.Stun: return EActionFlags.Move | EActionFlags.UseAbility | EActionFlags.UpdateTargetDirection;
                case EControlType.Silence: return EActionFlags.UseAbility;
                case EControlType.Root: return EActionFlags.Move;
            }

            return EActionFlags.None;
        }

        protected override bool OnApply()
        {
            targetCharacter?.ApplyTemporalActionLockRule(runtimeKey, GetActionFlags());
            return true;
        }

        protected override void OnRuntimeStateRestored()
        {
            targetCharacter?.ApplyTemporalActionLockRule(runtimeKey, GetActionFlags());
        }

        protected override void OnCompleted()
        {
            targetCharacter?.RemoveTemporalActionLockRule(runtimeKey);
        }

        public override ITemporalEffect Clone()
        {
            TemporalControlEffect clone = new()
            {
                m_controlData = m_controlData
            };

            CopySharedTemporalStateTo(clone);
            return clone;
        }

        protected override TemporalEffectPresentationState BuildPresentationState()
        {
            TermDefinition controlTermDefinition = GameManager.Config.GetTermDefinition(GetResolvedControlType());
            return CreatePresentationState(
                controlTermDefinition,
                controlTermDefinition.description);
        }

        protected override bool TryResolvePresentationEffectType(out EEffectType effectType)
        {
            effectType = EEffectType.Debuff;
            return true;
        }

        public bool TryCapturePersistedState(out TemporalEffectPersistedState persistedState)
        {
            TemporalControlEffectPersistedState state = new()
            {
                controlType = m_controlData.controlType
            };

            state.CaptureSharedStateFrom(this);
            persistedState = state;
            return true;
        }

        public void RestorePersistedState(TemporalEffectPersistedState persistedState)
        {
            if (persistedState is not TemporalControlEffectPersistedState state)
            {
                return;
            }

            state.RestoreSharedStateTo(this);
            m_controlData.controlType = state.controlType;
        }

        private EControlType GetResolvedControlType()
        {
            return m_controlData.controlType;
        }
    }
}

