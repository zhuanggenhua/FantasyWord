using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Minifantasy.DeepCaves
{
    public class DC_Stalagmite_Large : MonoBehaviour
    {
        [Tooltip("Select a Prop Variant.")]
        [SerializeField] private Stalagmite stalagmiteSelection = Stalagmite.Stalagmite0;
        [SerializeField] private StalagmiteColor stalagmiteColorSelection = StalagmiteColor.Brown;

        [Header("Sprites")]
        [SerializeField] private Sprite brownLargeStalagmite0;
        [SerializeField] private Sprite brownLargeStalagmite1;
        [SerializeField] private Sprite brownLargeStalagmite2;
        [SerializeField] private Sprite yellowLargeStalagmite0;
        [SerializeField] private Sprite yellowLargeStalagmite1;
        [SerializeField] private Sprite yellowLargeStalagmite2;

        [Header("Shadows")]
        [SerializeField] private Sprite stalagmiteLarge0Shadow;
        [SerializeField] private Sprite stalagmiteLarge1Shadow;
        [SerializeField] private Sprite stalagmiteLarge2Shadow;

        private void OnValidate()
        {
            Sprite selectedSprite = null;
            Sprite selectedShadow = null;

            switch (stalagmiteSelection)
            {
                case Stalagmite.Stalagmite0:
                    switch (stalagmiteColorSelection)
                    {
                        case StalagmiteColor.Brown:
                            selectedSprite = brownLargeStalagmite0;
                            break;
                        case StalagmiteColor.Yellow:
                            selectedSprite = yellowLargeStalagmite0;
                            break;
                    }
                    selectedShadow = stalagmiteLarge0Shadow;
                    break;
                case Stalagmite.Stalagmite1:
                    switch (stalagmiteColorSelection)
                    {
                        case StalagmiteColor.Brown:
                            selectedSprite = brownLargeStalagmite1;
                            break;
                        case StalagmiteColor.Yellow:
                            selectedSprite = yellowLargeStalagmite1;
                            break;
                    }
                    selectedShadow = stalagmiteLarge1Shadow;
                    break;
                case Stalagmite.Stalagmite2:
                    switch (stalagmiteColorSelection)
                    {
                        case StalagmiteColor.Brown:
                            selectedSprite = brownLargeStalagmite2;
                            break;
                        case StalagmiteColor.Yellow:
                            selectedSprite = yellowLargeStalagmite2;
                            break;
                    }
                    selectedShadow = stalagmiteLarge2Shadow;
                    break;
            }
            GetComponent<SpriteRenderer>().sprite = selectedSprite;
            transform.Find("Shadow").GetComponent<SpriteRenderer>().sprite = selectedShadow;
        }

        private enum Stalagmite
        {
            Stalagmite0,
            Stalagmite1,
            Stalagmite2,
        }

        private enum StalagmiteColor
        {
            Brown,
            Yellow
        }
    }
}