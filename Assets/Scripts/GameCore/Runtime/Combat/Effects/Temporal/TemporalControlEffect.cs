using System;
using Sirenix.OdinInspector;
using UnityEngine;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 持续控制效果类型。
    /// Stun/Silence/Root 分别映射到不同动作锁，不直接修改控制器本身。
    /// </summary>
    public enum EControlType
    {
        Stun,
        Silence,
        Root,
    }

    /// <summary>
    /// 控制类持续效果的持久化状态。
    /// 共享时长和运行键由基类保存，这里只补控制类型。
    /// </summary>
    [Serializable]
    public class TemporalControlEffectPersistedState : TemporalEffectPersistedState
    {
        public EControlType controlType;
    }

    /// <summary>
    /// 对角色施加动作锁的持续控制效果。
    /// 运行时通过 CharacterBase 的 temporal action lock 入口生效，结束时按 runtimeKey 成对移除。
    /// </summary>
    [Serializable]
    public class TemporalControlEffect : ATemporalEffect, ITemporalEffectRuntimeStateCarrier
    {
        /// <summary>
        /// 控制效果配置数据。
        /// 独立结构便于后续扩展持续控制参数，同时保持持久化字段稳定。
        /// </summary>
        [Serializable]
        public struct ControlData
        {
            public EControlType controlType;
        }

        [LabelText("控制数据")]
        [Tooltip("决定本持续效果锁定哪些角色动作。")]
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

        public bool TryRestorePersistedState(TemporalEffectPersistedState persistedState)
        {
            if (persistedState is not TemporalControlEffectPersistedState state)
            {
                return false;
            }

            state.RestoreSharedStateTo(this);
            m_controlData.controlType = state.controlType;
            return true;
        }

        private EControlType GetResolvedControlType()
        {
            return m_controlData.controlType;
        }
    }
}

