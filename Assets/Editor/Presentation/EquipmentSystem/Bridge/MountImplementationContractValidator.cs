using System;
using System.Collections.Generic;
using System.Reflection;
using UnityEditor;
using UnityEngine;

namespace FantasyWord.Presentation.EquipmentSystem
{
    /// <summary>
    /// 坐骑正式实现的编辑器合同验证入口。
    /// 每条合同只检查公开行为，供自动化在进入 PlayMode 前快速阻止能力倒退。
    /// </summary>
    public static class MountImplementationContractValidator
    {
        [MenuItem("Tools/Equipment System/Mounts/验证坐骑实现合同")]
        public static void LogValidationResult()
        {
            Debug.Log(RunActionResolverContract());
        }

        public static string RunActionResolverContract()
        {
            List<string> failures = new();
            Require(
                MountActionResolver.FromCharacterAnimationKey("MountUp") == MountActionSemantic.MountUp,
                "MountUp 没有解析为上坐骑动作。",
                failures);
            Require(
                MountActionResolver.FromCharacterAnimationKey("MountDown") == MountActionSemantic.MountDown,
                "MountDown 没有解析为下坐骑动作。",
                failures);

            return JsonUtility.ToJson(new ContractResult
            {
                Success = failures.Count == 0,
                Failures = failures.ToArray(),
            }, true);
        }

        public static string RunCustomActionContract()
        {
            List<string> failures = new();
            Type requestType = Type.GetType("MountActionRequest, Assembly-CSharp");
            MethodInfo resolver = typeof(MountActionResolver).GetMethod(
                "ResolveRequest",
                BindingFlags.Public | BindingFlags.Static,
                null,
                new[] { typeof(string) },
                null);

            Require(requestType != null, "缺少能携带自定义动作键的 MountActionRequest。", failures);
            Require(resolver != null, "缺少 MountActionResolver.ResolveRequest 公开入口。", failures);
            if (requestType != null && resolver != null)
            {
                object jump = resolver.Invoke(null, new object[] { "Jump" });
                object sleep = resolver.Invoke(null, new object[] { "Sleep" });
                PropertyInfo semantic = requestType.GetProperty("Semantic");
                PropertyInfo customKey = requestType.GetProperty("CustomKey");
                Require(semantic != null && customKey != null, "动作请求没有公开语义或自定义动作键。", failures);
                if (semantic != null && customKey != null)
                {
                    Require(
                        Equals(semantic.GetValue(jump), MountActionSemantic.Custom),
                        "Jump 没有保持 Custom 语义。",
                        failures);
                    Require(
                        string.Equals(customKey.GetValue(jump) as string, "Jump", StringComparison.Ordinal),
                        "Jump 自定义动作键丢失。",
                        failures);
                    Require(
                        string.Equals(customKey.GetValue(sleep) as string, "Sleep", StringComparison.Ordinal),
                        "Sleep 自定义动作键丢失。",
                        failures);
                }
            }

            return CreateResult(failures);
        }

        public static string RunFramePolicyContract()
        {
            List<string> failures = new();
            Texture2D texture = new(1, 1);
            Sprite sprite = Sprite.Create(texture, new Rect(0, 0, 1, 1), Vector2.zero, 1f);
            try
            {
                MountDirectionalFrames frames = new();
                FieldInfo southEast = typeof(MountDirectionalFrames).GetField(
                    "southEast",
                    BindingFlags.Instance | BindingFlags.NonPublic);
                southEast?.SetValue(frames, new[] { sprite });
                Require(
                    frames.GetFrameCount(CharacterAnimationDirections.SouthWest) == 0,
                    "缺少 SW 帧时仍静默使用了 SE 帧。",
                    failures);
                Require(frames.GetFrameCount(-1) == 0, "非法方向索引仍静默使用了 SE 帧。", failures);
                Require(frames.GetFrame(CharacterAnimationDirections.SouthEast, 1) == null,
                    "越界帧索引仍静默夹到了最后一帧。",
                    failures);

                Type behaviorType = Type.GetType("MountLayerEmptyBehavior, Assembly-CSharp");
                Type layoutType = Type.GetType("MountFrameLayout, Assembly-CSharp");
                MethodInfo resolver = layoutType?.GetMethod(
                    "TryResolveFrameCount",
                    BindingFlags.Public | BindingFlags.Static);
                Require(behaviorType != null && resolver != null, "缺少显式坐骑图层空帧策略。", failures);
                if (behaviorType != null && resolver != null)
                {
                    object required = Enum.Parse(behaviorType, "Required");
                    object keepPrevious = Enum.Parse(behaviorType, "KeepPrevious");
                    object hide = Enum.Parse(behaviorType, "Hide");

                    object[] mountUpArgs = { 0, 5, keepPrevious, required, 0 };
                    bool mountUpValid = (bool)resolver.Invoke(null, mountUpArgs);
                    Require(mountUpValid && (int)mountUpArgs[4] == 5, "只有骑手帧的上坐骑动作不能播放。", failures);

                    object[] dieArgs = { 11, 0, required, hide, 0 };
                    bool dieValid = (bool)resolver.Invoke(null, dieArgs);
                    Require(dieValid && (int)dieArgs[4] == 11, "只有坐骑帧的死亡动作不能播放。", failures);

                    object[] mismatchArgs = { 4, 6, required, required, 0 };
                    Require(!(bool)resolver.Invoke(null, mismatchArgs), "本体和骑手帧数不一致时仍被静默截断。", failures);
                }
            }
            finally
            {
                UnityEngine.Object.DestroyImmediate(sprite);
                UnityEngine.Object.DestroyImmediate(texture);
            }

            return CreateResult(failures);
        }

        public static string RunAnimationSelectionContract()
        {
            List<string> failures = new();
            MethodInfo selector = typeof(MountRenderData).GetMethod(
                "TryGetAnimation",
                BindingFlags.Public | BindingFlags.Instance,
                null,
                new[]
                {
                    typeof(MountActionRequest),
                    typeof(MountAnimationData).MakeByRefType(),
                    typeof(bool).MakeByRefType(),
                },
                null);
            Require(selector != null, "缺少能报告回退结果的坐骑动作选择入口。", failures);
            if (selector == null)
                return CreateResult(failures);

            MountRenderData data = ScriptableObject.CreateInstance<MountRenderData>();
            try
            {
                SerializedObject serialized = new(data);
                SerializedProperty animations = serialized.FindProperty("animations");
                animations.arraySize = 3;
                ConfigureAction(animations.GetArrayElementAtIndex(0), MountActionSemantic.Custom, "Jump");
                ConfigureAction(animations.GetArrayElementAtIndex(1), MountActionSemantic.Custom, "Sleep");
                ConfigureAction(animations.GetArrayElementAtIndex(2), MountActionSemantic.Stand, string.Empty);
                serialized.ApplyModifiedPropertiesWithoutUndo();

                object[] sleepArgs = { new MountActionRequest(MountActionSemantic.Custom, "Sleep"), null, false };
                bool sleepFound = (bool)selector.Invoke(data, sleepArgs);
                MountAnimationData sleep = sleepArgs[1] as MountAnimationData;
                PropertyInfo customActionKeyProperty = typeof(MountAnimationData).GetProperty("CustomActionKey");
                Require(
                    sleepFound
                    && sleep != null
                    && customActionKeyProperty != null
                    && string.Equals(customActionKeyProperty.GetValue(sleep) as string, "Sleep", StringComparison.Ordinal),
                    "Sleep 没有精确命中自己的自定义动作。",
                    failures);
                Require(!(bool)sleepArgs[2], "精确命中 Sleep 却被报告为回退。", failures);

                object[] attackArgs = { new MountActionRequest(MountActionSemantic.Attack), null, false };
                bool attackFound = (bool)selector.Invoke(data, attackArgs);
                MountAnimationData fallback = attackArgs[1] as MountAnimationData;
                Require(
                    attackFound && fallback != null && fallback.EffectiveAction == MountActionSemantic.Stand,
                    "不支持 Attack 时没有按资产默认语义回退 Stand。",
                    failures);
                Require((bool)attackArgs[2], "Attack 回退 Stand 没有显式报告。", failures);
            }
            finally
            {
                UnityEngine.Object.DestroyImmediate(data);
            }

            return CreateResult(failures);
        }

        public static string RunRuntimeApiContract()
        {
            List<string> failures = new();
            MethodInfo setContext = typeof(EquipmentRenderer).GetMethod(
                "SetAnimationContextOverride",
                BindingFlags.Public | BindingFlags.Instance,
                null,
                new[] { typeof(string), typeof(bool) },
                null);
            MethodInfo clearContext = typeof(EquipmentRenderer).GetMethod(
                "ClearAnimationContextOverride",
                BindingFlags.Public | BindingFlags.Instance,
                null,
                new[] { typeof(bool) },
                null);
            MethodInfo playAction = typeof(MountedCharacterPresentation).GetMethod(
                "TryPlayAction",
                BindingFlags.Public | BindingFlags.Instance,
                null,
                new[] { typeof(MountActionSemantic), typeof(string) },
                null);
            MethodInfo refreshOverlay = typeof(MountedCharacterPresentation).GetMethod(
                "RefreshRiderEquipmentOverlayFromRenderer",
                BindingFlags.Public | BindingFlags.Instance,
                null,
                Type.EmptyTypes,
                null);

            Require(setContext != null && clearContext != null, "换装渲染器缺少显式骑乘动作上下文。", failures);
            Require(playAction != null, "坐骑表现缺少主动动作请求入口。", failures);
            Require(refreshOverlay != null, "坐骑表现不能从最终渲染槽状态刷新骑手换装。", failures);
            return CreateResult(failures);
        }

        public static string RunGeneratorPreservationContract()
        {
            List<string> failures = new();
            MethodInfo configureMount = typeof(MountSampleAssetGenerator).GetMethod(
                "ConfigureMountAsset",
                BindingFlags.NonPublic | BindingFlags.Static);
            CharacterFrameData frameData = AssetDatabase.LoadAssetAtPath<CharacterFrameData>(
                "Assets/GameData/EquipmentSystem/FrameData/人类战马骑乘帧数据.asset");
            AnimationTypeItem idle = AssetDatabase.LoadAssetAtPath<AnimationTypeItem>(
                "Assets/GameData/EquipmentSystem/AnimationType/Idle.asset");
            AnimationTypeItem walk = AssetDatabase.LoadAssetAtPath<AnimationTypeItem>(
                "Assets/GameData/EquipmentSystem/AnimationType/Walk.asset");

            Require(configureMount != null, "坐骑生成器缺少可验证的表现资产配置入口。", failures);
            Require(frameData != null && idle != null && walk != null, "生成器保留合同缺少正式帧数据或动作资产。", failures);
            if (configureMount == null || frameData == null || idle == null || walk == null)
                return CreateResult(failures);

            MountRenderData data = ScriptableObject.CreateInstance<MountRenderData>();
            try
            {
                SerializedObject before = new(data);
                SerializedProperty animations = before.FindProperty("animations");
                animations.arraySize = 1;
                SerializedProperty custom = animations.GetArrayElementAtIndex(0);
                custom.FindPropertyRelative("mountAction").enumValueIndex = (int)MountActionSemantic.Custom;
                custom.FindPropertyRelative("customActionKey").stringValue = "Sleep";
                custom.FindPropertyRelative("cycleDurationSeconds").floatValue = 3.75f;
                before.ApplyModifiedPropertiesWithoutUndo();

                configureMount.Invoke(null, new object[] { data, frameData, idle, walk });

                SerializedObject after = new(data);
                SerializedProperty configuredAnimations = after.FindProperty("animations");
                Require(configuredAnimations.arraySize == 3, "生成 Stand/Move 时删除或重复追加了已有自定义动作。", failures);

                bool customPreserved = false;
                for (int i = 0; i < configuredAnimations.arraySize; i++)
                {
                    SerializedProperty candidate = configuredAnimations.GetArrayElementAtIndex(i);
                    if (candidate.FindPropertyRelative("mountAction").enumValueIndex != (int)MountActionSemantic.Custom)
                        continue;

                    customPreserved =
                        string.Equals(
                            candidate.FindPropertyRelative("customActionKey").stringValue,
                            "Sleep",
                            StringComparison.Ordinal)
                        && Mathf.Approximately(
                            candidate.FindPropertyRelative("cycleDurationSeconds").floatValue,
                            3.75f);
                    break;
                }

                Require(customPreserved, "生成 Stand/Move 时覆盖了已有 Sleep 动作的人工配置。", failures);
            }
            catch (TargetInvocationException exception)
            {
                failures.Add(exception.InnerException?.Message ?? exception.Message);
            }
            finally
            {
                UnityEngine.Object.DestroyImmediate(data);
            }

            return CreateResult(failures);
        }

        static void ConfigureAction(
            SerializedProperty animation,
            MountActionSemantic semantic,
            string customActionKey)
        {
            animation.FindPropertyRelative("mountAction").enumValueIndex = (int)semantic;
            SerializedProperty customKey = animation.FindPropertyRelative("customActionKey");
            if (customKey != null)
                customKey.stringValue = customActionKey;
        }

        static void Require(bool condition, string failure, List<string> failures)
        {
            if (!condition)
                failures.Add(failure);
        }

        static string CreateResult(List<string> failures)
        {
            return JsonUtility.ToJson(new ContractResult
            {
                Success = failures.Count == 0,
                Failures = failures.ToArray(),
            }, true);
        }

        [Serializable]
        sealed class ContractResult
        {
            public bool Success;
            public string[] Failures = Array.Empty<string>();
        }
    }
}
