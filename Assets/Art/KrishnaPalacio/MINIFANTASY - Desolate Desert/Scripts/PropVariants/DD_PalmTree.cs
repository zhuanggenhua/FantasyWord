using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Minifantasy.DesolateDesert
{
    public class DD_PalmTree : MonoBehaviour
    {
        [Tooltip("Select a Prop Variant.")]
        [SerializeField] private PalmTree selection = PalmTree.Tree1;

        [Header("Sprites")]
        [SerializeField] private Sprite tree1;
        [SerializeField] private Sprite tree2;
        [SerializeField] private Sprite tree3;

        [Header("Shadows")]
        [SerializeField] private Sprite tree1Shadow;
        [SerializeField] private Sprite tree2Shadow;
        [SerializeField] private Sprite tree3Shadow;

        private void OnValidate()
        {
            Sprite selectedSprite = null;
            Sprite selectedShadow = null;

            switch (selection)
            {
                case PalmTree.Tree1:
                    selectedSprite = tree1;
                    selectedShadow = tree1Shadow;
                    break;
                case PalmTree.Tree2:
                    selectedSprite = tree2;
                    selectedShadow = tree2Shadow;
                    break;
                case PalmTree.Tree3:
                    selectedSprite = tree3;
                    selectedShadow = tree3Shadow;
                    break;
            }
            GetComponent<SpriteRenderer>().sprite = selectedSprite;
            transform.Find("Shadow").GetComponent<SpriteRenderer>().sprite = selectedShadow;
        }


        private enum PalmTree
        {
            Tree1,
            Tree2,
            Tree3,
        }
    }
}