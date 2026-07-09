using System;
using UnityEngine.Assertions;
using UnityEngine.ResourceManagement.AsyncOperations;
using UObject = UnityEngine.Object;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// Addressables 异步资源句柄，迁自 Chris.Resource。
    /// 调用方只持有轻量索引，真正的 Unity handle 由 <see cref="ResourceSystem"/> 统一释放。
    /// </summary>
    public readonly struct ResourceHandle : IEquatable<ResourceHandle>, IDisposable
    {
        internal readonly uint Version;
        internal readonly int Index;
        internal readonly byte OperationType;

        internal AsyncOperationHandle InternalHandle => ResourceSystem.CastOperationHandle(Version, Index);

        public object Result => InternalHandle.Result;

        public ResourceHandle(uint version, int index, byte operationType)
        {
            Version = version;
            Index = index;
            OperationType = operationType;
        }

        public void RegisterCallback(Action<UObject> callback)
        {
            Assert.IsNotNull(callback);
            InternalHandle.Completed += h => callback((UObject)h.Result);
        }

        public UObject WaitForCompletion()
        {
            return InternalHandle.WaitForCompletion() as UObject;
        }

        public ResourceHandle<T> Convert<T>()
        {
            return this;
        }

        public bool Equals(ResourceHandle other)
        {
            return other.Index == Index && other.Version == Version;
        }

        public void Dispose()
        {
            ResourceSystem.Release(this);
        }
    }

    /// <summary>
    /// 类型化资源句柄，语义与 Chris.ResourceHandle 保持一致。
    /// </summary>
    public readonly struct ResourceHandle<T> : IEquatable<ResourceHandle<T>>, IDisposable
    {
        internal readonly uint Version;
        internal readonly int Index;
        internal readonly byte OperationType;

        internal AsyncOperationHandle<T> InternalHandle => ResourceSystem.CastOperationHandle<T>(Version, Index);

        public T Result => InternalHandle.Result;

        public ResourceHandle(uint version, int index, byte operationType)
        {
            Version = version;
            Index = index;
            OperationType = operationType;
        }

        public static implicit operator ResourceHandle(ResourceHandle<T> handle)
        {
            return new ResourceHandle(handle.Version, handle.Index, handle.OperationType);
        }

        public static implicit operator ResourceHandle<T>(ResourceHandle handle)
        {
            return new ResourceHandle<T>(handle.Version, handle.Index, handle.OperationType);
        }

        public ResourceHandle<TNew> Convert<TNew>()
        {
            return new ResourceHandle<TNew>(Version, Index, OperationType);
        }

        public void RegisterCallback(Action<T> callback)
        {
            Assert.IsNotNull(callback);
            InternalHandle.Completed += h => callback(h.Result);
        }

        public void RegisterCallback(Action callback)
        {
            Assert.IsNotNull(callback);
            InternalHandle.Completed += _ => callback();
        }

        public T WaitForCompletion()
        {
            return InternalHandle.WaitForCompletion();
        }

        public bool Equals(ResourceHandle<T> other)
        {
            return other.Index == Index && other.Version == Version;
        }

        public void Dispose()
        {
            ResourceSystem.Release(this);
        }
    }
}
