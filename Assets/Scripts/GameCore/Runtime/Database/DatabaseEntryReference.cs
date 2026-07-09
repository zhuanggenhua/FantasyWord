using System;
using UnityEngine;

namespace FantasyWord.GameCore
{
#if UNITY_EDITOR
    public partial class DatabaseEntryReference<T> : ISerializationCallbackReceiver where T : DatabaseEntry
    {
        public void OnBeforeSerialize()
        {
            // This code block is only executed in the Unity Editor and outside of play mode.
            // It is responsible for storing the asset GUID of the instance.
            // During runtime, the m_guid field should already be set by the DatabaseRegistry
            // through the DatabaseEntryReference constructor.
            if (!Application.isPlaying)
            {
                m_guid = m_instance ? m_instance.GetAssetGUID() : string.Empty;
            }
        }

        public void OnAfterDeserialize() { }
    }
#endif

    [Serializable]
    public partial class DatabaseEntryReference<T> where T : DatabaseEntry
    {
        public string guid => m_guid;

        [SerializeField] private T m_instance; // This field is only used in the Unity Editor
        [SerializeField] private string m_guid = string.Empty;

        public DatabaseEntryReference(string guid)
        {
            m_guid = guid;
        }
    }
}

