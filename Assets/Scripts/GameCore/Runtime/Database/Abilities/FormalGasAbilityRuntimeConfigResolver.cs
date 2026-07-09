using System;
using UnityEngine;

namespace FantasyWord.GameCore
{
    public enum EFormalGasAbilityRootMode
    {
        Static,
        Polydirectional,
        Horizontal
    }

    public readonly struct FormalGasAbilityRuntimeConfig
    {
        public FormalGasAbilityRuntimeConfig(
            string prefabGuid,
            string prefabPath,
            string iconGuid,
            string iconPath,
            EFormalGasAbilityRootMode abilityRootMode,
            FormalAbilityInputGateConfig inputExecution)
        {
            PrefabGuid = prefabGuid ?? string.Empty;
            PrefabPath = prefabPath ?? string.Empty;
            IconGuid = iconGuid ?? string.Empty;
            IconPath = iconPath ?? string.Empty;
            AbilityRootMode = abilityRootMode;
            InputGate = inputExecution ?? new FormalAbilityInputGateConfig();
        }

        public string PrefabGuid { get; }
        public string PrefabPath { get; }
        public string IconGuid { get; }
        public string IconPath { get; }
        public EFormalGasAbilityRootMode AbilityRootMode { get; }
        public FormalAbilityInputGateConfig InputGate { get; }

        public bool TryLoadPrefab(out GameObject prefab)
        {
            prefab = FormalGasAbilityResourceLoader.LoadSync<GameObject>(PrefabPath);
            if (prefab != null)
            {
                return true;
            }

#if UNITY_EDITOR
            prefab = LoadEditorAsset<GameObject>(PrefabGuid);
            return prefab != null;
#else
            return false;
#endif
        }

        public bool TryLoadIcon(out Sprite icon)
        {
            icon = FormalGasAbilityResourceLoader.LoadSync<Sprite>(IconPath);
            if (icon != null)
            {
                return true;
            }

#if UNITY_EDITOR
            icon = LoadEditorAsset<Sprite>(IconGuid);
            return icon != null;
#else
            return false;
#endif
        }

#if UNITY_EDITOR
        private static T LoadEditorAsset<T>(string guid)
            where T : UnityEngine.Object
        {
            if (string.IsNullOrWhiteSpace(guid))
            {
                return null;
            }

            string assetPath = UnityEditor.AssetDatabase.GUIDToAssetPath(guid);
            return string.IsNullOrWhiteSpace(assetPath)
                ? null
                : UnityEditor.AssetDatabase.LoadAssetAtPath<T>(assetPath);
        }
#endif
    }

    public static class FormalGasAbilityRuntimeConfigResolver
    {
        public delegate bool TryResolveRuntimeConfigHandler(
            int abilityCode,
            out FormalGasAbilityRuntimeConfig config);

        private static TryResolveRuntimeConfigHandler s_handler;

        public static void RegisterTryResolveRuntimeConfigHandler(TryResolveRuntimeConfigHandler handler)
        {
            s_handler = handler ?? throw new ArgumentNullException(nameof(handler));
        }

        public static bool TryResolveRuntimeConfig(
            int abilityCode,
            out FormalGasAbilityRuntimeConfig config)
        {
            config = default;
            if (abilityCode <= 0 || s_handler == null)
            {
                return false;
            }

            return s_handler.Invoke(abilityCode, out config);
        }
    }

    public static class FormalGasAbilityResourceLoader
    {
        public static T LoadSync<T>(string path)
            where T : UnityEngine.Object
        {
            if (string.IsNullOrWhiteSpace(path))
            {
                return null;
            }

#if UNITY_EDITOR
            if (path.StartsWith("Assets/", StringComparison.OrdinalIgnoreCase))
            {
                return UnityEditor.AssetDatabase.LoadAssetAtPath<T>(path);
            }
#endif

            try
            {
                ResourceHandle<T> handle = ResourceSystem.LoadAssetAsync<T>(path);
                return handle.WaitForCompletion();
            }
            catch (Exception exception)
            {
#if UNITY_EDITOR
                Debug.LogWarning($"GameCore 正式 GAS 资源加载失败：{path}。{exception.Message}");
#endif
                return null;
            }
        }

        public static UnityEngine.Object LoadSync(string path, Type type)
        {
            if (type == typeof(GameObject))
            {
                return LoadSync<GameObject>(path);
            }

            if (type == typeof(Sprite))
            {
                return LoadSync<Sprite>(path);
            }

            if (type == typeof(AudioClip))
            {
                return LoadSync<AudioClip>(path);
            }

#if UNITY_EDITOR
            if (!string.IsNullOrWhiteSpace(path) &&
                path.StartsWith("Assets/", StringComparison.OrdinalIgnoreCase))
            {
                return UnityEditor.AssetDatabase.LoadAssetAtPath(path, type);
            }
#endif

            return null;
        }

        public static void LoadAsync(string path, Type type, Action<UnityEngine.Object> onComplete)
        {
            onComplete?.Invoke(LoadSync(path, type));
        }

        public static void Release(UnityEngine.Object asset)
        {
            if (asset == null)
            {
                return;
            }

#if !UNITY_EDITOR
            Resources.UnloadAsset(asset);
#endif
        }
    }
}

