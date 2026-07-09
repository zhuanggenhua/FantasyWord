using System;
using UnityEngine;

namespace FantasyWord.GameCore
{
    public partial class PersistenceSystem
    {
        internal struct InstanstiationResult
        {
            public Persistable persistable;
            public string identifier;
        }

        // Instantiate a persistable object from a prefab reference, and automatically save it to respawn it on load
        internal TPersistable InstantiateRuntime<TPersistable>(PrefabReference instance, Vector3 position, Quaternion rotation, Transform parent = null, string identifier = null) where TPersistable : Persistable
        {
            InstanstiationResult result = InstantiateInternal(instance.prefab, position, rotation, parent, identifier);
            result.persistable.MakeRuntimeInstanced(instance, result.identifier);
            TPersistable persistable = result.persistable as TPersistable;
            Debug.Assert(persistable != null, $"The instantiated prefab must contain a {typeof(TPersistable).Name} component.");
            return persistable;
        }

        // Instantiate a persistable object from a prefab, but leave the saving responsibility to the caller
        internal TPersistable InstantiateCustom<TPersistable>(GameObject prefab, Vector3 position, Quaternion rotation, Transform parent = null, string identifier = null) where TPersistable : Persistable
        {
            InstanstiationResult result = InstantiateInternal(prefab, position, rotation, parent, identifier);
            result.persistable.MakeCustomInstanced(result.identifier);
            TPersistable persistable = result.persistable as TPersistable;
            Debug.Assert(persistable != null, $"The instantiated prefab must contain a {typeof(TPersistable).Name} component.");
            return persistable;
        }

        internal InstanstiationResult InstantiateInternal(GameObject prefab, Vector3 position, Quaternion rotation, Transform parent = null, string identifier = null)
        {
            identifier ??= Guid.NewGuid().ToString();

            GameObject go = Instantiate(prefab, position, rotation, parent);
            Persistable persistable = go.GetComponent<Persistable>();
            Debug.Assert(persistable != null, "The prefab doesn't contain a persistent object!");
            m_persistables[identifier] = persistable;

            return new InstanstiationResult
            {
                persistable = persistable,
                identifier = identifier
            };
        }

        internal void RegisterCustomInstancedPersistable(Persistable persistable, string identifier = null)
        {
            identifier ??= Guid.NewGuid().ToString();

            m_persistables[identifier] = persistable;
            persistable.MakeCustomInstanced(identifier);
        }
    }
}
