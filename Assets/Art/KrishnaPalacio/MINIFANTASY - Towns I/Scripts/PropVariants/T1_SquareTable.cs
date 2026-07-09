using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Minifantasy.TownsI
{
    public class T1_SquareTable : MonoBehaviour
    {
        [Tooltip("Select a Prop Variant.\nBased on roof position.")]
        [SerializeField] private SquareTableSelection selection = SquareTableSelection.Empty;
        [SerializeField] private TableclothSelection orientation = TableclothSelection.None;

        [Header("Sprites")]
        [SerializeField] private Sprite emptyTable;
        [SerializeField] private Sprite set1Table;
        [SerializeField] private Sprite set2Table;
        [SerializeField] private Sprite set3Table;
        [SerializeField] private Sprite clothedTable;
        [SerializeField] private Sprite clothedSet1Table;
        [SerializeField] private Sprite clothedSet2Table;
        [SerializeField] private Sprite clothedSet3Table;

        [Header("Shadows")]
        [SerializeField] private Sprite tableShadow;

        private void OnValidate()
        {
            Sprite selectedSprite = null;

            switch (selection)
            {
                case SquareTableSelection.Empty:
                    switch (orientation)
                    {
                        case TableclothSelection.None:
                            selectedSprite = emptyTable;
                            break;
                        case TableclothSelection.Tablecloth:
                            selectedSprite = clothedTable;
                            break;
                    }
                    break;
                case SquareTableSelection.Set1:
                    switch (orientation)
                    {
                        case TableclothSelection.None:
                            selectedSprite = set1Table;
                            break;
                        case TableclothSelection.Tablecloth:
                            selectedSprite = clothedSet1Table;
                            break;
                    }
                    break;
                case SquareTableSelection.Set2:
                    switch (orientation)
                    {
                        case TableclothSelection.None:
                            selectedSprite = set2Table;
                            break;
                        case TableclothSelection.Tablecloth:
                            selectedSprite = clothedSet2Table;
                            break;
                    }
                    break;
                case SquareTableSelection.Set3:
                    switch (orientation)
                    {
                        case TableclothSelection.None:
                            selectedSprite = set3Table;
                            break;
                        case TableclothSelection.Tablecloth:
                            selectedSprite = clothedSet3Table;
                            break;
                    }
                    break;
            }
            GetComponent<SpriteRenderer>().sprite = selectedSprite;
            Sprite shadowSprite = transform.Find("Shadow").GetComponent<SpriteRenderer>().sprite;
            if (shadowSprite != tableShadow)
            {
                shadowSprite = tableShadow;
            }
        }

        private enum SquareTableSelection
        {
            Empty,
            Set1,
            Set2,
            Set3,
        }

        private enum TableclothSelection
        {
            None,
            Tablecloth,
        }
    }
}