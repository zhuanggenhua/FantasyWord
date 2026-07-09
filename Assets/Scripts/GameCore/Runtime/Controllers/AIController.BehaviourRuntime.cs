using System;
using System.Collections.Generic;
using UnityEngine;

namespace FantasyWord.GameCore
{
    public partial class AIController
    {
        /// <summary>
        /// `AIController` 的内部行为执行模块。
        /// 这里只收口视野检测、追敌裁决、转向数组和避障执行，不替代 `AIController` 自己的正式控制器入口或可持久化追敌状态。
        /// </summary>
        private sealed class BehaviourRuntime
        {
            private readonly AIController m_owner;
            private readonly List<RaycastHit2D> m_castCollisions = new();
            private readonly float[] m_interests = new float[8];
            private readonly float[] m_dangers = new float[8];
            private readonly float[] m_steering = new float[8];
            private readonly Vector2[] m_directions =
            {
                Vector2.up,
                new Vector2(0.5f, 0.5f).normalized,
                Vector3.right,
                new Vector2(0.5f, -0.5f).normalized,
                Vector2.down,
                new Vector2(-0.5f, -0.5f).normalized,
                Vector2.left,
                new Vector2(-0.5f, 0.5f).normalized,
            };

            private Rigidbody2D m_rigidbody = null;
            private Vector2 m_steeringAverageOutput = Vector2.zero;
            private Vector2 m_targetPosition = Vector2.zero;
            private Vector2 m_lerpedTargetDirection = Vector2.zero;

            public BehaviourRuntime(AIController owner)
            {
                m_owner = owner;
            }

            public void Initialize()
            {
                m_rigidbody = m_owner.m_subject.GetComponent<Rigidbody2D>();
                m_owner.m_initialPosition = m_owner.m_subject.transform.position;

                Debug.Assert(m_owner.m_subject is CharacterBase, "AIController can only be attached to a CharacterBase");
                Debug.Assert(m_rigidbody != null, "No rigidbody found attached to this character");
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

            public void DrawGizmos()
            {
                for (int i = 0; i < m_directions.Length; ++i)
                {
                    Gizmos.color = m_steering[i] > 0.0f ? Color.green : Color.red;
                    Gizmos.DrawRay(m_owner.transform.position, m_directions[i] * Mathf.Abs(m_steering[i]));
                }

                Gizmos.color = Color.yellow;
                Gizmos.DrawRay(m_owner.transform.position, m_steeringAverageOutput);

                if (m_owner.m_target)
                {
                    Gizmos.color = CanSee(m_owner.m_target) ? Color.cyan : Color.magenta;
                    Gizmos.DrawLine(m_owner.transform.position, m_owner.m_target.transform.position);
                }
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
                RaycastHit2D[] hits = Physics2D.CircleCastAll(m_owner.transform.position, m_owner.m_detectionRadius, Vector2.zero, 0.0f);

                foreach (RaycastHit2D hit in hits)
                {
                    if (hit.transform.TryGetComponent(out CharacterBase potentialTarget) &&
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
                        m_owner.m_subject.SetTargetDirection((m_owner.m_target.transform.position - m_owner.transform.position).normalized);
                        m_owner.m_subject.FireFormalGasAbility(formalGasAbilityCode, GameCommandContext.AI(m_owner.m_subject));
                        m_owner.m_attackCooldownTimer = m_owner.m_attackCooldown;
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

                if (Vector2.Distance(m_owner.transform.position, m_targetPosition) > soughtDistance)
                {
                    m_steeringAverageOutput = Vector2.zero;

                    for (int i = 0; i < m_directions.Length; ++i)
                    {
                        ProcessSteeringBehaviour(i);
                        m_steeringAverageOutput += m_directions[i] * m_steering[i];
                    }

                    m_steeringAverageOutput.Normalize();

                    m_lerpedTargetDirection =
                        !m_owner.m_subject.IsMoving() ?
                        m_steeringAverageOutput :
                        Vector2.Lerp(m_lerpedTargetDirection, m_steeringAverageOutput, Time.fixedDeltaTime * m_owner.m_steeringDriftResponsiveness);

                    m_owner.m_subject.SetMovementDirection(m_lerpedTargetDirection.normalized);
                    return;
                }

                m_owner.m_subject.SetMovementDirection(Vector2.zero);

                if (m_owner.m_subject.CanMove())
                {
                    m_owner.m_subject.LookAtTarget(m_targetPosition);
                }
            }

            private void ProcessSteeringBehaviour(int index)
            {
                ProcessChaseBehaviour(index);
                ProcessAvoidBehaviour(index);
                m_steering[index] = m_interests[index] - m_dangers[index];
            }

            private void ProcessChaseBehaviour(int index)
            {
                Vector2 direction = m_directions[index];
                Vector2 currentPosition = m_owner.transform.position;
                Vector2 directionToTarget = m_targetPosition - currentPosition;
                directionToTarget.Normalize();

                float angleToTargetDirection = Vector2.Angle(direction, directionToTarget);
                m_interests[index] = Math.Max(1.0f - (angleToTargetDirection / 90.0f), 0.0f);
            }

            private void ProcessAvoidBehaviour(int index)
            {
                Vector2 direction = m_directions[index];

                int count = m_rigidbody.Cast(
                    direction,
                    GameManager.Config.collisionContactFilter,
                    m_castCollisions,
                    1.0f);

                m_dangers[index] = count > 0 ? 1.0f - m_castCollisions[0].distance : 0.0f;
            }
        }
    }
}
