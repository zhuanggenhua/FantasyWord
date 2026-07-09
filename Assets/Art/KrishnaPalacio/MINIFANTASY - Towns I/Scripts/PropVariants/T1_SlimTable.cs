using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Minifantasy.TownsI
{
    public class T1_SlimTable : MonoBehaviour
    {
        [Tooltip("Select a Prop Variant.\nBased on roof position.")]
        [SerializeField] private SlimTableSelection selection = SlimTableSelection.Plain;
        [SerializeField] private OrientationSelection orientation = OrientationSelection.Long;

        [Header("Sprites")]
        [SerializeField] private Sprite widePlainTable;
        [SerializeField] private Sprite longPlainTable;
        [SerializeField] private Sprite wideDesk;
        [SerializeField] private Sprite longDesk;
        [SerializeField] private Sprite wideButcherTable;
        [SerializeField] private Sprite longButcherTable;
        [SerializeField] private Sprite wideAlchemyTable;
        [SerializeField] private Sprite longAlchemyTable;

        [Header("Shadows")]
        [SerializeField] private Sprite wideTableShadow;
        [SerializeField] private Sprite longTableShadow;
        [SerializeField] private Sprite wideAlchemyTableShadow;
        [SerializeField] private Sprite longAlchemyTableShadow;

        private void OnValidate()
        {
            Sprite selectedSprite = null;
            Sprite selectedShadow = null;

            switch (selection)
            {
                case SlimTableSelection.Plain:
                    switch (orientation)
                    {
                        case OrientationSelection.Long:
                            selectedSprite = longPlainTable;
                            selectedShadow = longTableShadow;
                            break;
                        case OrientationSelection.Wide:
                            selectedSprite = widePlainTable;
                            selectedShadow = wideTableShadow;
                            break;
                    }
                    break;
                case SlimTableSelection.Desk:
                    switch (orientation)
                    {
                        case OrientationSelection.Long:
                            selectedSprite = longDesk;
                            selectedShadow = longTableShadow;
                            break;
                        case OrientationSelection.Wide:
                            selectedSprite = wideDesk;
                            selectedShadow = wideTableShadow;
                            break;
                    }
                    break;
                case SlimTableSelection.Butcher:
                    switch (orientation)
                    {
                        case OrientationSelection.Long:
                            selectedSprite = longButcherTable;
                            selectedShadow = longTableShadow;
                            break;
                        case OrientationSelection.Wide:
                            selectedSprite = wideButcherTable;
                            selectedShadow = wideTableShadow;
                            break;
                    }
                    break;
                case SlimTableSelection.Alchemy:
                    switch (orientation)
                    {
                        case OrientationSelection.Long:
                            selectedSprite = longAlchemyTable;
                            selectedShadow = longAlchemyTableShadow;
                            break;
                        case OrientationSelection.Wide:
                            selectedSprite = wideAlchemyTable;
                            selectedShadow = wideAlchemyTableShadow;
                            break;
                    }
                    break;
            }
            GetComponent<SpriteRenderer>().sprite = selectedSprite;
            transform.Find("Shadow").GetComponent<SpriteRenderer>().sprite = selectedShadow;
        }

        private enum SlimTableSelection
        {
            Plain,
            Desk,
            Butcher,
            Alchemy,
        }

        private enum OrientationSelection
        {
            Long,
            Wide,
        }
    }
}