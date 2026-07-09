using System;
using UnityEngine;
using Object = UnityEngine.Object;

namespace YokiFrame
{
    /// <summary>
    /// Strongly typed resource address for ResKit generated code.
    /// </summary>
    public readonly struct ResourceKey<T> where T : Object
    {
        public ResourceKey(string path)
        {
            Path = path ?? string.Empty;
        }

        public string Path { get; }
        public bool IsValid => !string.IsNullOrWhiteSpace(Path);

        public T Load() => ResKit.Load<T>(Path);
        public ResHandler LoadAsset() => ResKit.LoadAsset<T>(Path);
        public void LoadAsync(Action<T> onComplete) => ResKit.LoadAsync(Path, onComplete);
        public void LoadAssetAsync(Action<ResHandler> onComplete) => ResKit.LoadAssetAsync<T>(Path, onComplete);

        public override string ToString() => Path;
    }

    /// <summary>
    /// Strongly typed prefab address for ResKit generated code.
    /// </summary>
    public readonly struct PrefabKey
    {
        public PrefabKey(string path)
        {
            Path = path ?? string.Empty;
        }

        public string Path { get; }
        public bool IsValid => !string.IsNullOrWhiteSpace(Path);

        public GameObject Load() => ResKit.Load<GameObject>(Path);
        public ResHandler LoadAsset() => ResKit.LoadAsset<GameObject>(Path);
        public void LoadAsync(Action<GameObject> onComplete) => ResKit.LoadAsync(Path, onComplete);
        public void LoadAssetAsync(Action<ResHandler> onComplete) => ResKit.LoadAssetAsync<GameObject>(Path, onComplete);
        public GameObject Instantiate(Transform parent = null) => ResKit.Instantiate(Path, parent);
        public GameObject Rent(Transform parent = null) => GameObjectPoolService.Rent(this, parent);
        public GameObject Rent(Vector3 position, Quaternion rotation, Transform parent = null) => GameObjectPoolService.Rent(this, position, rotation, parent);
        public void Prewarm(int count) => GameObjectPoolService.Prewarm(this, count);
        public void SetMaxCapacity(int maxCapacity) => GameObjectPoolService.SetMaxCapacity(this, maxCapacity);
        public void SetReleaseOnSceneUnload(bool releaseOnSceneUnload) => GameObjectPoolService.SetReleaseOnSceneUnload(this, releaseOnSceneUnload);
        public void ClearPool() => GameObjectPoolService.Clear(this);
        public void InstantiateAsync(Action<GameObject> onComplete, Transform parent = null) => ResKit.InstantiateAsync(Path, onComplete, parent);

        public override string ToString() => Path;
    }

    /// <summary>
    /// Strongly typed sub-asset address for ResKit generated code.
    /// </summary>
    public readonly struct SubAssetKey<T> where T : Object
    {
        public SubAssetKey(string address, string parentPath, string subAssetName)
        {
            Address = address ?? string.Empty;
            ParentPath = parentPath ?? string.Empty;
            SubAssetName = subAssetName ?? string.Empty;
        }

        public string Address { get; }
        public string ParentPath { get; }
        public string SubAssetName { get; }
        public bool IsValid => !string.IsNullOrWhiteSpace(ParentPath) && !string.IsNullOrWhiteSpace(SubAssetName);

        public SubAssetLease<T> LoadAsset()
        {
            var handler = ResKit.LoadSubAsset<T>(ParentPath);
            if (handler == null)
            {
                return new SubAssetLease<T>(Address, ParentPath, SubAssetName, null, null);
            }

            var asset = handler.GetSubAssetObject<T>(SubAssetName);
            return new SubAssetLease<T>(Address, ParentPath, SubAssetName, handler, asset);
        }

        public T Load()
        {
            using var lease = LoadAsset();
            return lease.Asset;
        }

        public void LoadAssetAsync(Action<SubAssetLease<T>> onComplete)
        {
            if (onComplete == null)
            {
                return;
            }

            var address = Address;
            var parentPath = ParentPath;
            var subAssetName = SubAssetName;

            ResKit.LoadSubAssetAsync<T>(parentPath, handler =>
            {
                if (handler == null)
                {
                    onComplete(new SubAssetLease<T>(address, parentPath, subAssetName, null, null));
                    return;
                }

                var asset = handler.GetSubAssetObject<T>(subAssetName);
                onComplete(new SubAssetLease<T>(address, parentPath, subAssetName, handler, asset));
            });
        }

        public void LoadAsync(Action<T> onComplete)
        {
            if (onComplete == null)
            {
                return;
            }

            LoadAssetAsync(lease =>
            {
                using (lease)
                {
                    onComplete(lease.Asset);
                }
            });
        }

        public override string ToString() => Address;
    }

    public sealed class SubAssetLease<T> : IDisposable where T : Object
    {
        private SubAssetsResHandler mHandler;

        internal SubAssetLease(string address, string parentPath, string subAssetName, SubAssetsResHandler handler, T asset)
        {
            Address = address ?? string.Empty;
            ParentPath = parentPath ?? string.Empty;
            SubAssetName = subAssetName ?? string.Empty;
            mHandler = handler;
            Asset = asset;
        }

        public string Address { get; }
        public string ParentPath { get; }
        public string SubAssetName { get; }
        public T Asset { get; }
        public bool IsValid => Asset != null;

        public void Dispose()
        {
            if (mHandler == null)
            {
                return;
            }

            mHandler.Release();
            mHandler = null;
        }
    }
}
