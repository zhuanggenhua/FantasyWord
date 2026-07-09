using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Minifantasy.Farms
{
    public class FRM_Shovel : MonoBehaviour
    {
        [Tooltip("Select a Prop Variant.")]
        [SerializeField] private ShovelSelection selection = ShovelSelection.Left;

        [Header("Sprites")]
        [SerializeField] private Sprite leftShovel;
        [SerializeField] private Sprite centerShovel;
        [SerializeField] private Sprite rightShovel;

        private void OnValidate()
        {
            Sprite selectedSprite = null;

            switch (selection)
            {
                case ShovelSelection.Left:
                    selectedSprite = leftShovel;
                    break;
                case ShovelSelection.Center:
                    selectedSprite = centerShovel;
                    break;
                case ShovelSelection.Right:
                    selectedSprite = rightShovel;
                    break;
            }
            GetComponent<SpriteRenderer>().sprite = selectedSprite;
        }

        private enum ShovelSelection
        {
            Left,
            Center,
            Right,
        }
    }
}