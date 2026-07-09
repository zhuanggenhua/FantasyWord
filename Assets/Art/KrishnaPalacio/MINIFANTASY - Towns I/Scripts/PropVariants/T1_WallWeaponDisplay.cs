using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Minifantasy.TownsI
{
    public class T1_WallWeaponDisplay : MonoBehaviour
    {
        [Tooltip("Select a Prop Variant.\nBased on roof position.")]
        [SerializeField] private WallWeaponDisplaySelection selection = WallWeaponDisplaySelection.Knives;

        [Header("Sprites")]
        [SerializeField] private Sprite knives;
        [SerializeField] private Sprite swords;
        [SerializeField] private Sprite axe;
        [SerializeField] private Sprite swordsAndShield;

        [Header("Shadows")]
        [SerializeField] private Sprite knivesShadow;
        [SerializeField] private Sprite swordsShadow;
        [SerializeField] private Sprite axeShadow;
        [SerializeField] private Sprite swordsAndShieldShadow;

        private void OnValidate()
        {
            Sprite selectedSprite = null;
            Sprite selectedShadow = null;

            switch (selection)
            {
                case WallWeaponDisplaySelection.Knives:
                    selectedSprite = knives;
                    selectedShadow = knivesShadow;
                    break;
                case WallWeaponDisplaySelection.Swords:
                    selectedSprite = swords;
                    selectedShadow = swordsShadow;
                    break;
                case WallWeaponDisplaySelection.Axe:
                    selectedSprite = axe;
                    selectedShadow = axeShadow;
                    break;
                case WallWeaponDisplaySelection.SwordsAndShield:
                    selectedSprite = swordsAndShield;
                    selectedShadow = swordsAndShieldShadow;
                    break;
            }
            GetComponent<SpriteRenderer>().sprite = selectedSprite;
            transform.Find("Shadow").GetComponent<SpriteRenderer>().sprite = selectedShadow;
        }

        private enum WallWeaponDisplaySelection
        {
            Knives,
            Swords,
            Axe,
            SwordsAndShield,
        }
    }
}