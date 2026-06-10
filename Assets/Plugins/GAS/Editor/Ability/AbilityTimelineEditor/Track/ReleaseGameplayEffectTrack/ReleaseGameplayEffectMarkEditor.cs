using System;
using System.Collections.Generic;
using System.Linq;
using GAS.General;
using GAS.Runtime;
using NaughtyAttributes;
using UnityEditor;
using UnityEngine;

namespace GAS.Editor
{
    public class ReleaseGameplayEffectMarkEditor : NaughtyEditorWindow
    {
        private const string GRP_BOX = "GRP_BOX";
        private const string GRP_BOX_CATCHER = "GRP_BOX/Catcher";

        private ReleaseGameplayEffectMark _mark;

        public static ReleaseGameplayEffectMarkEditor Create(ReleaseGameplayEffectMark mark)
        {
            var window = CreateInstance<ReleaseGameplayEffectMarkEditor>();
            window._mark = mark;
            window.UpdateMarkInfo();
            return window;
        }
                        public string RunInfo;

        // TODO TargetCatcher
        [Delayed]
        [OnValueChanged("OnCatcherTypeChanged")]
        public string CatcherType;

        [Delayed]
                [HideIf("CatcherIsNull")]
        [OnValueChanged("OnCatcherChanged")]
        public TargetCatcherInspector Catcher;

        [Delayed]
                        [OnValueChanged("OnGameplayEffectListChanged")]
        public List<GameplayEffectAsset> gameplayEffects;
        [Button]
                void Delete()
        {
            _mark.Delete();
        }

        void UpdateMarkInfo()
        {
            RunInfo = $"<b>Trigger(f):{_mark.MarkData.startFrame}</b>";
            gameplayEffects = _mark.MarkDataForSave.gameplayEffectAssets;

            CatcherType = _mark.MarkDataForSave.jsonTargetCatcher.Type;
            RefreshCatcherInspector();
        }

        void RefreshCatcherInspector()
        {
            // 根据选择的OngoingAbilityTask子类，显示对应的属性
            var catcher = _mark.MarkDataForSave.LoadTargetCatcher();
            if (TargetCatcherInspectorMap.TryGetValue(catcher.GetType(), out var inspectorType))
            {
                var targetCatcherInspector =
                    (TargetCatcherInspector)Activator.CreateInstance(inspectorType, catcher);
                Catcher = targetCatcherInspector;
            }
            else
            {
                Catcher = null;
                Debug.LogWarning($"[EX] TargetCatcherInspector not found: {catcher.GetType()}");
            }
        }

        void OnGameplayEffectListChanged()
        {
            _mark.MarkDataForSave.gameplayEffectAssets = gameplayEffects;
            AbilityTimelineEditorWindow.Instance.Save();
        }

        void OnCatcherTypeChanged()
        {
            _mark.MarkDataForSave.jsonTargetCatcher.Type = CatcherType;
            _mark.MarkDataForSave.jsonTargetCatcher.Data = null;
            AbilityTimelineEditorWindow.Instance.Save();
            AbilityTimelineEditorWindow.Instance.TimelineInspector.RefreshInspector();
        }

        void OnCatcherChanged()
        {
            // _mark.MarkDataForSave.jsonTargetCatcher.Data = Catcher.ToJson();
            // AbilityTimelineEditorWindow.Instance.Save();
        }

        private bool CatcherIsNull => Catcher == null;


        private static Type[] _targetCatcherInspectorTypes;
        private static List<string> TargetCatcherSonTypeChoices;
        private static Dictionary<Type, Type> _targetCatcherInspectorMap;

        public static Type[] TargetCatcherInspectorTypes
        {
            get
            {
                if (_targetCatcherInspectorTypes != null) return _targetCatcherInspectorTypes;
                _targetCatcherInspectorTypes = TypeUtil.GetAllSonTypesOf(typeof(TargetCatcherInspector));
                TargetCatcherSonTypeChoices = ReleaseGameplayEffectMarkEvent.TargetCatcherSonTypes.Select(type => type.FullName).ToList();
                return _targetCatcherInspectorTypes;
            }
        }

        private static Dictionary<Type, Type> TargetCatcherInspectorMap
        {
            get
            {
                if (_targetCatcherInspectorMap != null) return _targetCatcherInspectorMap;
                _targetCatcherInspectorMap = new Dictionary<Type, Type>();
                foreach (var catcherInspectorType in TargetCatcherInspectorTypes)
                {
                    if (catcherInspectorType.BaseType != null)
                    {
                        var targetCatcherType = catcherInspectorType.BaseType.GetGenericArguments()[0];
                        _targetCatcherInspectorMap.Add(targetCatcherType, catcherInspectorType);
                    }
                }

                return _targetCatcherInspectorMap;
            }
        }
    }

    [CustomEditor(typeof(ReleaseGameplayEffectMarkEditor))]
    public class ReleaseGameplayEffectMarkInspector : NaughtyEditorWithoutHeader
    {
    }
}