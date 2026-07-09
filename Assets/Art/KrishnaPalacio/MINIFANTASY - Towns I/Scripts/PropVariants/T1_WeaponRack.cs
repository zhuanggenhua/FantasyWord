using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Minifantasy.TownsI
{
    public class T1_WeaponRack : MonoBehaviour
    {
        [Tooltip("Select a Prop Variant.")]
        [SerializeField] private WeaponRackSelection selection = WeaponRackSelection.WeaponRackEast;

        [Header("Sprites")]
        [SerializeField] private Sprite weaponRackEast;
        [SerializeField] private Sprite weaponRackWest;
        [SerializeField] private Sprite weaponRackNorth;
        [SerializeField] private Sprite weaponRackSouth;

        [Header("Shadows")]
        [SerializeField] private Sprite shadowWeaponRackEastWest;
        [SerializeField] private Sprite shadowWeaponRackNorthSouth;

        private void OnValidate()
        {
            Sprite selectedSprite = null;
            Sprite selectedShadow = null;

            switch (selection)
            {
                case WeaponRackSelection.WeaponRackEast:
                    selectedSprite = weaponRackEast;
                    selectedShadow = shadowWeaponRackEastWest;
                    break;
                case WeaponRackSelection.WeaponRackWest:
                    selectedSprite = weaponRackWest;
                    selectedShadow = shadowWeaponRackEastWest;
                    break;
                case WeaponRackSelection.WeaponRackNorth:
                    selectedSprite = weaponRackNorth;
                    selectedShadow = shadowWeaponRackNorthSouth;
                    break;
                case WeaponRackSelection.WeaponRackSouth:
                    selectedSprite = weaponRackSouth;
                    selectedShadow = shadowWeaponRackNorthSouth;
                    break;
            }
            GetComponent<SpriteRenderer>().sprite = selectedSprite;
            transform.Find("Shadow").GetComponent<SpriteRenderer>().sprite = selectedShadow;
        }

        private enum WeaponRackSelection
        {
            WeaponRackEast,
            WeaponRackWest,
            WeaponRackNorth,
            WeaponRackSouth,
        }
    }
}