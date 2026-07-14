using System;
using ContextSteering2D;
using UnityEngine;

namespace FantasyWord.GameCore
{
    public partial class AIController
    {
        /// <summary>
        /// `AIController` 的内部业务行为模块。
        /// 这里只维护目标、攻击和追击状态；转向求解、检测和局部避让统一交给 ContextSteering2D 世界模拟。
        /// </summary>
        private sealed class BehaviourRuntime
        {
            private const float MinimumNavigationWaypointTolerance = 0.3f;

            private readonly AIController m_owner;
            private CharacterSteeringRuntime2D m_steeringAdapter = null;
            private readonly CharacterSteeringPathCursor2D m_pathCursor = new();
            private Vector2 m_steeringAverageOutput = Vector2.zero;
            private Vector2 m_targetPosition = Vector2.zero;
            private float m_navigationRepathTimer;

            public BehaviourRuntime(AIController owner)
            {
                m_owner = owner;
            }

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
            }

            public void Stop()
            {
                InvalidateNavigationPath();
                m_steeringAdapter?.Stop();
            }

            public void Dispose()
            {
                m_steeringAdapter?.Dispose();
                m_steeringAdapter = null;
            }

            public void TryHandleProvoked(CharacterBase source)
            {
                if (source && !m_owner.m_target && m_owner.m_retargetCooldownTimer == 0.0f && CombatSolver.IsJudiciousTarget(m_owner.m_subject, source))
                {
                    m_owner.m_target = source;
                }
            }

            public void Tick()
            {
                UpdateCooldowns();
                RefreshTarget();
                UpdateTargetPosition();
                ApplyMovement();
            }

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

            private void RefreshTarget()
            {
                // 当前正式真相仍是“控制器自己维护当前追敌目标和冷却”，不额外升成项目级事件或系统。
                if (m_owner.m_target && (m_owner.m_target.dead || !CombatSolver.IsJudiciousTarget(m_owner.m_subject, m_owner.m_target)))
                {
                    m_owner.m_target = null;
                }

                if (!m_owner.m_target)
                {
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

            private void TryAttackTarget(float distanceToTarget)
            {
                if (CanSee(m_owner.m_target) && m_owner.m_attackCooldownTimer == 0.0f && distanceToTarget < m_owner.m_attackTriggerRadius)
                {
                    if (m_owner.m_subject.TryGetFirstTriggerableFormalGasAbilityCode(out int formalGasAbilityCode))
                    {
                        Vector2 attackDirection = m_owner.m_target.transform.position - m_owner.transform.position;
                        if (attackDirection.sqrMagnitude > 0.0001f)
                        {
                            attackDirection.Normalize();
                            m_owner.m_subject.SetLookAtDirection(attackDirection);
                            m_owner.m_subject.SetTargetDirection(attackDirection);
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
                }
            }

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

            private void StopChase(float retargetCooldown)
            {
                m_owner.m_retargetCooldownTimer = retargetCooldown;
                m_owner.m_target = null;
                InvalidateNavigationPath();
            }

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

                if (distanceToDestination <= finalApproachDistance)
                {
                    string finalGroupId = m_owner.m_target
                        ? m_owner.m_targetPursuitSteeringGroupId
                        : m_owner.m_steeringProfile.DefaultGroupIdValue;
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
                        m_owner.m_subject.transform.right,
                        finalGroupId,
                        m_owner.m_detectionRadius,
                        soughtDistance);
                    m_steeringAdapter.ApplyLatestResult();

                    if (m_owner.m_subject.CanMove())
                    {
                        m_owner.m_subject.LookAtTarget(m_targetPosition);
                    }
                    return;
                }

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
                        m_owner.m_subject.transform.right,
                        semanticQueryRadius: m_owner.m_detectionRadius);
                    m_owner.m_subject.SetSteeringMotion(1.0f, Vector2.zero);
                    m_owner.m_subject.SetMovementDirection(Vector2.zero);
                    return;
                }

                Vector2 forward = m_owner.m_subject.IsMoving()
                    ? m_steeringAverageOutput
                    : (steeringTarget - currentPosition);
                if (forward.sqrMagnitude <= 0.0001f)
                {
                    forward = m_owner.m_subject.transform.right;
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
                m_steeringAverageOutput = m_steeringAdapter.LatestResult.SafeDirection;
                m_steeringAdapter.ApplyLatestResult();
            }

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

            private void InvalidateNavigationPath()
            {
                m_pathCursor.Clear();
                m_navigationRepathTimer = 0.0f;
            }
        }
    }
}
