using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Minifantasy.Farms
{
    public class FRM_HayBales : MonoBehaviour
    {
        [Tooltip("Select a Prop Variant.")]
        [SerializeField] private HaySelection selection = HaySelection.SingleBale;

        [Header("Sprites")]
        [SerializeField] private Sprite singleBale;
        [SerializeField] private Sprite rowOfBales;
        [SerializeField] private Sprite columnOfBales;
        [SerializeField] private Sprite towerOfBales;

        [Header("Shadows")]
        [SerializeField] private Sprite singleBaleShadow;
        [SerializeField] private Sprite rowOfBalesShadow;
        [SerializeField] private Sprite columnOfBalesShadow;
        [SerializeField] private Sprite towerOfBalesShadow;

        private void OnValidate()
        {
            Sprite selectedSprite = null;
            Sprite selectedShadow = null;

            switch (selection)
            {
                case HaySelection.SingleBale:
                    selectedSprite = singleBale;
                    selectedShadow = singleBaleShadow;
                    break;
                case HaySelection.RowOfBales:
                    selectedSprite = rowOfBales;
                    selectedShadow = rowOfBalesShadow;
                    break;
                case HaySelection.ColumnOfBales:
                    selectedSprite = columnOfBales;
                    selectedShadow = columnOfBalesShadow;
                    break;
                case HaySelection.TowerOfBales:
                    selectedSprite = towerOfBales;
                    selectedShadow = towerOfBalesShadow;
                    break;
            }
            GetComponent<SpriteRenderer>().sprite = selectedSprite;
            transform.Find("Shadow").GetComponent<SpriteRenderer>().sprite = selectedShadow;
        }


        private enum HaySelection
        {
            SingleBale,
            RowOfBales,
            ColumnOfBales,
            TowerOfBales
        }
    }
}