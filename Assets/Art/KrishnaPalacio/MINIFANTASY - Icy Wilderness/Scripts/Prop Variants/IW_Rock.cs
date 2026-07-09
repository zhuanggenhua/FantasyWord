using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Minifantasy.IcyWilderness
{
    public class IW_Rock : MonoBehaviour
    {
        [Tooltip("Select a Rock.")]
        [SerializeField] private Rock selection = Rock.Rock_0;
        [SerializeField] private SnowTransition transitionSelection = SnowTransition.Transition;

        [Header("Sprites")]
        [SerializeField] private Sprite rock_0;
        [SerializeField] private Sprite rock_1;
        [SerializeField] private Sprite rock_2;
        [SerializeField] private Sprite rock_3;
        [SerializeField] private Sprite rock_4;

        [Header("Shadows")]
        [SerializeField] private Sprite rock_0_Shadow;
        [SerializeField] private Sprite rock_1_Shadow;
        [SerializeField] private Sprite rock_2_Shadow;
        [SerializeField] private Sprite rock_3_Shadow;
        [SerializeField] private Sprite rock_4_Shadow;

        [Header("Snow Transitions")]
        [SerializeField] private Sprite rock_0_SnowTransition;
        [SerializeField] private Sprite rock_1_SnowTransition;
        [SerializeField] private Sprite rock_2_SnowTransition;
        [SerializeField] private Sprite rock_3_SnowTransition;
        [SerializeField] private Sprite rock_4_SnowTransition;

        private void OnValidate()
        {
            Sprite selectedSprite = null;
            Sprite selectedShadow = null;
            Sprite selectedSnowTransition = null;

            switch (selection)
            {
                case Rock.Rock_0:
                    selectedSprite = rock_0;
                    selectedShadow = rock_0_Shadow;
                    selectedSnowTransition = rock_0_SnowTransition;
                    break;
                case Rock.Rock_1:
                    selectedSprite = rock_1;
                    selectedShadow = rock_1_Shadow;
                    selectedSnowTransition = rock_1_SnowTransition;
                    break;
                case Rock.Rock_2:
                    selectedSprite = rock_2;
                    selectedShadow = rock_2_Shadow;
                    selectedSnowTransition = rock_2_SnowTransition;
                    break;
                case Rock.Rock_3:
                    selectedSprite = rock_3;
                    selectedShadow = rock_3_Shadow;
                    selectedSnowTransition = rock_3_SnowTransition;
                    break;
                case Rock.Rock_4:
                    selectedSprite = rock_4;
                    selectedShadow = rock_4_Shadow;
                    selectedSnowTransition = rock_4_SnowTransition;
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

        private enum Rock
        {
            Rock_0,
            Rock_1,
            Rock_2,
            Rock_3,
            Rock_4,
        }

        private enum SnowTransition
        {
            NoTransition,
            Transition,
        }
    }
}