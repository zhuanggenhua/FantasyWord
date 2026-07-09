using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Minifantasy.TownsI
{
    public class T1_ShopSign : MonoBehaviour
    {
        [Tooltip("Select a Prop Variant.")]
        [SerializeField] private ShopSignSelection selection = ShopSignSelection.ShopSignArmor;

        [Header("Sprites")]
        [SerializeField] private Sprite shopSignArmor;
        [SerializeField] private Sprite shopSignPotions;
        [SerializeField] private Sprite shopSignTavern;
        [SerializeField] private Sprite shopSignWeapons;

        [Header("Shadows")]
        [SerializeField] private Sprite shadowshopSign;

        private void OnValidate()
        {
            Sprite selectedSprite = null;
            Sprite selectedShadow = null;

            switch (selection)
            {
                case ShopSignSelection.ShopSignArmor:
                    selectedSprite = shopSignArmor;
                    selectedShadow = shadowshopSign;
                    break;
                case ShopSignSelection.ShopSignPotions:
                    selectedSprite = shopSignPotions;
                    selectedShadow = shadowshopSign;
                    break;
                case ShopSignSelection.ShopSignTavern:
                    selectedSprite = shopSignTavern;
                    selectedShadow = shadowshopSign;
                    break;
                case ShopSignSelection.ShopSignWeapons:
                    selectedSprite = shopSignWeapons;
                    selectedShadow = shadowshopSign;
                    break;
            }
            GetComponent<SpriteRenderer>().sprite = selectedSprite;
            transform.Find("Shadow").GetComponent<SpriteRenderer>().sprite = selectedShadow;
        }

        private enum ShopSignSelection
        {
            ShopSignArmor,
            ShopSignPotions,
            ShopSignTavern,
            ShopSignWeapons,
        }
    }
}