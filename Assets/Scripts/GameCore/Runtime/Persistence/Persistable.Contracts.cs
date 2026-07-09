using System;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 持久化 handler 的最小合同，只回答“当前对象如何被持久化系统识别”。
    /// </summary>
    public interface APersistenceInfo
    {
        public bool IsValid();
    }

    /// <summary>
    /// 可被稳定标识符引用的持久化 handler 合同。
    /// </summary>
    public interface IIdentifiablePersistentDataHandler
    {
        public string GetIdentifier();
    }

    [Serializable]
    public class PreInstancedPersistentDataHandler : APersistenceInfo, IIdentifiablePersistentDataHandler
    {
        public string identifier;

        public string GetIdentifier() => identifier;

        public bool IsValid()
        {
            return !string.IsNullOrEmpty(identifier);
        }
    }

    [Serializable]
    public class RuntimeInstancedPersistentDataHandler : APersistenceInfo, IIdentifiablePersistentDataHandler
    {
        public PrefabReference prefab;
        public string map;
        public string identifier;

        public string GetIdentifier() => identifier;

        public bool IsValid()
        {
            return
                prefab != null &&
                !string.IsNullOrEmpty(map) &&
                !string.IsNullOrEmpty(identifier);
        }
    }

    [Serializable]
    public class CustomInstancedPersistentDataHandler : APersistenceInfo, IIdentifiablePersistentDataHandler
    {
        public string identifier;

        public string GetIdentifier() => identifier;

        public bool IsValid()
        {
            return !string.IsNullOrEmpty(identifier);
        }
    }

    public enum EPersistableOwnershipKind
    {
        None,
        PreInstanced,
        RuntimeInstanced,
        CustomInstanced
    }
}
