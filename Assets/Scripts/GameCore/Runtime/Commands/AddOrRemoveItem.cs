using System;
using System.Threading.Tasks;
using UnityEngine;

namespace FantasyWord.GameCore
{
    [Serializable]
    public class AddOrRemoveItem : IContextualCommand
    {
        [SerializeField] private EAction m_action = EAction.Add;
        [SerializeField] private Item m_item = null;
        [SerializeField][Min(1)] private int m_quantity = 1;

        public Task Execute()
        {
            return Execute(GameCommandContext.Script());
        }

        public Task Execute(GameCommandContext context)
        {
            Debug.Assert(m_quantity != 0, "Invalid quantity! Expected != 0");
            CharacterBase inventoryOwner = context.ResolveActorOrCurrentControlledCharacter();
            if (inventoryOwner == null)
            {
                return Task.CompletedTask;
            }

            InventoryOwnerHandle ownerHandle = GameManager.InventorySystem.GetOwner(inventoryOwner);
            switch (m_action)
            {
                case EAction.Add:
                    GameManager.InventorySystem.AddToBag(ownerHandle, m_item, m_quantity, EItemTransferType.Command);
                    break;

                case EAction.Remove:
                    GameManager.InventorySystem.RemoveFromBag(ownerHandle, m_item, m_quantity, EItemTransferType.Command);
                    break;
            }

            return Task.CompletedTask;
        }
    }
}

