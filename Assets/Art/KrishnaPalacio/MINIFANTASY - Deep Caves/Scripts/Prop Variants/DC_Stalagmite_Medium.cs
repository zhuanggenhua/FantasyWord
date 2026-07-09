using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Minifantasy.DeepCaves
{
    public class DC_Stalagmite_Medium : MonoBehaviour
    {
        [Tooltip("Select a Prop Variant.")]
        [SerializeField] private Stalagmite stalagmiteSelection = Stalagmite.Stalagmite0;
        [SerializeField] private StalagmiteColor stalagmiteColorSelection = StalagmiteColor.Brown;

        [Header("Sprites")]
        [SerializeField] private Sprite brownMediumStalagmite0;
        [SerializeField] private Sprite brownMediumStalagmite1;
        [SerializeField] private Sprite brownMediumStalagmite2;
        [SerializeField] private Sprite yellowMediumStalagmite0;
        [SerializeField] private Sprite yellowMediumStalagmite1;
        [SerializeField] private Sprite yellowMediumStalagmite2;

        [Header("Shadows")]
        [SerializeField] private Sprite stalagmiteMedium0Shadow;
        [SerializeField] private Sprite stalagmiteMedium1Shadow;
        [SerializeField] private Sprite stalagmiteMedium2Shadow;

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
                            selectedSprite = brownMediumStalagmite0;
                            break;
                        case StalagmiteColor.Yellow:
                            selectedSprite = yellowMediumStalagmite0;
                            break;
                    }
                    selectedShadow = stalagmiteMedium0Shadow;
                    break;
                case Stalagmite.Stalagmite1:
                    switch (stalagmiteColorSelection)
                    {
                        case StalagmiteColor.Brown:
                            selectedSprite = brownMediumStalagmite1;
                            break;
                        case StalagmiteColor.Yellow:
                            selectedSprite = yellowMediumStalagmite1;
                            break;
                    }
                    selectedShadow = stalagmiteMedium1Shadow;
                    break;
                case Stalagmite.Stalagmite2:
                    switch (stalagmiteColorSelection)
                    {
                        case StalagmiteColor.Brown:
                            selectedSprite = brownMediumStalagmite2;
                            break;
                        case StalagmiteColor.Yellow:
                            selectedSprite = yellowMediumStalagmite2;
                            break;
                    }
                    selectedShadow = stalagmiteMedium2Shadow;
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