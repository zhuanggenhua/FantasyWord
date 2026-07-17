using System;
using UnityEngine;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 属性持续修正效果的存档快照，保存被修改的属性和修改量。
    /// </summary>
    [Serializable]
    public class TemporalStatModifierEffectPersistedState : TemporalEffectPersistedState
    {
        /// <summary>
        /// 效果生效时施加到属性上的增量；效果结束时按相反方向撤销。
        /// </summary>
        public int amount;

        /// <summary>
        /// 被临时修改的角色属性。
        /// </summary>
        public EStat stat;
    }

    /// <summary>
    /// 在持续时间内临时修改目标角色属性，结束时撤销同等增量并保留生命值下限约束。
    /// </summary>
    [Serializable]
    public class TemporalStatModifierEffect : ATemporalEffect, ITemporalEffectRuntimeStateCarrier
    {
        /// <summary>
        /// 属性修正配置；正数表示增益，负数表示减益。
        /// </summary>
        [Serializable]
        internal struct StatBoostEffect
        {
            [InspectorName("属性增量")]
            [Tooltip("持续期间施加到目标属性上的增量；负数表示降低属性。")]
            public int amount;

            [InspectorName("目标属性")]
            [Tooltip("要临时修改的角色属性。生命值和法力值会走当前资源的专用裁剪逻辑。")]
            public EStat stat;
        }

        [InspectorName("属性修正配置")]
        [Tooltip("配置要临时修改的属性和增量，效果结束时会按同一规则撤销。")]
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
            // 目标死亡后属性归还没有稳定承载对象，避免在死亡流程里再次改写角色状态。
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

        public bool TryRestorePersistedState(TemporalEffectPersistedState persistedState)
        {
            if (persistedState is not TemporalStatModifierEffectPersistedState state)
            {
                return false;
            }

            state.RestoreSharedStateTo(this);
            m_statBoostData.amount = state.amount;
            m_statBoostData.stat = state.stat;
            return true;
        }
    }
}

