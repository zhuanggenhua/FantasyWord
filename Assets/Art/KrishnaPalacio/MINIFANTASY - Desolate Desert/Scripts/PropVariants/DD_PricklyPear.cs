using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Minifantasy.DesolateDesert
{
    public class DD_PricklyPear : MonoBehaviour
    {
        [Tooltip("Select a Cactus Type.")]
        [SerializeField] private PricklyPear selection = PricklyPear.NoFlower1;

        [Header("Sprites")]
        [SerializeField] private Sprite pricklyPear1;
        [SerializeField] private Sprite pricklyPear2;
        [SerializeField] private Sprite pricklyPearFlower1;
        [SerializeField] private Sprite pricklyPearFlower2;

        [Header("Shadows")]
        [SerializeField] private Sprite pricklyPear1Shadow;
        [SerializeField] private Sprite pricklyPear2Shadow;
        [SerializeField] private Sprite pricklyPearFlower1Shadow;
        [SerializeField] private Sprite pricklyPearFlower2Shadow;

        private void OnValidate()
        {
            Sprite selectedSprite = null;
            Sprite selectedShadow = null;

            switch (selection)
            {
                case PricklyPear.NoFlower1:
                    selectedSprite = pricklyPear1;
                    selectedShadow = pricklyPear1Shadow;
                    break;
                case PricklyPear.NoFlower2:
                    selectedSprite = pricklyPear2;
                    selectedShadow = pricklyPear2Shadow;
                    break;
                case PricklyPear.Flower1:
                    selectedSprite = pricklyPearFlower1;
                    selectedShadow = pricklyPearFlower1Shadow;
                    break;
                case PricklyPear.Flower2:
                    selectedSprite = pricklyPearFlower2;
                    selectedShadow = pricklyPearFlower2Shadow;
                    break;
            }
            GetComponent<SpriteRenderer>().sprite = selectedSprite;
            transform.Find("Shadow").GetComponent<SpriteRenderer>().sprite = selectedShadow;
        }

        private enum PricklyPear
        {
            NoFlower1,
            NoFlower2,
            Flower1,
            Flower2,
        }
    }
}