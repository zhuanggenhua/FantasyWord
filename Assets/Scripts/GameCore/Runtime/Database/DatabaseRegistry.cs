using System;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using azixMcAze.SerializableDictionary;

namespace FantasyWord.GameCore
{
    [CreateAssetMenu(menuName = AssetMenuIndexer.FantasyWord + nameof(DatabaseRegistry))]
    public partial class DatabaseRegistry : ScriptableObject
    {
        public bool autoAddNewDatabaseEntries => m_autoAddNewDatabaseEntries;
        public bool autoRemoveDatabaseEntries => m_autoRemoveDatabaseEntries;
        public int entryCount => m_entries?.Count ?? 0;
        public int conversionCount => m_GUIDConversionMap?.Count ?? 0;

        [Header("Automation Settings")]
        [SerializeField] private bool m_autoAddNewDatabaseEntries = true;
        [SerializeField] private bool m_autoRemoveDatabaseEntries = true;

        [Header("Database Content")]
        [SerializeField] private SerializableDictionary<string, DatabaseEntry> m_entries = null;
        [SerializeField] private SerializableDictionary<string, string> m_GUIDConversionMap = null;

        public KeyValuePair<string, DatabaseEntry>[] GetEntries()
        {
            EnsureCollectionsInitialized();
            return m_entries.ToArray();
        }

        public DatabaseEntryReference<T> CreateReference<T>(T entry) where T : DatabaseEntry
        {
            string guid = DatabaseEntryToGUID(entry);
            return new(guid);
        }

        public T LoadFromReference<T>(DatabaseEntryReference<T> reference) where T : DatabaseEntry
        {
            return GUIDToDatabaseEntry<T>(reference.guid);
        }

        public T GUIDToDatabaseEntry<T>(string guid) where T : DatabaseEntry
        {
            EnsureCollectionsInitialized();
            HashSet<string> visited = new();

            // Convert the GUID if it exists in the conversion map.
            while (m_GUIDConversionMap.ContainsKey(guid))
            {
                guid = m_GUIDConversionMap[guid];
                if (visited.Contains(guid))
                {
                    Debug.LogError($"Circular reference detected in DatabaseRegistry: {guid}");
                    return null;
                }

                visited.Add(guid);
            }

            return m_entries.TryGetValue(guid, out DatabaseEntry entry) ? entry as T : null;
        }

        public string DatabaseEntryToGUID<T>(T instance) where T : DatabaseEntry
        {
            EnsureCollectionsInitialized();
            string guid = m_entries.FirstOrDefault(entry => entry.Value == instance).Key;
            Debug.Assert(!string.IsNullOrEmpty(guid), $"Database entry {instance} does not exist in the registry.");
            return guid;
        }

        public bool HasGUID(string guid)
        {
            EnsureCollectionsInitialized();
            return m_entries.ContainsKey(guid);
        }

        public bool HasGUIDConversion(string guid)
        {
            EnsureCollectionsInitialized();
            return m_GUIDConversionMap.ContainsKey(guid);
        }

        private void EnsureCollectionsInitialized()
        {
            m_entries ??= new SerializableDictionary<string, DatabaseEntry>();
            m_GUIDConversionMap ??= new SerializableDictionary<string, string>();
        }
    }
}
