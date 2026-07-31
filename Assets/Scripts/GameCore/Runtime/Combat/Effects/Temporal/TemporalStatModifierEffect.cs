using System;
using Sirenix.OdinInspector;
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
            [LabelText("属性增量")]
            [Tooltip("持续期间施加到目标属性上的增量；负数表示降低属性。")]
            public int amount;

            [LabelText("目标属性")]
            [Tooltip("要临时修改的角色属性。生命值和法力值会走当前资源的专用裁剪逻辑。")]
            public EStat stat;
        }

        [LabelText("属性修正配置")]
        [Tooltip("配置要临时修改的属性和增量，效果结束时会按同一规则撤销。")]
        [SerializeField] private StatBoostEffect m_statBoostData;
        [NonSerialized] private FormalActiveAttributeModifierHandle m_activeModifierHandle;

        public override TemporalEffectRuntimeTraits GetRuntimeTraits() =>
            TemporalEffectRuntimeTraits.NeedsLocalLifetimeAdvance;

        protected override bool OnApply()
        {
            return ApplyConfiguredModifier(restoreFromRuntimeState: false);
        }

        protected override void OnRuntimeStateRestored()
        {
            ApplyConfiguredModifier(restoreFromRuntimeState: true);
        }

        protected override void OnCompleted()
        {
            if (targetCharacter == null)
            {
                return;
            }

            if (FormalAttributeCatalog.IsResourceStat(m_statBoostData.stat))
            {
                if (!targetCharacter.dead)
                {
                    ApplyCurrentResourceDelta(-m_statBoostData.amount, m_statBoostData.stat == EStat.Health ? 1 : 0);
                }
                return;
            }

            FormalGameplayEffectResourceModifier.TryRemoveActiveCurrentStatModifier(m_activeModifierHandle);
            m_activeModifierHandle = default;
        }

        private bool ApplyConfiguredModifier(bool restoreFromRuntimeState)
        {
            if (targetCharacter == null)
            {
                return true;
            }

            if (FormalAttributeCatalog.IsResourceStat(m_statBoostData.stat))
            {
                return restoreFromRuntimeState ||
                    ApplyCurrentResourceDelta(m_statBoostData.amount, minimumValue: 0);
            }

            return FormalGameplayEffectResourceModifier.TryAddActiveCurrentStatModifier(
                targetCharacter,
                m_statBoostData.stat,
                m_statBoostData.amount,
                sourceCharacter,
                out m_activeModifierHandle);
        }

        private bool ApplyCurrentResourceDelta(int delta, int minimumValue)
        {
            int appliedDelta = m_statBoostData.stat switch
            {
                EStat.Health => targetCharacter.ClampCurrentHealthDelta(delta, minimumValue),
                EStat.Mana => targetCharacter.ClampCurrentManaDelta(delta, minimumValue),
                _ => delta
            };

            if (appliedDelta == 0)
            {
                return true;
            }

            int? maxValue = appliedDelta > 0
                ? m_statBoostData.stat switch
                {
                    EStat.Health => targetCharacter.GetMaxHealth(),
                    EStat.Mana => targetCharacter.GetMaxMana(),
                    _ => null
                }
                : null;

            return FormalGameplayEffectResourceModifier.TryApplyCurrentStatDelta(
                targetCharacter,
                m_statBoostData.stat,
                appliedDelta,
                minValue: minimumValue,
                maxValue: maxValue,
                sourceCharacter,
                out _,
                out _);
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

