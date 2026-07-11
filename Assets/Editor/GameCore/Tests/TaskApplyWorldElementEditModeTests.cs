using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using NUnit.Framework;
using UnityEditor;
using UnityEngine;

namespace FantasyWord.GameCore.Tests
{
    public sealed class TaskApplyWorldElementEditModeTests
    {
        [Test]
        public void SubmissionSchedule_DoesNotRepeatBeginFrame()
        {
            MethodInfo method = typeof(TaskApplyWorldElement).GetMethod(
                "ShouldSubmitAtFrame",
                BindingFlags.Static | BindingFlags.NonPublic);
            Assert.IsNotNull(method);

            Assert.IsFalse(InvokeSchedule(method, 10, 10, 3));
            Assert.IsFalse(InvokeSchedule(method, 11, 10, 3));
            Assert.IsFalse(InvokeSchedule(method, 12, 10, 3));
            Assert.IsTrue(InvokeSchedule(method, 13, 10, 3));
            Assert.IsTrue(InvokeSchedule(method, 16, 10, 3));
        }

        [Test]
        public void ParameterExcelRoundTrip_PreservesWorldElementInputs()
        {
            XParamApplyWorldElement source = new();
            source.SetElementKind((int)EWorldElementKind.Electricity);
            source.SetIntensity(0.75f);
            source.SetExposureDuration(0.2f);
            source.SetIntervalFrames(4);
            source.SetConeRange(5.5f);
            source.SetConeHalfAngleDegrees(22.5f);

            List<object> encoded = source.EncodeExcelData();
            XParamApplyWorldElement restored = new();
            restored.DecodeExcelData(encoded);

            Assert.AreEqual(EWorldElementKind.Electricity, restored.ElementKind);
            Assert.AreEqual(0.75f, restored.Intensity);
            Assert.AreEqual(0.2f, restored.ExposureDuration);
            Assert.AreEqual(4, restored.IntervalFrames);
            Assert.AreEqual(5.5f, restored.ConeRange);
            Assert.AreEqual(22.5f, restored.ConeHalfAngleDegrees);
        }

        [Test]
        public void FlamethrowerPrefab_UsesGenericTimelineAbility()
        {
            const string PrefabPath = "Assets/Prefabs/Abilities/World/喷火.prefab";
            GameObject prefab = AssetDatabase.LoadAssetAtPath<GameObject>(PrefabPath);

            Assert.IsNotNull(prefab, "喷火正式 Ability Prefab 不存在。");
            Assert.AreEqual(
                "a146750504c64be4a948e93b1a20e117",
                AssetDatabase.AssetPathToGUID(PrefabPath),
                "喷火 Prefab GUID 与 EX-GAS 原始表不一致。");
            Assert.AreEqual(20010, FormalGasAbilityCodes.Flamethrower);

            TimelineActiveAbility ability = prefab.GetComponent<TimelineActiveAbility>();
            Assert.IsNotNull(ability, "喷火 Prefab 未挂载通用 EX-GAS Timeline 能力桥。");
            Assert.IsFalse(
                ability is MeleeAttackAbility,
                "喷火 Prefab 不应复用基础攻击的近战能力组件。");
        }

        [TestCase(1f, 0f, 0f)]
        [TestCase(0f, 1f, 90f)]
        [TestCase(-1f, 0f, 180f)]
        [TestCase(0f, -1f, -90f)]
        public void FlamethrowerCueVisual_CalculatesCardinalRotation(
            float x,
            float y,
            float expectedDegrees)
        {
            Assert.AreEqual(
                expectedDegrees,
                FlamethrowerCueVisual.CalculateRotationDegrees(new Vector2(x, y)),
                0.001f);
        }

        [Test]
        public void FlamethrowerCueAssets_AreConfiguredForPixelAnimation()
        {
            const string TexturePath =
                "Assets/ArtRes/Effects/Elements/Flamethrower/FlamethrowerJet.png";
            const string PrefabPath =
                "Assets/Prefabs/Abilities/World/喷火-火焰表现.prefab";

            TextureImporter importer = AssetImporter.GetAtPath(TexturePath) as TextureImporter;
            Assert.IsNotNull(importer, "喷火图集没有正式 TextureImporter。");
            Assert.AreEqual(SpriteImportMode.Multiple, importer.spriteImportMode);
            Assert.AreEqual(8f, importer.spritePixelsPerUnit);
            Assert.AreEqual(FilterMode.Point, importer.filterMode);
            Assert.AreEqual(
                TextureImporterCompression.Uncompressed,
                importer.textureCompression);
            Assert.IsFalse(importer.mipmapEnabled);

            Sprite[] frames = AssetDatabase.LoadAllAssetsAtPath(TexturePath)
                .OfType<Sprite>()
                .OrderBy(sprite => sprite.name)
                .ToArray();
            Assert.AreEqual(8, frames.Length, "喷火图集必须保持 8 帧动画。");

            GameObject prefab = AssetDatabase.LoadAssetAtPath<GameObject>(PrefabPath);
            Assert.IsNotNull(prefab, "喷火 GameplayCue 表现 Prefab 不存在。");

            FlamethrowerCueVisual visual = prefab.GetComponent<FlamethrowerCueVisual>();
            Assert.IsNotNull(visual, "喷火表现 Prefab 缺少正式朝向和帧播放组件。");

            SerializedObject serializedVisual = new(visual);
            Assert.IsNotNull(
                serializedVisual.FindProperty("m_renderer").objectReferenceValue,
                "喷火表现组件缺少 SpriteRenderer 引用。");
            Assert.AreEqual(
                8,
                serializedVisual.FindProperty("m_frames").arraySize,
                "喷火表现 Prefab 没有引用完整 8 帧图集。");
            Assert.AreEqual(
                14f,
                serializedVisual.FindProperty("m_framesPerSecond").floatValue,
                0.001f);
        }

        [Test]
        public void FlamethrowerGeneratedTimeline_UsesPresentationOnlyMountCue()
        {
            const string TimelinePath =
                "Assets/DataGenerated/Luban/Json/GAS/exgas_tbtimelineability.json";
            const string CuePrefabPath =
                "Assets/Prefabs/Abilities/World/喷火-火焰表现.prefab";

            string timelineJson = File.ReadAllText(TimelinePath);
            int timelineStart = timelineJson.IndexOf("\"ID\": 20010", System.StringComparison.Ordinal);
            Assert.GreaterOrEqual(timelineStart, 0, "生成 Timeline 中找不到喷火 20010。");

            int nextTimeline = timelineJson.IndexOf(
                "\"ID\":",
                timelineStart + 1,
                System.StringComparison.Ordinal);
            string flamethrowerJson = nextTimeline >= 0
                ? timelineJson.Substring(timelineStart, nextTimeline - timelineStart)
                : timelineJson.Substring(timelineStart);

            Assert.That(flamethrowerJson, Does.Contain("\"$type\": \"CueMountPrefab\""));
            Assert.That(flamethrowerJson, Does.Contain(CuePrefabPath));
            Assert.That(flamethrowerJson, Does.Contain("\"DestroyOnStop\": true"));
            Assert.That(flamethrowerJson, Does.Contain("\"$type\": \"TaskApplyWorldElement\""));
            Assert.That(flamethrowerJson, Does.Not.Contain("Grass"));
            Assert.That(flamethrowerJson, Does.Not.Contain("ScorchedDirt"));

            string visualSource = File.ReadAllText(
                "Assets/Scripts/GameCore/Runtime/Presentation/FlamethrowerCueVisual.cs");
            Assert.That(visualSource, Does.Not.Contain("ElementReactionSystem"));
            Assert.That(visualSource, Does.Not.Contain("TerrainNavigationMap"));
            Assert.That(visualSource, Does.Not.Contain("SetTile"));
            Assert.That(visualSource, Does.Not.Contain("TerrainCellRuntimeState"));
        }

        private static bool InvokeSchedule(
            MethodInfo method,
            int frameIndex,
            int startFrame,
            int intervalFrames)
        {
            return (bool)method.Invoke(
                null,
                new object[] { frameIndex, startFrame, intervalFrames });
        }
    }
}
