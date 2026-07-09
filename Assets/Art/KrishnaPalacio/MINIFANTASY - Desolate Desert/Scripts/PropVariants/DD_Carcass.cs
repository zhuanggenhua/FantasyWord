using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Minifantasy.DesolateDesert
{
    public class DD_Carcass : MonoBehaviour
    {
        [Tooltip("Select a Prop Variant.")]
        [SerializeField] private Carcass selection = Carcass.SkullLeft;

        [Header("Sprites")]
        [SerializeField] private Sprite skullLeft;
        [SerializeField] private Sprite skullRight;
        [SerializeField] private Sprite ribsLeft;
        [SerializeField] private Sprite ribsRight;

        private void OnValidate()
        {
            Sprite selectedSprite = null;

            switch (selection)
            {
                case Carcass.SkullLeft:
                    selectedSprite = skullLeft;
                    break;
                case Carcass.SkullRight:
                    selectedSprite = skullRight;
                    break;
                case Carcass.RibsLeft:
                    selectedSprite = ribsLeft;
                    break;
                case Carcass.RibsRight:
                    selectedSprite = ribsRight;
                    break;
            }
            GetComponent<SpriteRenderer>().sprite = selectedSprite;
        }


        private enum Carcass
        {
            SkullLeft,
            SkullRight,
            RibsLeft,
            RibsRight,
        }
    }
}