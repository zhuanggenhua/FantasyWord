using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Minifantasy.DeepCaves
{
    public class DC_SkullSpear : MonoBehaviour
    {
        [Tooltip("Select a Prop Variant.")]
        [SerializeField] private SkullSpear skullSpearSelection = SkullSpear.Left;

        [Header("Sprites")]
        [SerializeField] private Sprite skullSpearLeft;
        [SerializeField] private Sprite skullSpearStraight0;
        [SerializeField] private Sprite skullSpearStraight1;
        [SerializeField] private Sprite skullSpearRight;

        [Header("Shadows")]
        [SerializeField] private Sprite skullSpearLeftShadow;
        [SerializeField] private Sprite skullSpearStraight0Shadow;
        [SerializeField] private Sprite skullSpearStraight1Shadow;
        [SerializeField] private Sprite skullSpearRightShadow;

        private void OnValidate()
        {
            Sprite selectedSprite = null;
            Sprite selectedShadow = null;

            switch (skullSpearSelection)
            {
                case SkullSpear.Left:
                    selectedSprite = skullSpearLeft;
                    selectedShadow = skullSpearLeftShadow;
                    break;
                case SkullSpear.Straight0:
                    selectedSprite = skullSpearStraight0;
                    selectedShadow = skullSpearStraight0Shadow;
                    break;
                case SkullSpear.Straight1:
                    selectedSprite = skullSpearStraight1;
                    selectedShadow = skullSpearStraight1Shadow;
                    break;
                case SkullSpear.Right:
                    selectedSprite = skullSpearRight;
                    selectedShadow = skullSpearRightShadow;
                    break;
            }
            GetComponent<SpriteRenderer>().sprite = selectedSprite;
            transform.Find("Shadow").GetComponent<SpriteRenderer>().sprite = selectedShadow;
        }

        private enum SkullSpear
        {
            Left,
            Straight0,
            Straight1,
            Right
        }
    }
}