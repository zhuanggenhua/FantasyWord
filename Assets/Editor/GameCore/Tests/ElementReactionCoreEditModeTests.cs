using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using NUnit.Framework;
using UnityEditor;
using UnityEngine;
using UnityEngine.TestTools;
using UnityEngine.Tilemaps;

namespace FantasyWord.GameCore.Tests
{
    public sealed class ElementReactionCoreEditModeTests
    {
        private readonly List<Object> m_createdObjects = new();

        [TearDown]
        public void TearDown()
        {
            for (int i = 0; i < m_createdObjects.Count; i++)
            {
                Object.DestroyImmediate(m_createdObjects[i]);
            }

            m_createdObjects.Clear();
        }

        [Test]
        public void CollectMatches_SortsByPriorityThenStableId()
        {
            ElementReactionDefinition lowPriority = CreateReaction(5);
            ElementReactionDefinition firstStableId = CreateReaction(10);
            ElementReactionDefinition secondStableId = CreateReaction(10);
            ElementApplication application = CreateFireApplication();
            ElementReactionContext context = new(
                EElementReactionTrigger.OnElementApplied,
                application,
                ETerrainElementStateKind.None,
                ETerrainSurfaceKind.Grass,
                ETerrainSurfaceKind.Grass,
                ETerrainRuntimeSurfaceState.None);
            List<ElementReactionCandidate> candidates = new()
            {
                new("rule-b", secondStableId),
                new("rule-low", lowPriority),
                new("rule-a", firstStableId)
            };
            List<ElementReactionCandidate> matches = new();

            ElementReactionResolver.CollectMatches(candidates, context, matches);

            Assert.AreEqual(3, matches.Count);
            Assert.AreEqual("rule-a", matches[0].StableId);
            Assert.AreEqual("rule-b", matches[1].StableId);
            Assert.AreEqual("rule-low", matches[2].StableId);
        }

        [Test]
        public void RegisterReactionDefinition_RejectsDuplicateStableId()
        {
            GameObject systemObject = new("元素反应系统");
            m_createdObjects.Add(systemObject);
            ElementReactionSystem system =
                systemObject.AddComponent<ElementReactionSystem>();
            ElementReactionDefinition reaction = CreateReaction(10);
            MethodInfo registerMethod = typeof(ElementReactionSystem).GetMethod(
                "TryRegisterReactionDefinition",
                BindingFlags.Instance | BindingFlags.NonPublic);
            Assert.IsNotNull(registerMethod);

            bool firstRegistration = (bool)registerMethod.Invoke(
                system,
                new object[] { "duplicate-rule", reaction });
            LogAssert.Expect(
                LogType.Error,
                "元素反应稳定 ID 'duplicate-rule' 重复。");
            bool secondRegistration = (bool)registerMethod.Invoke(
                system,
                new object[] { "duplicate-rule", reaction });

            Assert.IsTrue(firstRegistration);
            Assert.IsFalse(secondRegistration);
        }

        [Test]
        public void ReactionDefinition_RequiresConfiguredSurfaceAndRuntimeState()
        {
            ElementReactionDefinition reaction = CreateReaction(0);
            SetPrivateField(reaction, "m_requireEffectiveSurface", true);
            SetPrivateField(reaction, "m_effectiveSurface", ETerrainSurfaceKind.Grass);
            SetPrivateField(
                reaction,
                "m_requiredStates",
                ETerrainRuntimeSurfaceState.Oiled);

            ElementApplication application = CreateFireApplication();
            ElementReactionContext matchingContext = new(
                EElementReactionTrigger.OnElementApplied,
                application,
                ETerrainElementStateKind.None,
                ETerrainSurfaceKind.Grass,
                ETerrainSurfaceKind.Grass,
                ETerrainRuntimeSurfaceState.Oiled);
            ElementReactionContext wrongSurfaceContext = new(
                EElementReactionTrigger.OnElementApplied,
                application,
                ETerrainElementStateKind.None,
                ETerrainSurfaceKind.Grass,
                ETerrainSurfaceKind.ScorchedDirt,
                ETerrainRuntimeSurfaceState.Oiled);
            ElementReactionContext missingStateContext = new(
                EElementReactionTrigger.OnElementApplied,
                application,
                ETerrainElementStateKind.None,
                ETerrainSurfaceKind.Grass,
                ETerrainSurfaceKind.Grass,
                ETerrainRuntimeSurfaceState.None);

            Assert.IsTrue(reaction.Matches(matchingContext));
            Assert.IsFalse(reaction.Matches(wrongSurfaceContext));
            Assert.IsFalse(reaction.Matches(missingStateContext));
        }

        [Test]
        public void RuntimeState_RefreshesDurationAndKeepsStrongerIntensity()
        {
            TerrainCellRuntimeState runtimeState = new();
            TerrainElementStateSource firstSource = new(null, 101);
            TerrainElementStateSource secondSource = new(null, 202);

            Assert.IsTrue(runtimeState.ApplyOrMergeState(
                ETerrainElementStateKind.Burning,
                0.8f,
                3.0f,
                firstSource,
                "fire-grass",
                ETerrainStateMergePolicy.RefreshDuration));
            Assert.IsTrue(runtimeState.ApplyOrMergeState(
                ETerrainElementStateKind.Burning,
                0.4f,
                5.0f,
                secondSource,
                "fire-grass",
                ETerrainStateMergePolicy.RefreshDuration));

            Assert.AreEqual(ETerrainRuntimeSurfaceState.Burning, runtimeState.RuntimeStateFlags);
            Assert.IsTrue(runtimeState.TryGetState(
                ETerrainElementStateKind.Burning,
                out TerrainElementStateInstance burning));
            Assert.AreEqual(0.8f, burning.Intensity);
            Assert.AreEqual(5.0f, burning.RemainingDuration);
            Assert.AreEqual(202, burning.SourceAbilityCode);
            Assert.AreEqual(1, runtimeState.ActiveStates.Count);
        }

        [Test]
        public void RuntimeState_TracksExpirationWithoutRemovingStateEarly()
        {
            TerrainCellRuntimeState runtimeState = new();
            TerrainElementStateSource source = new(null, 101);
            runtimeState.ApplyOrMergeState(
                ETerrainElementStateKind.Burning,
                0.5f,
                1.0f,
                source,
                "fire-grass",
                ETerrainStateMergePolicy.RefreshDuration);
            List<ETerrainElementStateKind> expiredStates = new();

            runtimeState.AdvanceDurations(1.0f, expiredStates);

            Assert.AreEqual(1, expiredStates.Count);
            Assert.AreEqual(ETerrainElementStateKind.Burning, expiredStates[0]);
            Assert.IsTrue(runtimeState.TryGetState(
                ETerrainElementStateKind.Burning,
                out TerrainElementStateInstance burning));
            Assert.AreEqual(0.0f, burning.RemainingDuration);
            Assert.AreEqual(
                ETerrainRuntimeSurfaceState.Burning,
                runtimeState.RuntimeStateFlags);
        }

        [Test]
        public void ProjectElementAssets_AreValidAndRegistered()
        {
            DatabaseRegistry registry = AssetDatabase.LoadAssetAtPath<DatabaseRegistry>(
                "Assets/GameData/GameCore/DatabaseRegistry.asset");
            Assert.IsNotNull(registry, "正式 DatabaseRegistry 资产不存在。");
            AssertRegistrySerializationIsUnique(registry);

            string[] stateGuids = AssetDatabase.FindAssets(
                "t:TerrainElementStateDefinition",
                new[] { "Assets/GameData/Elements/States" });
            Assert.AreEqual(4, stateGuids.Length, "首批地表元素状态资产数量不完整。");

            HashSet<ETerrainElementStateKind> stateKinds = new();
            for (int i = 0; i < stateGuids.Length; i++)
            {
                TerrainElementStateDefinition definition =
                    AssetDatabase.LoadAssetAtPath<TerrainElementStateDefinition>(
                        AssetDatabase.GUIDToAssetPath(stateGuids[i]));
                Assert.IsNotNull(definition);
                Assert.IsTrue(
                    definition.TryValidate(out string error),
                    $"{definition.name} 配置无效：{error}");
                Assert.IsTrue(
                    registry.HasGUID(stateGuids[i]),
                    $"{definition.name} 未登记到正式 DatabaseRegistry。");
                Assert.IsTrue(
                    stateKinds.Add(definition.StateKind),
                    $"状态类型 {definition.StateKind} 重复配置。");
            }

            CollectionAssert.AreEquivalent(
                new[]
                {
                    ETerrainElementStateKind.Wet,
                    ETerrainElementStateKind.Burning,
                    ETerrainElementStateKind.Oiled,
                    ETerrainElementStateKind.Electrified
                },
                stateKinds);

            TerrainElementStateDefinition burning =
                AssetDatabase.LoadAssetAtPath<TerrainElementStateDefinition>(
                    "Assets/GameData/Elements/States/地表元素状态-燃烧.asset");
            Assert.IsNotNull(burning);
            Assert.AreEqual(4.0f, burning.TraversalCostMultiplier);

            string[] reactionGuids = AssetDatabase.FindAssets(
                "t:ElementReactionDefinition",
                new[] { "Assets/GameData/Elements/Reactions" });
            Assert.AreEqual(6, reactionGuids.Length, "首批元素反应资产数量不完整。");
            for (int i = 0; i < reactionGuids.Length; i++)
            {
                ElementReactionDefinition definition =
                    AssetDatabase.LoadAssetAtPath<ElementReactionDefinition>(
                        AssetDatabase.GUIDToAssetPath(reactionGuids[i]));
                Assert.IsNotNull(definition);
                Assert.IsTrue(
                    definition.TryValidate(out string error),
                    $"{definition.name} 配置无效：{error}");
                Assert.IsTrue(
                    registry.HasGUID(reactionGuids[i]),
                    $"{definition.name} 未登记到正式 DatabaseRegistry。");
            }

            const string PresentationPath =
                "Assets/GameData/Elements/Presentation/地表元素表现-首批.asset";
            TerrainSurfacePresentationConfig presentation =
                AssetDatabase.LoadAssetAtPath<TerrainSurfacePresentationConfig>(
                    PresentationPath);
            Assert.IsNotNull(presentation, "首批地表元素表现配置不存在。");
            Assert.IsTrue(
                registry.HasGUID(AssetDatabase.AssetPathToGUID(PresentationPath)),
                "首批地表元素表现配置未登记到正式 DatabaseRegistry。");

            TerrainStateTileMapping[] stateMappings =
                GetPrivateField<TerrainStateTileMapping[]>(presentation, "m_stateTiles");
            Assert.AreEqual(4, stateMappings.Length, "首批临时状态表现映射数量不完整。");
            HashSet<ETerrainElementStateKind> presentationStateKinds = new();
            for (int i = 0; i < stateMappings.Length; i++)
            {
                Assert.IsNotNull(stateMappings[i]);
                Assert.IsNotNull(
                    stateMappings[i].Tile,
                    $"{stateMappings[i].StateKind} 缺少正式表现 Tile。");
                Assert.IsTrue(
                    presentationStateKinds.Add(stateMappings[i].StateKind),
                    $"{stateMappings[i].StateKind} 存在重复表现映射。");
            }

            CollectionAssert.AreEquivalent(
                new[]
                {
                    ETerrainElementStateKind.Wet,
                    ETerrainElementStateKind.Burning,
                    ETerrainElementStateKind.Oiled,
                    ETerrainElementStateKind.Electrified
                },
                presentationStateKinds);

            TerrainSurfaceTileMapping[] surfaceMappings =
                GetPrivateField<TerrainSurfaceTileMapping[]>(presentation, "m_surfaceTiles");
            Assert.AreEqual(1, surfaceMappings.Length, "首批结果地表表现映射数量不完整。");
            Assert.IsNotNull(surfaceMappings[0]);
            Assert.AreEqual(ETerrainSurfaceKind.ScorchedDirt, surfaceMappings[0].SurfaceKind);
            Assert.IsNotNull(surfaceMappings[0].Tile, "焦土缺少正式表现 Tile。");

            TerrainSignalTileMapping[] signalMappings =
                GetPrivateField<TerrainSignalTileMapping[]>(presentation, "m_signalTiles");
            Assert.AreEqual(1, signalMappings.Length, "首批短暂信号表现映射数量不完整。");
            Assert.IsNotNull(signalMappings[0]);
            Assert.AreEqual(EElementPresentationSignal.Steam, signalMappings[0].Signal);
            Assert.IsNotNull(signalMappings[0].Tile, "蒸汽缺少正式表现 Tile。");
            Assert.AreEqual(0.35f, signalMappings[0].Duration);
        }

        [Test]
        public void TerrainElementPresentationTiles_UseStableAtlasSprites()
        {
            const string AtlasPath =
                "Assets/ArtRes/Effects/Elements/Terrain/TerrainElementOverlays.png";
            const string AtlasGuid = "34b35ad294d3fc14e941df99f5cec9d6";
            string[] tilePaths =
            {
                "Assets/GameData/Elements/Presentation/Tiles/地表元素-燃烧.asset",
                "Assets/GameData/Elements/Presentation/Tiles/地表元素-湿润.asset",
                "Assets/GameData/Elements/Presentation/Tiles/地表元素-油污.asset",
                "Assets/GameData/Elements/Presentation/Tiles/地表元素-导电.asset",
                "Assets/GameData/Elements/Presentation/Tiles/地表元素-焦土.asset",
                "Assets/GameData/Elements/Presentation/Tiles/地表元素-蒸汽.asset"
            };
            string[] expectedTileGuids =
            {
                "b2f76a85dac64cabad770dfe6e199f26",
                "526f2a712a604f449433ce30e45677fd",
                "f5d65f7c93cb4310a291544c5ad52181",
                "0fe69fa78e644f90bb01845020df2ee8",
                "a98ef136e65e4465903c155da7ac41a2",
                "e0f90e8e7d1946f8ae7c9e2e0575b01e"
            };
            string[] expectedSpriteNames =
            {
                "TerrainElement_Burning",
                "TerrainElement_Wet",
                "TerrainElement_Oiled",
                "TerrainElement_Electrified",
                "TerrainElement_ScorchedDirt",
                "TerrainElement_Steam"
            };

            Assert.AreEqual(
                AtlasGuid,
                AssetDatabase.AssetPathToGUID(AtlasPath),
                "正式地表元素图集 GUID 被替换，会使现有 Tile 子资源引用失效。");

            TextureImporter importer = AssetImporter.GetAtPath(AtlasPath) as TextureImporter;
            Assert.IsNotNull(importer, "正式地表元素图集没有 TextureImporter。");
            Assert.AreEqual(SpriteImportMode.Multiple, importer.spriteImportMode);
            Assert.AreEqual(16f, importer.spritePixelsPerUnit);
            Assert.AreEqual(FilterMode.Point, importer.filterMode);
            Assert.AreEqual(TextureImporterCompression.Uncompressed, importer.textureCompression);
            Assert.IsFalse(importer.mipmapEnabled);

            Sprite[] sprites = AssetDatabase.LoadAllAssetRepresentationsAtPath(AtlasPath)
                .OfType<Sprite>()
                .OrderBy(sprite => sprite.rect.x)
                .ToArray();
            Assert.AreEqual(6, sprites.Length, "正式地表元素图集必须保持 6 个切片。");

            for (int i = 0; i < expectedSpriteNames.Length; i++)
            {
                Sprite sprite = sprites.SingleOrDefault(
                    candidate => candidate.name == expectedSpriteNames[i]);
                Assert.IsNotNull(sprite, $"图集缺少切片：{expectedSpriteNames[i]}。");
                Assert.AreEqual(16f, sprite.rect.width);
                Assert.AreEqual(16f, sprite.rect.height);
                Assert.AreEqual(i * 16f, sprite.rect.x);
                Assert.AreEqual(0f, sprite.rect.y);
                Assert.AreEqual(16f, sprite.pixelsPerUnit);
                Assert.AreEqual(new Vector2(8f, 8f), sprite.pivot);

                Assert.AreEqual(
                    expectedTileGuids[i],
                    AssetDatabase.AssetPathToGUID(tilePaths[i]),
                    $"{tilePaths[i]} 的 GUID 被替换，表现配置引用不再稳定。");

                Tile tile = AssetDatabase.LoadAssetAtPath<Tile>(tilePaths[i]);
                Assert.IsNotNull(tile, $"正式地表元素 Tile 不存在：{tilePaths[i]}。");
                Assert.AreSame(
                    sprite,
                    tile.sprite,
                    $"{tile.name} 没有引用预期图集切片 {expectedSpriteNames[i]}。");
                Assert.AreEqual(Color.white, tile.color, $"{tile.name} 不应二次染色。");
                Assert.AreEqual(
                    Matrix4x4.identity,
                    tile.transform,
                    $"{tile.name} 不应携带额外缩放、旋转或偏移。");
                Assert.AreEqual(
                    Tile.ColliderType.None,
                    tile.colliderType,
                    $"{tile.name} 是纯表现覆盖，不应生成碰撞。");
            }

            TerrainSurfacePresentationConfig presentation =
                AssetDatabase.LoadAssetAtPath<TerrainSurfacePresentationConfig>(
                    "Assets/GameData/Elements/Presentation/地表元素表现-首批.asset");
            Assert.IsNotNull(presentation);

            Dictionary<ETerrainElementStateKind, string> expectedStatePaths = new()
            {
                [ETerrainElementStateKind.Burning] = tilePaths[0],
                [ETerrainElementStateKind.Wet] = tilePaths[1],
                [ETerrainElementStateKind.Oiled] = tilePaths[2],
                [ETerrainElementStateKind.Electrified] = tilePaths[3]
            };
            TerrainStateTileMapping[] stateMappings =
                GetPrivateField<TerrainStateTileMapping[]>(presentation, "m_stateTiles");
            for (int i = 0; i < stateMappings.Length; i++)
            {
                Assert.AreEqual(
                    expectedStatePaths[stateMappings[i].StateKind],
                    AssetDatabase.GetAssetPath(stateMappings[i].Tile),
                    $"{stateMappings[i].StateKind} 的表现配置引用了错误 Tile。");
            }

            TerrainSurfaceTileMapping[] surfaceMappings =
                GetPrivateField<TerrainSurfaceTileMapping[]>(presentation, "m_surfaceTiles");
            Assert.AreEqual(tilePaths[4], AssetDatabase.GetAssetPath(surfaceMappings[0].Tile));

            TerrainSignalTileMapping[] signalMappings =
                GetPrivateField<TerrainSignalTileMapping[]>(presentation, "m_signalTiles");
            Assert.AreEqual(tilePaths[5], AssetDatabase.GetAssetPath(signalMappings[0].Tile));
        }

        private static void AssertRegistrySerializationIsUnique(DatabaseRegistry registry)
        {
            SerializedObject serializedRegistry = new(registry);
            SerializedProperty entries = serializedRegistry.FindProperty("m_entries");
            Assert.IsNotNull(entries, "DatabaseRegistry 缺少序列化条目字典。");

            SerializedProperty keys = entries.FindPropertyRelative("m_keys");
            SerializedProperty values = entries.FindPropertyRelative("m_values");
            Assert.IsNotNull(keys, "DatabaseRegistry 缺少序列化 key 列表。");
            Assert.IsNotNull(values, "DatabaseRegistry 缺少序列化 value 列表。");
            Assert.AreEqual(
                keys.arraySize,
                values.arraySize,
                "DatabaseRegistry 的序列化 key/value 数量不一致。");

            HashSet<string> uniqueKeys = new();
            HashSet<Object> uniqueValues = new();
            for (int i = 0; i < keys.arraySize; i++)
            {
                string key = keys.GetArrayElementAtIndex(i).stringValue;
                Object value = values.GetArrayElementAtIndex(i).objectReferenceValue;
                Assert.IsFalse(string.IsNullOrWhiteSpace(key), $"DatabaseRegistry 第 {i} 项 GUID 为空。");
                Assert.IsNotNull(value, $"DatabaseRegistry 第 {i} 项对象引用为空。");
                Assert.IsTrue(uniqueKeys.Add(key), $"DatabaseRegistry 重复登记 GUID：{key}。");
                Assert.IsTrue(
                    uniqueValues.Add(value),
                    $"DatabaseRegistry 重复登记对象：{value.name}。");
            }
        }

        private ElementReactionDefinition CreateReaction(int priority)
        {
            ElementReactionDefinition reaction =
                ScriptableObject.CreateInstance<ElementReactionDefinition>();
            m_createdObjects.Add(reaction);
            SetPrivateField(reaction, "m_trigger", EElementReactionTrigger.OnElementApplied);
            SetPrivateField(reaction, "m_elementKind", EWorldElementKind.Fire);
            SetPrivateField(reaction, "m_priority", priority);
            SetPrivateField(
                reaction,
                "m_operations",
                new[] { new ElementReactionOperation() });
            return reaction;
        }

        private static ElementApplication CreateFireApplication()
        {
            return new ElementApplication(
                EWorldElementKind.Fire,
                1.0f,
                0.25f,
                ElementArea.Cone(3.0f, 30.0f),
                Vector2.zero,
                Vector2.right,
                sourceAbilityCode: 101);
        }

        private static void SetPrivateField(object target, string fieldName, object value)
        {
            FieldInfo field = target.GetType().GetField(
                fieldName,
                BindingFlags.Instance | BindingFlags.NonPublic);
            Assert.IsNotNull(field, $"找不到字段：{target.GetType().Name}.{fieldName}");
            field.SetValue(target, value);
        }

        private static T GetPrivateField<T>(object target, string fieldName)
        {
            FieldInfo field = target.GetType().GetField(
                fieldName,
                BindingFlags.Instance | BindingFlags.NonPublic);
            Assert.IsNotNull(field, $"找不到字段：{target.GetType().Name}.{fieldName}");
            return (T)field.GetValue(target);
        }
    }
}
