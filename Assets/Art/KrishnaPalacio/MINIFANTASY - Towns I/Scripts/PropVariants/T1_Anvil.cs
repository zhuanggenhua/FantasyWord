using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Minifantasy.TownsI
{
    public class T1_Anvil : MonoBehaviour
    {
        [Tooltip("Select a Prop Variant.")]
        [SerializeField] private AnvilSelection selection = AnvilSelection.Vertical;

        [Header("Sprites")]
        [SerializeField] private Sprite anvilVertical;
        [SerializeField] private Sprite anvilHorizontal;

        [Header("Shadows")]
        [SerializeField] private Sprite shadowAnvilVertical;
        [SerializeField] private Sprite shadowAnvilHorizontal;

        private void OnValidate()
        {
            Sprite selectedSprite = null;
            Sprite selectedShadow = null;

            switch (selection)
            {
                case AnvilSelection.Vertical:
                    selectedSprite = anvilVertical;
                    selectedShadow = shadowAnvilVertical;
                    break;
                case AnvilSelection.Horizontal:
                    selectedSprite = anvilHorizontal;
                    selectedShadow = shadowAnvilHorizontal;
                    break;
            }
            GetComponent<SpriteRenderer>().sprite = selectedSprite;
            transform.Find("Shadow").GetComponent<SpriteRenderer>().sprite = selectedShadow;
        }

        private enum AnvilSelection
        {
            Vertical,
            Horizontal,
        }
    }
}