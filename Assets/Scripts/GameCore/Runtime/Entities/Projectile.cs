using UnityEngine;

namespace FantasyWord.GameCore
{
    public readonly struct ProjectileLaunchParameters
    {
        public ProjectileLaunchParameters(
            FormalDamageEffectPayload baseDamage,
            float speed,
            float explosionRadius = 0.0f,
            bool explosionApplyBaseDamage = true,
            bool explosionBaseDamageIgnorePrimaryTarget = true)
        {
            BaseDamage = baseDamage;
            Speed = speed;
            ExplosionRadius = explosionRadius;
            ExplosionApplyBaseDamage = explosionApplyBaseDamage;
            ExplosionBaseDamageIgnorePrimaryTarget = explosionBaseDamageIgnorePrimaryTarget;
        }

        public FormalDamageEffectPayload BaseDamage { get; }
        public float Speed { get; }
        public float ExplosionRadius { get; }
        public bool ExplosionApplyBaseDamage { get; }
        public bool ExplosionBaseDamageIgnorePrimaryTarget { get; }
    }

    [RequireComponent(typeof(Rigidbody2D))]
    public partial class Projectile : Entity
    {
        [Header("References")]
        [SerializeField] private Rigidbody2D m_rigidbody = null;
        [SerializeField] private Animator m_animator = null;

        [Header("Settings")]
        [SerializeField] private bool m_reverseRotation = false;
        [SerializeField] private float m_maxDuration = 2.0f;

        [Header("Animation Parameters")]
        [SerializeField] private string m_destroyAnimationParameter = "destroy";

        [Header("Audio")]
        [SerializeField] private AudioClipResolver m_collisionSound;

        private CharacterBase m_source;
        private FormalDamageEffectPayload m_baseDamage;
        private float m_explosionRadius;
        private bool m_explosionApplyBaseDamage;
        private bool m_explosionBaseDamageIgnorePrimaryTarget;
        private GameCommandContext m_fireCommandContext = GameCommandContext.Script();
        private Vector2 m_direction;
        private float m_speed;
        private float m_remainingLifetime;
        private bool m_hasDestroyAnimation;
        private bool m_operating = false;

        internal bool shouldPersistRuntimeState => m_operating && m_remainingLifetime > 0.0f;

        private void Awake()
        {
            m_hasDestroyAnimation = m_animator && AnimationUtils.HasParameter(m_animator, m_destroyAnimationParameter);
        }

        public void Throw(CharacterBase source, Vector2 direction, ProjectileLaunchParameters parameters, GameCommandContext commandContext)
        {
            Debug.Assert(parameters.Speed > 0.0f, $"{name} 缺少有效投射物速度，无法初始化投射物执行参数。");
            m_source = source;
            m_fireCommandContext = commandContext.HasActor
                ? commandContext
                : GameCommandContext.Recreate(commandContext.IssuerKind, source, commandContext.IssuerId);

            m_baseDamage = parameters.BaseDamage;
            m_direction = direction;
            m_speed = parameters.Speed;
            m_remainingLifetime = m_maxDuration;
            m_explosionRadius = parameters.ExplosionRadius;
            m_explosionApplyBaseDamage = parameters.ExplosionApplyBaseDamage;
            m_explosionBaseDamageIgnorePrimaryTarget = parameters.ExplosionBaseDamageIgnorePrimaryTarget;
            m_operating = true;
        }

        public void OnDestroyAnimationEnd()
        {
            Destroy(ResolveDestroyCommandContext());
        }

        private GameCommandContext ResolveDestroyCommandContext()
        {
            if (!m_source)
            {
                return m_fireCommandContext;
            }

            return GameCommandContext.Recreate(m_fireCommandContext.IssuerKind, m_source, m_fireCommandContext.IssuerId);
        }

        private void Terminate(CharacterBase primaryTarget = null)
        {
            if (m_operating)
            {
                m_operating = false;
                m_rigidbody.linearVelocity = Vector3.zero;
                HandleExplosion(primaryTarget);

                if (m_hasDestroyAnimation)
                {
                    m_animator?.SetTrigger(m_destroyAnimationParameter);
                }
                else
                {
                    Destroy(ResolveDestroyCommandContext());
                }
            }
        }

        private void Update()
        {
            if (m_operating)
            {
                m_remainingLifetime -= Time.deltaTime;

                if (m_remainingLifetime <= 0.0f)
                {
                    Terminate();
                }
            }
        }

        private void FixedUpdate()
        {
            transform.rotation = Quaternion.LookRotation(Vector3.forward, m_direction * (m_reverseRotation ? -1.0f : 1.0f));

            m_rigidbody.linearVelocity =
                m_operating ?
                m_direction * m_speed :
                Vector2.zero;
        }
    }
}
