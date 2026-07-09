using System.Collections.Generic;
using Unity.Mathematics;
using UnityEngine;

namespace FantasyWord.GameCore
{
    public enum ETransactionType
    {
        Buy,
        Sell
    }

    [CreateAssetMenu(menuName = AssetMenuIndexer.FantasyWord_Shops + nameof(Shop))]
    public class Shop : DatabaseEntry
    {
        [SerializeField] private Item[] m_items = null;
        [SerializeField] private float m_sellingPriceMultiplier = 0.5f;
        [SerializeField] private float m_buyingPriceMultiplier = 1.0f;

        public int itemCount => m_items?.Length ?? 0;
        public Item GetItemAt(int index) => index >= 0 && index < itemCount ? m_items[index] : null;
        public Item[] GetItems() => m_items != null ? (Item[])m_items.Clone() : System.Array.Empty<Item>();

        public int GetPrice(Item item, ETransactionType transaction)
        {
            float floatPrice = 0.0f;

            switch (transaction)
            {
                case ETransactionType.Buy:
                    floatPrice = item.price * m_buyingPriceMultiplier;
                    break;

                case ETransactionType.Sell:
                    floatPrice = item.price * m_sellingPriceMultiplier;
                    break;
            }

            return (int)math.ceil(floatPrice);
        }
    }
}
