using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Minifantasy.TownsI
{
    public class T1_SideShelf : MonoBehaviour
    {
        [Tooltip("Select a Prop Variant.\nBased on roof position.")]
        [SerializeField] private SideShelfSelection selection = SideShelfSelection.Empty;
        [SerializeField] private HeightSelection height = HeightSelection.SingleShelf;
        [SerializeField] private WidthSelection width = WidthSelection.Short;

        [Header("Sprites")]
        [SerializeField] private Sprite emptySingleLongShelf;
        [SerializeField] private Sprite emptyDoubleLongShelf;
        [SerializeField] private Sprite emptyTripleLongShelf;
        [SerializeField] private Sprite emptySingleShortShelf;
        [SerializeField] private Sprite emptyDoubleShortShelf;
        [SerializeField] private Sprite emptyTripleShortShelf;

        [SerializeField] private Sprite filledEastSingleLongShelf;
        [SerializeField] private Sprite filledEastDoubleLongShelf;
        [SerializeField] private Sprite filledEastTripleLongShelf;
        [SerializeField] private Sprite filledEastSingleShortShelf;
        [SerializeField] private Sprite filledEastDoubleShortShelf;
        [SerializeField] private Sprite filledEastTripleShortShelf;

        [SerializeField] private Sprite filledWestSingleLongShelf;
        [SerializeField] private Sprite filledWestDoubleLongShelf;
        [SerializeField] private Sprite filledWestTripleLongShelf;
        [SerializeField] private Sprite filledWestSingleShortShelf;
        [SerializeField] private Sprite filledWestDoubleShortShelf;
        [SerializeField] private Sprite filledWestTripleShortShelf;

        [Header("Shadows")]
        [SerializeField] private Sprite singleLongShelfShadow;
        [SerializeField] private Sprite doubleLongShelfShadow;
        [SerializeField] private Sprite tripleLongShelfShadow;
        [SerializeField] private Sprite singleShortShelfShadow;
        [SerializeField] private Sprite doubleShortShelfShadow;
        [SerializeField] private Sprite tripleShortShelfShadow;

        [SerializeField] private Sprite filledEastSingleLongShelfShadow;
        [SerializeField] private Sprite filledEastDoubleLongShelfShadow;
        [SerializeField] private Sprite filledEastTripleLongShelfShadow;
        [SerializeField] private Sprite filledEastSingleShortShelfShadow;
        [SerializeField] private Sprite filledEastDoubleShortShelfShadow;
        [SerializeField] private Sprite filledEastTripleShortShelfShadow;

        [SerializeField] private Sprite filledWestSingleLongShelfShadow;
        [SerializeField] private Sprite filledWestDoubleLongShelfShadow;
        [SerializeField] private Sprite filledWestTripleLongShelfShadow;
        [SerializeField] private Sprite filledWestSingleShortShelfShadow;
        [SerializeField] private Sprite filledWestDoubleShortShelfShadow;
        [SerializeField] private Sprite filledWestTripleShortShelfShadow;

        private void OnValidate()
        {
            Sprite selectedSprite = null;
            Sprite selectedShadow = null;

            switch (selection)
            {
                case SideShelfSelection.Empty:
                    switch (height)
                    {
                        case HeightSelection.SingleShelf:
                            switch (width)
                            {
                                case WidthSelection.Short:
                                    selectedSprite = emptySingleShortShelf;
                                    selectedShadow = singleShortShelfShadow;
                                    break;
                                case WidthSelection.Long:
                                    selectedSprite = emptySingleLongShelf;
                                    selectedShadow = singleLongShelfShadow;
                                    break;
                            }
                            break;
                        case HeightSelection.DoubleShelf:
                            switch (width)
                            {
                                case WidthSelection.Short:
                                    selectedSprite = emptyDoubleShortShelf;
                                    selectedShadow = doubleShortShelfShadow;
                                    break;
                                case WidthSelection.Long:
                                    selectedSprite = emptyDoubleLongShelf;
                                    selectedShadow = doubleLongShelfShadow;
                                    break;
                            }
                            break;
                        case HeightSelection.TripleShelf:
                            switch (width)
                            {
                                case WidthSelection.Short:
                                    selectedSprite = emptyTripleShortShelf;
                                    selectedShadow = tripleShortShelfShadow;
                                    break;
                                case WidthSelection.Long:
                                    selectedSprite = emptyTripleLongShelf;
                                    selectedShadow = tripleLongShelfShadow;
                                    break;
                            }
                            break;
                    }
                    break;
                case SideShelfSelection.FilledEast:
                    switch (height)
                    {
                        case HeightSelection.SingleShelf:
                            switch (width)
                            {
                                case WidthSelection.Short:
                                    selectedSprite = filledEastSingleShortShelf;
                                    selectedShadow = filledEastSingleShortShelfShadow;
                                    break;
                                case WidthSelection.Long:
                                    selectedSprite = filledEastSingleLongShelf;
                                    selectedShadow = filledEastSingleLongShelfShadow;
                                    break;
                            }
                            break;
                        case HeightSelection.DoubleShelf:
                            switch (width)
                            {
                                case WidthSelection.Short:
                                    selectedSprite = filledEastDoubleShortShelf;
                                    selectedShadow = filledEastDoubleShortShelfShadow;
                                    break;
                                case WidthSelection.Long:
                                    selectedSprite = filledEastDoubleLongShelf;
                                    selectedShadow = filledEastDoubleLongShelfShadow;
                                    break;
                            }
                            break;
                        case HeightSelection.TripleShelf:
                            switch (width)
                            {
                                case WidthSelection.Short:
                                    selectedSprite = filledEastTripleShortShelf;
                                    selectedShadow = filledEastTripleShortShelfShadow;
                                    break;
                                case WidthSelection.Long:
                                    selectedSprite = filledEastTripleLongShelf;
                                    selectedShadow = filledEastTripleLongShelfShadow;
                                    break;
                            }
                            break;
                    }
                    break;
                case SideShelfSelection.FilledWest:
                    switch (height)
                    {
                        case HeightSelection.SingleShelf:
                            switch (width)
                            {
                                case WidthSelection.Short:
                                    selectedSprite = filledWestSingleShortShelf;
                                    selectedShadow = filledWestSingleShortShelfShadow;
                                    break;
                                case WidthSelection.Long:
                                    selectedSprite = filledWestSingleLongShelf;
                                    selectedShadow = filledWestSingleLongShelfShadow;
                                    break;
                            }
                            break;
                        case HeightSelection.DoubleShelf:
                            switch (width)
                            {
                                case WidthSelection.Short:
                                    selectedSprite = filledWestDoubleShortShelf;
                                    selectedShadow = filledWestDoubleShortShelfShadow;
                                    break;
                                case WidthSelection.Long:
                                    selectedSprite = filledWestDoubleLongShelf;
                                    selectedShadow = filledWestDoubleLongShelfShadow;
                                    break;
                            }
                            break;
                        case HeightSelection.TripleShelf:
                            switch (width)
                            {
                                case WidthSelection.Short:
                                    selectedSprite = filledWestTripleShortShelf;
                                    selectedShadow = filledWestTripleShortShelfShadow;
                                    break;
                                case WidthSelection.Long:
                                    selectedSprite = filledWestTripleLongShelf;
                                    selectedShadow = filledWestTripleLongShelfShadow;
                                    break;
                            }
                            break;
                    }
                    break;
            }
            GetComponent<SpriteRenderer>().sprite = selectedSprite;
            transform.Find("Shadow").GetComponent<SpriteRenderer>().sprite = selectedShadow;
        }

        private enum SideShelfSelection
        {
            Empty,
            FilledWest,
            FilledEast,
        }

        private enum HeightSelection
        {
            SingleShelf,
            DoubleShelf,
            TripleShelf,
        }

        private enum WidthSelection
        {
            Short,
            Long,
        }
    }
}