using System;
using System.Collections;
using System.Collections.Generic;
using System.Reflection;
using NUnit.Framework;
using UnityEngine;
using UnityEngine.Tilemaps;

namespace FantasyWord.GameCore.Tests
{
    public sealed class ElementReactionSystemEditModeTests
    {
        private readonly List<UnityEngine.Object> m_createdObjects = new();

        private GameObject m_gridObject;
        private Tilemap m_tilemap;
        private TerrainNavigationMap m_navigationMap;
        private ElementReactionSystem m_reactionSystem;
        private Vector3Int m_testCell;

        [SetUp]
        public void SetUp()
        {
            m_gridObject = new GameObject("元素反应测试 Grid", typeof(Grid));
            GameObject tilemapObject = new(
                "地形规则",
                typeof(Tilemap),
                typeof(TilemapRenderer));
            tilemapObject.transform.SetParent(m_gridObject.transform);
            m_tilemap = tilemapObject.GetComponent<Tilemap>();
            m_navigationMap = m_gridObject.AddComponent<TerrainNavigationMap>();
            SetPrivateField(m_navigationMap, "m_ruleTilemap", m_tilemap);

            GameObject systemObject = new("元素反应系统");
            m_createdObjects.Add(systemObject);
            m_reactionSystem = systemObject.AddComponent<ElementReactionSystem>();
            SetPrivateField(m_reactionSystem, "m_navigationMap", m_navigationMap);
            SetPrivateField(m_reactionSystem, "m_initialized", true);

            RegisterStateDefinition(
                ETerrainElementStateKind.Burning,
                defaultDuration: 1.0f,
                traversalMultiplier: 3.0f);
            RegisterStateDefinition(
                ETerrainElementStateKind.Wet,
                defaultDuration: 2.0f,
                traversalMultiplier: 1.0f);
            RegisterStateDefinition(
                ETerrainElementStateKind.Oiled,
                defaultDuration: 4.0f,
                traversalMultiplier: 1.0f);
            RegisterStateDefinition(
                ETerrainElementStateKind.Electrified,
                defaultDuration: 1.5f,
                traversalMultiplier: 1.5f);

            RegisterReaction(CreateElementReaction(
                "fire-grass",
                EWorldElementKind.Fire,
                priority: 10,
                requireEffectiveSurface: ETerrainSurfaceKind.Grass,
                requiredStates: ETerrainRuntimeSurfaceState.None,
                CreateOperation(
                    EElementReactionOperationKind.AddOrRefreshState,
                    stateKind: ETerrainElementStateKind.Burning)));
            RegisterReaction(CreateElementReaction(
                "oil-surface",
                EWorldElementKind.Oil,
                priority: 10,
                requireEffectiveSurface: ETerrainSurfaceKind.Grass,
                requiredStates: ETerrainRuntimeSurfaceState.None,
                CreateOperation(
                    EElementReactionOperationKind.AddOrRefreshState,
                    stateKind: ETerrainElementStateKind.Oiled)));
            RegisterReaction(CreateElementReaction(
                "fire-oiled",
                EWorldElementKind.Fire,
                priority: 20,
                requireEffectiveSurface: ETerrainSurfaceKind.Grass,
                requiredStates: ETerrainRuntimeSurfaceState.Oiled,
                CreateOperation(
                    EElementReactionOperationKind.AddOrRefreshState,
                    stateKind: ETerrainElementStateKind.Burning,
                    durationOverride: 5.0f)));
            RegisterReaction(CreateElementReaction(
                "water-burning",
                EWorldElementKind.Water,
                priority: 30,
                requireEffectiveSurface: null,
                requiredStates: ETerrainRuntimeSurfaceState.Burning,
                CreateOperation(
                    EElementReactionOperationKind.RemoveState,
                    stateKind: ETerrainElementStateKind.Burning),
                CreateOperation(
                    EElementReactionOperationKind.AddOrRefreshState,
                    stateKind: ETerrainElementStateKind.Wet),
                CreateOperation(
                    EElementReactionOperationKind.EmitPresentationSignal,
                    presentationSignal: EElementPresentationSignal.Steam)));
            RegisterReaction(CreateElementReaction(
                "electricity-wet",
                EWorldElementKind.Electricity,
                priority: 10,
                requireEffectiveSurface: null,
                requiredStates: ETerrainRuntimeSurfaceState.Wet,
                CreateOperation(
                    EElementReactionOperationKind.AddOrRefreshState,
                    stateKind: ETerrainElementStateKind.Electrified)));
            RegisterReaction(CreateExpirationReaction(
                "burning-grass-expired",
                ETerrainElementStateKind.Burning,
                ETerrainSurfaceKind.Grass,
                CreateOperation(
                    EElementReactionOperationKind.SetEffectiveSurface,
                    surfaceKind: ETerrainSurfaceKind.ScorchedDirt)));

            m_testCell = Vector3Int.zero;
            TerrainNavigationTile grassTile =
                ScriptableObject.CreateInstance<TerrainNavigationTile>();
            m_createdObjects.Add(grassTile);
            SetPrivateField(grassTile, "m_walkable", true);
            SetPrivateField(grassTile, "m_surfaceKind", ETerrainSurfaceKind.Grass);
            SetPrivateField(grassTile, "m_traversalCost", 1.0f);
            m_tilemap.SetTile(m_testCell, grassTile);
            m_navigationMap.RefreshNavigationData();
        }

        [TearDown]
        public void TearDown()
        {
            if (m_gridObject != null)
            {
                UnityEngine.Object.DestroyImmediate(m_gridObject);
            }

            for (int i = 0; i < m_createdObjects.Count; i++)
            {
                if (m_createdObjects[i] != null)
                {
                    UnityEngine.Object.DestroyImmediate(m_createdObjects[i]);
                }
            }

            m_createdObjects.Clear();
        }

        [Test]
        public void ApplyFireToGrass_AddsBurningAndRaisesTraversalCost()
        {
            bool changed = m_reactionSystem.Apply(
                CreateApplication(EWorldElementKind.Fire, 0.6f));

            Assert.IsTrue(changed);
            Assert.IsTrue(m_navigationMap.TryGetSurfaceSample(
                m_testCell,
                out TerrainSurfaceSample sample));
            Assert.AreEqual(ETerrainSurfaceKind.Grass, sample.BaseSurface);
            Assert.AreEqual(ETerrainSurfaceKind.Grass, sample.EffectiveSurface);
            Assert.AreEqual(
                ETerrainRuntimeSurfaceState.Burning,
                sample.RuntimeState);
            Assert.AreEqual(1.0f, sample.BaseTraversalCost);
            Assert.AreEqual(3.0f, sample.EffectiveTraversalCost);
            Assert.AreEqual(1, m_reactionSystem.ActiveTimedCellCount);
        }

        [Test]
        public void OilFireWaterAndElectricity_ResolveThroughConfiguredRules()
        {
            Assert.IsTrue(m_reactionSystem.Apply(
                CreateApplication(EWorldElementKind.Oil, 1.0f)));
            Assert.IsTrue(m_reactionSystem.Apply(
                CreateApplication(EWorldElementKind.Fire, 0.8f)));

            Assert.IsTrue(m_navigationMap.TryGetRuntimeState(
                m_testCell,
                out TerrainCellRuntimeState burningState));
            Assert.IsTrue(burningState.TryGetState(
                ETerrainElementStateKind.Burning,
                out TerrainElementStateInstance burning));
            Assert.AreEqual(5.0f, burning.RemainingDuration);
            Assert.AreEqual(0.8f, burning.Intensity);

            Assert.IsTrue(m_reactionSystem.Apply(
                CreateApplication(EWorldElementKind.Water, 1.0f)));
            Assert.IsTrue(m_navigationMap.TryGetSurfaceSample(
                m_testCell,
                out TerrainSurfaceSample wetSample));
            Assert.IsFalse(
                (wetSample.RuntimeState & ETerrainRuntimeSurfaceState.Burning) != 0);
            Assert.IsTrue(
                (wetSample.RuntimeState & ETerrainRuntimeSurfaceState.Wet) != 0);
            Assert.AreEqual(1.0f, wetSample.EffectiveTraversalCost);
            Assert.AreEqual(1, m_reactionSystem.ActiveTimedCellCount);

            Assert.IsTrue(m_reactionSystem.Apply(
                CreateApplication(EWorldElementKind.Electricity, 1.0f)));
            Assert.IsTrue(m_navigationMap.TryGetSurfaceSample(
                m_testCell,
                out TerrainSurfaceSample electrifiedSample));
            Assert.IsTrue(
                (electrifiedSample.RuntimeState &
                 ETerrainRuntimeSurfaceState.Electrified) != 0);
        }

        [Test]
        public void BurningExpiration_SetsScorchedDirtAndRemovesBurning()
        {
            Assert.IsTrue(m_reactionSystem.Apply(
                CreateApplication(EWorldElementKind.Fire, 1.0f)));

            InvokePrivate(
                m_reactionSystem,
                "AdvanceTimedStates",
                1.0f);

            Assert.IsTrue(m_navigationMap.TryGetSurfaceSample(
                m_testCell,
                out TerrainSurfaceSample sample));
            Assert.AreEqual(ETerrainSurfaceKind.Grass, sample.BaseSurface);
            Assert.AreEqual(
                ETerrainSurfaceKind.ScorchedDirt,
                sample.EffectiveSurface);
            Assert.AreEqual(
                ETerrainRuntimeSurfaceState.None,
                sample.RuntimeState);
            Assert.AreEqual(1.0f, sample.EffectiveTraversalCost);
            Assert.AreEqual(0, m_reactionSystem.ActiveTimedCellCount);
        }

        [Test]
        public void MapUnloading_ClearsTransientStateAndStopsTiming()
        {
            Assert.IsTrue(m_reactionSystem.Apply(
                CreateApplication(EWorldElementKind.Fire, 1.0f)));

            m_reactionSystem.OnMapUnloading();

            Assert.IsNull(m_reactionSystem.BoundNavigationMap);
            Assert.AreEqual(0, m_reactionSystem.ActiveTimedCellCount);
            Assert.AreEqual(0, m_navigationMap.RuntimeStateCount);
            Assert.IsTrue(m_navigationMap.TryGetSurfaceSample(
                m_testCell,
                out TerrainSurfaceSample sample));
            Assert.AreEqual(ETerrainSurfaceKind.Grass, sample.EffectiveSurface);
            Assert.AreEqual(
                ETerrainRuntimeSurfaceState.None,
                sample.RuntimeState);
        }

        private ElementApplication CreateApplication(
            EWorldElementKind elementKind,
            float intensity)
        {
            return new ElementApplication(
                elementKind,
                intensity,
                0.1f,
                ElementArea.Cone(1.0f, 45.0f),
                m_tilemap.GetCellCenterWorld(m_testCell),
                Vector2.right,
                sourceAbilityCode: 9001);
        }

        private void RegisterStateDefinition(
            ETerrainElementStateKind stateKind,
            float defaultDuration,
            float traversalMultiplier)
        {
            TerrainElementStateDefinition definition =
                ScriptableObject.CreateInstance<TerrainElementStateDefinition>();
            m_createdObjects.Add(definition);
            SetPrivateField(definition, "m_stateKind", stateKind);
            SetPrivateField(definition, "m_defaultDuration", defaultDuration);
            SetPrivateField(
                definition,
                "m_mergePolicy",
                ETerrainStateMergePolicy.RefreshDuration);
            SetPrivateField(
                definition,
                "m_traversalCostMultiplier",
                traversalMultiplier);

            FieldInfo definitionsField = typeof(ElementReactionSystem).GetField(
                "m_stateDefinitions",
                BindingFlags.Instance | BindingFlags.NonPublic);
            Assert.IsNotNull(definitionsField);
            IDictionary definitions =
                definitionsField.GetValue(m_reactionSystem) as IDictionary;
            Assert.IsNotNull(definitions);

            Type bindingType = typeof(ElementReactionSystem).GetNestedType(
                "StateDefinitionBinding",
                BindingFlags.NonPublic);
            Assert.IsNotNull(bindingType);
            object binding = Activator.CreateInstance(
                bindingType,
                BindingFlags.Instance |
                BindingFlags.Public |
                BindingFlags.NonPublic,
                binder: null,
                args: new object[]
                {
                    $"state-{stateKind.ToString().ToLowerInvariant()}",
                    definition
                },
                culture: null);
            definitions.Add(stateKind, binding);
        }

        private void RegisterReaction(
            (string stableId, ElementReactionDefinition definition) reaction)
        {
            FieldInfo candidatesField = typeof(ElementReactionSystem).GetField(
                "m_reactionCandidates",
                BindingFlags.Instance | BindingFlags.NonPublic);
            Assert.IsNotNull(candidatesField);
            List<ElementReactionCandidate> candidates =
                candidatesField.GetValue(m_reactionSystem) as
                    List<ElementReactionCandidate>;
            Assert.IsNotNull(candidates);
            candidates.Add(new ElementReactionCandidate(
                reaction.stableId,
                reaction.definition));
        }

        private (string stableId, ElementReactionDefinition definition)
            CreateElementReaction(
                string stableId,
                EWorldElementKind elementKind,
                int priority,
                ETerrainSurfaceKind? requireEffectiveSurface,
                ETerrainRuntimeSurfaceState requiredStates,
                params ElementReactionOperation[] operations)
        {
            ElementReactionDefinition definition =
                ScriptableObject.CreateInstance<ElementReactionDefinition>();
            m_createdObjects.Add(definition);
            SetPrivateField(
                definition,
                "m_trigger",
                EElementReactionTrigger.OnElementApplied);
            SetPrivateField(definition, "m_elementKind", elementKind);
            SetPrivateField(definition, "m_priority", priority);
            SetPrivateField(definition, "m_requiredStates", requiredStates);
            SetPrivateField(definition, "m_operations", operations);
            if (requireEffectiveSurface.HasValue)
            {
                SetPrivateField(
                    definition,
                    "m_requireEffectiveSurface",
                    true);
                SetPrivateField(
                    definition,
                    "m_effectiveSurface",
                    requireEffectiveSurface.Value);
            }

            return (stableId, definition);
        }

        private (string stableId, ElementReactionDefinition definition)
            CreateExpirationReaction(
                string stableId,
                ETerrainElementStateKind expiredStateKind,
                ETerrainSurfaceKind baseSurface,
                params ElementReactionOperation[] operations)
        {
            ElementReactionDefinition definition =
                ScriptableObject.CreateInstance<ElementReactionDefinition>();
            m_createdObjects.Add(definition);
            SetPrivateField(
                definition,
                "m_trigger",
                EElementReactionTrigger.OnStateExpired);
            SetPrivateField(
                definition,
                "m_expiredStateKind",
                expiredStateKind);
            SetPrivateField(definition, "m_requireBaseSurface", true);
            SetPrivateField(definition, "m_baseSurface", baseSurface);
            SetPrivateField(definition, "m_priority", 10);
            SetPrivateField(definition, "m_operations", operations);
            return (stableId, definition);
        }

        private static ElementReactionOperation CreateOperation(
            EElementReactionOperationKind kind,
            ETerrainElementStateKind stateKind =
                ETerrainElementStateKind.None,
            float durationOverride = 0.0f,
            ETerrainSurfaceKind surfaceKind = ETerrainSurfaceKind.None,
            EElementPresentationSignal presentationSignal =
                EElementPresentationSignal.None)
        {
            ElementReactionOperation operation = new();
            SetPrivateField(operation, "m_kind", kind);
            SetPrivateField(operation, "m_stateKind", stateKind);
            SetPrivateField(
                operation,
                "m_durationOverride",
                durationOverride);
            SetPrivateField(operation, "m_surfaceKind", surfaceKind);
            SetPrivateField(
                operation,
                "m_presentationSignal",
                presentationSignal);
            return operation;
        }

        private static void InvokePrivate(
            object target,
            string methodName,
            params object[] arguments)
        {
            MethodInfo method = target.GetType().GetMethod(
                methodName,
                BindingFlags.Instance | BindingFlags.NonPublic);
            Assert.IsNotNull(method, $"找不到方法：{target.GetType().Name}.{methodName}");
            method.Invoke(target, arguments);
        }

        private static void SetPrivateField(
            object target,
            string fieldName,
            object value)
        {
            FieldInfo field = target.GetType().GetField(
                fieldName,
                BindingFlags.Instance | BindingFlags.NonPublic);
            Assert.IsNotNull(field, $"找不到字段：{target.GetType().Name}.{fieldName}");
            field.SetValue(target, value);
        }
    }
}
