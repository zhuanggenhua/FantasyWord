using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Minifantasy.IcyWilderness
{
    public class IW_Snowman : MonoBehaviour
    {
        [Tooltip("Select a Snowman.")]
        [SerializeField] private Snowman selection = Snowman.Snowman;
        [SerializeField] private SnowTransition transitionSelection = SnowTransition.Transition;

        [Header("Sprites")]
        [SerializeField] private Sprite snowman;
        [SerializeField] private Sprite snowman_arms;
        [SerializeField] private Sprite snowman_arms_hat;
        [SerializeField] private Sprite snowman_arms_nose;
        [SerializeField] private Sprite snowman_arms_nose_hat;
        [SerializeField] private Sprite snowman_hat;
        [SerializeField] private Sprite snowman_nose;
        [SerializeField] private Sprite snowman_nose_hat;

        [Header("Shadows")]
        [SerializeField] private Sprite snowman_Shadow;
        [SerializeField] private Sprite snowman_arms_Shadow;
        [SerializeField] private Sprite snowman_arms_hat_Shadow;
        [SerializeField] private Sprite snowman_arms_nose_Shadow;
        [SerializeField] private Sprite snowman_arms_nose_hat_Shadow;
        [SerializeField] private Sprite snowman_hat_Shadow;
        [SerializeField] private Sprite snowman_nose_Shadow;
        [SerializeField] private Sprite snowman_nose_hat_Shadow;

        [Header("Snow Transitions")]
        [SerializeField] private Sprite snowman_SnowTransition;
        [SerializeField] private Sprite snowman_hat_SnowTransition;
        [SerializeField] private Sprite snowman_hat_arms_SnowTransition;

        private void OnValidate()
        {
            Sprite selectedSprite = null;
            Sprite selectedShadow = null;
            Sprite selectedSnowTransition = null;

            switch (selection)
            {
                case Snowman.Snowman:
                    selectedSprite = snowman;
                    selectedShadow = snowman_Shadow;
                    selectedSnowTransition = snowman_SnowTransition;
                    break;
                case Snowman.Snowman_Arms:
                    selectedSprite = snowman_arms;
                    selectedShadow = snowman_arms_Shadow;
                    selectedSnowTransition = snowman_SnowTransition;
                    break;
                case Snowman.Snowman_Arms_Hat:
                    selectedSprite = snowman_arms_hat;
                    selectedShadow = snowman_arms_hat_Shadow;
                    selectedSnowTransition = snowman_hat_arms_SnowTransition;
                    break;
                case Snowman.Snowman_Arms_Nose:
                    selectedSprite = snowman_arms_nose;
                    selectedShadow = snowman_arms_nose_Shadow;
                    selectedSnowTransition = snowman_SnowTransition;
                    break;
                case Snowman.Snowman_Arms_Nose_Hat:
                    selectedSprite = snowman_arms_nose_hat;
                    selectedShadow = snowman_arms_nose_hat_Shadow;
                    selectedSnowTransition = snowman_hat_arms_SnowTransition;
                    break;
                case Snowman.Snowman_Hat:
                    selectedSprite = snowman_hat;
                    selectedShadow = snowman_hat_Shadow;
                    selectedSnowTransition = snowman_hat_SnowTransition;
                    break;
                case Snowman.Snowman_Nose:
                    selectedSprite = snowman_nose;
                    selectedShadow = snowman_nose_Shadow;
                    selectedSnowTransition = snowman_SnowTransition;
                    break;
                case Snowman.Snowman_Nose_Hat:
                    selectedSprite = snowman_nose_hat;
                    selectedShadow = snowman_nose_hat_Shadow;
                    selectedSnowTransition = snowman_hat_SnowTransition;
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

        private enum Snowman
        {
            Snowman,
            Snowman_Arms,
            Snowman_Arms_Hat,
            Snowman_Arms_Nose,
            Snowman_Arms_Nose_Hat,
            Snowman_Hat,
            Snowman_Nose,
            Snowman_Nose_Hat,
        }

        private enum SnowTransition
        {
            NoTransition,
            Transition,
        }
    }
}