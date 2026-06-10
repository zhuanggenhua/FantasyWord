using System;
using System.Collections.Generic;
using System.IO;
using GAS.Runtime;
using UnityEditor;
using UnityEngine;
using Object = UnityEngine.Object;

namespace GAS.Editor
{
    /// <summary>
    /// EX-GAS 资产聚合窗口；当前项目移除了原插件依赖的第三方 ProjectMenu 编辑器框架，因此这里使用 Unity 原生 EditorWindow 保留正式资产入口。
    /// </summary>
    public sealed class GASAssetAggregator : EditorWindow
    {
        private readonly List<Object> _assets = new();
        private Vector2 _scroll;
        private int _selectedLibraryIndex;

        private static readonly Type[] AssetTypes =
        {
            typeof(ModifierMagnitudeCalculation),
            typeof(GameplayCue),
            typeof(GameplayEffectAsset),
            typeof(AbilityAsset),
            typeof(AbilitySystemComponentPreset)
        };

        private static readonly string[] LibraryLabels =
        {
            "Mod Magnitude Calculation",
            "Gameplay Cue",
            "Gameplay Effect",
            "Ability",
            "Ability System Component"
        };

        private static string[] LibraryPaths => new[]
        {
            GASSettingAsset.MMCLibPath,
            GASSettingAsset.GameplayCueLibPath,
            GASSettingAsset.GameplayEffectLibPath,
            GASSettingAsset.GameplayAbilityLibPath,
            GASSettingAsset.ASCLibPath
        };

        private const string OpenWindowMenuItemName = "EX-GAS/Asset Aggregator";

        [MenuItem(OpenWindowMenuItemName, priority = 1)]
        private static void OpenWindow()
        {
            GASAssetAggregator window = GetWindow<GASAssetAggregator>();
            window.titleContent = new GUIContent("EX-GAS Assets");
            window.minSize = new Vector2(760f, 420f);
            window.RefreshAssets();
        }

        private void OnEnable()
        {
            RefreshAssets();
        }

        private void OnGUI()
        {
            EditorGUILayout.Space(6f);
            using (new EditorGUILayout.HorizontalScope(EditorStyles.toolbar))
            {
                _selectedLibraryIndex = EditorGUILayout.Popup(_selectedLibraryIndex, LibraryLabels, EditorStyles.toolbarPopup, GUILayout.Width(220f));
                if (GUILayout.Button("刷新", EditorStyles.toolbarButton, GUILayout.Width(64f)))
                {
                    RefreshAssets();
                }

                if (GUILayout.Button("打开目录", EditorStyles.toolbarButton, GUILayout.Width(80f)))
                {
                    OpenSelectedLibraryFolder();
                }

                if (GUILayout.Button("新建资产", EditorStyles.toolbarButton, GUILayout.Width(80f)))
                {
                    CreateAssetInSelectedLibrary();
                }
            }

            _scroll = EditorGUILayout.BeginScrollView(_scroll);
            for (int i = 0; i < _assets.Count; i++)
            {
                Object asset = _assets[i];
                using (new EditorGUILayout.HorizontalScope())
                {
                    EditorGUILayout.ObjectField(asset, AssetTypes[_selectedLibraryIndex], false);
                    if (GUILayout.Button("定位", GUILayout.Width(56f)))
                    {
                        Selection.activeObject = asset;
                        EditorGUIUtility.PingObject(asset);
                    }
                }
            }
            EditorGUILayout.EndScrollView();
        }

        private void RefreshAssets()
        {
            _assets.Clear();
            string path = LibraryPaths[_selectedLibraryIndex];
            EnsureFolder(path);
            string filter = $"t:{AssetTypes[_selectedLibraryIndex].Name}";
            foreach (string guid in AssetDatabase.FindAssets(filter, new[] { path }))
            {
                string assetPath = AssetDatabase.GUIDToAssetPath(guid);
                Object asset = AssetDatabase.LoadAssetAtPath(assetPath, AssetTypes[_selectedLibraryIndex]);
                if (asset != null)
                {
                    _assets.Add(asset);
                }
            }
        }

        private void CreateAssetInSelectedLibrary()
        {
            string path = LibraryPaths[_selectedLibraryIndex];
            EnsureFolder(path);
            ScriptableObject asset = CreateInstance(AssetTypes[_selectedLibraryIndex]);
            string assetPath = AssetDatabase.GenerateUniqueAssetPath($"{path}/{AssetTypes[_selectedLibraryIndex].Name}.asset");
            AssetDatabase.CreateAsset(asset, assetPath);
            AssetDatabase.SaveAssets();
            RefreshAssets();
            Selection.activeObject = asset;
            EditorGUIUtility.PingObject(asset);
        }

        private void OpenSelectedLibraryFolder()
        {
            string path = LibraryPaths[_selectedLibraryIndex];
            EnsureFolder(path);
            string absolutePath = Path.GetFullPath(path);
            EditorUtility.RevealInFinder(absolutePath);
        }

        private static void EnsureFolder(string assetPath)
        {
            string normalized = assetPath.Replace('\\', '/').TrimEnd('/');
            if (AssetDatabase.IsValidFolder(normalized))
            {
                return;
            }

            string[] parts = normalized.Split('/');
            string current = parts[0];
            for (int i = 1; i < parts.Length; i++)
            {
                string next = $"{current}/{parts[i]}";
                if (!AssetDatabase.IsValidFolder(next))
                {
                    AssetDatabase.CreateFolder(current, parts[i]);
                }

                current = next;
            }
        }
    }
}
