using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Minifantasy.TownsI
{
    public class T1_Bed : MonoBehaviour
    {
        [Tooltip("Select a Prop Variant.")]
        [SerializeField] private BedSelection selection = BedSelection.East;

        [Header("Sprites")]
        [SerializeField] private Sprite eastBed;
        [SerializeField] private Sprite northBed;
        [SerializeField] private Sprite westBed;
        [SerializeField] private Sprite southBed;

        [Header("Shadows")]
        [SerializeField] private Sprite northSouthBedShadow;
        [SerializeField] private Sprite eastWestBedShadow;

        private void OnValidate()
        {
            Sprite selectedSprite = null;
            Sprite selectedShadow = null;

            switch (selection)
            {
                case BedSelection.East:
                    selectedSprite = eastBed;
                    selectedShadow = eastWestBedShadow;
                    break;
                case BedSelection.North:
                    selectedSprite = northBed;
                    selectedShadow = northSouthBedShadow;
                    break;
                case BedSelection.West:
                    selectedSprite = westBed;
                    selectedShadow = eastWestBedShadow;
                    break;
                case BedSelection.South:
                    selectedSprite = southBed;
                    selectedShadow = northSouthBedShadow;
                    break;
            }
            GetComponent<SpriteRenderer>().sprite = selectedSprite;
            transform.Find("Shadow").GetComponent<SpriteRenderer>().sprite = selectedShadow;
        }


        private enum BedSelection
        {
            East,
            North,
            West,
            South
        }
    }
}