using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Minifantasy.DeepCaves
{
    public class DC_Crystal : MonoBehaviour
    {
        [Tooltip("Select a Prop Variant.")]
        [SerializeField] private CrystalSize crystalSizeSelection = CrystalSize.Large;
        [SerializeField] private CrystalColor crystalColorSelection = CrystalColor.Red;

        [Header("Sprites")]
        [SerializeField] private Sprite crystalLargeRed;
        [SerializeField] private Sprite crystalLargeBlue;
        [SerializeField] private Sprite crystalLargeGreen;
        [SerializeField] private Sprite crystalMediumRed;
        [SerializeField] private Sprite crystalMediumBlue;
        [SerializeField] private Sprite crystalMediumGreen;
        [SerializeField] private Sprite crystalSmallRed;
        [SerializeField] private Sprite crystalSmallBlue;
        [SerializeField] private Sprite crystalSmallGreen;

        [Header("Shadows")]
        [SerializeField] private Sprite crystalLargeShadow;
        [SerializeField] private Sprite crystalMediumShadow;
        [SerializeField] private Sprite crystalSmallShadow;

        private void OnValidate()
        {
            Sprite selectedSprite = null;
            Sprite selectedShadow = null;

            switch (crystalSizeSelection)
            {
                case CrystalSize.Large:
                    switch (crystalColorSelection)
                    {
                        case CrystalColor.Red:
                            selectedSprite = crystalLargeRed;
                            break;
                        case CrystalColor.Blue:
                            selectedSprite = crystalLargeBlue;
                            break;
                        case CrystalColor.Green:
                            selectedSprite = crystalLargeGreen;
                            break;
                    }
                    selectedShadow = crystalLargeShadow;
                    break;
                case CrystalSize.Medium:
                    switch (crystalColorSelection)
                    {
                        case CrystalColor.Red:
                            selectedSprite = crystalMediumRed;
                            break;
                        case CrystalColor.Blue:
                            selectedSprite = crystalMediumBlue;
                            break;
                        case CrystalColor.Green:
                            selectedSprite = crystalMediumGreen;
                            break;
                    }
                    selectedShadow = crystalMediumShadow;
                    break;
                case CrystalSize.Small:
                    switch (crystalColorSelection)
                    {
                        case CrystalColor.Red:
                            selectedSprite = crystalSmallRed;
                            break;
                        case CrystalColor.Blue:
                            selectedSprite = crystalSmallBlue;
                            break;
                        case CrystalColor.Green:
                            selectedSprite = crystalSmallGreen;
                            break;
                    }
                    selectedShadow = crystalSmallShadow;
                    break;
            }
            GetComponent<SpriteRenderer>().sprite = selectedSprite;
            transform.Find("Shadow").GetComponent<SpriteRenderer>().sprite = selectedShadow;
        }

        private enum CrystalSize
        {
            Large,
            Medium,
            Small,
        }

        private enum CrystalColor
        {
            Red,
            Blue,
            Green
        }
    }
}