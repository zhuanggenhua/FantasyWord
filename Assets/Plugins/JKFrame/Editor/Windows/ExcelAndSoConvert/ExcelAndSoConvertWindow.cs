using UnityEditor;
using UnityEngine;
using UnityEngine.UIElements;

namespace JKFrame.Editor
{
    public class ExcelAndSoConvertWindow : EditorWindow
    {
        public int num;
        public ExcelAndSoConvertSetting setting;     // 通过面板拖拽赋值
        public VisualTreeAsset editorUIAsset;   // 通过面板拖拽赋值
        [MenuItem("JKFrame/Excel和SO互转")]
        public static void ShowExample()
        {
            ExcelAndSoConvertWindow wnd = GetWindow<ExcelAndSoConvertWindow>();
            wnd.titleContent = new GUIContent("Excel和SO互转");
        }

        public void CreateGUI()
        {
            VisualElement root = rootVisualElement;

            root.Add(new IMGUIContainer(DrawSettingInspector));
            root.Add(editorUIAsset.Instantiate());
        }

        private void DrawSettingInspector()
        {
            setting = (ExcelAndSoConvertSetting)EditorGUILayout.ObjectField("设置", setting, typeof(ExcelAndSoConvertSetting), false);
            if (setting == null)
            {
                EditorGUILayout.HelpBox("请指定 Excel 和 SO 互转设置资产。", MessageType.Info);
                return;
            }

            global::UnityEditor.Editor editor = global::UnityEditor.Editor.CreateEditor(setting);
            try
            {
                editor.OnInspectorGUI();
            }
            finally
            {
                if (editor != null)
                {
                    DestroyImmediate(editor);
                }
            }
        }
    }
}
