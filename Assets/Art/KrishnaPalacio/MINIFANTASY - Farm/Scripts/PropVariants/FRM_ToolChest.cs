using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Minifantasy.Farms
{
    public class FRM_ToolChest : MonoBehaviour
    {
        [Tooltip("Select a Prop Variant.")]
        [SerializeField] private ToolChestSelection selection = ToolChestSelection.Short;

        [Header("Sprites")]
        [SerializeField] private Sprite toolChestShort;
        [SerializeField] private Sprite toolChestWide;

        [Header("Shadows")]
        [SerializeField] private Sprite toolChestShortShadow;
        [SerializeField] private Sprite toolChestWideShadow;

        private void OnValidate()
        {
            Sprite selectedSprite = null;
            Sprite selectedShadow = null;

            switch (selection)
            {
                case ToolChestSelection.Short:
                    selectedSprite = toolChestShort;
                    selectedShadow = toolChestShortShadow;
                    break;
                case ToolChestSelection.Wide:
                    selectedSprite = toolChestWide;
                    selectedShadow = toolChestWideShadow;
                    break;
            }
            GetComponent<SpriteRenderer>().sprite = selectedSprite;
            transform.Find("Shadow").GetComponent<SpriteRenderer>().sprite = selectedShadow;
        }

        private enum ToolChestSelection
        {
            Short,
            Wide,
        }
    }
}