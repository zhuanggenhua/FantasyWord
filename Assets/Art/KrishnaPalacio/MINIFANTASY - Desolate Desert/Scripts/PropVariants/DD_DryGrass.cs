using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Minifantasy.DesolateDesert
{
    public class DD_DryGrass : MonoBehaviour
    {
        [Tooltip("Select a Prop Variant.")]
        [SerializeField] private DryGrass selection = DryGrass.DryGrass1;

        [Header("Sprites")]
        [SerializeField] private Sprite dryGrass1;
        [SerializeField] private Sprite dryGrass2;
        [SerializeField] private Sprite dryGrass3;
        [SerializeField] private Sprite dryGrass4;
        [SerializeField] private Sprite dryGrass5;
        [SerializeField] private Sprite dryGrass6;

        [Header("Shadows")]
        [SerializeField] private Sprite dryGrass1Shadow;
        [SerializeField] private Sprite dryGrass2Shadow;
        [SerializeField] private Sprite dryGrass3Shadow;
        [SerializeField] private Sprite dryGrass4Shadow;
        [SerializeField] private Sprite dryGrass5Shadow;
        [SerializeField] private Sprite dryGrass6Shadow;

        private void OnValidate()
        {
            Sprite selectedSprite = null;
            Sprite selectedShadow = null;

            switch (selection)
            {
                case DryGrass.DryGrass1:
                    selectedSprite = dryGrass1;
                    selectedShadow = dryGrass1Shadow;
                    break;
                case DryGrass.DryGrass2:
                    selectedSprite = dryGrass2;
                    selectedShadow = dryGrass2Shadow;
                    break;
                case DryGrass.DryGrass3:
                    selectedSprite = dryGrass3;
                    selectedShadow = dryGrass3Shadow;
                    break;
                case DryGrass.DryGrass4:
                    selectedSprite = dryGrass4;
                    selectedShadow = dryGrass4Shadow;
                    break;
                case DryGrass.DryGrass5:
                    selectedSprite = dryGrass5;
                    selectedShadow = dryGrass5Shadow;
                    break;
                case DryGrass.DryGrass6:
                    selectedSprite = dryGrass6;
                    selectedShadow = dryGrass6Shadow;
                    break;
            }
            GetComponent<SpriteRenderer>().sprite = selectedSprite;
            transform.Find("Shadow").GetComponent<SpriteRenderer>().sprite = selectedShadow;
        }

        private enum DryGrass
        {
            DryGrass1,
            DryGrass2,
            DryGrass3,
            DryGrass4,
            DryGrass5,
            DryGrass6
        }
    }
}