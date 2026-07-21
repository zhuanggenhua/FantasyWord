using System;
using ContextSteering2D;
using UnityEngine;

namespace FantasyWord.GameCore
{
    public partial class AIController
    {
        /// <summary>
        /// `AIController` 的内部业务行为模块。
        /// 这里只维护目标、攻击和战斗移动状态；转向求解、检测和局部避让统一交给 ContextSteering2D 世界模拟。
        /// </summary>
        private sealed class BehaviourRuntime
        {
            // 路径点容差下限。太小会让像素角色在格点附近抖动或反复重算路径。
            private const float MinimumNavigationWaypointTolerance = 0.3f;

            // 外层 AIController 是所有配置、目标和存档计时器的 owner。
            private readonly AIController m_owner;
            // ContextSteering2D 适配器，负责检测、方向评分和把结果写回角色移动。
            private CharacterSteeringRuntime2D m_steeringAdapter = null;
            // 地形导航路径游标。只缓存当前目标点的路径，不写入存档。
            private readonly CharacterSteeringPathCursor2D m_pathCursor = new();
            // 近身战斗游走运行时，独立保存随机游走意图和节奏。
            private readonly CombatWanderRuntime2D m_combatWander = new();
            // 最近一次 steering 输出方向。角色静止时会拿它作为下一次前向参考，减少方向跳变。
            private Vector2 m_steeringAverageOutput = Vector2.zero;
            // 当前追踪位置。看不见目标时保持最后一次可见位置，空目标时回到 home。
            private Vector2 m_targetPosition = Vector2.zero;
            // 下一次允许重算导航路径前的计时器。
            private float m_navigationRepathTimer;
            // 攻击前对准门禁。为 true 时 AI 会优先 FaceTarget，等下一次攻击判断再真正开火。
            private bool m_waitingForAttackFacing = false;

            /// <summary>
            /// 创建 AI 行为运行时。
            /// owner 不做空兜底，因为该运行时只允许由 AIController 自己延迟创建。
            /// </summary>
            public BehaviourRuntime(AIController owner)
            {
                m_owner = owner;
            }

            /// <summary>
            /// 初始化转向适配器、记录初始归位点，并校验所有会被用到的 steering 行为组。
            /// 配置缺失在这里直接抛错，避免运行中静默切回错误行为组。
            /// </summary>
            public void Initialize()
            {
                m_owner.m_initialPosition = m_owner.m_subject.transform.position;

                if (m_owner.m_subject is not CharacterBase character)
                {
                    throw new InvalidOperationException("AIController can only be attached to a CharacterBase.");
                }

                m_steeringAdapter = new CharacterSteeringRuntime2D(character, m_owner.m_steeringProfile);
                ValidateSteeringGroupMapping(m_owner.m_transitSteeringGroupId, "中间路线");
                ValidateSteeringGroupMapping(m_owner.m_targetPursuitSteeringGroupId, "移动目标追击");
                if (m_owner.ShouldUseCombatWander)
                {
                    ValidateSteeringGroupMapping(m_owner.m_combatWanderSteeringGroupId, "战斗游走");
                }
                if (m_owner.ShouldUseTargetOrbitSteeringAtSoughtDistance)
                {
                    ValidateSteeringGroupMapping(m_owner.TargetOrbitSteeringGroupIdValue, "近身环绕");
                }
            }

            /// <summary>
            /// 停止当前行为运行时。
            /// 清路径、游走和等待攻击对准状态，保证下一次接管不会沿用旧目标动作。
            /// </summary>
            public void Stop()
            {
                InvalidateNavigationPath();
                m_waitingForAttackFacing = false;
                m_combatWander.Reset();
                m_steeringAdapter?.Stop();
            }

            /// <summary>
            /// 释放 ContextSteering2D 适配器。
            /// Dispose 后不会保留检测列表或运动输出，外层重新启用时会重新初始化。
            /// </summary>
            public void Dispose()
            {
                m_steeringAdapter?.Dispose();
                m_steeringAdapter = null;
            }

            /// <summary>
            /// 处理被挑衅事件。
            /// 只有当前没有目标且重新选敌冷却结束时，才允许挑衅来源成为新目标。
            /// </summary>
            public void TryHandleProvoked(CharacterBase source)
            {
                if (source && !m_owner.m_target && m_owner.m_retargetCooldownTimer == 0.0f && CombatSolver.IsJudiciousTarget(m_owner.m_subject, source))
                {
                    m_owner.m_target = source;
                }
            }

            /// <summary>
            /// 固定步推进 AI 行为。
            /// 顺序固定为冷却、目标、目标位置、移动，后续逻辑不要绕开这个节奏单独开火或移动。
            /// </summary>
            public void Tick()
            {
                UpdateCooldowns();
                RefreshTarget();
                UpdateTargetPosition();
                ApplyMovement();
            }

            /// <summary>
            /// 判断目标是否有直线视线。
            /// 这里只用项目配置的 visibilityContactFilter，避免 AI 自己维护第二套遮挡层规则。
            /// </summary>
            private bool CanSee(CharacterBase other)
            {
                Vector2 targetPosition = other.transform.position;
                Vector2 currentPosition = m_owner.transform.position;
                Vector2 directionToTarget = targetPosition - currentPosition;
                RaycastHit2D hit = Physics2D.Raycast(
                    currentPosition,
                    directionToTarget,
                    Vector2.Distance(currentPosition, targetPosition),
                    GameManager.Config.visibilityContactFilter.layerMask);
                return hit.collider == null;
            }

            /// <summary>
            /// 从 steering 检测列表里选择第一个可见且敌对的目标。
            /// 当前保持简单优先级，不在这里引入仇恨表或全局目标系统。
            /// </summary>
            private CharacterBase FindTarget()
            {
                foreach (Collider2D collider in m_steeringAdapter.DetectedColliders)
                {
                    CharacterBase potentialTarget = collider != null ? collider.GetComponentInParent<CharacterBase>() : null;
                    if (potentialTarget != null &&
                        CombatSolver.IsHostileTowards(m_owner.m_subject, potentialTarget) &&
                        CanSee(potentialTarget))
                    {
                        return potentialTarget;
                    }
                }

                return null;
            }

            /// <summary>
            /// 推进重新选敌、攻击和重新寻路冷却。
            /// 使用 fixedDeltaTime 保持和 FixedUpdate 驱动一致。
            /// </summary>
            private void UpdateCooldowns()
            {
                if (m_owner.m_retargetCooldownTimer > 0.0f)
                {
                    m_owner.m_retargetCooldownTimer = Math.Max(m_owner.m_retargetCooldownTimer - Time.fixedDeltaTime, 0.0f);
                }

                if (m_owner.m_attackCooldownTimer > 0.0f)
                {
                    m_owner.m_attackCooldownTimer = Math.Max(m_owner.m_attackCooldownTimer - Time.fixedDeltaTime, 0.0f);
                }

                if (m_navigationRepathTimer > 0.0f)
                {
                    m_navigationRepathTimer = Math.Max(m_navigationRepathTimer - Time.fixedDeltaTime, 0.0f);
                }
            }

            /// <summary>
            /// 刷新当前目标，并在目标有效时尝试攻击和越界检查。
            /// 目标死亡或不再是合理攻击对象时会立即清空，等待冷却后再重新搜索。
            /// </summary>
            private void RefreshTarget()
            {
                // 当前正式真相仍是“控制器自己维护当前追敌目标和冷却”，不额外升成项目级事件或系统。
                if (m_owner.m_target && (m_owner.m_target.dead || !CombatSolver.IsJudiciousTarget(m_owner.m_subject, m_owner.m_target)))
                {
                    m_owner.m_target = null;
                    m_waitingForAttackFacing = false;
                }

                if (!m_owner.m_target)
                {
                    m_waitingForAttackFacing = false;
                    if (m_owner.m_retargetCooldownTimer == 0.0f)
                    {
                        m_owner.m_target = FindTarget();
                    }

                    return;
                }

                float distanceToTarget = Vector2.Distance(m_owner.m_target.transform.position, m_owner.transform.position);
                TryAttackTarget(distanceToTarget);
                CheckIfTargetOutOfRange(distanceToTarget);
            }

            /// <summary>
            /// 尝试对当前目标释放第一项可触发正式能力。
            /// 视线、冷却、距离、可触发能力和攻击朝向全部通过后才会真正提交 AI 命令。
            /// </summary>
            private void TryAttackTarget(float distanceToTarget)
            {
                if (!m_owner.m_target ||
                    !CanSee(m_owner.m_target) ||
                    m_owner.m_attackCooldownTimer != 0.0f ||
                    distanceToTarget >= m_owner.m_attackTriggerRadius)
                {
                    m_waitingForAttackFacing = false;
                    return;
                }

                if (!m_owner.m_subject.TryGetFirstTriggerableFormalGasAbilityCode(out int formalGasAbilityCode))
                {
                    m_waitingForAttackFacing = false;
                    return;
                }

                Vector2 attackDirection = m_owner.m_target.transform.position - m_owner.transform.position;
                if (attackDirection.sqrMagnitude <= 0.0001f)
                {
                    m_waitingForAttackFacing = false;
                    return;
                }

                attackDirection.Normalize();
                m_owner.m_subject.SetTargetDirection(attackDirection);
                if (!PrepareAttackFacing(attackDirection))
                {
                    return;
                }

                m_owner.m_subject.StopFireFormalGasAbility(formalGasAbilityCode);
                EAbilityFireCheckResult fireResult = m_owner.m_subject.FireFormalGasAbility(
                    formalGasAbilityCode,
                    GameCommandContext.AI(m_owner.m_subject));
                if (fireResult == EAbilityFireCheckResult.Valid)
                {
                    m_owner.m_attackCooldownTimer = m_owner.m_attackCooldown;
                }
            }

            /// <summary>
            /// 处理攻击前身体朝向门禁。
            /// 返回 false 表示本帧只推进朝向，攻击留到下一次 Tick 再判断。
            /// </summary>
            private bool PrepareAttackFacing(Vector2 attackDirection)
            {
                if (!m_owner.ShouldRequireTargetFacingBeforeAttack)
                {
                    m_waitingForAttackFacing = false;
                    m_owner.m_subject.SetLookAtDirection(attackDirection);
                    return true;
                }

                if (AIController.IsAttackFacingAligned(
                        m_owner.m_subject.GetLookAtDirection(),
                        attackDirection,
                        m_owner.AttackFacingCompletionAngleDegrees))
                {
                    m_waitingForAttackFacing = false;
                    return true;
                }

                // 对齐 duolafashi TurnTargetNode：未面向目标时只推进身体朝向，本次攻击保持等待。
                m_waitingForAttackFacing = true;
                m_owner.m_subject.SetLookAtDirection(attackDirection);
                return false;
            }

            /// <summary>
            /// 检查 AI 是否离归位点或目标过远。
            /// 任一距离超限都会停止追击，并进入越界重新选敌冷却。
            /// </summary>
            private void CheckIfTargetOutOfRange(float distanceToTarget)
            {
                float distanceToInitialPosition = Vector2.Distance(m_owner.m_homePosition, m_owner.transform.position);
                bool isTooFarFromInitialPosition = distanceToInitialPosition > m_owner.m_resetFromInitialPositionRadius;
                bool isTooFarFromTarget = distanceToTarget > m_owner.m_resetFromTargetDistanceRadius;

                if (isTooFarFromInitialPosition || isTooFarFromTarget)
                {
                    StopChase(m_owner.m_targetOutOfRangeRetargetCooldown);
                }
            }

            /// <summary>
            /// 停止当前追击并设置重新选敌冷却。
            /// 清掉路径可以避免下一个目标沿用旧目标的导航结果。
            /// </summary>
            private void StopChase(float retargetCooldown)
            {
                m_owner.m_retargetCooldownTimer = retargetCooldown;
                m_owner.m_target = null;
                m_waitingForAttackFacing = false;
                InvalidateNavigationPath();
            }

            /// <summary>
            /// 更新 steering 追踪位置。
            /// 有目标时使用最后一次可见位置；无目标时回到 homePosition。
            /// </summary>
            private void UpdateTargetPosition()
            {
                if (m_owner.m_target)
                {
                    // 一旦失去视线，AI 仍先朝最后一次确认的位置追一段时间，而不是立刻原地丢失目标。
                    if (CanSee(m_owner.m_target))
                    {
                        m_targetPosition = (Vector2)m_owner.m_target.transform.position;
                        m_owner.m_timeSinceTargetLastSeen = 0.0f;
                    }
                    else
                    {
                        m_owner.m_timeSinceTargetLastSeen += Time.deltaTime;

                        if (m_owner.m_timeSinceTargetLastSeen > m_owner.m_timeBeforeResetAfterTargetSightLost)
                        {
                            StopChase(m_owner.m_cannotSeeTargetRetargetCooldown);
                        }
                    }
                }
                else
                {
                    m_targetPosition = m_owner.m_homePosition;
                }
            }

            /// <summary>
            /// 根据当前目标位置提交 steering 移动。
            /// 这里统一处理战斗游走、近身环绕、地形导航和无路径停步四种情况。
            /// </summary>
            private void ApplyMovement()
            {
                float soughtDistance =
                    m_owner.m_target ?
                    m_owner.m_soughtDistanceFromTarget :
                    m_owner.m_soughtDistanceFromMasterTarget;
                Vector2 currentPosition = m_owner.transform.position;
                float distanceToDestination = Vector2.Distance(currentPosition, m_targetPosition);
                float finalApproachDistance = soughtDistance +
                    ResolveNavigationWaypointTolerance();

                // 战斗游走优先于普通追击，避免目标已经进近身范围后仍持续 Arrive 挤压目标。
                if (CombatWanderRuntime2D.ShouldUse(
                        m_owner.ShouldUseCombatWander,
                        m_owner.m_target,
                        distanceToDestination,
                        m_owner.m_combatWanderRange))
                {
                    SteeringWanderIntent2D wanderIntent = m_combatWander.Tick(
                        Time.fixedDeltaTime,
                        m_owner.m_attackTriggerRadius,
                        m_owner.m_combatWanderRange);
                    Vector2 targetVelocity = Vector2.zero;
                    if (m_owner.m_target.TryGetComponent(out Rigidbody2D wanderTargetBody))
                    {
                        targetVelocity = wanderTargetBody.linearVelocity;
                    }

                    m_steeringAdapter.Submit(
                        true,
                        m_targetPosition,
                        targetVelocity,
                        ResolveSubjectForward(),
                        m_owner.m_combatWanderSteeringGroupId,
                        m_owner.m_detectionRadius,
                        speedMultiplier: m_owner.m_combatWanderSpeedMultiplier,
                        wanderIntent: wanderIntent);
                    m_steeringAdapter.ApplyLatestResult();
                    m_steeringAverageOutput = m_steeringAdapter.LatestResult.SafeDirection;
                    ApplySubjectFacing(m_owner.CombatWanderFacingMode, m_steeringAverageOutput);
                    return;
                }

                // 接近最终目标时直接使用最终行为组，不再绕地形路径点，避免近身阶段转向被中间路径点拉走。
                if (distanceToDestination <= finalApproachDistance)
                {
                    bool useTargetOrbit =
                        m_owner.m_target &&
                        m_owner.ShouldUseTargetOrbitSteeringAtSoughtDistance;
                    string finalGroupId = useTargetOrbit
                        ? m_owner.TargetOrbitSteeringGroupIdValue
                        : (m_owner.m_target
                            ? m_owner.m_targetPursuitSteeringGroupId
                            : m_owner.m_steeringProfile.DefaultGroupIdValue);
                    Vector2 targetVelocity = Vector2.zero;
                    if (m_owner.m_target &&
                        m_owner.m_target.TryGetComponent(out Rigidbody2D targetBody))
                    {
                        targetVelocity = targetBody.linearVelocity;
                    }

                    m_steeringAdapter.Submit(
                        true,
                        m_targetPosition,
                        targetVelocity,
                        ResolveSubjectForward(),
                        finalGroupId,
                        m_owner.m_detectionRadius,
                        soughtDistance);
                    m_steeringAdapter.ApplyLatestResult();
                    m_steeringAverageOutput = m_steeringAdapter.LatestResult.SafeDirection;
                    ApplySubjectFacing(ResolveActiveFacingMode(), m_steeringAverageOutput);
                    return;
                }

                // 远距离追踪走地形导航；如果没有可用路径，明确提交停步结果，避免沿用上一帧 steering 输出。
                if (!TryResolveSteeringTarget(
                        currentPosition,
                        m_targetPosition,
                        out Vector2 steeringTarget,
                        out string behaviourGroupId,
                        out bool isFinalTarget))
                {
                    m_steeringAdapter.Submit(
                        false,
                        null,
                        Vector2.zero,
                        ResolveSubjectForward(),
                        semanticQueryRadius: m_owner.m_detectionRadius);
                    m_owner.m_subject.SetSteeringMotion(1.0f, Vector2.zero);
                    m_owner.m_subject.SetSteeringMovementDirection(Vector2.zero);
                    return;
                }

                Vector2 forward = m_owner.m_subject.IsMoving()
                    ? m_steeringAverageOutput
                    : (steeringTarget - currentPosition);
                if (forward.sqrMagnitude <= 0.0001f)
                {
                    forward = ResolveSubjectForward();
                }

                Vector2 resolvedTargetVelocity = Vector2.zero;
                if (isFinalTarget &&
                    m_owner.m_target &&
                    m_owner.m_target.TryGetComponent(out Rigidbody2D resolvedTargetBody))
                {
                    resolvedTargetVelocity = resolvedTargetBody.linearVelocity;
                }

                m_steeringAdapter.Submit(
                    true,
                    steeringTarget,
                    resolvedTargetVelocity,
                    forward,
                    behaviourGroupId,
                    m_owner.m_detectionRadius,
                    isFinalTarget ? soughtDistance : -1.0f);
                m_steeringAdapter.ApplyLatestResult();
                m_steeringAverageOutput = m_steeringAdapter.LatestResult.SafeDirection;
                ApplySubjectFacing(ResolveActiveFacingMode(), m_steeringAverageOutput);
            }

            /// <summary>
            /// 解析当前身体朝向模式。
            /// 攻击等待对准时强制面向目标，其余场景按追击/移动状态选择配置。
            /// </summary>
            private AICharacterFacingMode2D ResolveActiveFacingMode()
            {
                if (m_waitingForAttackFacing)
                {
                    return AICharacterFacingMode2D.FaceTarget;
                }

                return m_owner.m_target
                    ? m_owner.TargetPursuitFacingMode
                    : AICharacterFacingMode2D.FaceMovement;
            }

            /// <summary>
            /// 解析 steering 前向参考。
            /// 优先使用角色当前 LookAtDirection，缺失时回退到 Transform.right。
            /// </summary>
            private Vector2 ResolveSubjectForward()
            {
                Vector2 lookAtDirection = m_owner.m_subject.GetLookAtDirection();
                if (lookAtDirection != Vector2.zero)
                {
                    return lookAtDirection.normalized;
                }

                return m_owner.m_subject.transform.right;
            }

            /// <summary>
            /// 应用身体朝向。
            /// 角色当前不能移动时不改朝向，避免动作锁期间 AI 抢走表现层控制权。
            /// </summary>
            private void ApplySubjectFacing(AICharacterFacingMode2D facingMode, Vector2 movementDirection)
            {
                if (!m_owner.m_subject.CanMove())
                {
                    return;
                }

                switch (facingMode)
                {
                    case AICharacterFacingMode2D.FaceTarget:
                        if (m_owner.m_target)
                        {
                            m_owner.m_subject.LookAtTarget(m_targetPosition);
                        }
                        break;
                    case AICharacterFacingMode2D.FaceMovement:
                        if (movementDirection != Vector2.zero)
                        {
                            m_owner.m_subject.SetLookAtDirection(movementDirection.normalized);
                        }
                        break;
                    case AICharacterFacingMode2D.KeepCurrent:
                    default:
                        break;
                }
            }

            /// <summary>
            /// 解析本帧 steering 目标点和行为组。
            /// 有地形导航图时优先走路径游标；无导航图时直接把最终位置交给 steering。
            /// </summary>
            private bool TryResolveSteeringTarget(
                Vector2 currentPosition,
                Vector2 finalDestination,
                out Vector2 steeringTarget,
                out string behaviourGroupId,
                out bool isFinalTarget)
            {
                steeringTarget = finalDestination;
                behaviourGroupId = m_owner.m_steeringProfile.DefaultGroupIdValue;
                isFinalTarget = true;

                if (!GameManager.Exists() ||
                    !GameManager.TryGetSystem(out MapSystem mapSystem) ||
                    !mapSystem.TryGetActiveTerrainNavigationMap(out TerrainNavigationMap navigationMap))
                {
                    InvalidateNavigationPath();
                    return true;
                }

                float targetMoveThreshold = Mathf.Max(m_owner.m_navigationTargetMoveThreshold, 0.05f);
                bool destinationMoved = m_pathCursor.HasDestinationMoved(
                    finalDestination,
                    targetMoveThreshold);
                if (!m_pathCursor.HasPath ||
                    destinationMoved ||
                    m_navigationRepathTimer <= 0.0f)
                {
                    // 目标移动、路径缺失或重算冷却结束时才重新请求路径，减少每帧寻路开销。
                    m_navigationRepathTimer = Mathf.Max(m_owner.m_navigationRepathInterval, 0.1f);
                    if (!navigationMap.TryBuildWorldPathWithoutDebug(
                            currentPosition,
                            finalDestination,
                            out Vector2[] navigationPath))
                    {
                        m_pathCursor.Clear();
                        return false;
                    }

                    m_pathCursor.SetPath(navigationPath, finalDestination);
                }

                if (!m_pathCursor.TryGetTarget(
                        currentPosition,
                        ResolveNavigationWaypointTolerance(),
                        out steeringTarget,
                        out isFinalTarget))
                {
                    return false;
                }

                behaviourGroupId = isFinalTarget
                    ? (m_owner.m_target
                        ? m_owner.m_targetPursuitSteeringGroupId
                        : m_owner.m_steeringProfile.DefaultGroupIdValue)
                    : m_owner.m_transitSteeringGroupId;
                return true;
            }

            /// <summary>
            /// 解析路径点到达容差。
            /// 同时考虑 Inspector 配置、steering profile 半径和项目下限，避免容差过小导致卡点。
            /// </summary>
            private float ResolveNavigationWaypointTolerance()
            {
                float profileAgentRadius = m_owner.m_steeringProfile != null
                    ? m_owner.m_steeringProfile.AgentRadius
                    : 0.0f;
                return Mathf.Max(
                    m_owner.m_navigationWaypointTolerance,
                    profileAgentRadius,
                    MinimumNavigationWaypointTolerance);
            }

            /// <summary>
            /// 校验配置的 steering 行为组 ID 是否存在。
            /// 缺失时直接抛出带用途的错误，方便定位是哪一类 AI 行为没配。
            /// </summary>
            private void ValidateSteeringGroupMapping(string groupId, string usage)
            {
                if (string.IsNullOrWhiteSpace(groupId))
                {
                    throw new InvalidOperationException($"AIController 的{usage}未配置 ContextSteering 行为组 ID。");
                }

                try
                {
                    m_owner.m_steeringProfile.GetBehaviourGroup(groupId);
                }
                catch (InvalidOperationException exception)
                {
                    throw new InvalidOperationException(
                        $"AIController 的{usage}配置为行为组 '{groupId}'，但 Profile '{m_owner.m_steeringProfile.name}' 中不存在该组。",
                        exception);
                }
            }

            /// <summary>
            /// 让当前导航路径失效，并允许下一帧立即重新规划。
            /// </summary>
            private void InvalidateNavigationPath()
            {
                m_pathCursor.Clear();
                m_navigationRepathTimer = 0.0f;
            }
        }
    }
}
