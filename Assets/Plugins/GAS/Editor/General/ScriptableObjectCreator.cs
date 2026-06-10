#if UNITY_EDITOR
namespace GAS.Editor
{
    using System;
    using System.Collections.Generic;
    using System.IO;
    using System.Linq;
    using UnityEditor;
    using UnityEngine;

    public static class ScriptableObjectCreator
    {
        public static void ShowDialog<T>(string defaultDestinationPath, Action<T> onScritpableObjectCreated = null)
            where T : ScriptableObject
        {
            var types = TypeCache.GetTypesDerivedFrom<T>()
                .Where(type => type is { IsClass: true, IsAbstract: false })
                .OrderBy(type => type.Name)
                .ToArray();

            if (types.Length == 0)
            {
                EditorUtility.DisplayDialog("创建失败", $"未找到 {typeof(T).Name} 的可创建子类。", "确定");
                return;
            }

            if (types.Length == 1)
            {
                CreateAsset(types[0], defaultDestinationPath, onScritpableObjectCreated);
                return;
            }

            ScriptableObjectTypeSelector<T>.Open(types, defaultDestinationPath, onScritpableObjectCreated);
        }

        private static void CreateAsset<T>(Type selectedType, string defaultDestinationPath, Action<T> onScritpableObjectCreated)
            where T : ScriptableObject
        {
            var obj = ScriptableObject.CreateInstance(selectedType) as T;
            var destinationPath = defaultDestinationPath.TrimEnd('/');

            if (!Directory.Exists(destinationPath))
            {
                Directory.CreateDirectory(destinationPath);
                AssetDatabase.Refresh();
            }

            var absolutePath = EditorUtility.SaveFilePanel("保存资源", destinationPath, $"New {typeof(T).Name}", "asset");
            if (!string.IsNullOrEmpty(absolutePath) &&
                TryMakeAssetsRelativePath(absolutePath, out var assetPath))
            {
                AssetDatabase.CreateAsset(obj, assetPath);
                AssetDatabase.Refresh();
                onScritpableObjectCreated?.Invoke(obj);
                return;
            }

            UnityEngine.Object.DestroyImmediate(obj);
        }

        private static bool TryMakeAssetsRelativePath(string absolutePath, out string assetPath)
        {
            var projectRoot = Path.GetDirectoryName(Application.dataPath);
            assetPath = absolutePath;
            if (string.IsNullOrEmpty(projectRoot))
            {
                return false;
            }

            var relative = Path.GetRelativePath(projectRoot, absolutePath).Replace('\\', '/');
            if (!relative.StartsWith("Assets/", StringComparison.Ordinal))
            {
                return false;
            }

            assetPath = relative;
            return true;
        }

        private sealed class ScriptableObjectTypeSelector<T> : EditorWindow where T : ScriptableObject
        {
            private Type[] types;
            private string defaultDestinationPath;
            private Action<T> onCreated;
            private Vector2 scroll;

            public static void Open(IEnumerable<Type> types, string defaultDestinationPath, Action<T> onCreated)
            {
                var window = CreateInstance<ScriptableObjectTypeSelector<T>>();
                window.types = types.ToArray();
                window.defaultDestinationPath = defaultDestinationPath;
                window.onCreated = onCreated;
                window.titleContent = new GUIContent("选择资源类型");
                window.ShowUtility();
            }

            private void OnGUI()
            {
                EditorGUILayout.LabelField("选择要创建的资源类型", EditorStyles.boldLabel);
                scroll = EditorGUILayout.BeginScrollView(scroll);
                foreach (var type in types)
                {
                    if (GUILayout.Button(type.Name, EditorStyles.toolbarButton))
                    {
                        Close();
                        CreateAsset(type, defaultDestinationPath, onCreated);
                    }
                }

                EditorGUILayout.EndScrollView();
            }
        }
    }
}
#endif
