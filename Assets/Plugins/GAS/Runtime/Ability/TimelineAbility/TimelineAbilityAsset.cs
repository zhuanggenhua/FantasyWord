using System;
using System.Collections.Generic;
using System.Reflection;
using GAS.General;
using NaughtyAttributes;
using UnityEditor;
using UnityEngine;

namespace GAS.Runtime
{
    public abstract class TimelineAbilityAssetBase : AbilityAsset
    {
                                [Button("查看/编辑能力时间轴")]
                private void EditAbilityTimeline()
        {
            try
            {
                var assembly = Assembly.Load("com.exhard.exgas.editor");
                var type = assembly.GetType("GAS.Editor.AbilityTimelineEditorWindow");
                var methodInfo = type.GetMethod("ShowWindow", BindingFlags.Public | BindingFlags.Static);
                methodInfo!.Invoke(null, new object[] { this });
            }
            catch (Exception e)
            {
                Debug.LogError(
                    $"调用\"GAS.Editor.AbilityTimelineEditorWindow\"类的静态方法ShowWindow(TimelineAbilityAsset asset)失败, 代码可能被重构了: {e}");
            }
        }

                [Label(GASTextDefine.ABILITY_MANUAL_ENDABILITY)]
                public bool manualEndAbility;

        [HideInInspector]
        public int FrameCount; // 能力结束时间

        [HideInInspector]
        public List<DurationalCueTrackData> DurationalCues = new List<DurationalCueTrackData>();

        [HideInInspector]
        public List<InstantCueTrackData> InstantCues = new List<InstantCueTrackData>();

        [HideInInspector]
        public List<ReleaseGameplayEffectTrackData> ReleaseGameplayEffect = new List<ReleaseGameplayEffectTrackData>();

        [HideInInspector]
        public List<BuffGameplayEffectTrackData> BuffGameplayEffects = new List<BuffGameplayEffectTrackData>();

        [HideInInspector]
        public List<TaskMarkEventTrackData> InstantTasks = new List<TaskMarkEventTrackData>();

        [HideInInspector]
        public List<TaskClipEventTrackData> OngoingTasks = new List<TaskClipEventTrackData>();

#if UNITY_EDITOR
        public void Save()
        {
            EditorUtility.SetDirty(this);
            AssetDatabase.SaveAssets();
        }
#endif
    }

    public abstract class TimelineAbilityAssetT<T> : TimelineAbilityAssetBase where T : class
    {
        public sealed override Type AbilityType()
        {
            return typeof(T);
        }
    }

    /// <summary>
    /// 这是一个最朴素的TimelineAbilityAsset实现, 如果要实现更复杂的TimelineAbilityAsset, 请用TimelineAbilityAssetBase或TimelineAbilityAssetT为基类
    /// </summary>
    public sealed class TimelineAbilityAsset : TimelineAbilityAssetT<TimelineAbility>
    {
    }
}