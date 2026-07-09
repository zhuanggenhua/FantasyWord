using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Minifantasy.TownsI
{
    public class T1_Wardrobe : MonoBehaviour
    {
        [Tooltip("Select a Prop Variant.\nBased on roof position.")]
        [SerializeField] private WardrobeSelection selection = WardrobeSelection.Closed;

        [Header("Sprites")]
        [SerializeField] private Sprite closed;
        [SerializeField] private Sprite openEmpty;
        [SerializeField] private Sprite openHammer;
        [SerializeField] private Sprite openVials;
        [SerializeField] private Sprite openBooks;

        [Header("Shadows")]
        [SerializeField] private Sprite wardrobeShadow;

        private void OnValidate()
        {
            Sprite selectedSprite = null;

            switch (selection)
            {
                case WardrobeSelection.Closed:
                    selectedSprite = closed;
                    break;
                case WardrobeSelection.OpenEmpty:
                    selectedSprite = openEmpty;
                    break;
                case WardrobeSelection.OpenHammer:
                    selectedSprite = openHammer;
                    break;
                case WardrobeSelection.OpenVials:
                    selectedSprite = openVials;
                    break;
                case WardrobeSelection.OpenBooks:
                    selectedSprite = openBooks;
                    break;
            }
            GetComponent<SpriteRenderer>().sprite = selectedSprite;
            Sprite shadowSprite = transform.Find("Shadow").GetComponent<SpriteRenderer>().sprite;
            if (shadowSprite != wardrobeShadow)
            {
                shadowSprite = wardrobeShadow;
            }
        }

        private enum WardrobeSelection
        {
            Closed,
            OpenEmpty,
            OpenHammer,
            OpenVials,
            OpenBooks
        }
    }
}