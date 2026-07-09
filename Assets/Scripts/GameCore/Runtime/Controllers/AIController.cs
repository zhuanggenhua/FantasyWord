using System;
using UnityEngine;

namespace FantasyWord.GameCore
{
    [Serializable]
    public class AIControllerDataBlock : ControllerDataBlock
    {
        public Vector3 initialPosition;
        public PersistableReference<CharacterBase> target;
        public float retargetCooldownTimer;
        public float attackCooldownTimer;
        public float timeSinceTargetLastSeen;
    }

    [Serializable]
    public partial class AIController : AController<CharacterBase>
    {
        [Header("References")]
        [SerializeField] private Entity m_master = null;

        [Header("Chase Settings")]
        [SerializeField, Min(1.0f)] private float m_detectionRadius = 5.0f;
        [SerializeField, Min(1.0f)] private float m_resetFromInitialPositionRadius = 10.0f;
        [SerializeField, Min(1.0f)] private float m_resetFromTargetDistanceRadius = 10.0f;
        [SerializeField, Min(0.5f)] private float m_targetOutOfRangeRetargetCooldown = 3.0f;
        [SerializeField, Min(0.1f)] private float m_soughtDistanceFromMasterTarget = 1.0f;
        [SerializeField, Min(0.1f)] private float m_soughtDistanceFromTarget = 1.0f;

        [Header("Steering Settings")]
        [SerializeField, Min(0.1f)] private float m_steeringDriftResponsiveness = 3.0f;
        [SerializeField, Min(0.1f)] private float m_timeBeforeResetAfterTargetSightLost = 3.0f;
        [SerializeField, Min(0.1f)] private float m_cannotSeeTargetRetargetCooldown = 1.0f;

        [Header("Attack Settings")]
        [SerializeField] public float m_attackTriggerRadius = 1.0f;
        [SerializeField] public float m_attackCooldown = 1.0f;

        private Transform transform => m_subject.transform;

        private Vector2 m_homePosition =>
            m_master ?
            (Vector2)m_master.transform.position :
            m_initialPosition;

        private CharacterBase m_target = null;
        private float m_retargetCooldownTimer = 0.0f;
        private float m_attackCooldownTimer = 0.0f;
        private Vector2 m_initialPosition;
        private float m_timeSinceTargetLastSeen = 0.0f;

        private BehaviourRuntime m_behaviourRuntime = null;
        private BehaviourRuntime behaviourRuntime => m_behaviourRuntime ??= new BehaviourRuntime(this);

        protected override void OnInitialize()
        {
            behaviourRuntime.Initialize();
        }

        protected override void OnStart()
        {
            m_subject.AddProvokedListener(OnProvoked);
        }

        protected override void OnStop()
        {
            m_subject.RemoveProvokedListener(OnProvoked);
        }

        public void SetMaster(Entity master, float? soughtDistanceFromMaster = null)
        {
            m_soughtDistanceFromMasterTarget = soughtDistanceFromMaster ?? m_soughtDistanceFromMasterTarget;
            m_master = master;
        }

        private void OnProvoked(CharacterBase source)
        {
            behaviourRuntime.TryHandleProvoked(source);
        }

        protected override void OnFixedUpdate()
        {
            behaviourRuntime.Tick();
        }

        protected override void OnDrawGizmos()
        {
            behaviourRuntime.DrawGizmos();
        }

        protected override Type GetDataBlockType() => typeof(AIControllerDataBlock);

        protected override void OnLoad(IControllerDataBlock block)
        {
            base.OnLoad(block);
            var aiControllerDataBlock = block.As<AIControllerDataBlock>();
            m_initialPosition = aiControllerDataBlock.initialPosition;
            m_target = aiControllerDataBlock.target.ResolveOrNull();
            m_retargetCooldownTimer = aiControllerDataBlock.retargetCooldownTimer;
            m_attackCooldownTimer = aiControllerDataBlock.attackCooldownTimer;
            m_timeSinceTargetLastSeen = aiControllerDataBlock.timeSinceTargetLastSeen;
        }

        protected override void OnSave(IControllerDataBlock block)
        {
            base.OnSave(block);
            var aiControllerDataBlock = block.As<AIControllerDataBlock>();
            aiControllerDataBlock.initialPosition = m_initialPosition;
            aiControllerDataBlock.target = m_target;
            aiControllerDataBlock.retargetCooldownTimer = m_retargetCooldownTimer;
            aiControllerDataBlock.attackCooldownTimer = m_attackCooldownTimer;
            aiControllerDataBlock.timeSinceTargetLastSeen = m_timeSinceTargetLastSeen;
        }
    }
}
