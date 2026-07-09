using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Minifantasy.TownsI
{
    public class T1_Hearth : MonoBehaviour
    {
        [Tooltip("Select a Prop Variant.")]
        [SerializeField] private HearthSelection selection = HearthSelection.NorthStack;

        [Header("Sprites")]
        [SerializeField] private Sprite hearthStack;
        [SerializeField] private Sprite hearthNoStack;
        [SerializeField] private Sprite hearthEast;
        [SerializeField] private Sprite hearthWest;

        [Header("Shadows")]
        [SerializeField] private Sprite shadowHearthStack;
        [SerializeField] private Sprite shadowHearthNoStack;

        private void OnValidate()
        {
            Sprite selectedSprite = null;
            Sprite selectedShadow = null;

            switch (selection)
            {
                case HearthSelection.NorthStack:
                    selectedSprite = hearthStack;
                    selectedShadow = shadowHearthStack;
                    break;
                case HearthSelection.NorthNoStack:
                    selectedSprite = hearthNoStack;
                    selectedShadow = shadowHearthNoStack;
                    break;
                case HearthSelection.East:
                    selectedSprite = hearthEast;
                    selectedShadow = null;
                    break;
                case HearthSelection.West:
                    selectedSprite = hearthWest;
                    selectedShadow = null;
                    break;
            }
            GetComponent<SpriteRenderer>().sprite = selectedSprite;
            transform.Find("Shadow").GetComponent<SpriteRenderer>().sprite = selectedShadow;
        }

        private enum HearthSelection
        {
            NorthStack,
            NorthNoStack,
            East,
            West,
        }
    }
}