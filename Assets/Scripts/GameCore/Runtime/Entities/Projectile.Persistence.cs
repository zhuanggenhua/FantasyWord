using System;
using UnityEngine;
using UnityEngine.Serialization;

namespace FantasyWord.GameCore
{
    [Serializable]
    public class ProjectileDataBlock : EntityDataBlock
    {
        public Vector2 direction;
        public float speed;
        public float remainingLifetime;
        public bool operating;
        public PersistableReference<CharacterBase> source;
        public EGameCommandIssuerKind fireCommandIssuerKind;
        public string fireCommandIssuerId;
        public FormalDamageEffectPayload baseDamage;
        public float explosionRadius;
        [FormerlySerializedAs("explosionApplyBaseEffects")]
        public bool explosionApplyBaseDamage;
        [FormerlySerializedAs("explosionBaseEffectsIgnorePrimaryTarget")]
        public bool explosionBaseDamageIgnorePrimaryTarget;
    }

    /// <summary>
    /// 飞行物局部运行时快照。
    /// 它只服务能力 extra state 恢复，不再夹带持久化系统专用的 info 字段。
    /// </summary>
    [Serializable]
    public class ProjectileRuntimeStateData
    {
        public EPersistableObjectState state;
        public Vector3 position;
        public Quaternion rotation;
        public Vector3 scale;
        public Vector2 direction;
        public float speed;
        public float remainingLifetime;
        public bool operating;
        public PersistableReference<CharacterBase> source;
        public EGameCommandIssuerKind fireCommandIssuerKind;
        public string fireCommandIssuerId;
        public FormalDamageEffectPayload baseDamage;
        public float explosionRadius;
        [FormerlySerializedAs("explosionApplyBaseEffects")]
        public bool explosionApplyBaseDamage;
        [FormerlySerializedAs("explosionBaseEffectsIgnorePrimaryTarget")]
        public bool explosionBaseDamageIgnorePrimaryTarget;
    }

    public partial class Projectile
    {
        protected override Type GetDataBlockType() => typeof(ProjectileDataBlock);

        protected override void OnSave(PersistableDataBlock block)
        {
            base.OnSave(block);

            ProjectileDataBlock projectileBlock = block.As<ProjectileDataBlock>();
            projectileBlock.direction = m_direction;
            projectileBlock.speed = m_speed;
            projectileBlock.remainingLifetime = m_remainingLifetime;
            projectileBlock.operating = m_operating;
            projectileBlock.source = m_source;
            projectileBlock.fireCommandIssuerKind = m_fireCommandContext.IssuerKind;
            projectileBlock.fireCommandIssuerId = m_fireCommandContext.IssuerId;
            projectileBlock.baseDamage = m_baseDamage;
            projectileBlock.explosionRadius = m_explosionRadius;
            projectileBlock.explosionApplyBaseDamage = m_explosionApplyBaseDamage;
            projectileBlock.explosionBaseDamageIgnorePrimaryTarget = m_explosionBaseDamageIgnorePrimaryTarget;
        }

        protected override void OnLoad(PersistableDataBlock block)
        {
            base.OnLoad(block);

            ProjectileDataBlock projectileBlock = block.As<ProjectileDataBlock>();
            m_direction = projectileBlock.direction;
            m_speed = projectileBlock.speed;
            m_remainingLifetime = projectileBlock.remainingLifetime;
            m_operating = projectileBlock.operating;
            m_source = projectileBlock.source.ResolveOrNull();
            m_fireCommandContext = GameCommandContext.Recreate(projectileBlock.fireCommandIssuerKind, m_source, projectileBlock.fireCommandIssuerId);
            m_baseDamage = projectileBlock.baseDamage;
            m_explosionRadius = projectileBlock.explosionRadius;
            m_explosionApplyBaseDamage = projectileBlock.explosionApplyBaseDamage;
            m_explosionBaseDamageIgnorePrimaryTarget = projectileBlock.explosionBaseDamageIgnorePrimaryTarget;
        }

        internal ProjectileRuntimeStateData CreateRuntimeState()
        {
            return new ProjectileRuntimeStateData
            {
                state = CapturePersistableState(),
                position = transform.position,
                rotation = transform.rotation,
                scale = transform.localScale,
                direction = m_direction,
                speed = m_speed,
                remainingLifetime = m_remainingLifetime,
                operating = m_operating,
                source = m_source,
                fireCommandIssuerKind = m_fireCommandContext.IssuerKind,
                fireCommandIssuerId = m_fireCommandContext.IssuerId,
                baseDamage = m_baseDamage,
                explosionRadius = m_explosionRadius,
                explosionApplyBaseDamage = m_explosionApplyBaseDamage,
                explosionBaseDamageIgnorePrimaryTarget = m_explosionBaseDamageIgnorePrimaryTarget
            };
        }

        internal void LoadRuntimeState(ProjectileRuntimeStateData runtimeState)
        {
            if (runtimeState == null || !ApplyPersistableState(runtimeState.state))
            {
                return;
            }

            transform.position = runtimeState.position;
            transform.rotation = runtimeState.rotation;
            transform.localScale = runtimeState.scale;
            m_direction = runtimeState.direction;
            m_speed = runtimeState.speed;
            m_remainingLifetime = runtimeState.remainingLifetime;
            m_operating = runtimeState.operating;
            m_source = runtimeState.source.ResolveOrNull();
            m_fireCommandContext = GameCommandContext.Recreate(runtimeState.fireCommandIssuerKind, m_source, runtimeState.fireCommandIssuerId);
            m_baseDamage = runtimeState.baseDamage;
            m_explosionRadius = runtimeState.explosionRadius;
            m_explosionApplyBaseDamage = runtimeState.explosionApplyBaseDamage;
            m_explosionBaseDamageIgnorePrimaryTarget = runtimeState.explosionBaseDamageIgnorePrimaryTarget;
        }
    }
}
