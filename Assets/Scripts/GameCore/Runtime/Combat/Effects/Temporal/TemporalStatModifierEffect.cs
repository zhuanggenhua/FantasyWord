using System;
using UnityEngine;

namespace FantasyWord.GameCore
{
    [Serializable]
    public class TemporalStatModifierEffectPersistedState : TemporalEffectPersistedState
    {
        public int amount;
        public EStat stat;
    }

    [Serializable]
    public class TemporalStatModifierEffect : ATemporalEffect, ITemporalEffectRuntimeStateCarrier
    {
        [Serializable]
        internal struct StatBoostEffect
        {
            public int amount;
            public EStat stat;
        }

        [SerializeField] private StatBoostEffect m_statBoostData;

        public override TemporalEffectRuntimeTraits GetRuntimeTraits() =>
            TemporalEffectRuntimeTraits.NeedsLocalLifetimeAdvance;

        protected override bool OnApply()
        {
            if (targetCharacter == null)
            {
                return true;
            }

            switch (m_statBoostData.stat)
            {
                case EStat.Health:
                    targetCharacter.ModifyCurrentHealth(m_statBoostData.amount);
                    break;
                case EStat.Mana:
                    targetCharacter.ModifyCurrentMana(m_statBoostData.amount);
                    break;
                default:
                    targetCharacter.ModifyCurrentStat(m_statBoostData.stat, m_statBoostData.amount);
                    break;
            }

            return true;
        }

        protected override void OnCompleted()
        {
            // If the target is dead, we can't remove stats, so we skip this step
            if (targetCharacter == null || targetCharacter.dead)
            {
                return;
            }

            int amountToRemove = m_statBoostData.amount;

            // 资源约束由角色拥有者统一裁剪，效果层只表达“我要撤掉多少增量”。
            if (m_statBoostData.stat == EStat.Health)
            {
                amountToRemove = -targetCharacter.ClampCurrentHealthDelta(-amountToRemove, minimumValue: 1);
            }

            if (m_statBoostData.stat == EStat.Mana)
            {
                amountToRemove = -targetCharacter.ClampCurrentManaDelta(-amountToRemove);
            }

            switch (m_statBoostData.stat)
            {
                case EStat.Health:
                    targetCharacter.ModifyCurrentHealth(-amountToRemove, minimumValue: 1);
                    break;
                case EStat.Mana:
                    targetCharacter.ModifyCurrentMana(-amountToRemove);
                    break;
                default:
                    targetCharacter.ModifyCurrentStat(m_statBoostData.stat, -amountToRemove);
                    break;
            }
        }

        public override ITemporalEffect Clone()
        {
            TemporalStatModifierEffect clone = new()
            {
                m_statBoostData = m_statBoostData
            };

            CopySharedTemporalStateTo(clone);
            return clone;
        }

        protected override TemporalEffectPresentationState BuildPresentationState()
        {
            TermDefinition statModifierTermDefinition =
                m_statBoostData.amount > 0 ?
                    GameManager.Config.GetStatIncreaseTermDefinition(m_statBoostData.stat) :
                    GameManager.Config.GetStatDecreaseTermDefinition(m_statBoostData.stat);
            return CreatePresentationState(
                statModifierTermDefinition,
                GetStatModifierDetails());
        }

        protected override bool TryResolvePresentationEffectType(out EEffectType effectType)
        {
            effectType = m_statBoostData.amount < 0 ? EEffectType.Debuff : EEffectType.Buff;
            return true;
        }

        private string GetStatModifierDetails()
        {
            string prefix = m_statBoostData.amount > 0 ? "+" : string.Empty;
            return $"{prefix}{m_statBoostData.amount} {GameManager.Config.GetTermDefinition(m_statBoostData.stat).shortName}";
        }

        public bool TryCapturePersistedState(out TemporalEffectPersistedState persistedState)
        {
            TemporalStatModifierEffectPersistedState state = new()
            {
                amount = m_statBoostData.amount,
                stat = m_statBoostData.stat
            };

            state.CaptureSharedStateFrom(this);
            persistedState = state;
            return true;
        }

        public void RestorePersistedState(TemporalEffectPersistedState persistedState)
        {
            if (persistedState is not TemporalStatModifierEffectPersistedState state)
            {
                return;
            }

            state.RestoreSharedStateTo(this);
            m_statBoostData.amount = state.amount;
            m_statBoostData.stat = state.stat;
        }
    }
}

