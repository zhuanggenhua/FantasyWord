using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Minifantasy.TownsI
{
    public class T1_Stove : MonoBehaviour
    {
        [Tooltip("Select a Prop Variant.")]
        [SerializeField] private StoveSelection selection = StoveSelection.StoveNorth;

        [Header("Sprites")]
        [SerializeField] private Sprite stoveNorth;
        [SerializeField] private Sprite stoveEast;
        [SerializeField] private Sprite stoveWest;

        [Header("Shadows")]
        [SerializeField] private Sprite shadowStoveNorth;
        [SerializeField] private Sprite shadowStoveWest;

        private void OnValidate()
        {
            Sprite selectedSprite = null;
            Sprite selectedShadow = null;

            switch (selection)
            {
                case StoveSelection.StoveNorth:
                    selectedSprite = stoveNorth;
                    selectedShadow = shadowStoveNorth;
                    break;
                case StoveSelection.StoveEast:
                    selectedSprite = stoveEast;
                    selectedShadow = null;
                    break;
                case StoveSelection.StoveWest:
                    selectedSprite = stoveWest;
                    selectedShadow = shadowStoveWest;
                    break;
            }
            GetComponent<SpriteRenderer>().sprite = selectedSprite;
            transform.Find("Shadow").GetComponent<SpriteRenderer>().sprite = selectedShadow;
        }

        private enum StoveSelection
        {
            StoveNorth,
            StoveEast,
            StoveWest,
        }
    }
}