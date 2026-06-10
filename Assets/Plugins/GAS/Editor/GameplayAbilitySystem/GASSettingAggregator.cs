using UnityEditor;
using UnityEngine;

namespace GAS.Editor
{
    /// <summary>
    /// EX-GAS 设置窗口；使用 Unity 原生 Inspector 绘制设置资产，避免继续依赖退役的第三方 ProjectMenu 编辑器框架。
    /// </summary>
    public sealed class GASSettingAggregator : EditorWindow
    {
        private Vector2 _scroll;
        private UnityEditor.Editor _settingEditor;
        private UnityEditor.Editor _tagsEditor;
        private UnityEditor.Editor _attributeEditor;
        private UnityEditor.Editor _attributeSetEditor;

        private const string OpenWindowMenuItemName = "EX-GAS/Settings";

        [MenuItem(OpenWindowMenuItemName, priority = 0)]
        public static void OpenWindow()
        {
            GASSettingAggregator window = GetWindow<GASSettingAggregator>();
            window.titleContent = new GUIContent("EX-GAS Settings");
            window.minSize = new Vector2(720f, 420f);
            window.RebuildEditors();
        }

        private void OnEnable()
        {
            RebuildEditors();
        }

        private void OnDisable()
        {
            DestroyCachedEditor(_settingEditor);
            DestroyCachedEditor(_tagsEditor);
            DestroyCachedEditor(_attributeEditor);
            DestroyCachedEditor(_attributeSetEditor);
        }

        private void OnGUI()
        {
            if (_settingEditor == null)
            {
                RebuildEditors();
            }

            _scroll = EditorGUILayout.BeginScrollView(_scroll);
            DrawEditor("GAS 设置", _settingEditor);
            DrawEditor("Gameplay Tags", _tagsEditor);
            DrawEditor("Attributes", _attributeEditor);
            DrawEditor("Attribute Sets", _attributeSetEditor);
            EditorGUILayout.EndScrollView();

            if (GUI.changed)
            {
                GASSettingAsset.Save();
                GameplayTagsAsset.Save();
                AttributeAsset.Save();
                AttributeSetAsset.Save();
            }
        }

        private void RebuildEditors()
        {
            DestroyCachedEditor(_settingEditor);
            DestroyCachedEditor(_tagsEditor);
            DestroyCachedEditor(_attributeEditor);
            DestroyCachedEditor(_attributeSetEditor);

            _settingEditor = UnityEditor.Editor.CreateEditor(GASSettingAsset.LoadOrCreate());
            _tagsEditor = UnityEditor.Editor.CreateEditor(GameplayTagsAsset.LoadOrCreate());
            _attributeEditor = UnityEditor.Editor.CreateEditor(AttributeAsset.LoadOrCreate());
            _attributeSetEditor = UnityEditor.Editor.CreateEditor(AttributeSetAsset.LoadOrCreate());
        }

        private static void DrawEditor(string title, UnityEditor.Editor editor)
        {
            EditorGUILayout.Space(8f);
            EditorGUILayout.LabelField(title, EditorStyles.boldLabel);
            editor?.OnInspectorGUI();
        }

        private static void DestroyCachedEditor(UnityEditor.Editor editor)
        {
            if (editor != null)
            {
                DestroyImmediate(editor);
            }
        }
    }
}
