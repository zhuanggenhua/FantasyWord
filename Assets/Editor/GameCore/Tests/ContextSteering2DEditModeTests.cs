using System;
using System.Collections.Generic;
using ContextSteering2D;
using NUnit.Framework;
using UnityEditor;
using UnityEngine;

namespace FantasyWord.GameCore.Tests
{
    public sealed class ContextSteering2DEditModeTests
    {
        private const string DefaultProfilePath = "Assets/Plugins/ContextSteering2D/Runtime/Defaults/DefaultContextSteeringProfile2D.asset";
        private const string GameConfigPath = "Assets/GameData/GameCore/GameConfig.asset";
        private const string CharacterBasePrefabPath = "Assets/Prefabs/Entities/Characters/0_Character_Base.prefab";
        private const string TransitGroupId = "transit";
        private const string PredictiveTargetGroupId = "predictive-target";

        [Test]
        public void GameConfig_UsesDedicatedCharacterFilterForSteeringNeighbours()
        {
            GameConfig config = AssetDatabase.LoadAssetAtPath<GameConfig>(GameConfigPath);
            int characterLayer = LayerMask.NameToLayer("Character");

            Assert.That(config, Is.Not.Null);
            Assert.That(characterLayer, Is.GreaterThanOrEqualTo(0));
            Assert.That(config.steeringNeighbourContactFilter.useLayerMask, Is.True);
            Assert.That(
                config.steeringNeighbourContactFilter.layerMask.value & (1 << characterLayer),
                Is.Not.Zero);
            Assert.That(
                config.collisionContactFilter.layerMask.value & (1 << characterLayer),
                Is.Zero,
                "角色接触由 RVO2 + PBD 统一处理，地形移动查询不得再次解析 Character。");
            Assert.That(
                config.steeringNeighbourContactFilter.layerMask.value,
                Is.Not.EqualTo(config.collisionContactFilter.layerMask.value));
        }

        [Test]
        public void Physics2DSettings_DisablesCharacterSelfCollisionForCentralizedContactResolution()
        {
            int characterLayer = LayerMask.NameToLayer("Character");

            Assert.That(characterLayer, Is.GreaterThanOrEqualTo(0));
            Assert.That(Physics2D.GetIgnoreLayerCollision(characterLayer, characterLayer), Is.True);
        }

        [Test]
        public void CharacterBasePrefab_UsesTriggerHitboxSoPbdOwnsBodyContacts()
        {
            GameObject prefab = AssetDatabase.LoadAssetAtPath<GameObject>(CharacterBasePrefabPath);
            int hitboxLayer = LayerMask.NameToLayer("Hitbox");

            Assert.That(prefab, Is.Not.Null);
            Assert.That(hitboxLayer, Is.GreaterThanOrEqualTo(0));
            BoxCollider2D[] colliders = prefab.GetComponentsInChildren<BoxCollider2D>(true);
            BoxCollider2D hitbox = Array.Find(
                colliders,
                collider => collider.gameObject.layer == hitboxLayer);

            Assert.That(hitbox, Is.Not.Null, "角色基础 prefab 缺少 Hitbox 层的受击盒。");
            Assert.That(hitbox.isTrigger, Is.True, "Hitbox 只能用于受击查询，不能参与角色实体碰撞。");
        }

        [Test]
        public void DefaultProfile_HasDefaultAndPathFollowBehaviourGroups()
        {
            ContextSteeringProfile2D profile = AssetDatabase.LoadAssetAtPath<ContextSteeringProfile2D>(DefaultProfilePath);

            Assert.That(profile, Is.Not.Null);
            Assert.DoesNotThrow(profile.ValidateOrThrow);
            Assert.That(profile.BehaviourGroups, Has.Count.EqualTo(3));
            SteeringBehaviourGroup2D group = profile.GetBehaviourGroup(ContextSteeringProfile2D.DefaultGroupId);
            Assert.That(group.Behaviours, Has.Count.EqualTo(5));
            Assert.That(group.Behaviours[0], Is.TypeOf<SeekSteeringBehaviour2D>());
            Assert.That(group.Behaviours[1], Is.TypeOf<ArriveSteeringBehaviour2D>());
            Assert.That(group.Behaviours[2], Is.TypeOf<ObstacleAvoidanceSteeringBehaviour2D>());
            Assert.That(group.Behaviours[3], Is.TypeOf<SeparationSteeringBehaviour2D>());
            Assert.That(group.Behaviours[4], Is.TypeOf<SideStepSteeringBehaviour2D>());

            SteeringBehaviourGroup2D pathFollow = profile.GetBehaviourGroup(TransitGroupId);
            Assert.That(pathFollow.Behaviours, Has.Count.EqualTo(4));
            Assert.That(pathFollow.Behaviours[0], Is.TypeOf<SeekSteeringBehaviour2D>());
            Assert.That(pathFollow.Behaviours[1], Is.TypeOf<ObstacleAvoidanceSteeringBehaviour2D>());
            Assert.That(pathFollow.Behaviours[2], Is.TypeOf<SeparationSteeringBehaviour2D>());
            Assert.That(pathFollow.Behaviours[3], Is.TypeOf<SideStepSteeringBehaviour2D>());
            Assert.That(pathFollow.Behaviours, Has.None.TypeOf<ArriveSteeringBehaviour2D>());

            SteeringBehaviourGroup2D pursuit = profile.GetBehaviourGroup(PredictiveTargetGroupId);
            Assert.That(pursuit.Behaviours, Has.Count.EqualTo(5));
            Assert.That(pursuit.Behaviours[0], Is.TypeOf<PursuitSteeringBehaviour2D>());
            Assert.That(pursuit.Behaviours[1], Is.TypeOf<ArriveSteeringBehaviour2D>());
            Assert.That(pursuit.Behaviours[2], Is.TypeOf<ObstacleAvoidanceSteeringBehaviour2D>());
            Assert.That(pursuit.Behaviours[3], Is.TypeOf<SeparationSteeringBehaviour2D>());
            Assert.That(pursuit.Behaviours[4], Is.TypeOf<SideStepSteeringBehaviour2D>());
        }

        [Test]
        public void MissingBehaviourGroup_ThrowsInsteadOfFallingBack()
        {
            ContextSteeringProfile2D profile = AssetDatabase.LoadAssetAtPath<ContextSteeringProfile2D>(DefaultProfilePath);
            Assert.Throws<InvalidOperationException>(() => profile.GetBehaviourGroup("missing"));
        }

        [Test]
        public void PathCursor_UsesIntermediateWaypointBeforeFinalTarget()
        {
            CharacterSteeringPathCursor2D cursor = new();
            cursor.SetPath(
                new[] { new Vector2(1.0f, 0.0f), new Vector2(1.0f, 1.0f) },
                new Vector2(1.0f, 1.0f));

            Assert.IsTrue(cursor.TryGetTarget(Vector2.zero, 0.2f, out Vector2 target, out bool isFinal));
            Assert.That(target, Is.EqualTo(new Vector2(1.0f, 0.0f)));
            Assert.IsFalse(isFinal);

            Assert.IsTrue(cursor.TryGetTarget(new Vector2(0.9f, 0.0f), 0.2f, out target, out isFinal));
            Assert.That(target, Is.EqualTo(new Vector2(1.0f, 1.0f)));
            Assert.IsTrue(isFinal);
        }

        [Test]
        public void PathCursor_ReplansOnlyAfterDestinationMovesPastThreshold()
        {
            CharacterSteeringPathCursor2D cursor = new();
            cursor.SetPath(new[] { Vector2.right }, Vector2.right);

            Assert.IsFalse(cursor.HasDestinationMoved(new Vector2(1.2f, 0.0f), 0.5f));
            Assert.IsTrue(cursor.HasDestinationMoved(new Vector2(1.5f, 0.0f), 0.5f));
            cursor.Clear();
            Assert.IsTrue(cursor.HasDestinationMoved(Vector2.right, 0.5f));
        }

        [Test]
        public void Arrive_PreservesSpeedScaleAndIndependentContributions()
        {
            ContextSteeringProfile2D profile = AssetDatabase.LoadAssetAtPath<ContextSteeringProfile2D>(DefaultProfilePath);
            ContextSteeringSolver2D solver = new(profile.SampleCount);
            SteeringDetectionFrame2D frame = new();
            frame.Reset(
                solver.DirectionSet,
                1,
                Vector2.zero,
                Vector2.right,
                Vector2.zero,
                profile,
                new Vector2(0.5f, 0.0f),
                Vector2.zero);

            SteeringResult2D result = solver.Solve(frame, profile, profile.DefaultGroupIdValue);

            Assert.That(result.SpeedScale, Is.GreaterThan(0.0f).And.LessThan(1.0f));
            Assert.That(result.PreferredVelocity.magnitude, Is.GreaterThan(0.0f).And.LessThan(profile.MaxSpeed));
            Assert.That(solver.Context.Contributions, Has.Count.GreaterThanOrEqualTo(4));
            Assert.That(solver.Context.Contributions[0].StableId, Is.EqualTo("seek"));
            Assert.That(solver.Context.Contributions[1].StableId, Is.EqualTo("arrive"));
            Assert.That(solver.Context.Contributions[0].Interest.ToArray(), Is.Not.SameAs(solver.Context.Contributions[1].Interest.ToArray()));
        }

        [Test]
        public void Arrive_IntentStopRadiusOverridesProfileDefault()
        {
            ContextSteeringProfile2D profile = AssetDatabase.LoadAssetAtPath<ContextSteeringProfile2D>(DefaultProfilePath);
            ContextSteeringSolver2D solver = new(profile.SampleCount);
            SteeringDetectionFrame2D frame = new();
            frame.Reset(
                solver.DirectionSet,
                1,
                Vector2.zero,
                Vector2.right,
                Vector2.zero,
                profile,
                new Vector2(1.1f, 0.0f),
                Vector2.zero,
                1.0f);

            SteeringResult2D slowing = solver.Solve(frame, profile, PredictiveTargetGroupId);
            Assert.That(slowing.SpeedScale, Is.GreaterThan(0.0f).And.LessThan(1.0f));

            frame.Reset(
                solver.DirectionSet,
                1,
                Vector2.zero,
                Vector2.right,
                Vector2.zero,
                profile,
                new Vector2(1.0f, 0.0f),
                Vector2.zero,
                1.0f);
            SteeringResult2D stopped = solver.Solve(frame, profile, PredictiveTargetGroupId);
            Assert.That(stopped.SpeedScale, Is.EqualTo(0.0f));
        }

        [Test]
        public void PursuitGroup_UsesPredictedDirectionWhileArriveOnlyLimitsSpeed()
        {
            ContextSteeringProfile2D profile = AssetDatabase.LoadAssetAtPath<ContextSteeringProfile2D>(DefaultProfilePath);
            ContextSteeringSolver2D solver = new(profile.SampleCount);
            SteeringDetectionFrame2D frame = new();
            frame.Reset(
                solver.DirectionSet,
                1,
                Vector2.zero,
                Vector2.right,
                Vector2.zero,
                profile,
                new Vector2(2.0f, 0.0f),
                new Vector2(0.0f, 2.0f));

            SteeringResult2D result = solver.Solve(frame, profile, PredictiveTargetGroupId);

            Assert.That(result.DesiredDirection.y, Is.GreaterThan(0.2f));
            Assert.That(solver.Context.Contributions[0].StableId, Is.EqualTo("pursuit"));
            Assert.That(solver.Context.Contributions[1].StableId, Is.EqualTo("arrive"));
            Assert.That(
                Array.TrueForAll(
                    solver.Context.Contributions[1].Interest.ToArray(),
                    value => Mathf.Approximately(value, 0.0f)),
                Is.True);
        }

        [Test]
        public void LocalAvoidance_HeadOnAgentsReceiveSafeVelocitiesWithinSpeedLimit()
        {
            List<LocalAvoidanceInput2D> inputs = new()
            {
                CreateAvoidanceInput(1, new Vector2(-1.0f, 0.0f), Vector2.right, Vector2.right, maxSpeed: 0.75f),
                CreateAvoidanceInput(2, new Vector2(1.0f, 0.0f), Vector2.left, Vector2.left, maxSpeed: 0.75f),
            };
            Vector2[] outputs = new Vector2[2];

            using Rvo2LocalAvoidanceBackend2D backend = new();
            backend.Resolve(inputs, outputs, 0.02f);

            Assert.That(outputs[0].magnitude, Is.LessThanOrEqualTo(0.7501f));
            Assert.That(outputs[1].magnitude, Is.LessThanOrEqualTo(0.7501f));
            Assert.That(Vector2.Distance(outputs[0], inputs[0].PreferredVelocity), Is.GreaterThan(0.01f));
            Assert.That(Vector2.Distance(outputs[1], inputs[1].PreferredVelocity), Is.GreaterThan(0.01f));
        }

        [Test]
        public void LocalAvoidance_RemovedAgentDoesNotCorruptRemainingAgentMapping()
        {
            List<LocalAvoidanceInput2D> inputs = new()
            {
                CreateAvoidanceInput(10, Vector2.left, Vector2.zero, Vector2.right),
                CreateAvoidanceInput(20, Vector2.right, Vector2.zero, Vector2.left),
            };
            Vector2[] outputs = new Vector2[2];

            using Rvo2LocalAvoidanceBackend2D backend = new();
            backend.Resolve(inputs, outputs, 0.02f);
            inputs.RemoveAt(0);

            Assert.DoesNotThrow(() => backend.Resolve(inputs, outputs, 0.02f));
            Assert.That(outputs[0].magnitude, Is.LessThanOrEqualTo(inputs[0].MaxSpeed + 0.0001f));
        }

        [Test]
        public void LocalAvoidance_GlobalRvoSimulatorRejectsConcurrentBackendOwners()
        {
            using Rvo2LocalAvoidanceBackend2D owner = new();

            InvalidOperationException exception = Assert.Throws<InvalidOperationException>(
                () => new Rvo2LocalAvoidanceBackend2D());

            Assert.That(exception.Message, Does.Contain("one global Simulator instance"));
        }

        [Test]
        public void AgentSpatialIndex_CollectsOnlyAgentsInsideQueryRadius()
        {
            AgentSpatialIndex2D index = new();
            Vector2[] positions =
            {
                Vector2.zero,
                new Vector2(0.75f, 0.0f),
                new Vector2(3.0f, 0.0f),
            };
            List<int> results = new();

            index.Build(positions, positions.Length, 1.0f);
            index.Collect(Vector2.zero, 1.0f, results);

            Assert.That(results, Is.EquivalentTo(new[] { 0, 1 }));
        }

        [Test]
        public void SideStep_HeadOnAgentsChooseDeterministicOppositeSides()
        {
            ContextSteeringProfile2D profile = AssetDatabase.LoadAssetAtPath<ContextSteeringProfile2D>(DefaultProfilePath);
            ContextSteeringSolver2D firstSolver = new(profile.SampleCount);
            ContextSteeringSolver2D secondSolver = new(profile.SampleCount);
            SteeringDetectionFrame2D first = new();
            SteeringDetectionFrame2D second = new();
            first.Reset(
                firstSolver.DirectionSet,
                1,
                new Vector2(-0.25f, 0.0f),
                Vector2.right,
                Vector2.zero,
                profile,
                null,
                Vector2.zero);
            second.Reset(
                secondSolver.DirectionSet,
                2,
                new Vector2(0.25f, 0.0f),
                Vector2.left,
                Vector2.zero,
                profile,
                null,
                Vector2.zero);
            first.AddNeighbour(new SteeringBody2D(2, second.Position, profile.AgentRadius));
            second.AddNeighbour(new SteeringBody2D(1, first.Position, profile.AgentRadius));
            SideStepSteeringBehaviour2D behaviour = new();
            SteeringContribution2D firstContribution = new(profile.SampleCount);
            SteeringContribution2D secondContribution = new(profile.SampleCount);

            behaviour.Evaluate(first, firstContribution);
            behaviour.Evaluate(second, secondContribution);

            Vector2 firstDirection = ResolveStrongestDirection(first.DirectionSet, firstContribution.Interest);
            Vector2 secondDirection = ResolveStrongestDirection(second.DirectionSet, secondContribution.Interest);
            Assert.That(firstDirection.y * secondDirection.y, Is.LessThan(0.0f));
        }

        [Test]
        public void ContactResolution_ExactlyOverlappingAgentsSeparateInOppositeDirections()
        {
            ContextSteeringProfile2D profile = AssetDatabase.LoadAssetAtPath<ContextSteeringProfile2D>(DefaultProfilePath);
            List<LocalAvoidanceInput2D> inputs = new()
            {
                new LocalAvoidanceInput2D(1, Vector2.zero, Vector2.zero, Vector2.zero, 1.0f, profile.AgentRadius, 1.0f, 1.0f, 1.0f, 1.0f, 2.0f, 1.0f, 8, true),
                new LocalAvoidanceInput2D(2, Vector2.zero, Vector2.zero, Vector2.zero, 1.0f, profile.AgentRadius, 1.0f, 1.0f, 1.0f, 1.0f, 2.0f, 1.0f, 8, true),
            };
            Vector2[] safeVelocities = new Vector2[2];
            Vector2[] corrections = new Vector2[2];
            PositionBasedContactResolver2D resolver = new();
            resolver.Resolve(inputs, safeVelocities, corrections, 1, 0.02f);

            Vector2 firstCorrection = corrections[0];
            Vector2 secondCorrection = corrections[1];

            Assert.That(firstCorrection.x, Is.LessThan(0.0f));
            Assert.That(secondCorrection.x, Is.GreaterThan(0.0f));
            Assert.That(firstCorrection, Is.EqualTo(-secondCorrection));
        }

        [Test]
        public void ContactResolution_HighResistanceAgentMovesLess()
        {
            List<LocalAvoidanceInput2D> inputs = new()
            {
                CreateAvoidanceInput(1, new Vector2(-0.1f, 0.0f), Vector2.zero, Vector2.zero, mass: 10.0f, priority: 5.0f),
                CreateAvoidanceInput(2, new Vector2(0.1f, 0.0f), Vector2.zero, Vector2.zero, mass: 1.0f, priority: 1.0f),
            };
            Vector2[] corrections = ResolveContacts(inputs, 1);

            Assert.That(corrections[0].magnitude, Is.LessThan(corrections[1].magnitude));
        }

        [Test]
        public void ContactResolution_IsStableWhenInputOrderChanges()
        {
            List<LocalAvoidanceInput2D> forward = new()
            {
                CreateAvoidanceInput(1, new Vector2(-0.1f, 0.0f), Vector2.zero, Vector2.zero, mass: 4.0f),
                CreateAvoidanceInput(2, new Vector2(0.1f, 0.0f), Vector2.zero, Vector2.zero),
            };
            List<LocalAvoidanceInput2D> reversed = new() { forward[1], forward[0] };

            Vector2[] forwardCorrections = ResolveContacts(forward, 2);
            Vector2[] reversedCorrections = ResolveContacts(reversed, 2);

            Assert.That(Vector2.Distance(forwardCorrections[0], reversedCorrections[1]), Is.LessThan(0.0001f));
            Assert.That(Vector2.Distance(forwardCorrections[1], reversedCorrections[0]), Is.LessThan(0.0001f));
        }

        [Test]
        public void ContactResolution_MultipleIterationsReducePenetration()
        {
            List<LocalAvoidanceInput2D> inputs = new()
            {
                CreateAvoidanceInput(1, new Vector2(-0.05f, 0.0f), Vector2.zero, Vector2.zero),
                CreateAvoidanceInput(2, new Vector2(0.05f, 0.0f), Vector2.zero, Vector2.zero),
                CreateAvoidanceInput(3, new Vector2(0.15f, 0.0f), Vector2.zero, Vector2.zero),
            };

            Vector2[] oneIteration = ResolveContacts(inputs, 1);
            Vector2[] fourIterations = ResolveContacts(inputs, 4);

            Assert.That(MaximumPenetration(inputs, fourIterations), Is.LessThan(MaximumPenetration(inputs, oneIteration)));
        }

        [Test]
        public void WorldSimulation_PublishesVelocityAndDoesNotMoveRigidbody()
        {
            ContextSteeringProfile2D profile = AssetDatabase.LoadAssetAtPath<ContextSteeringProfile2D>(DefaultProfilePath);
            GameObject simulationObject = new("Context Steering Test Simulation");
            GameObject agentObject = new("Context Steering Test Agent");
            ContextSteeringSimulation2D simulation = null;
            try
            {
                simulation = simulationObject.AddComponent<ContextSteeringSimulation2D>();
                Rigidbody2D body = agentObject.AddComponent<Rigidbody2D>();
                body.bodyType = RigidbodyType2D.Kinematic;
                agentObject.AddComponent<CircleCollider2D>().radius = profile.AgentRadius;
                ContactFilter2D filter = ContactFilter2D.noFilter;
                ContextSteeringAgentHandle2D handle = simulation.Register(body, profile, filter, filter, filter);
                handle.SubmitIntent(true, new Vector2(2.0f, 0.0f), Vector2.zero, Vector2.right, captureDebug: true);
                Vector2 originalPosition = body.position;

                simulation.Simulate(0.02f);

                Assert.That(handle.Result.PreferredVelocity.sqrMagnitude, Is.GreaterThan(0.0f));
                Assert.That(handle.Result.SafeVelocity.sqrMagnitude, Is.GreaterThan(0.0f));
                Assert.That(handle.Result.SafeDirection, Is.EqualTo(handle.Result.SafeVelocity.normalized));
                Assert.That(body.position, Is.EqualTo(originalPosition));
                Assert.That(handle.DebugSnapshot, Is.Not.Null);
                Assert.That(handle.DebugSnapshot.ProfileName, Is.EqualTo(profile.name));
                Assert.That(handle.DebugSnapshot.BehaviourGroupId, Is.EqualTo(profile.DefaultGroupIdValue));
                Assert.That(handle.DebugSnapshot.Contributions, Has.Length.EqualTo(5));
                handle.Dispose();
            }
            finally
            {
                simulation?.ReleaseRuntimeServices();
                UnityEngine.Object.DestroyImmediate(agentObject);
                UnityEngine.Object.DestroyImmediate(simulationObject);
            }
        }

        [Test]
        public void WorldSimulation_UsesSubmittedRuntimeMaximumSpeed()
        {
            ContextSteeringProfile2D profile = AssetDatabase.LoadAssetAtPath<ContextSteeringProfile2D>(DefaultProfilePath);
            GameObject simulationObject = new("Context Steering Speed Test Simulation");
            GameObject agentObject = new("Context Steering Speed Test Agent");
            ContextSteeringSimulation2D simulation = null;
            try
            {
                simulation = simulationObject.AddComponent<ContextSteeringSimulation2D>();
                Rigidbody2D body = agentObject.AddComponent<Rigidbody2D>();
                body.bodyType = RigidbodyType2D.Kinematic;
                agentObject.AddComponent<CircleCollider2D>().radius = profile.AgentRadius;
                ContactFilter2D filter = ContactFilter2D.noFilter;
                ContextSteeringAgentHandle2D handle = simulation.Register(body, profile, filter, filter, filter);
                handle.SubmitIntent(
                    true,
                    new Vector2(10.0f, 0.0f),
                    Vector2.zero,
                    Vector2.right,
                    maxSpeed: 0.35f);

                simulation.Simulate(0.02f);

                Assert.That(handle.Result.PreferredVelocity.magnitude, Is.LessThanOrEqualTo(0.3501f));
                Assert.That(handle.Result.SafeVelocity.magnitude, Is.LessThanOrEqualTo(0.3501f));
                handle.Dispose();
            }
            finally
            {
                simulation?.ReleaseRuntimeServices();
                UnityEngine.Object.DestroyImmediate(agentObject);
                UnityEngine.Object.DestroyImmediate(simulationObject);
            }
        }

        [Test]
        public void WorldSimulation_PublishesInitialContactCorrectionInSameTick()
        {
            ContextSteeringProfile2D profile = AssetDatabase.LoadAssetAtPath<ContextSteeringProfile2D>(DefaultProfilePath);
            GameObject simulationObject = new("Context Steering Contact Publication Test");
            GameObject firstAgentObject = new("First Overlapping Agent");
            GameObject secondAgentObject = new("Second Overlapping Agent");
            ContextSteeringSimulation2D simulation = null;
            try
            {
                simulation = simulationObject.AddComponent<ContextSteeringSimulation2D>();
                firstAgentObject.transform.position = Vector2.zero;
                secondAgentObject.transform.position = Vector2.right * 0.25f;
                ContextSteeringAgentHandle2D first = RegisterTestAgent(simulation, firstAgentObject, profile);
                ContextSteeringAgentHandle2D second = RegisterTestAgent(simulation, secondAgentObject, profile);
                SteeringDebugSnapshot2D firstPublished = null;
                SteeringDebugSnapshot2D secondPublished = null;
                first.DebugSnapshotPublished += snapshot => firstPublished = snapshot;
                second.DebugSnapshotPublished += snapshot => secondPublished = snapshot;
                first.SubmitIntent(true, Vector2.right * 2.0f, Vector2.zero, Vector2.right, captureDebug: true);
                second.SubmitIntent(true, Vector2.left * 2.0f, Vector2.zero, Vector2.left, captureDebug: true);

                simulation.Simulate(0.02f);

                Assert.That(firstPublished, Is.Not.Null);
                Assert.That(secondPublished, Is.Not.Null);
                Assert.That(firstPublished.Result.PushCorrection.sqrMagnitude, Is.GreaterThan(0.0f));
                Assert.That(secondPublished.Result.PushCorrection.sqrMagnitude, Is.GreaterThan(0.0f));
                first.Dispose();
                second.Dispose();
            }
            finally
            {
                simulation?.ReleaseRuntimeServices();
                UnityEngine.Object.DestroyImmediate(firstAgentObject);
                UnityEngine.Object.DestroyImmediate(secondAgentObject);
                UnityEngine.Object.DestroyImmediate(simulationObject);
            }
        }

        [Test]
        public void WorldSimulation_ReleasesAndReacquiresRvoRuntimeServices()
        {
            ContextSteeringProfile2D profile = AssetDatabase.LoadAssetAtPath<ContextSteeringProfile2D>(DefaultProfilePath);
            GameObject firstSimulationObject = new("First Context Steering Simulation");
            GameObject firstAgentObject = new("First Context Steering Agent");
            GameObject secondSimulationObject = null;
            GameObject secondAgentObject = null;
            ContextSteeringSimulation2D firstSimulation = null;
            ContextSteeringSimulation2D secondSimulation = null;
            try
            {
                firstSimulation = firstSimulationObject.AddComponent<ContextSteeringSimulation2D>();
                ContextSteeringAgentHandle2D firstHandle = RegisterTestAgent(firstSimulation, firstAgentObject, profile);
                firstHandle.SubmitIntent(true, Vector2.right * 4.0f, Vector2.zero, Vector2.right);
                firstSimulation.Simulate(0.02f);
                Assert.That(firstHandle.Result.SafeVelocity.sqrMagnitude, Is.GreaterThan(0.0f));

                firstSimulation.ReleaseRuntimeServices();
                secondSimulationObject = new GameObject("Second Context Steering Simulation");
                secondAgentObject = new GameObject("Second Context Steering Agent");
                secondSimulation = secondSimulationObject.AddComponent<ContextSteeringSimulation2D>();
                ContextSteeringAgentHandle2D secondHandle = RegisterTestAgent(secondSimulation, secondAgentObject, profile);
                secondHandle.SubmitIntent(true, Vector2.left * 4.0f, Vector2.zero, Vector2.left);
                secondSimulation.Simulate(0.02f);
                Assert.That(secondHandle.Result.SafeVelocity.sqrMagnitude, Is.GreaterThan(0.0f));

                secondHandle.Dispose();
                secondSimulation.ReleaseRuntimeServices();
                UnityEngine.Object.DestroyImmediate(secondAgentObject);
                secondAgentObject = null;
                UnityEngine.Object.DestroyImmediate(secondSimulationObject);
                secondSimulationObject = null;

                Assert.DoesNotThrow(() => firstSimulation.Simulate(0.02f));
                Assert.That(firstHandle.Result.SafeVelocity.sqrMagnitude, Is.GreaterThan(0.0f));
                firstHandle.Dispose();
            }
            finally
            {
                secondSimulation?.ReleaseRuntimeServices();
                firstSimulation?.ReleaseRuntimeServices();
                if (secondAgentObject != null) UnityEngine.Object.DestroyImmediate(secondAgentObject);
                if (secondSimulationObject != null) UnityEngine.Object.DestroyImmediate(secondSimulationObject);
                UnityEngine.Object.DestroyImmediate(firstAgentObject);
                UnityEngine.Object.DestroyImmediate(firstSimulationObject);
            }
        }

        [Test]
        public void WorldSimulation_DoesNotRegisterIndependentChildHitboxAsSelfNeighbour()
        {
            ContextSteeringProfile2D profile = AssetDatabase.LoadAssetAtPath<ContextSteeringProfile2D>(DefaultProfilePath);
            GameObject simulationObject = new("Context Steering Test Simulation");
            GameObject agentObject = new("Context Steering Test Agent");
            GameObject hitboxObject = new("Independent Hitbox");
            ContextSteeringSimulation2D simulation = null;
            try
            {
                simulation = simulationObject.AddComponent<ContextSteeringSimulation2D>();
                Rigidbody2D body = agentObject.AddComponent<Rigidbody2D>();
                body.bodyType = RigidbodyType2D.Kinematic;
                agentObject.AddComponent<CircleCollider2D>().radius = profile.AgentRadius;

                hitboxObject.transform.SetParent(agentObject.transform);
                Rigidbody2D hitboxBody = hitboxObject.AddComponent<Rigidbody2D>();
                hitboxBody.bodyType = RigidbodyType2D.Kinematic;
                hitboxObject.AddComponent<BoxCollider2D>();

                ContactFilter2D filter = ContactFilter2D.noFilter;
                ContextSteeringAgentHandle2D handle = simulation.Register(body, profile, filter, filter, filter);
                handle.SubmitIntent(true, new Vector2(2.0f, 0.0f), Vector2.zero, Vector2.right);

                simulation.Simulate(0.02f);

                Assert.That(handle.Frame.Neighbours, Is.Empty);
                handle.Dispose();
            }
            finally
            {
                simulation?.ReleaseRuntimeServices();
                UnityEngine.Object.DestroyImmediate(hitboxObject);
                UnityEngine.Object.DestroyImmediate(agentObject);
                UnityEngine.Object.DestroyImmediate(simulationObject);
            }
        }

        [Test]
        public void SteeringResult_KeepsSafeDirectionIndependentFromPushCorrection()
        {
            SteeringResult2D result = new(
                Vector2.right,
                1.0f,
                Vector2.right,
                Vector2.right,
                Vector2.up,
                new Vector2(1.0f, 1.0f));

            Assert.That(result.SafeDirection, Is.EqualTo(Vector2.right));
            Assert.That(result.FinalDirection, Is.EqualTo(new Vector2(1.0f, 1.0f).normalized));
            Assert.That(result.SafeDirection, Is.Not.EqualTo(result.FinalDirection));
        }

        [Test]
        public void DebugProbe_RetainsTransientPushCorrectionPeak()
        {
            GameObject probeObject = new("Context Steering Debug Probe Peak Test");
            try
            {
                ContextSteeringDebugProbe2D probe = probeObject.AddComponent<ContextSteeringDebugProbe2D>();
                SteeringDebugSnapshot2D pushed = CreateSnapshotWithPush(Vector2.right * 0.25f);
                SteeringDebugSnapshot2D settled = CreateSnapshotWithPush(Vector2.zero);

                probe.Capture(pushed);
                probe.Capture(settled);

                Assert.That(probe.Snapshot, Is.SameAs(settled));
                Assert.That(probe.MaximumObservedPushCorrectionSqrMagnitude, Is.EqualTo(0.0625f));
                probe.Clear();
                Assert.That(probe.MaximumObservedPushCorrectionSqrMagnitude, Is.EqualTo(0.0625f));
                probe.ResetHistory();
                Assert.That(probe.MaximumObservedPushCorrectionSqrMagnitude, Is.Zero);
            }
            finally
            {
                UnityEngine.Object.DestroyImmediate(probeObject);
            }
        }

        private static SteeringDetectionFrame2D CreateOverlappingFrame(
            ContextSteeringSolver2D solver,
            ContextSteeringProfile2D profile,
            int selfId,
            int otherId)
        {
            SteeringDetectionFrame2D frame = new();
            frame.Reset(
                solver.DirectionSet,
                selfId,
                Vector2.zero,
                Vector2.right,
                Vector2.zero,
                profile,
                null,
                Vector2.zero);
            frame.AddNeighbour(new SteeringBody2D(otherId, Vector2.zero, profile.AgentRadius));
            return frame;
        }

        private static SteeringDebugSnapshot2D CreateSnapshotWithPush(Vector2 push)
        {
            ContextSteeringProfile2D profile = AssetDatabase.LoadAssetAtPath<ContextSteeringProfile2D>(DefaultProfilePath);
            ContextSteeringSolver2D solver = new(profile.SampleCount);
            SteeringDetectionFrame2D frame = new();
            frame.Reset(
                solver.DirectionSet,
                1,
                Vector2.zero,
                Vector2.right,
                Vector2.zero,
                profile,
                Vector2.right,
                Vector2.zero);
            solver.Prepare(profile);
            solver.Solve(frame, profile, profile.DefaultGroupIdValue);
            return new SteeringDebugSnapshot2D(
                frame,
                solver.Context,
                profile.GetBehaviourGroup(profile.DefaultGroupIdValue).Behaviours.Count,
                new SteeringResult2D(Vector2.right, 1.0f, Vector2.right, Vector2.right, push, Vector2.right + push),
                profile.name,
                profile.DefaultGroupIdValue);
        }

        private static Vector2 ResolveStrongestDirection(
            SteeringDirectionSet2D directions,
            ReadOnlySpan<float> values)
        {
            int bestIndex = 0;
            for (int i = 1; i < values.Length; i++)
            {
                if (values[i] > values[bestIndex])
                {
                    bestIndex = i;
                }
            }

            return directions[bestIndex];
        }

        private static LocalAvoidanceInput2D CreateAvoidanceInput(
            int agentId,
            Vector2 position,
            Vector2 velocity,
            Vector2 preferredVelocity,
            float maxSpeed = 1.0f,
            float mass = 1.0f,
            float priority = 1.0f)
        {
            return new LocalAvoidanceInput2D(
                agentId,
                position,
                velocity,
                preferredVelocity,
                maxSpeed,
                0.3f,
                mass,
                priority,
                1.0f,
                2.0f,
                4.0f,
                2.0f,
                8,
                true);
        }

        private static ContextSteeringAgentHandle2D RegisterTestAgent(
            ContextSteeringSimulation2D simulation,
            GameObject agentObject,
            ContextSteeringProfile2D profile)
        {
            Rigidbody2D body = agentObject.AddComponent<Rigidbody2D>();
            body.bodyType = RigidbodyType2D.Kinematic;
            agentObject.AddComponent<CircleCollider2D>().radius = profile.AgentRadius;
            ContactFilter2D filter = ContactFilter2D.noFilter;
            return simulation.Register(body, profile, filter, filter, filter);
        }

        private static Vector2[] ResolveContacts(IReadOnlyList<LocalAvoidanceInput2D> inputs, int iterations)
        {
            Vector2[] safeVelocities = new Vector2[inputs.Count];
            Vector2[] corrections = new Vector2[inputs.Count];
            new PositionBasedContactResolver2D().Resolve(inputs, safeVelocities, corrections, iterations, 0.02f);
            return corrections;
        }

        private static float MaximumPenetration(IReadOnlyList<LocalAvoidanceInput2D> inputs, Vector2[] corrections)
        {
            float maximum = 0.0f;
            for (int i = 0; i < inputs.Count; i++)
            {
                for (int j = i + 1; j < inputs.Count; j++)
                {
                    float distance = Vector2.Distance(
                        inputs[i].Position + corrections[i],
                        inputs[j].Position + corrections[j]);
                    maximum = Mathf.Max(maximum, inputs[i].Radius + inputs[j].Radius - distance);
                }
            }

            return maximum;
        }
    }
}
