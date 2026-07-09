using System;
using UnityEngine;
using UnityEngine.Scripting.APIUpdating;
using YokiFrame;

namespace FantasyWord.GameCore
{
    [Serializable]
    [MovedFrom(false, null, "FantasyWord.GameCore.Conditions")]
    public class IsItemInInventory : ABaseCondition
    {
        [SerializeField] private Item m_item = null;
        [SerializeField] private EInventoryQueryScope m_inventoryScope = EInventoryQueryScope.Party;

        public override bool Evaluate() =>
            GameManager.InventorySystem.HasItemInBag(
                GameManager.InventorySystem.GetOwner(m_inventoryScope),
                m_item);

        protected override void OnStartListening()
        {
            EventKit.Type.Register<InventoryItemAddedEvent>(OnItemAdded);
            EventKit.Type.Register<InventoryItemRemovedEvent>(OnItemRemoved);

            if (m_inventoryScope == EInventoryQueryScope.CurrentControlledCharacter &&
                GameManager.Exists() &&
                GameManager.HasSystem<PlayerSystem>())
            {
                GameManager.PlayerSystem.AddCurrentControlledCharacterChangedListener(OnCurrentControlledCharacterChanged);
            }
        }

        protected override void OnStopListening()
        {
            EventKit.Type.UnRegister<InventoryItemAddedEvent>(OnItemAdded);
            EventKit.Type.UnRegister<InventoryItemRemovedEvent>(OnItemRemoved);

            if (m_inventoryScope == EInventoryQueryScope.CurrentControlledCharacter &&
                GameManager.Exists() &&
                GameManager.HasSystem<PlayerSystem>())
            {
                GameManager.PlayerSystem.RemoveCurrentControlledCharacterChangedListener(OnCurrentControlledCharacterChanged);
            }
        }

        private void OnItemAdded(InventoryItemAddedEvent inventoryItemAddedEvent)
        {
            if (GameManager.InventorySystem.IsOwnerInScope(m_inventoryScope, inventoryItemAddedEvent.Owner))
            {
                NotifyStateChange();
            }
        }

        private void OnItemRemoved(InventoryItemRemovedEvent inventoryItemRemovedEvent)
        {
            if (GameManager.InventorySystem.IsOwnerInScope(m_inventoryScope, inventoryItemRemovedEvent.Owner))
            {
                NotifyStateChange();
            }
        }

        private void OnCurrentControlledCharacterChanged(CharacterBase character) => NotifyStateChange();
    }
}
