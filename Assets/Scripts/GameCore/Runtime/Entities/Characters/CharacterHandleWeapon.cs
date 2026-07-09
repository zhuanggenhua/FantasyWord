using UnityEngine;
using UnityEngine.Serialization;

namespace FantasyWord.GameCore
{
    [DisallowMultipleComponent]
    [RequireComponent(typeof(CharacterBase))]
    public sealed class CharacterHandleWeapon : MonoBehaviour
    {
        [Header("Weapon Handling")]
        [FormerlySerializedAs("m_hero")]
        [SerializeField] private CharacterBase m_character = null;
        [SerializeField] private Transform m_weaponAttachment = null;
        [SerializeField] private Transform m_projectileSpawn = null;
        [SerializeField] private EquipmentSpriteLibraryUpdater m_weaponVisualUpdater = null;

        public CharacterBase Character => m_character;
        public Transform WeaponAttachment => m_weaponAttachment ? m_weaponAttachment : transform;
        public Transform ProjectileSpawn => m_projectileSpawn ? m_projectileSpawn : WeaponAttachment;
        public Vector3 ProjectileSpawnPosition => ProjectileSpawn.position;
        public EquipmentSpriteLibraryUpdater WeaponVisualUpdater => ResolveWeaponVisualUpdater();

        public bool TryGetWeaponAttachment(out Transform attachment)
        {
            attachment = WeaponAttachment;
            return attachment != null;
        }

        public bool TryGetProjectileSpawn(out Transform spawn)
        {
            spawn = ProjectileSpawn;
            return spawn != null;
        }

        public bool TryGetWeaponVisualUpdater(out EquipmentSpriteLibraryUpdater weaponVisualUpdater)
        {
            weaponVisualUpdater = ResolveWeaponVisualUpdater();
            return weaponVisualUpdater != null;
        }

        public Vector3 ResolveProjectileSpawnPosition()
        {
            return TryGetProjectileSpawn(out Transform spawn) ? spawn.position : transform.position;
        }

        public bool TryApplyWeaponVisualOverride(EEquipmentType equipmentType)
        {
            if (!TryGetWeaponVisualUpdater(out EquipmentSpriteLibraryUpdater weaponVisualUpdater))
            {
                return false;
            }

            weaponVisualUpdater.UpdateVisual(m_character, equipmentType);
            return true;
        }

        public void ResetWeaponVisualOverride()
        {
            if (TryGetWeaponVisualUpdater(out EquipmentSpriteLibraryUpdater weaponVisualUpdater))
            {
                weaponVisualUpdater.ResetVisual();
            }
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

        private EquipmentSpriteLibraryUpdater ResolveWeaponVisualUpdater()
        {
            if (m_weaponVisualUpdater == null)
            {
                m_weaponVisualUpdater = GetComponentInChildren<EquipmentSpriteLibraryUpdater>(true);
            }

            return m_weaponVisualUpdater;
        }
    }
}
