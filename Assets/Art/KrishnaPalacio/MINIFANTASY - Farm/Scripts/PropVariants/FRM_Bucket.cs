using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Minifantasy.Farms
{
    public class FRM_Bucket : MonoBehaviour
    {
        [Tooltip("Select a Prop Variant.")]
        [SerializeField] private BucketSelection selection = BucketSelection.Water;

        [Header("Sprites")]
        [SerializeField] private Sprite waterBucket;
        [SerializeField] private Sprite milkBucket;

        [Header("Shadows")]
        [SerializeField] private Sprite bucketShadow;

        private void OnValidate()
        {
            Sprite selectedSprite = null;
            Sprite selectedShadow = null;

            switch (selection)
            {
                case BucketSelection.Water:
                    selectedSprite = waterBucket;
                    selectedShadow = bucketShadow;
                    break;
                case BucketSelection.Milk:
                    selectedSprite = milkBucket;
                    selectedShadow = bucketShadow;
                    break;
            }
            GetComponent<SpriteRenderer>().sprite = selectedSprite;
            transform.Find("Shadow").GetComponent<SpriteRenderer>().sprite = selectedShadow;
        }

        private enum BucketSelection
        {
            Water,
            Milk,
        }
    }
}