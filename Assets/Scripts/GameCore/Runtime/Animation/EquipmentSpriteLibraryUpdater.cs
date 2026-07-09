using UnityEngine;
using UnityEngine.U2D.Animation;

namespace FantasyWord.GameCore
{
    [RequireComponent(typeof(SpriteLibrary))]
    public class EquipmentSpriteLibraryUpdater : MonoBehaviour
    {
        private SpriteLibrary m_spriteLibrary = null;
        private SpriteLibraryAsset m_defaultSpriteLibraryAsset = null;

        private void Awake()
        {
            m_spriteLibrary = GetComponent<SpriteLibrary>();
            m_defaultSpriteLibraryAsset = m_spriteLibrary.spriteLibraryAsset;
        }

        public void UpdateVisual(CharacterBase character, EEquipmentType equipmentType)
        {
            if (character != null &&
                character.TryGetComponent(out CharacterEquipment equipmentComponent) &&
                equipmentComponent != null &&
                equipmentComponent.TryGetEquipment(equipmentType, out Equipment equippedItem) &&
                equippedItem.visualOverride)
            {
                m_spriteLibrary.spriteLibraryAsset = equippedItem.visualOverride;
                return;
            }

            m_spriteLibrary.spriteLibraryAsset = m_defaultSpriteLibraryAsset;
        }

        public void ResetVisual()
        {
            m_spriteLibrary.spriteLibraryAsset = m_defaultSpriteLibraryAsset;
        }
    }
}

