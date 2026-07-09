using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Minifantasy.TownsI
{
    public class T1_PaintingWide : MonoBehaviour
    {
        [Tooltip("Select a Prop Variant.\nBased on roof position.")]
        [SerializeField] private PaintingSelection selection = PaintingSelection.Colors;

        [Header("Sprites")]
        [SerializeField] private Sprite colors;
        [SerializeField] private Sprite night;
        [SerializeField] private Sprite wave;

        [Header("Shadows")]
        [SerializeField] private Sprite shadow;

        private void OnValidate()
        {
            Sprite selectedSprite = null;
            Sprite selectedShadow = null;

            switch (selection)
            {
                case PaintingSelection.Colors:
                    selectedSprite = colors;
                    selectedShadow = shadow;
                    break;
                case PaintingSelection.Night:
                    selectedSprite = night;
                    selectedShadow = shadow;
                    break;
                case PaintingSelection.Wave:
                    selectedSprite = wave;
                    selectedShadow = shadow;
                    break;
            }
            GetComponent<SpriteRenderer>().sprite = selectedSprite;
            transform.Find("Shadow").GetComponent<SpriteRenderer>().sprite = selectedShadow;
        }

        private enum PaintingSelection
        {
            Colors,
            Night,
            Wave,
        }
    }
}