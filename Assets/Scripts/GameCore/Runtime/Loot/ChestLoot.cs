using System;
using System.Collections.Generic;
using UnityEngine;

namespace FantasyWord.GameCore
{
    [Serializable]
    public struct ChestLootEntry
    {
        public Item item;
        public int quantity;
    }

    [Serializable]
    public struct ChestLoot
    {
        [SerializeField] private ChestLootEntry[] m_entries;
        public int money;

        public int entryCount => m_entries?.Length ?? 0;
        public bool HasMoney() => money != 0;
        public bool HasItems() => entryCount > 0;
        public bool IsEmpty() => !(HasItems() || HasMoney());
        public ChestLootEntry[] GetEntries() => m_entries != null ? (ChestLootEntry[])m_entries.Clone() : Array.Empty<ChestLootEntry>();

        public Sprite[] GetLootSprites()
        {
            List<Sprite> sprites = new();

            foreach (ChestLootEntry entry in GetEntries())
            {
                sprites.Add(entry.item.icon);
            }

            if (HasMoney())
            {
                sprites.Add(GameManager.Config.GetTermDefinition("currency").icon);
            }

            sprites.RemoveAll((sprite) => sprite == null);

            return sprites.ToArray();
        }
    }
}
