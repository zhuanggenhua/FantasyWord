using System;
using UnityEngine;

namespace FantasyWord.GameCore
{
    [Flags]
    public enum EEffectTargetFlags
    {
        [HideInInspector] None = 0,
        Self = 1 << 0,
        Allies = 1 << 1,
        Enemies = 1 << 2,
        Anything = 1 << 3,
        [HideInInspector] All = ~None
    }

    [Flags]
    public enum EEffectVisualFlags
    {
        [HideInInspector] None,
        NoFloatingText = 1 << 0,
        NoCameraShake = 1 << 1,
        NoScreenFlash = 1 << 2,
        [HideInInspector] All = ~None
    }


    [Serializable]
    public abstract class AEffect : IEffect
    {
        [Serializable]
        protected struct EffectData
        {
            public EEffectTargetFlags targetFlags;
            public EEffectInterruptionPolicy interruptionPolicy;
            public EEffectVisualFlags visualFlags;
            [Range(0.0f, 1.0f)] public float failureRate;

            [HideInInspector] public bool initialized;
            [HideInInspector] public PersistableReference<CharacterBase> source;
            [HideInInspector] public PersistableReference<CharacterBase> target;
            [HideInInspector] public Vector2 velocity;
            [HideInInspector] public DamageImpactSettings damageImpact;
        }

        public bool initialized => m_effectData.initialized;
        public EEffectInterruptionPolicy interruptionPolicy => m_effectData.interruptionPolicy;
        public EEffectVisualFlags visualFlags => m_effectData.visualFlags;
        protected CharacterBase sourceCharacter => m_runtimeSourceCharacter != null ? m_runtimeSourceCharacter : m_effectData.source.ResolveOrNull();
        protected CharacterBase targetCharacter => m_runtimeTargetCharacter != null ? m_runtimeTargetCharacter : m_effectData.target.ResolveOrNull();

        [SerializeField] protected EffectData m_effectData;
        private CharacterBase m_runtimeSourceCharacter = null;
        private CharacterBase m_runtimeTargetCharacter = null;

        private bool IsTargetValidBasedOnFlags(CharacterBase target)
        {
            return
                m_effectData.targetFlags.HasFlag(EEffectTargetFlags.Anything) ||
                m_effectData.targetFlags.HasFlag(EEffectTargetFlags.Self) && target == sourceCharacter ||
                m_effectData.targetFlags.HasFlag(EEffectTargetFlags.Allies) && CombatSolver.AreAllies(sourceCharacter, target) ||
                m_effectData.targetFlags.HasFlag(EEffectTargetFlags.Enemies) && CombatSolver.AreEnemies(sourceCharacter, target);
        }

        private bool EvaluateFailure()
        {
            return UnityEngine.Random.value < m_effectData.failureRate;
        }

        public virtual bool IsApplicable(CharacterBase target) =>
            target != null &&
            CombatSolver.CanTarget(sourceCharacter, target) &&
            IsTargetValidBasedOnFlags(target) &&
            !EvaluateFailure();

        public virtual EffectDescription GenerateDescription() => new()
        {
            name = GetType().Name,
            details = string.Empty
        };

        protected virtual void OnInit() { }
        protected virtual bool OnApply() => true;
        protected virtual void OnDeinit() { }

        public void Init(CharacterBase source)
        {
            if (initialized)
            {
                Debug.LogError($"Effect is already initialized");
            }

            Debug.Assert(!initialized, $"Effect is already initialized");
            m_runtimeSourceCharacter = source;
            m_effectData.source = source;
            OnInit();
            m_effectData.initialized = true;
        }

        private Vector2 ExtractVelocityFromImpactSettings(EffectImpactSettings impactSettings)
        {
            return impactSettings.impactDataType switch
            {
                EEffectImpactDataType.Velocity => impactSettings.impactData,
                EEffectImpactDataType.SourcePosition => targetCharacter != null ? (Vector2)targetCharacter.transform.position - impactSettings.impactData : Vector2.zero,
                _ => Vector2.zero
            };
        }

        public virtual bool Apply(CharacterBase target, EffectImpactSettings? impactSettings = null)
        {
            m_runtimeTargetCharacter = target;
            m_effectData.target = target;

            m_effectData.velocity = impactSettings.HasValue ?
                ExtractVelocityFromImpactSettings(impactSettings.Value) :
                (sourceCharacter != null && targetCharacter != null ? (Vector2)targetCharacter.transform.position - (Vector2)sourceCharacter.transform.position : Vector2.zero);
            m_effectData.damageImpact = impactSettings?.damageImpact ?? default;

            return OnApply();
        }

        public void Deinit()
        {
            OnDeinit();
            Cleanup();
        }

        protected void Cleanup()
        {
            Debug.Assert(initialized, $"Effect isn't initialized");
            m_effectData.source = null;
            m_effectData.target = null;
            m_runtimeSourceCharacter = null;
            m_runtimeTargetCharacter = null;
            m_effectData.velocity = Vector2.zero;
            m_effectData.damageImpact = default;
            m_effectData.initialized = false;
        }
    }
}

