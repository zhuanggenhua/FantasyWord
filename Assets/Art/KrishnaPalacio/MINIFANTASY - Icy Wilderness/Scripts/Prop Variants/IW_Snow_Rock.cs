using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Minifantasy.IcyWilderness
{
    public class IW_Snow_Rock : MonoBehaviour
    {
        [Tooltip("Select a Rock.")]
        [SerializeField] private Rock selection = Rock.SnowRock_0;
        [SerializeField] private SnowTransition transitionSelection = SnowTransition.Transition;

        [Header("Sprites")]
        [SerializeField] private Sprite snowRock_0;
        [SerializeField] private Sprite snowRock_1;
        [SerializeField] private Sprite snowRock_2;
        [SerializeField] private Sprite snowRock_3;
        [SerializeField] private Sprite snowRock_4;

        [Header("Shadows")]
        [SerializeField] private Sprite snowRock_0_Shadow;
        [SerializeField] private Sprite snowRock_1_Shadow;
        [SerializeField] private Sprite snowRock_2_Shadow;
        [SerializeField] private Sprite snowRock_3_Shadow;
        [SerializeField] private Sprite snowRock_4_Shadow;

        [Header("Snow Transitions")]
        [SerializeField] private Sprite snowRock_0_SnowTransition;
        [SerializeField] private Sprite snowRock_1_SnowTransition;
        [SerializeField] private Sprite snowRock_2_SnowTransition;
        [SerializeField] private Sprite snowRock_3_SnowTransition;
        [SerializeField] private Sprite snowRock_4_SnowTransition;

        private void OnValidate()
        {
            Sprite selectedSprite = null;
            Sprite selectedShadow = null;
            Sprite selectedSnowTransition = null;

            switch (selection)
            {
                case Rock.SnowRock_0:
                    selectedSprite = snowRock_0;
                    selectedShadow = snowRock_0_Shadow;
                    selectedSnowTransition = snowRock_0_SnowTransition;
                    break;
                case Rock.SnowRock_1:
                    selectedSprite = snowRock_1;
                    selectedShadow = snowRock_1_Shadow;
                    selectedSnowTransition = snowRock_1_SnowTransition;
                    break;
                case Rock.SnowRock_2:
                    selectedSprite = snowRock_2;
                    selectedShadow = snowRock_2_Shadow;
                    selectedSnowTransition = snowRock_2_SnowTransition;
                    break;
                case Rock.SnowRock_3:
                    selectedSprite = snowRock_3;
                    selectedShadow = snowRock_3_Shadow;
                    selectedSnowTransition = snowRock_3_SnowTransition;
                    break;
                case Rock.SnowRock_4:
                    selectedSprite = snowRock_4;
                    selectedShadow = snowRock_4_Shadow;
                    selectedSnowTransition = snowRock_4_SnowTransition;
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
            SnowRock_0,
            SnowRock_1,
            SnowRock_2,
            SnowRock_3,
            SnowRock_4,
        }

        private enum SnowTransition
        {
            NoTransition,
            Transition,
        }
    }
}