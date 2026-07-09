using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Unity.Mathematics;
using UnityEngine;
using UnityEngine.Events;
using MackySoft.SerializeReferenceExtensions;

namespace FantasyWord.GameCore
{
    public enum EDirection
    {
        Left,
        Right,
        Up,
        Down,
        None,
        Default = Right
    }

    public enum ELookAtDirectionUpdateStrategy
    {
        MovementBased,
        TargetBased
    }

    public enum EMovementInputMode
    {
        Free,
        Strict2DirectionsHorizontal,
        Strict2DirectionsVertical,
        Strict4Directions,
        Strict8Directions
    }

    [Serializable]
    public class MovableDataBlock : EntityDataBlock
    {
        public Vector2 lookAtDirection;
        [SerializeReference, SubclassSelector] public IControllerDataBlock controllerData;
    }

    public abstract partial class Movable : Entity, ICharacterAnimationStateReceiver
    {
        [Header("References")]
        [SerializeField] private Rigidbody2D m_rigidbody = null;

        [Header("Movement Settings")]
        [SerializeField] private float m_moveSpeed = 4.0f;
        [Tooltip("移动输入方向限制。吸收 TopDown CharacterMovement 的方向模式，但不接入它的 InputManager。")]
        [SerializeField] private EMovementInputMode m_movementInputMode = EMovementInputMode.Free;
        [Tooltip("启用后保留摇杆输入强度；关闭后只使用归一化方向，键盘和摇杆速度一致。")]
        [SerializeField] private bool m_useAnalogMovementInput = false;
        [Tooltip("输入从静止过渡到目标速度的响应速度。0 表示立即达到目标速度。")]
        [SerializeField] private float m_acceleration = 10.0f;
        [Tooltip("输入松开后回到静止的响应速度。0 表示立即停止。")]
        [SerializeField] private float m_deceleration = 10.0f;
        [Tooltip("低于该强度时视为静止，避免摇杆漂移或浮点误差让角色抖动。")]
        [SerializeField] private float m_idleThreshold = 0.05f;
        [Tooltip("动作执行层的常规速度倍率；RPG 属性、装备和状态修正仍在 CharacterBase 中处理。")]
        [SerializeField] private float m_movementSpeedMultiplier = 1.0f;
        [Tooltip("限制动作执行层速度倍率上限，避免区域、Buff 和临时效果叠乘后失控。")]
        [SerializeField] private float m_movementSpeedMaxMultiplier = float.MaxValue;
        [Tooltip("禁用玩家输入和 AI 驱动的普通移动；强制位移和推力仍按各自规则处理。")]
        [SerializeField] private bool m_movementForbidden = false;
        [SerializeField] private float m_pushIntensityScale = 1.0f;
        [SerializeField] private float m_pushResistanceScale = 1.0f;
        [SerializeField] private bool m_disableAllMovements = false;
        [SerializeField] private bool m_canMoveDuringDeath = false;
        [SerializeField] protected ELookAtDirectionUpdateStrategy m_lookAtDirectionUpdateStrategy = ELookAtDirectionUpdateStrategy.MovementBased;

        [Header("Controller Settings")]
        [SerializeReference, SubclassSelector] protected IController m_controller = null;

        [Header("Animation Settings")]
        [SerializeReference, SubclassSelector] protected IAnimationStrategy m_animationStrategy = null;

        protected bool m_destroyOnDeath = true;
        protected Vector2 m_lookAtDirection = Vector2.zero;
        private UnityEvent<Vector2> m_targetDirectionChangedEvent = new();
        private Vector2? m_targetDirectionOverride = null;
        private Vector2 m_movementDirection;
        private UnityEvent m_teleported = new();
        private MotionRuntime m_motionRuntime = null;
        private IController m_activeControllerOverride = null;
        private MotionRuntime motionRuntime => m_motionRuntime ??= new MotionRuntime(this);
        private IController activeController => m_activeControllerOverride ?? m_controller;

        protected virtual void Awake()
        {
            Debug.Assert(m_rigidbody, ErrorMessages.InspectorMissingComponentReference<Rigidbody2D>());

            m_animationStrategy?.AddDeathAnimationEndedListener(OnDeathAnimationEnd);

            _ = motionRuntime;
            m_animationStrategy?.Initialize();
            InitializeControllers();
        }

        public void AddTeleportedListener(UnityAction listener)
        {
            m_teleported.AddListener(listener);
        }

        public void RemoveTeleportedListener(UnityAction listener)
        {
            m_teleported.RemoveListener(listener);
        }

        public void AddTargetDirectionChangedListener(UnityAction<Vector2> listener)
        {
            m_targetDirectionChangedEvent.AddListener(listener);
        }

        public void RemoveTargetDirectionChangedListener(UnityAction<Vector2> listener)
        {
            m_targetDirectionChangedEvent.RemoveListener(listener);
        }

        public bool TryGetController<TController>(out TController controller) where TController : class
        {
            if (m_controller is TController typedController)
            {
                controller = typedController;
                return true;
            }

            controller = null;
            return false;
        }

        public bool IsControllerActive<TController>() where TController : class
        {
            return activeController is TController;
        }

        protected bool TryActivateController<TController>() where TController : class, IController
        {
            if (!TryGetController(out TController controller))
            {
                return false;
            }

            SetActiveControllerOverride(controller);
            return true;
        }

        protected bool ClearControllerOverride<TController>() where TController : class, IController
        {
            if (m_activeControllerOverride is not TController)
            {
                return false;
            }

            SetActiveControllerOverride(null);
            return true;
        }

        public void StartController()
        {
            StartActiveController();
        }

        public void StopController()
        {
            StopActiveController();
        }

        public virtual void Revive()
        {
            StartActiveController();
            MarkAsNotDestroyed();
        }

        public void OnInvincibleAnimationStart()
        {
            m_animationStrategy?.OnInvincibleAnimationStart();
        }

        public void OnInvincibleAnimationStop()
        {
            m_animationStrategy?.OnInvincibleAnimationStop();
        }

        public void OnDeathAnimationStart()
        {
            m_animationStrategy?.OnDeathAnimationStart();
        }

        public void OnDeathAnimationStop()
        {
            m_animationStrategy?.OnDeathAnimationStop();
        }

        protected virtual AudioClipResolver GetDeathAudio() => null;

        public virtual void Kill()
        {
            StopActiveController();
            MarkAsDestroyed();
            PlayDeathAudio();
            ResetMovement();

            if (!(m_animationStrategy?.PlayDeathAnimation() ?? false))
            {
                OnDeath();
            }
        }

        /// <summary>
        /// 检查一个出生点/传送点对当前 2D 碰撞闭包是否有效。
        /// 吸收 uMMORPG `Movement.IsValidSpawnPoint(...)` 的职责，但继续沿用当前 Rigidbody2D + ContactFilter2D 真相源。
        /// </summary>
        public bool IsValidSpawnPoint(Vector3 position)
        {
            return motionRuntime.IsValidSpawnPoint(position);
        }

        /// <summary>
        /// 返回距离目标点最近、且对当前移动闭包有效的位置。
        /// 吸收 uMMORPG `Movement.NearestValidDestination(...)` 的职责，用于传送、出生点和后续点击移动目标修正。
        /// </summary>
        public Vector3 NearestValidDestination(Vector3 destination)
        {
            return motionRuntime.NearestValidDestination(destination);
        }

        public void TeleportTo(Vector3 position)
        {
            motionRuntime.TeleportTo(position);
        }

        private void PlayDeathAudio()
        {
            AudioClipResolver deathAudio = GetDeathAudio();

            if (deathAudio)
            {
                GameRuntimeEvents.RequestAudioPlayback(deathAudio);
            }
        }

        protected virtual void OnDeath()
        {
            if (m_destroyOnDeath)
            {
                Destroy(ResolveDeathCommandContext());
            }
        }

        protected virtual GameCommandContext ResolveDeathCommandContext()
        {
            return GameCommandContext.Script();
        }

        protected virtual void OnDestroy()
        {
            TerminateControllers();
        }

        protected virtual void OnDeathAnimationEnd() => OnDeath();

        protected virtual void OnStuckInAWall() { }

        protected virtual void OnEnable() => StartActiveController();

        /// <summary>
        /// 默认只负责停掉控制器。
        /// 角色等子类若还持有临时运行时状态，应在 override 中先完成自己的收尾，再回到这里停控制器。
        /// </summary>
        protected virtual void OnDisable() => StopActiveController();
        private void OnDrawGizmos() => activeController?.DrawGizmos();
        protected virtual void Update() => activeController?.Update();
        protected virtual float CalculateMoveSpeed() => m_moveSpeed;
        protected virtual float CalculateMovementSpeedMultiplier()
        {
            float cappedMultiplier = Mathf.Min(m_movementSpeedMultiplier, m_movementSpeedMaxMultiplier);
            return cappedMultiplier * motionRuntime.GetContextSpeedMultiplier();
        }

        protected float GetContextMovementSpeedMultiplier() => motionRuntime.GetContextSpeedMultiplier();

        /// <summary>
        /// 设置动作执行层的常规速度倍率。RPG 属性、装备和状态效果的倍率仍由 <see cref="CharacterBase"/> 维护。
        /// </summary>
        public void SetMovementSpeedMultiplier(float multiplier)
        {
            m_movementSpeedMultiplier = Mathf.Max(0.0f, multiplier);
        }

        /// <summary>
        /// 限制动作执行层速度倍率上限，用于防止多个临时移动区域或 Buff 叠乘后超过设计范围。
        /// </summary>
        public void SetMovementSpeedMaxMultiplier(float maxMultiplier)
        {
            m_movementSpeedMaxMultiplier = Mathf.Max(0.0f, maxMultiplier);
        }

        /// <summary>
        /// 压入一个临时上下文速度倍率，例如地形区域、机关、脚下效果；后压入的倍率优先生效。
        /// </summary>
        public void SetContextSpeedMultiplier(float multiplier)
        {
            motionRuntime.SetContextSpeedMultiplier(multiplier);
        }

        /// <summary>
        /// 移除最近一次上下文速度倍率，恢复到上一层上下文；没有上下文时保持默认倍率。
        /// </summary>
        public void ResetContextSpeedMultiplier()
        {
            motionRuntime.ResetContextSpeedMultiplier();
        }

        /// <summary>
        /// 清空所有临时上下文速度倍率，通常用于场景切换、复活或外部区域强制收尾。
        /// </summary>
        public void ClearContextSpeedMultipliers()
        {
            motionRuntime.ClearContextSpeedMultipliers();
        }

        /// <summary>
        /// 清空当前普通移动和导航移动状态。
        /// 吸收 uMMORPG `Movement.Reset()` 的“立刻停住并清掉当前移动命令”语义，
        /// 但继续沿用当前 Rigidbody2D + MoveOrder 真相源，不引入 NavMesh 或第二套控制器。
        /// </summary>
        public void ResetMovement()
        {
            motionRuntime.ResetMovement();
        }

        /// <summary>
        /// 禁止或恢复普通移动输入。强制位移和推力有独立生命周期，不通过这个开关隐藏。
        /// </summary>
        public void SetMovementForbidden(bool movementForbidden)
        {
            m_movementForbidden = movementForbidden;

            if (movementForbidden)
            {
                ResetMovement();
            }
        }

        /// <summary>
        /// 普通移动输入是否被动作层禁止；强制位移和推力不通过这个状态表达。
        /// </summary>
        public bool IsMovementForbidden() => m_movementForbidden;

        /// <summary>
        /// 当前是否存在 MoveTo 指令。能力权限可用它阻断需要玩家完全自由控制的能力。
        /// </summary>
        public bool HasMoveOrder() => motionRuntime.HasMoveOrder();

        protected virtual void FixedUpdate()
        {
            activeController?.FixedUpdate();

            // Convenient if we want to disable all movements/physics for a character
            // For instance, a character that is not supposed to move or be pushed,
            // and is positioned on top of a suposedly collidable object.
            if (!m_disableAllMovements)
            {
                motionRuntime.HandleWallCollision();
                motionRuntime.HandleMovement();
                motionRuntime.HandlePush();
            }
        }

        public void SetMovementDirection(Vector2 direction)
        {
            motionRuntime.SetMovementDirection(direction);
        }

        public virtual bool CanUpdateTargetDirection() => !IsMarkedAsDestroyed();
        public virtual bool CanMove() => !m_disableAllMovements && !m_movementForbidden && !IsPushed() && (!IsMarkedAsDestroyed() || m_canMoveDuringDeath);

        public TaskCompletionSource<bool> MoveTo(Vector2 destination, float? speedOverride = null)
        {
            return motionRuntime.MoveTo(destination, speedOverride);
        }

        /// <summary>
        /// 吸收 uMMORPG `Navigate(destination, stoppingDistance)` 的停止半径合同：
        /// 当前仍是直线 MoveOrder，不引入路径搜索，但正式允许“靠近到指定距离即算到达”。
        /// </summary>
        public TaskCompletionSource<bool> MoveTo(Vector2 destination, float stoppingDistance, float? speedOverride = null)
        {
            return motionRuntime.MoveTo(destination, stoppingDistance, speedOverride);
        }

        public bool IsMovingUp() => motionRuntime.IsMovingUp();
        public bool IsMovingDown() => motionRuntime.IsMovingDown();
        public bool IsMovingLeft() => motionRuntime.IsMovingLeft();
        public bool IsMovingRight() => motionRuntime.IsMovingRight();
        public bool IsMoving() => motionRuntime.IsMoving();

        public void LookAtTarget(Transform target)
        {
            float3 direction = target.position - transform.position;
            SetLookAtDirection(direction.xy);
        }

        public void LookAtTarget(Vector2 targetPosition)
        {
            Vector2 direction = targetPosition - (Vector2)transform.position;
            SetLookAtDirection(direction);
        }

        public void SetLookAtDirection(Vector2 direction)
        {
            if (direction.magnitude > 0.0f && direction != m_lookAtDirection)
            {
                // If no target direction override is set, update the target direction to match the look-at direction.
                // This ensures the character's target direction aligns with its facing direction when no specific target direction is provided (i.e. when using a controller).
                if (!m_targetDirectionOverride.HasValue)
                {
                    m_targetDirectionChangedEvent.Invoke(direction);
                    m_animationStrategy.SetTargetDirection(direction);
                }

                m_lookAtDirection = direction;
                m_animationStrategy?.SetLookAtDirection(direction);
            }
        }

        public void SetTargetDirection(Vector2 direction)
        {
            if (CanUpdateTargetDirection())
            {
                m_targetDirectionOverride = direction;
                m_targetDirectionChangedEvent.Invoke(direction);
                m_animationStrategy?.SetTargetDirection(direction);

                if (m_lookAtDirectionUpdateStrategy == ELookAtDirectionUpdateStrategy.TargetBased)
                {
                    SetLookAtDirection(direction);
                }
            }
        }

        public void ResetTargetDirection()
        {
            m_targetDirectionOverride = null;
        }

        public Vector2 GetTargetDirection()
        {
            return m_targetDirectionOverride ?? m_lookAtDirection;
        }

        public bool TryGetGas2DFacingDirection(out Vector2 direction)
        {
            direction = GetTargetDirection();
            if (direction.sqrMagnitude <= 0.0001f)
            {
                direction = Vector2.right;
            }

            direction.Normalize();
            return true;
        }

        public bool IsPushable() => m_pushIntensityScale > 0.0f;
        public bool IsPushed() => motionRuntime.IsPushed();
        public void InterruptPush() => motionRuntime.InterruptPush();

        protected bool TryPush(DamageInputDescriptor damageInput, Vector2 velocity) => TryPush(damageInput, velocity, default);

        protected bool TryPush(DamageInputDescriptor damageInput, Vector2 velocity, DamageImpactSettings impactSettings)
        {
            bool isSelfTargeted = damageInput.TryGetSourceCharacter(out CharacterBase sourceCharacter) && sourceCharacter == this;

            bool disablePush =
                impactSettings.pushMode == EDamagePushMode.Disabled ||
                isSelfTargeted ||
                (damageInput.silent && !GameManager.Config.allowPushOnSilentHit) ||
                (damageInput.IsRegularHit && !GameManager.Config.allowPushOnRegularHit) ||
                (damageInput.IsCriticalHit && !GameManager.Config.allowPushOnCriticalHit) ||
                (damageInput.IsMissed && !GameManager.Config.allowPushOnMissedHit);


            if (!disablePush)
            {
                if (impactSettings.pushMode == EDamagePushMode.Override)
                {
                    Push(velocity.normalized, impactSettings.sanitizedPushIntensity, impactSettings.sanitizedPushResistance);
                }
                else
                {
                    Push(velocity.normalized);
                }

                return true;
            }

            return false;
        }

        public void Push(Vector2 direction, float intensity = 5.0f, float resistance = 10.0f)
        {
            motionRuntime.Push(direction, intensity, resistance);
        }

        protected override Type GetDataBlockType() => typeof(MovableDataBlock);

        protected override void OnSave(PersistableDataBlock block)
        {
            base.OnSave(block);
            MovableDataBlock movableBlock = block.As<MovableDataBlock>();
            movableBlock.lookAtDirection = m_lookAtDirection;
            movableBlock.controllerData = m_controller?.CreateDataBlock();
        }

        protected override void OnLoad(PersistableDataBlock block)
        {
            base.OnLoad(block);
            var movableBlock = block.As<MovableDataBlock>();
            SetLookAtDirection(movableBlock.lookAtDirection);
            m_controller?.LoadDataBlock(movableBlock.controllerData);
        }

        private void InitializeControllers()
        {
            m_controller?.Initialize(this);
        }

        private void TerminateControllers()
        {
            m_controller?.Terminate();
        }

        private void StartActiveController()
        {
            activeController?.Start();
        }

        private void StopActiveController()
        {
            activeController?.Stop();
        }

        private void SetActiveControllerOverride(IController controller)
        {
            IController previousController = activeController;
            IController nextController = controller ?? m_controller;

            if (ReferenceEquals(previousController, nextController))
            {
                m_activeControllerOverride = controller;
                return;
            }

            if (isActiveAndEnabled)
            {
                previousController?.Stop();
            }

            m_activeControllerOverride = controller;

            if (isActiveAndEnabled && !IsMarkedAsDestroyed())
            {
                nextController?.Start();
            }
        }

    }
}

