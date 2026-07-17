using System.Collections.Generic;
using System.Linq;
using UnityEngine;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 正式持久化对象系统。
    /// 它继续拥有持久化字典真相、正式生命周期、对象解析和稳定标识映射，
    /// 不替代 SaveSystem 的世界聚合语义，也不把 YokiFrame 工具层抬成第二套存档真相。
    /// </summary>
    public partial class PersistenceSystem : AGameSystem, IDataBlockHandler<PersistenceDataBlock>
    {
        private readonly Dictionary<string, PersistableDataBlock> m_preInstanced = new();
        private readonly Dictionary<string, PersistableDataBlock> m_runtimeInstanced = new();
        private readonly Dictionary<string, Persistable> m_persistables = new();

        public override void OnMapLoaded()
        {
            LoadPreInstancedDataBlocks();
            LoadRuntimeInstancedDataBlocks();
        }

        public override void OnMapUnloading()
        {
            SnapshotPersistables(true);
        }

        internal bool TryResolvePersistable<TPersistable>(string identifier, out TPersistable persistable) where TPersistable : Persistable
        {
            persistable = null;
            identifier = GetActualIdentifier(identifier);

            if (!string.IsNullOrEmpty(identifier) && m_persistables.TryGetValue(identifier, out Persistable resolvedPersistable))
            {
                persistable = resolvedPersistable as TPersistable;
                return persistable != null;
            }

            return false;
        }

        public void LoadDataBlock(PersistenceDataBlock block)
        {
            m_preInstanced.Clear();
            m_runtimeInstanced.Clear();

            if (block?.objects == null)
            {
                return;
            }

            foreach (PersistableDataBlock objectBlock in block.objects)
            {
                switch (objectBlock.info)
                {
                    case PreInstancedPersistentDataHandler preInstancedPersistentDataHandler:
                        m_preInstanced[preInstancedPersistentDataHandler.identifier] = objectBlock;
                        break;
                    case RuntimeInstancedPersistentDataHandler runtimeInstancedPersistentDataHandler:
                        m_runtimeInstanced[runtimeInstancedPersistentDataHandler.identifier] = objectBlock;
                        break;
                }
            }
        }

        public PersistenceDataBlock CreateDataBlock()
        {
            SnapshotPersistables();

            return new PersistenceDataBlock
            {
                objects = m_preInstanced.Values.Union(m_runtimeInstanced.Values).ToArray()
            };
        }

        private string GetActualIdentifier(string identifier)
        {
            return GameManager.Config.GetActualPersistentIdentifier(identifier);
        }

        internal void NotifyPersistableDestroyed(PersistableDestructionSnapshot destructionSnapshot)
        {
            if (!destructionSnapshot.AutomaticallyPersisted || destructionSnapshot.DataBlock == null)
            {
                return;
            }

            if (destructionSnapshot.IsPreInstanced)
            {
                StorePreInstancedDataBlock(destructionSnapshot.DataBlock);
                return;
            }

            if (destructionSnapshot.IsRuntimeInstanced && !string.IsNullOrEmpty(destructionSnapshot.Identifier))
            {
                m_persistables.Remove(destructionSnapshot.Identifier);
                RemoveRuntimeInstancedDataBlock(destructionSnapshot.Identifier);
            }
        }

        private void SnapshotPersistables(bool disablePersistence = false)
        {
            foreach (Persistable persistable in Object.FindObjectsByType<Persistable>(FindObjectsSortMode.InstanceID))
            {
                if (!persistable.IsAutomaticallyPersisted())
                {
                    continue;
                }

                if (persistable.IsPreInstanced())
                {
                    StorePreInstancedDataBlock(persistable.CreateDataBlock());
                    if (disablePersistence)
                    {
                        persistable.DisablePersistence();
                    }
                }
                else if (persistable.IsRuntimeInstanced())
                {
                    EvaluateRuntimeInstancedDataBlock(persistable.CreateDataBlock());
                    if (disablePersistence)
                    {
                        persistable.DisablePersistence();
                    }
                }
            }
        }

        private PersistableDataBlock GetPreInstancedDataBlock(string identifier)
        {
            m_preInstanced.TryGetValue(
                GetActualIdentifier(identifier),
                out PersistableDataBlock dataBlock);

            return dataBlock;
        }

        private void StorePreInstancedDataBlock(PersistableDataBlock block)
        {
            Debug.Assert(block.info is PreInstancedPersistentDataHandler, "StorePreInstancedDataBlock() expected a pre-instanced data handler");
            m_preInstanced[((PreInstancedPersistentDataHandler)block.info).identifier] = block;
        }

        private void RemoveRuntimeInstancedDataBlock(string identifier)
        {
            m_runtimeInstanced.Remove(identifier);
        }

        private void EvaluateRuntimeInstancedDataBlock(PersistableDataBlock block)
        {
            Debug.Assert(block.info is RuntimeInstancedPersistentDataHandler, "StoreRuntimeInstancedDataBlock() expected a runtime-instanced data handler");

            if (block.state == EPersistableObjectState.Destroyed)
            {
                m_runtimeInstanced.Remove(((RuntimeInstancedPersistentDataHandler)block.info).identifier);
            }
            else
            {
                m_runtimeInstanced[((RuntimeInstancedPersistentDataHandler)block.info).identifier] = block;
            }
        }

        private void LoadPreInstancedDataBlocks()
        {
            foreach (Persistable persistable in Object.FindObjectsByType<Persistable>(FindObjectsSortMode.InstanceID))
            {
                if (!persistable.IsPreInstanced())
                {
                    continue;
                }

                string identifier = persistable.GetPersistentIdentifier();
                m_persistables[identifier] = persistable;

                PersistableDataBlock block = GetPreInstancedDataBlock(identifier);
                if (block != null)
                {
                    persistable.LoadDataBlock(block);
                }
            }
        }

        private void LoadRuntimeInstancedDataBlocks()
        {
            string currentMap = GameManager.MapSystem.GetCurrentMapName();
            List<string> keysToRemove = new();

            foreach (KeyValuePair<string, PersistableDataBlock> kvp in m_runtimeInstanced)
            {
                PersistableDataBlock block = kvp.Value;
                Debug.Assert(block.info is RuntimeInstancedPersistentDataHandler, "Expected a runtime instanced data handler!");
                RuntimeInstancedPersistentDataHandler handler = (RuntimeInstancedPersistentDataHandler)block.info;
                if (handler.map == currentMap)
                {
                    if (handler.prefab == null || string.IsNullOrWhiteSpace(handler.prefab.guid))
                    {
                        Debug.LogError($"[{nameof(PersistenceSystem)}] 运行时持久化对象 {handler.identifier} 缺少 PrefabReference GUID，无法恢复。", this);
                        continue;
                    }

                    PrefabReference prefabReference = GameManager.Database.LoadFromReference(handler.prefab);
                    if (prefabReference == null)
                    {
                        Debug.LogError($"[{nameof(PersistenceSystem)}] 运行时持久化对象 {handler.identifier} 无法通过 PrefabReference GUID 恢复 Prefab。", this);
                        continue;
                    }

                    Persistable persistable = InstantiateRuntime<Persistable>(prefabReference, Vector3.zero, Quaternion.identity, null, handler.identifier);
                    persistable.LoadDataBlock(block);
                    keysToRemove.Add(kvp.Key);
                }
            }

            foreach (string key in keysToRemove)
            {
                m_runtimeInstanced.Remove(key);
            }
        }
    }
}

