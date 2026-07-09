using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Minifantasy.TownsI
{
    public class T1_Painting : MonoBehaviour
    {
        [Tooltip("Select a Prop Variant.\nBased on roof position.")]
        [SerializeField] private PaintingSelection selection = PaintingSelection.Pearl;

        [Header("Sprites")]
        [SerializeField] private Sprite pearl;
        [SerializeField] private Sprite scream;
        [SerializeField] private Sprite mona;
        [SerializeField] private Sprite sunset;

        [Header("Shadows")]
        [SerializeField] private Sprite pearlShadow;
        [SerializeField] private Sprite screamShadow;
        [SerializeField] private Sprite monaShadow;
        [SerializeField] private Sprite sunsetShadow;

        private void OnValidate()
        {
            Sprite selectedSprite = null;
            Sprite selectedShadow = null;

            switch (selection)
            {
                case PaintingSelection.Pearl:
                    selectedSprite = pearl;
                    selectedShadow = pearlShadow;
                    break;
                case PaintingSelection.Scream:
                    selectedSprite = scream;
                    selectedShadow = screamShadow;
                    break;
                case PaintingSelection.Mona:
                    selectedSprite = mona;
                    selectedShadow = monaShadow;
                    break;
                case PaintingSelection.Sunset:
                    selectedSprite = sunset;
                    selectedShadow = sunsetShadow;
                    break;
            }
            GetComponent<SpriteRenderer>().sprite = selectedSprite;
            transform.Find("Shadow").GetComponent<SpriteRenderer>().sprite = selectedShadow;
        }

        private enum PaintingSelection
        {
            Pearl,
            Scream,
            Mona,
            Sunset,
        }
    }
}