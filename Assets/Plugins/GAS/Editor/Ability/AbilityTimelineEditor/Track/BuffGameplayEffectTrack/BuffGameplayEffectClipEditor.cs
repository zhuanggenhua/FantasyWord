#if UNITY_EDITOR
namespace GAS.Editor
{
    using UnityEditor;
    using UnityEngine;
    using NaughtyAttributes;
    using GAS.Runtime;

    public class BuffGameplayEffectClipEditor : NaughtyEditorWindow
    {
        private TimelineAbilityAssetBase AbilityAsset => AbilityTimelineEditorWindow.Instance.AbilityAsset;

        private BuffGameplayEffectClip _clip;

        public static BuffGameplayEffectClipEditor Create(BuffGameplayEffectClip clip)
        {
            var window = new BuffGameplayEffectClipEditor();
            window._clip = clip;
            window.Refresh();
            return window;
        }
                        public string RunInfo;

        [Delayed]
        [OnValueChanged("OnDurationFrameChanged")]
        public int Duration;

        [Delayed]
                [OnValueChanged("OnBuffChanged")]
        public GameplayEffectAsset Buff;
        [Button]
                void Delete()
        {
            _clip.Delete();
        }

        void Refresh()
        {
            Buff = _clip.BuffGameplayEffectClipData.gameplayEffect;
            RunInfo = $"<b>Run(f):{_clip.BuffGameplayEffectClipData.startFrame} -> {_clip.BuffGameplayEffectClipData.EndFrame}</b>";
            Duration = _clip.BuffGameplayEffectClipData.durationFrame;
        }

        private void OnDurationFrameChanged()
        {
            // 钳制
            var max = AbilityAsset.FrameCount - _clip.BuffGameplayEffectClipData.startFrame;
            var newValue = Mathf.Clamp(Duration, 1, max);
            // 保存数据
            _clip.UpdateClipDataDurationFrame(newValue);

            _clip.RefreshShow(_clip.FrameUnitWidth);
            Refresh();
        }

        private void OnBuffChanged()
        {
            _clip.UpdateClipDataBuff(Buff);
            _clip.RefreshShow(_clip.FrameUnitWidth);
            Refresh();
        }
    }


    [CustomEditor(typeof(BuffGameplayEffectClipEditor))]
    public class BuffGameplayEffectClipInspector : NaughtyEditorWithoutHeader
    {
        public override void OnInspectorGUI()
        {
            EditorGUILayout.HelpBox("【注意！！】请确保设置的GameplayEffect类型为Durational或Infinite。 非持续类型的GameplayEffect不会生效。且GameplayEffect执行时会设置为Infinite执行策略， 生命周期由Clip长度（Duration）决定。", MessageType.Info);

            GUILayout.Space(20);

            base.OnInspectorGUI();
        }
    }
}
#endif