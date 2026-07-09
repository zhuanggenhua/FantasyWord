using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;
using Object = UnityEngine.Object;

namespace YokiFrame
{
    public static class GameObjectPoolService
    {
        private const string RootName = "[YokiFrame GameObject Pools]";

        private static readonly Dictionary<string, PoolBucket> Pools = new();
        private static Transform sRoot;

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
        private static void Reset()
        {
            SceneManager.sceneUnloaded -= OnSceneUnloaded;
            SceneManager.sceneUnloaded += OnSceneUnloaded;
            Pools.Clear();
            sRoot = null;
        }

        public static GameObject Rent(PrefabKey key, Transform parent = null) => Rent(key.Path, parent);
        public static GameObject Rent(PrefabKey key, Vector3 position, Quaternion rotation, Transform parent = null) => Rent(key.Path, position, rotation, parent);

        public static GameObject Rent(string path, Transform parent = null)
        {
            if (string.IsNullOrWhiteSpace(path))
            {
                return null;
            }

            var bucket = GetOrCreateResourceBucket(path);
            return RentFromBucket(bucket, parent);
        }

        public static GameObject Rent(string path, Vector3 position, Quaternion rotation, Transform parent = null)
        {
            var instance = Rent(path, parent);
            if (instance == null)
            {
                return null;
            }

            instance.transform.SetPositionAndRotation(position, rotation);
            return instance;
        }

        public static GameObject Rent(GameObject prefab, Transform parent = null)
        {
            if (prefab == null)
            {
                return null;
            }

            var bucket = GetOrCreatePrefabBucket(prefab);
            return RentFromBucket(bucket, parent);
        }

        public static GameObject Rent(GameObject prefab, Vector3 position, Quaternion rotation, Transform parent = null)
        {
            var instance = Rent(prefab, parent);
            if (instance == null)
            {
                return null;
            }

            instance.transform.SetPositionAndRotation(position, rotation);
            return instance;
        }

        public static void Prewarm(PrefabKey key, int count) => Prewarm(key.Path, count);

        public static void Prewarm(string path, int count)
        {
            if (string.IsNullOrWhiteSpace(path) || count <= 0)
            {
                return;
            }

            Prewarm(GetOrCreateResourceBucket(path), count);
        }

        public static void Prewarm(GameObject prefab, int count)
        {
            if (prefab == null || count <= 0)
            {
                return;
            }

            Prewarm(GetOrCreatePrefabBucket(prefab), count);
        }

        public static void SetMaxCapacity(PrefabKey key, int maxCapacity) => SetMaxCapacity(key.Path, maxCapacity);

        public static void SetMaxCapacity(string path, int maxCapacity)
        {
            if (string.IsNullOrWhiteSpace(path))
            {
                return;
            }

            if (Pools.TryGetValue(path, out var bucket))
            {
                bucket.SetMaxCapacity(maxCapacity);
            }
        }

        public static void SetMaxCapacity(GameObject prefab, int maxCapacity)
        {
            if (prefab == null)
            {
                return;
            }

            GetOrCreatePrefabBucket(prefab).SetMaxCapacity(maxCapacity);
        }

        public static bool Return(GameObject instance)
        {
            if (instance == null)
            {
                return false;
            }

            if (!instance.TryGetComponent(out PooledGameObject pooled))
            {
                DestroyObject(instance);
                return false;
            }

            if (pooled.InPool)
            {
                return false;
            }

            if (!Pools.TryGetValue(pooled.PoolKey, out var bucket))
            {
                DestroyObject(instance);
                return false;
            }

            if (!bucket.CanReturnInactiveInstance)
            {
                bucket.Remove(instance);
                DestroyObject(instance);
                return false;
            }

            pooled.MarkReturned();
            instance.SetActive(false);
            instance.transform.SetParent(bucket.Root, false);
            bucket.Inactive.Enqueue(instance);
            return true;
        }

        public static void SetReleaseOnSceneUnload(PrefabKey key, bool releaseOnSceneUnload) => SetReleaseOnSceneUnload(key.Path, releaseOnSceneUnload);

        public static void SetReleaseOnSceneUnload(string path, bool releaseOnSceneUnload)
        {
            if (string.IsNullOrWhiteSpace(path))
            {
                return;
            }

            if (Pools.TryGetValue(path, out var bucket))
            {
                bucket.ReleaseOnSceneUnload = releaseOnSceneUnload;
            }
        }

        public static void Clear(PrefabKey key) => Clear(key.Path);

        public static void Clear(string key)
        {
            if (string.IsNullOrWhiteSpace(key) || !Pools.Remove(key, out var bucket))
            {
                return;
            }

            bucket.Dispose();
        }

        public static void ClearAll()
        {
            foreach (var bucket in Pools.Values)
            {
                bucket.Dispose();
            }

            Pools.Clear();
        }

        public static IReadOnlyList<GameObjectPoolDiagnostics> GetDiagnostics()
        {
            var diagnostics = new List<GameObjectPoolDiagnostics>(Pools.Count);
            foreach (var bucket in Pools.Values)
            {
                diagnostics.Add(bucket.CreateDiagnostics());
            }

            return diagnostics;
        }

        public static bool TryGetDiagnostics(GameObject prefab, out GameObjectPoolDiagnostics diagnostics)
        {
            diagnostics = default;
            if (prefab == null)
            {
                return false;
            }

            if (!Pools.TryGetValue(CreatePrefabKey(prefab), out var bucket))
            {
                return false;
            }

            diagnostics = bucket.CreateDiagnostics();
            return true;
        }

        private static GameObject RentFromBucket(PoolBucket bucket, Transform parent)
        {
            GameObject instance = null;
            while (bucket.Inactive.Count > 0 && instance == null)
            {
                instance = bucket.Inactive.Dequeue();
            }

            if (instance == null)
            {
                if (!bucket.CanCreateInstance)
                {
                    return null;
                }

                instance = Object.Instantiate(bucket.Prefab);
                instance.name = bucket.Prefab.name;
                bucket.AllInstances.Add(instance);
                var pooled = instance.GetComponent<PooledGameObject>();
                if (pooled == null)
                {
                    pooled = instance.AddComponent<PooledGameObject>();
                }

                pooled.Initialize(bucket.Key);
            }

            instance.transform.SetParent(parent, false);
            instance.SetActive(true);
            instance.GetComponent<PooledGameObject>().MarkRented();
            return instance;
        }

        private static void Prewarm(PoolBucket bucket, int count)
        {
            var targetCount = bucket.GetPrewarmTarget(count);
            for (var i = bucket.LiveCount; i < targetCount; i++)
            {
                var instance = Object.Instantiate(bucket.Prefab, bucket.Root);
                instance.name = bucket.Prefab.name;
                instance.SetActive(false);
                bucket.AllInstances.Add(instance);

                var pooled = instance.GetComponent<PooledGameObject>();
                if (pooled == null)
                {
                    pooled = instance.AddComponent<PooledGameObject>();
                }

                pooled.Initialize(bucket.Key);
                pooled.MarkReturned();
                bucket.Inactive.Enqueue(instance);
            }
        }

        private static PoolBucket GetOrCreateResourceBucket(string path)
        {
            if (Pools.TryGetValue(path, out var bucket))
            {
                return bucket;
            }

            var handler = ResKit.LoadAsset<GameObject>(path);
            var prefab = handler?.Asset as GameObject;
            if (prefab == null)
            {
                handler?.Release();
                throw new InvalidOperationException($"Unable to create pool because prefab load failed: {path}");
            }

            bucket = new PoolBucket(path, prefab, handler, EnsureRoot());
            Pools.Add(path, bucket);
            return bucket;
        }

        private static PoolBucket GetOrCreatePrefabBucket(GameObject prefab)
        {
            var key = CreatePrefabKey(prefab);
            if (Pools.TryGetValue(key, out var bucket))
            {
                return bucket;
            }

            bucket = new PoolBucket(key, prefab, null, EnsureRoot());
            Pools.Add(key, bucket);
            return bucket;
        }

        private static string CreatePrefabKey(GameObject prefab)
        {
            return $"prefab:{prefab.GetInstanceID()}:{prefab.name}";
        }

        private static Transform EnsureRoot()
        {
            if (sRoot != null)
            {
                return sRoot;
            }

            var root = new GameObject(RootName);
            if (Application.isPlaying)
            {
                Object.DontDestroyOnLoad(root);
            }

            sRoot = root.transform;
            return sRoot;
        }

        private static void OnSceneUnloaded(Scene scene)
        {
            List<string> toRelease = null;
            foreach (var pair in Pools)
            {
                if (!pair.Value.ReleaseOnSceneUnload)
                {
                    continue;
                }

                toRelease ??= new List<string>();
                toRelease.Add(pair.Key);
            }

            if (toRelease == null)
            {
                return;
            }

            for (var i = 0; i < toRelease.Count; i++)
            {
                Clear(toRelease[i]);
            }
        }

        private sealed class PoolBucket : IDisposable
        {
            public readonly string Key;
            public readonly GameObject Prefab;
            public readonly Queue<GameObject> Inactive = new();
            public readonly HashSet<GameObject> AllInstances = new();
            public readonly Transform Root;
            private readonly ResHandler mResourceHandle;
            private int mMaxCapacity = -1;

            public bool ReleaseOnSceneUnload;
            public bool CanReturnInactiveInstance => mMaxCapacity < 0 || Inactive.Count < mMaxCapacity;
            public bool CanCreateInstance => mMaxCapacity < 0 || CountLiveInstances() < mMaxCapacity;
            public int LiveCount => CountLiveInstances();
            public int MaxCapacity => mMaxCapacity;
            public bool IsResourceBacked => mResourceHandle != null;

            public int GetPrewarmTarget(int requestedCount)
            {
                return mMaxCapacity < 0 ? requestedCount : Math.Min(requestedCount, mMaxCapacity);
            }

            public PoolBucket(string key, GameObject prefab, ResHandler resourceHandle, Transform root)
            {
                Key = key;
                Prefab = prefab;
                mResourceHandle = resourceHandle;

                var bucketRoot = new GameObject(key);
                bucketRoot.transform.SetParent(root, false);
                Root = bucketRoot.transform;
            }

            public void SetMaxCapacity(int maxCapacity)
            {
                mMaxCapacity = maxCapacity < 0 ? -1 : maxCapacity;

                while (mMaxCapacity >= 0 && Inactive.Count > mMaxCapacity)
                {
                    var instance = Inactive.Dequeue();
                    Remove(instance);
                    DestroyObject(instance);
                }
            }

            public void Remove(GameObject instance)
            {
                AllInstances.Remove(instance);
            }

            public void Dispose()
            {
                Inactive.Clear();

                foreach (var instance in AllInstances)
                {
                    if (instance != null)
                    {
                        DestroyObject(instance);
                    }
                }

                AllInstances.Clear();

                if (Root != null)
                {
                    DestroyObject(Root.gameObject);
                }

                mResourceHandle?.Release();
            }

            public GameObjectPoolDiagnostics CreateDiagnostics()
            {
                var totalCount = CountLiveInstances();
                var inactiveCount = 0;
                foreach (var instance in Inactive)
                {
                    if (instance != null)
                    {
                        inactiveCount++;
                    }
                }

                return new GameObjectPoolDiagnostics(
                    Key,
                    Prefab != null ? Prefab.name : string.Empty,
                    totalCount,
                    inactiveCount,
                    Math.Max(0, totalCount - inactiveCount),
                    MaxCapacity,
                    ReleaseOnSceneUnload,
                    IsResourceBacked);
            }

            private int CountLiveInstances()
            {
                var totalCount = 0;
                foreach (var instance in AllInstances)
                {
                    if (instance != null)
                    {
                        totalCount++;
                    }
                }

                return totalCount;
            }
        }

        private static void DestroyObject(Object obj)
        {
            if (obj == null)
            {
                return;
            }

            if (Application.isPlaying)
            {
                Object.Destroy(obj);
            }
            else
            {
                Object.DestroyImmediate(obj);
            }
        }
    }

    public readonly struct GameObjectPoolDiagnostics
    {
        internal GameObjectPoolDiagnostics(
            string key,
            string prefabName,
            int totalCount,
            int inactiveCount,
            int activeCount,
            int maxCapacity,
            bool releaseOnSceneUnload,
            bool isResourceBacked)
        {
            Key = key ?? string.Empty;
            PrefabName = prefabName ?? string.Empty;
            TotalCount = totalCount;
            InactiveCount = inactiveCount;
            ActiveCount = activeCount;
            MaxCapacity = maxCapacity;
            ReleaseOnSceneUnload = releaseOnSceneUnload;
            IsResourceBacked = isResourceBacked;
        }

        public string Key { get; }
        public string PrefabName { get; }
        public int TotalCount { get; }
        public int InactiveCount { get; }
        public int ActiveCount { get; }
        public int MaxCapacity { get; }
        public bool HasMaxCapacity => MaxCapacity >= 0;
        public bool ReleaseOnSceneUnload { get; }
        public bool IsResourceBacked { get; }
    }
}
