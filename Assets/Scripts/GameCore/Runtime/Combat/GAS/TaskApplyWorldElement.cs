using System;
using System.Collections.Generic;
using GAS.General;
using GAS.Runtime;
using Sirenix.OdinInspector;
using UnityEngine;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// EX-GAS Timeline 向世界地表提交元素的薄桥接。
    /// 地表匹配、状态合并和地貌转化全部由 ElementReactionSystem 决定。
    /// </summary>
    public sealed class TaskApplyWorldElement : AbilityTaskBase<XParamApplyWorldElement>
    {
#if UNITY_EDITOR
        public static int DebugSubmitCount { get; private set; }
        public static int DebugSuccessfulApplyCount { get; private set; }
        public static bool DebugLastApplyReturned { get; private set; }
        public static string DebugLastFailure { get; private set; } = string.Empty;
        public static Vector3 DebugLastOrigin { get; private set; }
        public static Vector2 DebugLastDirection { get; private set; }
        public static int DebugLastSourceAbilityCode { get; private set; }

        public static void ResetDebugState()
        {
            DebugSubmitCount = 0;
            DebugSuccessfulApplyCount = 0;
            DebugLastApplyReturned = false;
            DebugLastFailure = string.Empty;
            DebugLastOrigin = default;
            DebugLastDirection = default;
            DebugLastSourceAbilityCode = 0;
        }
#endif

        public TaskApplyWorldElement(AbilityLogicBase logic) : base(logic)
        {
        }

        protected override void OnBegin(int startFrame)
        {
            SubmitCurrentPose();
        }

        protected override void OnTick(int frameIndex)
        {
            if (ShouldSubmitAtFrame(
                    frameIndex,
                    _startTime,
                    Parameter?.IntervalFrames ?? 1))
            {
                SubmitCurrentPose();
            }
        }

        internal static bool ShouldSubmitAtFrame(
            int frameIndex,
            int startFrame,
            int intervalFrames)
        {
            int normalizedInterval = Mathf.Max(1, intervalFrames);
            return frameIndex > startFrame &&
                (frameIndex - startFrame) % normalizedInterval == 0;
        }

        private bool SubmitCurrentPose()
        {
            RecordDebugSubmit();

            if (Parameter == null)
            {
                Debug.LogError("TaskApplyWorldElement 缺少参数，无法提交世界元素。");
                RecordDebugFailure("缺少参数");
                return false;
            }

            GameObject source = Owner?.GameObject;
            if (source == null)
            {
                Debug.LogError("TaskApplyWorldElement 缺少施法者对象，无法提交世界元素。");
                RecordDebugFailure("缺少施法者对象");
                return false;
            }

            Movable movable = source.GetComponent<Movable>();
            if (movable == null)
            {
                Debug.LogError(
                    "TaskApplyWorldElement 要求施法者挂载 Movable，以读取执行帧的正式 2D 朝向。",
                    source);
                RecordDebugFailure("施法者缺少 Movable");
                return false;
            }

            if (!movable.TryGetGas2DFacingDirection(out Vector2 direction))
            {
                Debug.LogError(
                    "TaskApplyWorldElement 无法取得施法者在执行帧的正式 2D 朝向。",
                    source);
                RecordDebugFailure("无法取得正式 2D 朝向");
                return false;
            }

            if (!GameManager.Exists() ||
                !GameManager.TryGetSystem<ElementReactionSystem>(
                    out ElementReactionSystem reactionSystem))
            {
                Debug.LogError(
                    "TaskApplyWorldElement 无法取得 ElementReactionSystem，本次世界元素未生效。",
                    source);
                RecordDebugFailure("无法取得 ElementReactionSystem");
                return false;
            }

            ElementApplication application = new(
                Parameter.ElementKind,
                Parameter.Intensity,
                Parameter.ExposureDuration,
                ElementArea.Cone(
                    Parameter.ConeRange,
                    Parameter.ConeHalfAngleDegrees),
                source.transform.position,
                direction,
                source,
                Spec?.Code ?? 0);
            bool applyReturned = reactionSystem.Apply(application);
            RecordDebugApply(application, applyReturned);
            return applyReturned;
        }

        private static void RecordDebugSubmit()
        {
#if UNITY_EDITOR
            ++DebugSubmitCount;
            DebugLastApplyReturned = false;
            DebugLastFailure = string.Empty;
#endif
        }

        private static void RecordDebugFailure(string failure)
        {
#if UNITY_EDITOR
            DebugLastFailure = failure;
            DebugLastApplyReturned = false;
#endif
        }

        private static void RecordDebugApply(
            in ElementApplication application,
            bool applyReturned)
        {
#if UNITY_EDITOR
            DebugLastApplyReturned = applyReturned;
            DebugLastFailure = applyReturned ? string.Empty : "ElementReactionSystem.Apply 返回 false";
            DebugLastOrigin = application.Origin;
            DebugLastDirection = application.Direction;
            DebugLastSourceAbilityCode = application.SourceAbilityCode;
            if (applyReturned)
            {
                ++DebugSuccessfulApplyCount;
            }
#endif
        }
    }

    [Serializable]
    public sealed class XParamApplyWorldElement : XParam
    {
        [ShowInInspector]
        [LabelText("世界元素")]
        [BeanField(
            nameof(SetElementKind),
            LubanType = "int",
            Comment = "世界元素类型",
            Order = 1)]
        public EWorldElementKind ElementKind { get; private set; } =
            EWorldElementKind.Fire;

        [ShowInInspector]
        [LabelText("强度")]
        [Range(0.0f, 1.0f)]
        [BeanField(nameof(SetIntensity), Comment = "元素强度", Order = 2)]
        public float Intensity { get; private set; } = 1.0f;

        [ShowInInspector]
        [LabelText("暴露时长")]
        [MinValue(0.0f)]
        [BeanField(
            nameof(SetExposureDuration),
            Comment = "单次元素暴露时长",
            Order = 3)]
        public float ExposureDuration { get; private set; } = 0.1f;

        [ShowInInspector]
        [LabelText("重复间隔帧")]
        [MinValue(1)]
        [BeanField(
            nameof(SetIntervalFrames),
            Comment = "持续片段重复提交间隔帧",
            Order = 4)]
        public int IntervalFrames { get; private set; } = 1;

        [ShowInInspector]
        [LabelText("锥形距离")]
        [MinValue(0.01f)]
        [BeanField(nameof(SetConeRange), Comment = "锥形世界距离", Order = 5)]
        public float ConeRange { get; private set; } = 3.0f;

        [ShowInInspector]
        [LabelText("锥形半角")]
        [Range(0.1f, 180.0f)]
        [BeanField(
            nameof(SetConeHalfAngleDegrees),
            Comment = "锥形半角（度）",
            Order = 6)]
        public float ConeHalfAngleDegrees { get; private set; } = 30.0f;

        public void SetElementKind(int value)
        {
            ElementKind = Enum.IsDefined(typeof(EWorldElementKind), value)
                ? (EWorldElementKind)value
                : EWorldElementKind.Fire;
        }

        public void SetIntensity(float value)
        {
            Intensity = Mathf.Clamp01(value);
        }

        public void SetExposureDuration(float value)
        {
            ExposureDuration = Mathf.Max(0.0f, value);
        }

        public void SetIntervalFrames(int value)
        {
            IntervalFrames = Mathf.Max(1, value);
        }

        public void SetConeRange(float value)
        {
            ConeRange = Mathf.Max(0.01f, value);
        }

        public void SetConeHalfAngleDegrees(float value)
        {
            ConeHalfAngleDegrees = Mathf.Clamp(value, 0.1f, 180.0f);
        }

#if UNITY_EDITOR
        public void DecodeExcelData(List<object> paramData)
        {
            if (paramData == null)
            {
                return;
            }

            if (TryReadInt(paramData, 0, out int elementKind))
            {
                SetElementKind(elementKind);
            }

            if (TryReadFloat(paramData, 1, out float intensity))
            {
                SetIntensity(intensity);
            }

            if (TryReadFloat(paramData, 2, out float exposureDuration))
            {
                SetExposureDuration(exposureDuration);
            }

            if (TryReadInt(paramData, 3, out int intervalFrames))
            {
                SetIntervalFrames(intervalFrames);
            }

            if (TryReadFloat(paramData, 4, out float coneRange))
            {
                SetConeRange(coneRange);
            }

            if (TryReadFloat(paramData, 5, out float coneHalfAngleDegrees))
            {
                SetConeHalfAngleDegrees(coneHalfAngleDegrees);
            }
        }

        public List<object> EncodeExcelData()
        {
            return new List<object>
            {
                (int)ElementKind,
                Intensity,
                ExposureDuration,
                IntervalFrames,
                ConeRange,
                ConeHalfAngleDegrees
            };
        }

        private static bool TryReadInt(
            IReadOnlyList<object> values,
            int index,
            out int value)
        {
            value = default;
            return index < values.Count &&
                int.TryParse(values[index]?.ToString(), out value);
        }

        private static bool TryReadFloat(
            IReadOnlyList<object> values,
            int index,
            out float value)
        {
            value = default;
            return index < values.Count &&
                float.TryParse(
                    values[index]?.ToString(),
                    System.Globalization.NumberStyles.Float,
                    System.Globalization.CultureInfo.InvariantCulture,
                    out value);
        }
#endif
    }
}
