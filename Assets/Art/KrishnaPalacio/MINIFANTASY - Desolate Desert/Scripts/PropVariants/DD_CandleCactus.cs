using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Minifantasy.DesolateDesert
{
    public class DD_CandleCactus : MonoBehaviour
    {
        [Tooltip("Select a Cactus Type.")]
        [SerializeField] private CandleCactus selection = CandleCactus.NoFlower1;

        [Header("Sprites")]
        [SerializeField] private Sprite candleCactus1;
        [SerializeField] private Sprite candleCactus2;
        [SerializeField] private Sprite candleCactusFlower1;
        [SerializeField] private Sprite candleCactusFlower2;
        [SerializeField] private Sprite candleCactusWide;

        [Header("Shadows")]
        [SerializeField] private Sprite candleCactus1Shadow;
        [SerializeField] private Sprite candleCactus2Shadow;
        [SerializeField] private Sprite candleCactusFlower1Shadow;
        [SerializeField] private Sprite candleCactusFlower2Shadow;
        [SerializeField] private Sprite candleCactusWideShadow;

        private void OnValidate()
        {
            Sprite selectedSprite = null;
            Sprite selectedShadow = null;

            switch (selection)
            {
                case CandleCactus.NoFlower1:
                    selectedSprite = candleCactus1;
                    selectedShadow = candleCactus1Shadow;
                    break;
                case CandleCactus.NoFlower2:
                    selectedSprite = candleCactus2;
                    selectedShadow = candleCactus2Shadow;
                    break;
                case CandleCactus.Flower1:
                    selectedSprite = candleCactusFlower1;
                    selectedShadow = candleCactusFlower1Shadow;
                    break;
                case CandleCactus.Flower2:
                    selectedSprite = candleCactusFlower2;
                    selectedShadow = candleCactusFlower2Shadow;
                    break;
                case CandleCactus.Wide:
                    selectedSprite = candleCactusWide;
                    selectedShadow = candleCactusWideShadow;
                    break;
            }
            GetComponent<SpriteRenderer>().sprite = selectedSprite;
            transform.Find("Shadow").GetComponent<SpriteRenderer>().sprite = selectedShadow;
        }

        private enum CandleCactus
        {
            NoFlower1,
            NoFlower2,
            Flower1,
            Flower2,
            Wide,
        }
    }
}