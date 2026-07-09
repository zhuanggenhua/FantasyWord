using System.Threading.Tasks;
using UnityEngine;

namespace FantasyWord.GameCore
{
    public struct ItemUsageResult
    {
        public bool success;
        public string message;
    }

    public abstract class AItemEffect : IItemEffect
    {
        [SerializeField] private bool m_consumeAfterUse = false;
        [SerializeField] private AudioClipResolver m_useAudio = null;

        protected abstract ItemUsageResult OnUse(Item item, CharacterBase sourceOwner, CharacterBase target, EItemLocation location);

        public async Task<bool> TryUse(Item item, CharacterBase sourceOwner, CharacterBase target, EItemLocation location)
        {
            ItemUsageResult result = OnUse(item, sourceOwner, target, location);

            if (result.success)
            {
                GameRuntimeEvents.RequestAudioPlayback(m_useAudio);

                await GameManager.DialogueSystem.PlayNow(
                    string.IsNullOrEmpty(result.message) ?
                    $"You used {item.name}." :
                    result.message
                );

                if (m_consumeAfterUse)
                {
                    InventoryOwnerHandle ownerHandle = GameManager.InventorySystem.GetOwner(sourceOwner);
                    GameManager.InventorySystem.RemoveFromBag(ownerHandle, item, 1, EItemTransferType.Use);
                }

                return true;
            }

            return false;
        }
    }
}

