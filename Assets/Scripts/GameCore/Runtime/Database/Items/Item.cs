using System.Threading.Tasks;
using UnityEngine;
using MackySoft.SerializeReferenceExtensions;

namespace FantasyWord.GameCore
{
    public enum EItemLocation
    {
        Bag,
        Equipment
    }

    public enum EItemCategory
    {
        Consumable,
        Resource,
        Gear,
        Key
    }

    // List where items can come from or go to
    public enum EItemTransferType
    {
        Equipment, // when the item is added to the inventory after it has been unequipped (special treatment, the UI won't show the item as new in the event log)
        Crafting, // when the item is added to or removed from the inventory during crafting
        Trading, // when the item is added to or removed from the inventory during a trade (buy/sell)
        Use, // when the item is removed from the inventory by using it
        Chest, // when the item is added to the inventory by opening a chest
        MonsterDrop, // when the item is added to the inventory by defeating a monster
        Command, // when the item is added to the inventory by using a command
        Unknown, // when the item is added to the inventory by any other means
        Corpse // when an inventory owner is moved onto a corpse owner after death
    }

    [CreateAssetMenu(menuName = AssetMenuIndexer.FantasyWord_Items + nameof(Item))]
    public class Item : DatabaseEntry, INameable
    {
        [Header("General")]
        [SerializeField] private EItemCategory m_category = 0;
        [SerializeField] private Sprite m_icon = null;
        [SerializeField] private string m_displayName = string.Empty;
        [SerializeField] private string m_description = string.Empty;
        [SerializeField] private int m_price = 50;

        [Header("Usage")]
        [SerializeReference, SubclassSelector] protected IItemEffect m_onUse = null;

        public EItemCategory category => m_category;
        public Sprite icon => m_icon;
        public string displayName => DisplayNameUtils.GetNameOrDefault(this, m_displayName);
        public string description => StringFormatter.Format(m_description);
        public int price => m_price;
        public bool sellable => m_price > 0 && m_category != EItemCategory.Key;

        public Task Use(CharacterBase target, EItemLocation location)
        {
            return Use(target, target, location);
        }

        public async virtual Task Use(CharacterBase sourceOwner, CharacterBase target, EItemLocation location)
        {
            if (sourceOwner && !sourceOwner.Can(EActionFlags.ManageInventory))
            {
                await GameManager.DialogueSystem.PlayNow(MenuFeedbackPrompts.InventoryUseActionLocked, displayName);
                return;
            }

            if (!await (m_onUse?.TryUse(this, sourceOwner, target, location) ?? Task.FromResult(false)))
            {
                await GameManager.DialogueSystem.PlayNow("This item has no effect");
            }
        }
    }
}

