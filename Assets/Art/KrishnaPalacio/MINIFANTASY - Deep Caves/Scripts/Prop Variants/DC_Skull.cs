using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Minifantasy.DeepCaves
{
    public class DC_Skull : MonoBehaviour
    {
        [Tooltip("Select a Prop Variant.")]
        [SerializeField] private Skull skullSelection = Skull.Left;

        [Header("Sprites")]
        [SerializeField] private Sprite skullLeft;
        [SerializeField] private Sprite skullRight;

        [Header("Shadows")]
        [SerializeField] private Sprite skullLeftShadow;
        [SerializeField] private Sprite skullRightShadow;

        private void OnValidate()
        {
            Sprite selectedSprite = null;
            Sprite selectedShadow = null;

            switch (skullSelection)
            {
                case Skull.Left:
                    selectedSprite = skullLeft;
                    selectedShadow = skullLeftShadow;
                    break;
                case Skull.Right:
                    selectedSprite = skullRight;
                    selectedShadow = skullRightShadow;
                    break;
            }
            GetComponent<SpriteRenderer>().sprite = selectedSprite;
            transform.Find("Shadow").GetComponent<SpriteRenderer>().sprite = selectedShadow;
        }

        private enum Skull
        {
            Left,
            Right,
        }
    }
}