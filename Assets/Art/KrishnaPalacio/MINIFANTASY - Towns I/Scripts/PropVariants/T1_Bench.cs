using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Minifantasy.TownsI
{
    public class T1_Bench : MonoBehaviour
    {
        [Tooltip("Select a Prop Variant.")]
        [SerializeField] private BenchSelection selection = BenchSelection.Wide;

        [Header("Sprites")]
        [SerializeField] private Sprite benchWide;
        [SerializeField] private Sprite benchLong;

        [Header("Shadows")]
        [SerializeField] private Sprite shadowBenchWide;
        [SerializeField] private Sprite shadowBenchLong;

        private void OnValidate()
        {
            Sprite selectedSprite = null;
            Sprite selectedShadow = null;

            switch (selection)
            {
                case BenchSelection.Wide:
                    selectedSprite = benchWide;
                    selectedShadow = shadowBenchWide;
                    break;
                case BenchSelection.Long:
                    selectedSprite = benchLong;
                    selectedShadow = shadowBenchLong;
                    break;
            }
            GetComponent<SpriteRenderer>().sprite = selectedSprite;
            transform.Find("Shadow").GetComponent<SpriteRenderer>().sprite = selectedShadow;
        }

        private enum BenchSelection
        {
            Wide,
            Long,
        }
    }
}