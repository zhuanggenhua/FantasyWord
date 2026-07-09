using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Minifantasy.Farms
{
    public class FRM_WaterTrough : MonoBehaviour
    {
        [Tooltip("Select a Prop Variant.")]
        [SerializeField] private WaterTrough selection = WaterTrough.EmptyHorizontal;

        [Header("Sprites")]
        [SerializeField] private Sprite emptyHorizontal;
        [SerializeField] private Sprite fullHorizontal;
        [SerializeField] private Sprite emptyVertical;
        [SerializeField] private Sprite fullVertical;

        [Header("Shadows")]
        [SerializeField] private Sprite emptyHorizontalShadow;
        [SerializeField] private Sprite fullHorizontalShadow;
        [SerializeField] private Sprite emptyVerticalShadow;
        [SerializeField] private Sprite fullVerticalShadow;

        private void OnValidate()
        {
            Sprite selectedSprite = null;
            Sprite selectedShadow = null;

            switch (selection)
            {
                case WaterTrough.EmptyHorizontal:
                    selectedSprite = emptyHorizontal;
                    selectedShadow = emptyHorizontalShadow;
                    break;
                case WaterTrough.FullHorizontal:
                    selectedSprite = fullHorizontal;
                    selectedShadow = fullHorizontalShadow;
                    break;
                case WaterTrough.EmptyVertical:
                    selectedSprite = emptyVertical;
                    selectedShadow = emptyVerticalShadow;
                    break;
                case WaterTrough.FullVertical:
                    selectedSprite = fullVertical;
                    selectedShadow = fullVerticalShadow;
                    break;
            }
            GetComponent<SpriteRenderer>().sprite = selectedSprite;
            transform.Find("Shadow").GetComponent<SpriteRenderer>().sprite = selectedShadow;
        }


        private enum WaterTrough
        {
            EmptyHorizontal,
            FullHorizontal,
            EmptyVertical,
            FullVertical
        }
    }
}