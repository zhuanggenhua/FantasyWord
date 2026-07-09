using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Minifantasy.DeepCaves
{
    public class DC_Column : MonoBehaviour
    {
        [Tooltip("Select a Prop Variant.")]
        [SerializeField] private Column columnSelection = Column.Column0;
        [SerializeField] private ColumnColor columnColorSelection = ColumnColor.Brown;

        [Header("Sprites")]
        [SerializeField] private Sprite brownColumn0;
        [SerializeField] private Sprite brownColumn1;
        [SerializeField] private Sprite brownColumn2;
        [SerializeField] private Sprite brownColumn3;
        [SerializeField] private Sprite yellowColumn0;
        [SerializeField] private Sprite yellowColumn1;
        [SerializeField] private Sprite yellowColumn2;
        [SerializeField] private Sprite yellowColumn3;

        [Header("Shadows")]
        [SerializeField] private Sprite column0Shadow;
        [SerializeField] private Sprite column1Shadow;
        [SerializeField] private Sprite column2Shadow;
        [SerializeField] private Sprite column3Shadow;

        private void OnValidate()
        {
            Sprite selectedSprite = null;
            Sprite selectedShadow = null;

            switch (columnSelection)
            {
                case Column.Column0:
                    switch (columnColorSelection)
                    {
                        case ColumnColor.Brown:
                            selectedSprite = brownColumn0;
                            break;
                        case ColumnColor.Yellow:
                            selectedSprite = yellowColumn0;
                            break;
                    }
                    selectedShadow = column0Shadow;
                    break;
                case Column.Column1:
                    switch (columnColorSelection)
                    {
                        case ColumnColor.Brown:
                            selectedSprite = brownColumn1;
                            break;
                        case ColumnColor.Yellow:
                            selectedSprite = yellowColumn1;
                            break;
                    }
                    selectedShadow = column1Shadow;
                    break;
                case Column.Column2:
                    switch (columnColorSelection)
                    {
                        case ColumnColor.Brown:
                            selectedSprite = brownColumn2;
                            break;
                        case ColumnColor.Yellow:
                            selectedSprite = yellowColumn2;
                            break;
                    }
                    selectedShadow = column2Shadow;
                    break;
                case Column.Column3:
                    switch (columnColorSelection)
                    {
                        case ColumnColor.Brown:
                            selectedSprite = brownColumn3;
                            break;
                        case ColumnColor.Yellow:
                            selectedSprite = yellowColumn3;
                            break;
                    }
                    selectedShadow = column3Shadow;
                    break;
            }
            GetComponent<SpriteRenderer>().sprite = selectedSprite;
            transform.Find("Shadow").GetComponent<SpriteRenderer>().sprite = selectedShadow;
        }

        private enum Column
        {
            Column0,
            Column1,
            Column2,
            Column3
        }

        private enum ColumnColor
        {
            Brown,
            Yellow
        }
    }
}