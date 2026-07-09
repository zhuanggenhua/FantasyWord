using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Minifantasy.DesolateDesert
{
    public class DD_BarrelCactus : MonoBehaviour
    {
        [Tooltip("Select a Cactus Type.")]
        [SerializeField] private BarrelCactus selection = BarrelCactus.NoFlower;

        [Header("Sprites")]
        [SerializeField] private Sprite barrelCactus;
        [SerializeField] private Sprite barrelCactusFlower;

        [Header("Shadows")]
        [SerializeField] private Sprite barrelCactusShadow;
        [SerializeField] private Sprite barrelCactusFlowerShadow;

        private void OnValidate()
        {
            Sprite selectedSprite = null;
            Sprite selectedShadow = null;

            switch (selection)
            {
                case BarrelCactus.NoFlower:
                    selectedSprite = barrelCactus;
                    selectedShadow = barrelCactusShadow;
                    break;
                case BarrelCactus.Flower:
                    selectedSprite = barrelCactusFlower;
                    selectedShadow = barrelCactusFlowerShadow;
                    break;
            }
            GetComponent<SpriteRenderer>().sprite = selectedSprite;
            transform.Find("Shadow").GetComponent<SpriteRenderer>().sprite = selectedShadow;
        }

        private enum BarrelCactus
        {
            NoFlower,
            Flower,
        }
    }
}