using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Minifantasy.TownsI
{
    public class T1_FrontShelf : MonoBehaviour
    {
        [Tooltip("Select a Prop Variant.")]
        [SerializeField] private FrontShelfSelection selection = FrontShelfSelection.Empty;
        [SerializeField] private HeightSelection height = HeightSelection.SingleShelf;
        [SerializeField] private WidthSelection width = WidthSelection.Short;

        [Header("Sprites")]
        [SerializeField] private Sprite emptySingleLongShelf;
        [SerializeField] private Sprite emptyDoubleLongShelf;
        [SerializeField] private Sprite emptyTripleLongShelf;
        [SerializeField] private Sprite emptySingleShortShelf;
        [SerializeField] private Sprite emptyDoubleShortShelf;
        [SerializeField] private Sprite emptyTripleShortShelf;

        [SerializeField] private Sprite booksSingleLongShelf;
        [SerializeField] private Sprite booksDoubleLongShelf;
        [SerializeField] private Sprite booksTripleLongShelf;
        [SerializeField] private Sprite booksSingleShortShelf;
        [SerializeField] private Sprite booksDoubleShortShelf;
        [SerializeField] private Sprite booksTripleShortShelf;

        [SerializeField] private Sprite vialsSingleLongShelf;
        [SerializeField] private Sprite vialsDoubleLongShelf;
        [SerializeField] private Sprite vialsTripleLongShelf;
        [SerializeField] private Sprite vialsSingleShortShelf;
        [SerializeField] private Sprite vialsDoubleShortShelf;
        [SerializeField] private Sprite vialsTripleShortShelf;

        [Header("Shadows")]
        [SerializeField] private Sprite singleLongShelfShadow;
        [SerializeField] private Sprite doubleLongShelfShadow;
        [SerializeField] private Sprite tripleLongShelfShadow;
        [SerializeField] private Sprite singleShortShelfShadow;
        [SerializeField] private Sprite doubleShortShelfShadow;
        [SerializeField] private Sprite tripleShortShelfShadow;

        [SerializeField] private Sprite booksSingleLongShelfShadow;
        [SerializeField] private Sprite booksDoubleLongShelfShadow;
        [SerializeField] private Sprite booksTripleLongShelfShadow;
        [SerializeField] private Sprite booksSingleShortShelfShadow;
        [SerializeField] private Sprite booksDoubleShortShelfShadow;
        [SerializeField] private Sprite booksTripleShortShelfShadow;

        [SerializeField] private Sprite vialsSingleLongShelfShadow;
        [SerializeField] private Sprite vialsDoubleLongShelfShadow;
        [SerializeField] private Sprite vialsTripleLongShelfShadow;
        [SerializeField] private Sprite vialsSingleShortShelfShadow;
        [SerializeField] private Sprite vialsDoubleShortShelfShadow;
        [SerializeField] private Sprite vialsTripleShortShelfShadow;

        private void OnValidate()
        {
            Sprite selectedSprite = null;
            Sprite selectedShadow = null;

            switch (selection)
            {
                case FrontShelfSelection.Empty:
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
                case FrontShelfSelection.Books:
                    switch (height)
                    {
                        case HeightSelection.SingleShelf:
                            switch (width)
                            {
                                case WidthSelection.Short:
                                    selectedSprite = booksSingleShortShelf;
                                    selectedShadow = booksSingleShortShelfShadow;
                                    break;
                                case WidthSelection.Long:
                                    selectedSprite = booksSingleLongShelf;
                                    selectedShadow = booksSingleLongShelfShadow;
                                    break;
                            }
                            break;
                        case HeightSelection.DoubleShelf:
                            switch (width)
                            {
                                case WidthSelection.Short:
                                    selectedSprite = booksDoubleShortShelf;
                                    selectedShadow = booksDoubleShortShelfShadow;
                                    break;
                                case WidthSelection.Long:
                                    selectedSprite = booksDoubleLongShelf;
                                    selectedShadow = booksDoubleLongShelfShadow;
                                    break;
                            }
                            break;
                        case HeightSelection.TripleShelf:
                            switch (width)
                            {
                                case WidthSelection.Short:
                                    selectedSprite = booksTripleShortShelf;
                                    selectedShadow = booksTripleShortShelfShadow;
                                    break;
                                case WidthSelection.Long:
                                    selectedSprite = booksTripleLongShelf;
                                    selectedShadow = booksTripleLongShelfShadow;
                                    break;
                            }
                            break;
                    }
                    break;
                case FrontShelfSelection.Vials:
                    switch (height)
                    {
                        case HeightSelection.SingleShelf:
                            switch (width)
                            {
                                case WidthSelection.Short:
                                    selectedSprite = vialsSingleShortShelf;
                                    selectedShadow = vialsSingleShortShelfShadow;
                                    break;
                                case WidthSelection.Long:
                                    selectedSprite = vialsSingleLongShelf;
                                    selectedShadow = vialsSingleLongShelfShadow;
                                    break;
                            }
                            break;
                        case HeightSelection.DoubleShelf:
                            switch (width)
                            {
                                case WidthSelection.Short:
                                    selectedSprite = vialsDoubleShortShelf;
                                    selectedShadow = vialsDoubleShortShelfShadow;
                                    break;
                                case WidthSelection.Long:
                                    selectedSprite = vialsDoubleLongShelf;
                                    selectedShadow = vialsDoubleLongShelfShadow;
                                    break;
                            }
                            break;
                        case HeightSelection.TripleShelf:
                            switch (width)
                            {
                                case WidthSelection.Short:
                                    selectedSprite = vialsTripleShortShelf;
                                    selectedShadow = vialsTripleShortShelfShadow;
                                    break;
                                case WidthSelection.Long:
                                    selectedSprite = vialsTripleLongShelf;
                                    selectedShadow = vialsTripleLongShelfShadow;
                                    break;
                            }
                            break;
                    }
                    break;
            }
            GetComponent<SpriteRenderer>().sprite = selectedSprite;
            transform.Find("Shadow").GetComponent<SpriteRenderer>().sprite = selectedShadow;
        }

        private enum FrontShelfSelection
        {
            Empty,
            Vials,
            Books,
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