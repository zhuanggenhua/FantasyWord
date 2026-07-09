using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Minifantasy.DesolateDesert
{
    public class DD_Rock : MonoBehaviour
    {
        [Tooltip("Select a Prop Variant.")]
        [SerializeField] private Rock selection = Rock.Small1;

        [Header("Sprites")]
        [SerializeField] private Sprite small1;
        [SerializeField] private Sprite small2;
        [SerializeField] private Sprite small3;
        [SerializeField] private Sprite large1;
        [SerializeField] private Sprite large2;

        [Header("Shadows")]
        [SerializeField] private Sprite small1Shadow;
        [SerializeField] private Sprite small2Shadow;
        [SerializeField] private Sprite small3Shadow;
        [SerializeField] private Sprite large1Shadow;
        [SerializeField] private Sprite large2Shadow;

        private void OnValidate()
        {
            Sprite selectedSprite = null;
            Sprite selectedShadow = null;

            switch (selection)
            {
                case Rock.Small1:
                    selectedSprite = small1;
                    selectedShadow = small1Shadow;
                    break;
                case Rock.Small2:
                    selectedSprite = small2;
                    selectedShadow = small2Shadow;
                    break;
                case Rock.Small3:
                    selectedSprite = small3;
                    selectedShadow = small3Shadow;
                    break;
                case Rock.Large1:
                    selectedSprite = large1;
                    selectedShadow = large1Shadow;
                    break;
                case Rock.Large2:
                    selectedSprite = large2;
                    selectedShadow = large2Shadow;
                    break;
            }
            GetComponent<SpriteRenderer>().sprite = selectedSprite;
            transform.Find("Shadow").GetComponent<SpriteRenderer>().sprite = selectedShadow;
        }


        private enum Rock
        {
            Small1,
            Small2,
            Small3,
            Large1,
            Large2
        }
    }
}