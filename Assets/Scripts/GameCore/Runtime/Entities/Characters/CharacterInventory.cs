using UnityEngine;

namespace FantasyWord.GameCore
{
    public enum ECharacterInventoryChannel
    {
        Main,
        Weapon,
        Hotbar
    }

    [DisallowMultipleComponent]
    [RequireComponent(typeof(CharacterBase))]
    public sealed class CharacterInventory : MonoBehaviour
    {
        [Header("Inventory Ownership")]
        [SerializeField] private CharacterBase m_character = null;
        [SerializeField] private bool m_ownsMainInventory = true;
        [SerializeField] private bool m_ownsWeaponInventory = true;
        [SerializeField] private bool m_ownsHotbarInventory = true;

        public CharacterBase Character => m_character;
        public bool OwnsMainInventory => m_ownsMainInventory;
        public bool OwnsWeaponInventory => m_ownsWeaponInventory;
        public bool OwnsHotbarInventory => m_ownsHotbarInventory;

        public InventoryOwnerHandle ResolveMainInventoryOwner()
        {
            return ResolveOwner(m_ownsMainInventory);
        }

        public InventoryOwnerHandle ResolveWeaponInventoryOwner()
        {
            return ResolveOwner(m_ownsWeaponInventory);
        }

        public InventoryOwnerHandle ResolveHotbarInventoryOwner()
        {
            return ResolveOwner(m_ownsHotbarInventory);
        }

        public InventoryOwnerHandle ResolveOwner(ECharacterInventoryChannel channel)
        {
            return channel switch
            {
                ECharacterInventoryChannel.Weapon => ResolveWeaponInventoryOwner(),
                ECharacterInventoryChannel.Hotbar => ResolveHotbarInventoryOwner(),
                _ => ResolveMainInventoryOwner()
            };
        }

        private InventoryOwnerHandle ResolveOwner(bool ownedByCharacter)
        {
            if (!ownedByCharacter)
            {
                return InventoryOwnerHandle.DefaultParty;
            }

            if (m_character == null)
            {
                throw new MissingComponentException(
                    $"[{nameof(CharacterInventory)}] Character-owned inventory requires {nameof(CharacterBase)} on the same GameObject.");
            }

            return InventoryOwnerHandle.ForCharacter(m_character);
        }

        private void Awake()
        {
            EnsureCharacterReference();
        }

        private void Reset()
        {
            EnsureCharacterReference();
        }

        private void OnValidate()
        {
            EnsureCharacterReference();
        }

        private void EnsureCharacterReference()
        {
            if (m_character == null)
            {
                TryGetComponent(out m_character);
            }
        }
    }
}
