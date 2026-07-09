using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Minifantasy.DeepCaves
{
    public class DC_Stalagmite_Small : MonoBehaviour
    {
        [Tooltip("Select a Prop Variant.")]
        [SerializeField] private Stalagmite stalagmiteSelection = Stalagmite.Stalagmite0;
        [SerializeField] private StalagmiteColor stalagmiteColorSelection = StalagmiteColor.Brown;

        [Header("Sprites")]
        [SerializeField] private Sprite brownSmallStalagmite0;
        [SerializeField] private Sprite brownSmallStalagmite1;
        [SerializeField] private Sprite yellowSmallStalagmite0;
        [SerializeField] private Sprite yellowSmallStalagmite1;

        [Header("Shadows")]
        [SerializeField] private Sprite stalagmiteSmall0Shadow;
        [SerializeField] private Sprite stalagmiteSmall1Shadow;

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
                            selectedSprite = brownSmallStalagmite0;
                            break;
                        case StalagmiteColor.Yellow:
                            selectedSprite = yellowSmallStalagmite0;
                            break;
                    }
                    selectedShadow = stalagmiteSmall0Shadow;
                    break;
                case Stalagmite.Stalagmite1:
                    switch (stalagmiteColorSelection)
                    {
                        case StalagmiteColor.Brown:
                            selectedSprite = brownSmallStalagmite1;
                            break;
                        case StalagmiteColor.Yellow:
                            selectedSprite = yellowSmallStalagmite1;
                            break;
                    }
                    selectedShadow = stalagmiteSmall1Shadow;
                    break;
            }
            GetComponent<SpriteRenderer>().sprite = selectedSprite;
            transform.Find("Shadow").GetComponent<SpriteRenderer>().sprite = selectedShadow;
        }

        private enum Stalagmite
        {
            Stalagmite0,
            Stalagmite1,
        }

        private enum StalagmiteColor
        {
            Brown,
            Yellow
        }
    }
}