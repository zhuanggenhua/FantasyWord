using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Minifantasy.IcyWilderness
{
    public class IW_PineTree : MonoBehaviour
    {
        [Tooltip("Select an Ice Sprite.")]
        [SerializeField] private LeaningDirection leaningSelection = LeaningDirection.Left;
        [SerializeField] private SnowTransition transitionSelection = SnowTransition.Transition;
        [SerializeField] private Snow snowSelection = Snow.NoSnow;

        [Header("Sprites")]

        [SerializeField] private Sprite pine_Tree_Straight;
        [SerializeField] private Sprite pine_Tree_Straight_LightSnow;
        [SerializeField] private Sprite pine_Tree_Straight_HeavySnow;
        [SerializeField] private Sprite pine_Tree_Left;
        [SerializeField] private Sprite pine_Tree_Left_LightSnow;
        [SerializeField] private Sprite pine_Tree_Left_HeavySnow;
        [SerializeField] private Sprite pine_Tree_Right;
        [SerializeField] private Sprite pine_Tree_Right_LightSnow;
        [SerializeField] private Sprite pine_Tree_Right_HeavySnow;

        [Header("Shadows")]
        [SerializeField] private Sprite pine_Tree_Staight_Shadow;
        [SerializeField] private Sprite pine_Tree_Left_Shadow;
        [SerializeField] private Sprite pine_Tree_Right_Shadow;

        [Header("Snow Transitions")]
        [SerializeField] private Sprite pine_Tree_Straight_SnowTransition;
        [SerializeField] private Sprite pine_Tree_Left_SnowTransition;
        [SerializeField] private Sprite pine_Tree_Right_SnowTransition;

        private void OnValidate()
        {
            Sprite selectedSprite = null;
            Sprite selectedShadow = null;
            Sprite selectedSnowTransition = null;

            switch (snowSelection)
            {
                case Snow.NoSnow:
                    switch (leaningSelection)
                    {
                        case LeaningDirection.Left:
                            selectedSprite = pine_Tree_Left;
                            selectedShadow = pine_Tree_Left_Shadow;
                            selectedSnowTransition = pine_Tree_Left_SnowTransition;
                            break;
                        case LeaningDirection.Straight:
                            selectedSprite = pine_Tree_Straight;
                            selectedShadow = pine_Tree_Staight_Shadow;
                            selectedSnowTransition = pine_Tree_Straight_SnowTransition;
                            break;
                        case LeaningDirection.Right:
                            selectedSprite = pine_Tree_Right;
                            selectedShadow = pine_Tree_Right_Shadow;
                            selectedSnowTransition = pine_Tree_Right_SnowTransition;
                            break;
                    }
                    break;
                case Snow.LightSnow:
                    switch (leaningSelection)
                    {
                        case LeaningDirection.Left:
                            selectedSprite = pine_Tree_Left_LightSnow;
                            selectedShadow = pine_Tree_Left_Shadow;
                            selectedSnowTransition = pine_Tree_Left_SnowTransition;
                            break;
                        case LeaningDirection.Straight:
                            selectedSprite = pine_Tree_Straight_LightSnow;
                            selectedShadow = pine_Tree_Staight_Shadow;
                            selectedSnowTransition = pine_Tree_Straight_SnowTransition;
                            break;
                        case LeaningDirection.Right:
                            selectedSprite = pine_Tree_Right_LightSnow;
                            selectedShadow = pine_Tree_Right_Shadow;
                            selectedSnowTransition = pine_Tree_Right_SnowTransition;
                            break;
                    }
                    break;
                case Snow.HeavySnow:
                    switch (leaningSelection)
                    {
                        case LeaningDirection.Left:
                            selectedSprite = pine_Tree_Left_HeavySnow;
                            selectedShadow = pine_Tree_Left_Shadow;
                            selectedSnowTransition = pine_Tree_Left_SnowTransition;
                            break;
                        case LeaningDirection.Straight:
                            selectedSprite = pine_Tree_Straight_HeavySnow;
                            selectedShadow = pine_Tree_Staight_Shadow;
                            selectedSnowTransition = pine_Tree_Straight_SnowTransition;
                            break;
                        case LeaningDirection.Right:
                            selectedSprite = pine_Tree_Right_HeavySnow;
                            selectedShadow = pine_Tree_Right_Shadow;
                            selectedSnowTransition = pine_Tree_Right_SnowTransition;
                            break;
                    }
                    break;
            }

            switch (transitionSelection)
            {
                case SnowTransition.NoTransition:
                    transform.Find("Snow Transition").GetComponent<SpriteRenderer>().enabled = false;
                    break;
                case SnowTransition.Transition:
                    transform.Find("Snow Transition").GetComponent<SpriteRenderer>().enabled = true;
                    break;
            }

            GetComponent<SpriteRenderer>().sprite = selectedSprite;
            transform.Find("Shadow").GetComponent<SpriteRenderer>().sprite = selectedShadow;
            transform.Find("Snow Transition").GetComponent<SpriteRenderer>().sprite = selectedSnowTransition;
        }

        private enum LeaningDirection
        {
            Left,
            Straight,
            Right,
        }

        private enum Snow
        {
            NoSnow,
            LightSnow,
            HeavySnow,
        }

        private enum SnowTransition
        {
            NoTransition,
            Transition,
        }
    }
}