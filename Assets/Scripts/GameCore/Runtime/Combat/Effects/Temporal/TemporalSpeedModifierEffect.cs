using System;
using Sirenix.OdinInspector;
using UnityEngine;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 移速持续修正效果的存档快照，保存倍率和可选曲线配置。
    /// </summary>
    [Serializable]
    public class TemporalSpeedModifierEffectPersistedState : TemporalEffectPersistedState
    {
        /// <summary>
        /// 目标移动速度倍率；1 表示不变，小于 1 为减速，大于 1 为加速。
        /// </summary>
        public float factor;

        /// <summary>
        /// 可选的恢复曲线，用于让倍率随持续时间逐渐回到 1。
        /// </summary>
        public AnimationCurve customCurve;
    }

    /// <summary>
    /// 在持续时间内向目标角色登记移动速度规则，可选按曲线逐步回到正常速度。
    /// </summary>
    [Serializable]
    public class TemporalSpeedModifierEffect : ATemporalEffect, ITemporalEffectRuntimeStateCarrier
    {
        /// <summary>
        /// 移速修正的配置数据；曲线存在时运行时需要 tick 回调刷新当前倍率。
        /// </summary>
        [Serializable]
        public struct SpeedModifierData
        {
            [LabelText("移动速度倍率")]
            [Tooltip("持续期间应用到目标移动速度上的倍率；1 表示不变，小于 1 减速，大于 1 加速。")]
            public float factor;

            [LabelText("恢复曲线")]
            [Tooltip("可选曲线。存在两个以上关键帧时，会按持续进度把倍率插值回 1。")]
            public AnimationCurve customCurve;
        }

        [LabelText("移速修正配置")]
        [Tooltip("配置持续期间目标移动速度倍率，以及是否随时间恢复正常速度。")]
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

        public bool TryRestorePersistedState(TemporalEffectPersistedState persistedState)
        {
            if (persistedState is not TemporalSpeedModifierEffectPersistedState state)
            {
                return false;
            }

            state.RestoreSharedStateTo(this);
            m_speedModifierData.factor = state.factor;
            m_speedModifierData.customCurve = state.customCurve;
            return true;
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

