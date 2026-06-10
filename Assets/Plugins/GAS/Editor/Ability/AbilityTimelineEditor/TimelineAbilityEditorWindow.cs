//
// #if UNITY_EDITOR
// namespace GAS.Editor
// {
//     using Runtime;
//     using UnityEditor;
//     using UnityEngine;
//     using GAS.General;
//
//     [CustomEditor(typeof(TimelineAbilityAsset))]
//     public class TimelineAbilityEditorWindow : NaughtyAttributes.Editor.NaughtyInspector
//     {
//         private TimelineAbilityAsset _asset => target as TimelineAbilityAsset;
//
//         public override void OnInspectorGUI()
//         {
//             base.OnInspectorGUI();
//
//             EditorGUILayout.BeginVertical(GUI.skin.box);
//             if (GUILayout.Button(GASTextDefine.BUTTON_CHECK_TIMELINE_ABILITY, GUILayout.Height(30), GUILayout.Width(300))) EditAbilityTimeline();
//             EditorGUILayout.EndVertical();
//         }
//
//         private void EditAbilityTimeline()
//         {
//             AbilityTimelineEditorWindow.ShowWindow(_asset);
//         }
//     }
// }
// #endif