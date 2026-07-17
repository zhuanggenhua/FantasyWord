using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Threading.Tasks;
using Cysharp.Threading.Tasks;
using UnityEngine;
using UnityEngine.AddressableAssets;
using UnityEngine.ResourceManagement.AsyncOperations;
#if !(UNITY_6000_0_OR_NEWER && !ENABLE_JSON_CATALOG)
using System.Text;
#endif
using UObject = UnityEngine.Object;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// Addressables 资源加载入口，主体迁自 Chris.ResourceSystem。
    /// 当前项目只把它作为资源和 Mod catalog 层使用，不替换 DatabaseRegistry 的数据引用真相。
    /// </summary>
    public static class ResourceSystem
    {
        public const string DynamicLoadPath = "{DYNAMIC_LOCAL_PATH}";

        private const byte AssetLoadOperation = 0;
        private const byte InstantiateOperation = 1;
        private static uint s_version = 1;
        private static readonly Dictionary<int, ResourceHandle> InstanceIdMap = new();
        private static readonly SparseArray<AsyncOperationStructure> Operations = new(10, int.MaxValue);

        /// <summary>
        /// Addressables 多键加载的合并策略，映射到 Addressables.MergeMode。
        /// </summary>
        public enum MergeMode
        {
            None = 0,
            UseFirst = 0,
            Union,
            Intersection
        }

        private struct AsyncOperationStructure
        {
            public AsyncOperationHandle AsyncOperationHandle;
            public ResourceHandle ResourceHandle;
        }

        public static void EnsureAssetExists<TAsset>(object key)
        {
            AsyncOperationHandle<IList<UnityEngine.ResourceManagement.ResourceLocations.IResourceLocation>> location =
                Addressables.LoadResourceLocationsAsync(key, typeof(TAsset));
            try
            {
                location.WaitForCompletion();
                if (location.Status != AsyncOperationStatus.Succeeded || location.Result == null || location.Result.Count == 0)
                {
                    throw new InvalidResourceRequestException(StringifyKey(key), $"Address {StringifyKey(key)} not valid for loading {typeof(TAsset)} asset.");
                }
            }
            finally
            {
                Addressables.Release(location);
            }
        }

        public static void EnsureAssetExists<TAsset>(IEnumerable key, MergeMode mergeMode)
        {
            AsyncOperationHandle<IList<UnityEngine.ResourceManagement.ResourceLocations.IResourceLocation>> location =
                Addressables.LoadResourceLocationsAsync(key, (Addressables.MergeMode)mergeMode, typeof(TAsset));
            try
            {
                location.WaitForCompletion();
                if (location.Status != AsyncOperationStatus.Succeeded || location.Result == null || location.Result.Count == 0)
                {
                    throw new InvalidResourceRequestException(StringifyKey(key), $"Address {StringifyKey(key)} not valid for loading {typeof(TAsset)} asset.");
                }
            }
            finally
            {
                Addressables.Release(location);
            }
        }

        public static async UniTask EnsureAssetExistsAsync<TAsset>(object key)
        {
            AsyncOperationHandle<IList<UnityEngine.ResourceManagement.ResourceLocations.IResourceLocation>> location =
                Addressables.LoadResourceLocationsAsync(key, typeof(TAsset));
            try
            {
                await location.ToUniTask();
                if (location.Status != AsyncOperationStatus.Succeeded || location.Result == null || location.Result.Count == 0)
                {
                    throw new InvalidResourceRequestException(StringifyKey(key), $"Address {StringifyKey(key)} not valid for loading {typeof(TAsset)} asset.");
                }
            }
            finally
            {
                Addressables.Release(location);
            }
        }

        public static async UniTask EnsureAssetExistsAsync<TAsset>(IEnumerable key, MergeMode mergeMode)
        {
            AsyncOperationHandle<IList<UnityEngine.ResourceManagement.ResourceLocations.IResourceLocation>> location =
                Addressables.LoadResourceLocationsAsync(key, (Addressables.MergeMode)mergeMode, typeof(TAsset));
            try
            {
                await location.ToUniTask();
                if (location.Status != AsyncOperationStatus.Succeeded || location.Result == null || location.Result.Count == 0)
                {
                    throw new InvalidResourceRequestException(StringifyKey(key), $"Address {StringifyKey(key)} not valid for loading {typeof(TAsset)} asset.");
                }
            }
            finally
            {
                Addressables.Release(location);
            }
        }

        public static ResourceHandle<T> LoadAssetAsync<T>(string address, Action<T> callback = null)
            where T : UObject
        {
            AsyncOperationHandle<T> handle = Addressables.LoadAssetAsync<T>(address);
            ResourceHandle<T> resourceHandle = CreateHandle<T>(handle, AssetLoadOperation);
            if (callback != null)
            {
                resourceHandle.RegisterCallback(callback);
            }

            return resourceHandle;
        }

        public static ResourceHandle<T> InstantiateAsync<T>(string address, Transform parent = null, Action<T> callback = null)
            where T : UObject
        {
            AsyncOperationHandle<GameObject> handle = Addressables.InstantiateAsync(address, parent);
            ResourceHandle<GameObject> resourceHandle = CreateHandle<GameObject>(handle, InstantiateOperation);
            if (callback != null)
            {
                resourceHandle.RegisterCallback(instance => callback(instance as T));
            }

            return resourceHandle.Convert<T>();
        }

        public static void Release(ResourceHandle handle)
        {
            if (!IsValid(handle.Version, handle.Index))
            {
                return;
            }

            if (handle.OperationType == InstantiateOperation)
            {
                ReleaseInstance(handle);
            }
            else
            {
                ReleaseAsset(handle);
            }
        }

        public static void Release<T>(ResourceHandle<T> handle)
        {
            Release((ResourceHandle)handle);
        }

        public static void ReleaseAsset(ResourceHandle handle)
        {
            if (!IsValid(handle.Version, handle.Index))
            {
                return;
            }

            Addressables.Release(handle.InternalHandle);
            Operations.RemoveAt(handle.Index);
        }

        public static void ReleaseAsset<T>(ResourceHandle<T> handle)
        {
            ReleaseAsset((ResourceHandle)handle);
        }

        public static void ReleaseInstance(ResourceHandle handle)
        {
            if (!IsValid(handle.Version, handle.Index))
            {
                return;
            }

            GameObject gameObject = handle.Result as GameObject;
            if (gameObject != null)
            {
                InstanceIdMap.Remove(gameObject.GetInstanceID());
                Addressables.ReleaseInstance(gameObject);
            }

            Operations.RemoveAt(handle.Index);
        }

        public static ResourceHandle<IList<T>> LoadAssetsAsync<T>(object key, Action<IList<T>> callback = null)
        {
            AsyncOperationHandle<IList<T>> handle = Addressables.LoadAssetsAsync<T>(key, null);
            ResourceHandle<IList<T>> resourceHandle = CreateHandle<IList<T>>(handle, AssetLoadOperation);
            if (callback != null)
            {
                resourceHandle.RegisterCallback(callback);
            }

            return resourceHandle;
        }

        public static ResourceHandle<IList<T>> LoadAssetsAsync<T>(IEnumerable key, MergeMode mode, Action<IList<T>> callback = null)
        {
            AsyncOperationHandle<IList<T>> handle = Addressables.LoadAssetsAsync<T>(key, null, (Addressables.MergeMode)mode);
            ResourceHandle<IList<T>> resourceHandle = CreateHandle<IList<T>>(handle, AssetLoadOperation);
            if (callback != null)
            {
                resourceHandle.RegisterCallback(callback);
            }

            return resourceHandle;
        }

        internal static AsyncOperationHandle CastOperationHandle(uint version, int index)
        {
            return IsValid(version, index) ? Operations[index].AsyncOperationHandle : default;
        }

        internal static AsyncOperationHandle<T> CastOperationHandle<T>(uint version, int index)
        {
            return IsValid(version, index) ? Operations[index].AsyncOperationHandle.Convert<T>() : default;
        }

        public static bool IsValid(uint version, int index)
        {
            return Operations.IsAllocated(index) && Operations[index].ResourceHandle.Version == version;
        }

        public static bool IsValid(this ResourceHandle handle)
        {
            return IsValid(handle.Version, handle.Index);
        }

        public static bool IsValid<T>(this ResourceHandle<T> handle)
        {
            return IsValid(handle.Version, handle.Index);
        }

        public static bool IsDone(this ResourceHandle handle)
        {
            return handle.IsValid() && handle.InternalHandle.IsDone;
        }

        public static bool IsDone<T>(this ResourceHandle<T> handle)
        {
            return handle.IsValid() && handle.InternalHandle.IsDone;
        }

        public static UniTask<T> ToUniTask<T>(this ResourceHandle<T> handle)
        {
            return handle.InternalHandle.ToUniTask();
        }

        public static UniTask ToUniTask(this ResourceHandle handle)
        {
            return handle.InternalHandle.ToUniTask();
        }

        public static string GetCatalogExtension()
        {
#if UNITY_6000_0_OR_NEWER && !ENABLE_JSON_CATALOG
            return ".bin";
#else
            return ".json";
#endif
        }

        public static bool LoadCatalog(string path)
        {
            if (!TryFindCatalogPath(path, out string catalogPath))
            {
                Debug.LogError($"[ResourceSystem] No catalog file found in {path}.");
                return false;
            }

            catalogPath = catalogPath.Replace(@"\", "/");
            string actualPath = Path.GetDirectoryName(catalogPath)?.Replace(@"\", "/");

            try
            {
#if UNITY_6000_0_OR_NEWER && !ENABLE_JSON_CATALOG
                ProcessBinaryCatalog(catalogPath, actualPath);
#else
                ProcessJsonCatalog(catalogPath, actualPath);
#endif
                return true;
            }
            catch (Exception e)
            {
                Debug.LogError($"[ResourceSystem] Unexpected error during catalog load {catalogPath}: {e}");
                return false;
            }
        }

        public static async UniTask<bool> LoadCatalogAsync(string path)
        {
            if (!TryFindCatalogPath(path, out string catalogPath))
            {
                Debug.LogError($"[ResourceSystem] No catalog file found in {path}.");
                return false;
            }

            catalogPath = catalogPath.Replace(@"\", "/");
            string actualPath = Path.GetDirectoryName(catalogPath)?.Replace(@"\", "/");

            try
            {
#if UNITY_6000_0_OR_NEWER && !ENABLE_JSON_CATALOG
                await ProcessBinaryCatalogAsync(catalogPath, actualPath);
#else
                await ProcessJsonCatalogAsync(catalogPath, actualPath);
#endif
                return true;
            }
            catch (Exception e)
            {
                Debug.LogError($"[ResourceSystem] Unexpected error during catalog load {catalogPath}: {e}");
                return false;
            }
        }

        private static ResourceHandle<T> CreateHandle<T>(AsyncOperationHandle<T> asyncOperationHandle, byte operationType)
        {
            int index = Operations.Add(default);
            ResourceHandle<T> resourceHandle = new(s_version++, index, operationType);
            Operations[index] = new AsyncOperationStructure
            {
                AsyncOperationHandle = asyncOperationHandle,
                ResourceHandle = resourceHandle
            };

            if (operationType == InstantiateOperation)
            {
                asyncOperationHandle.Completed += handle =>
                {
                    if (handle.Result is GameObject gameObject)
                    {
                        InstanceIdMap[gameObject.GetInstanceID()] = resourceHandle;
                    }
                };
            }

            return resourceHandle;
        }

        private static bool TryFindCatalogPath(string path, out string catalogPath)
        {
            if (File.Exists(path) && string.Equals(Path.GetExtension(path), GetCatalogExtension(), StringComparison.OrdinalIgnoreCase))
            {
                catalogPath = path;
                return true;
            }

            if (!Directory.Exists(path))
            {
                catalogPath = null;
                return false;
            }

            catalogPath = Path.Combine(path, $"catalog{GetCatalogExtension()}");
            return File.Exists(catalogPath);
        }

        private static string StringifyKey(object key)
        {
            return key is IEnumerable<string> list ? $"[{string.Join(",", list)}]" : key?.ToString() ?? string.Empty;
        }

#if UNITY_6000_0_OR_NEWER && !ENABLE_JSON_CATALOG
        private static void ProcessBinaryCatalog(string path, string actualPath)
        {
            Debug.Log($"[ResourceSystem] Load binary content catalog {path}.");
            WarnDynamicLoadPathForBinaryCatalog(actualPath);
            LoadAddressablesCatalog(path);
        }

        private static async Task ProcessBinaryCatalogAsync(string path, string actualPath)
        {
            Debug.Log($"[ResourceSystem] Load binary content catalog {path}.");
            WarnDynamicLoadPathForBinaryCatalog(actualPath);
            await LoadAddressablesCatalogAsync(path);
        }

        private static void WarnDynamicLoadPathForBinaryCatalog(string actualPath)
        {
            Debug.LogWarning("[ResourceSystem] Unity 6 binary catalog is loaded through public Addressables API. " +
                             $"If this catalog uses {DynamicLoadPath}, export it with concrete local paths or enable JSON catalog until binary rewrite is implemented.");
        }
#else
        private static void ProcessJsonCatalog(string path, string actualPath)
        {
            string contentCatalog = File.ReadAllText(path, Encoding.UTF8);
            string modifiedCatalog = contentCatalog.Replace(DynamicLoadPath, actualPath);
            try
            {
                File.WriteAllText(path, modifiedCatalog, Encoding.UTF8);
                Debug.Log($"[ResourceSystem] Load json content catalog {path}.");
                LoadAddressablesCatalog(path);
            }
            finally
            {
                File.WriteAllText(path, contentCatalog, Encoding.UTF8);
            }
        }

        private static async Task ProcessJsonCatalogAsync(string path, string actualPath)
        {
            string contentCatalog = await File.ReadAllTextAsync(path, Encoding.UTF8);
            string modifiedCatalog = contentCatalog.Replace(DynamicLoadPath, actualPath);
            try
            {
                await File.WriteAllTextAsync(path, modifiedCatalog, Encoding.UTF8);
                Debug.Log($"[ResourceSystem] Load json content catalog {path}.");
                await LoadAddressablesCatalogAsync(path);
            }
            finally
            {
                await File.WriteAllTextAsync(path, contentCatalog, Encoding.UTF8);
            }
        }
#endif

        private static void LoadAddressablesCatalog(string path)
        {
            AsyncOperationHandle handle = Addressables.LoadContentCatalogAsync(path, false);
            try
            {
                handle.WaitForCompletion();
                if (handle.Status != AsyncOperationStatus.Succeeded)
                {
                    throw new InvalidResourceRequestException(path, $"Addressables catalog load failed: {path}.");
                }
            }
            finally
            {
                Addressables.Release(handle);
            }
        }

        private static async UniTask LoadAddressablesCatalogAsync(string path)
        {
            AsyncOperationHandle handle = Addressables.LoadContentCatalogAsync(path, false);
            try
            {
                await handle.ToUniTask();
                if (handle.Status != AsyncOperationStatus.Succeeded)
                {
                    throw new InvalidResourceRequestException(path, $"Addressables catalog load failed: {path}.");
                }
            }
            finally
            {
                Addressables.Release(handle);
            }
        }
    }

    /// <summary>
    /// 资源地址无效时抛出的异常，保留原始地址便于定位配置问题。
    /// </summary>
    public class InvalidResourceRequestException : Exception
    {
        public string InvalidAddress { get; }

        public InvalidResourceRequestException(string address, string message) : base(message)
        {
            InvalidAddress = address;
        }
    }
}
