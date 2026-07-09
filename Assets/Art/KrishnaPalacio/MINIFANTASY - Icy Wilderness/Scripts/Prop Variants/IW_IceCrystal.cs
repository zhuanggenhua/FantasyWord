using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Minifantasy.IcyWilderness
{
    public class IW_IceCrystal : MonoBehaviour
    {
        [Tooltip("Select an Ice Sprite.")]
        [SerializeField] private IceCrystal selection = IceCrystal.IceCrystal_0;
        [SerializeField] private SnowTransition transitionSelection = SnowTransition.Transition;

        [Header("Sprites")]
        [SerializeField] private Sprite iceCrystal_0;
        [SerializeField] private Sprite iceCrystal_1;
        [SerializeField] private Sprite iceCrystal_2;
        [SerializeField] private Sprite iceCrystal_3;
        [SerializeField] private Sprite iceCrystal_4;

        [Header("Shadows")]
        [SerializeField] private Sprite iceCrystal_0_Shadow;
        [SerializeField] private Sprite iceCrystal_1_Shadow;
        [SerializeField] private Sprite iceCrystal_2_Shadow;
        [SerializeField] private Sprite iceCrystal_3_Shadow;
        [SerializeField] private Sprite iceCrystal_4_Shadow;

        [Header("Snow Transitions")]
        [SerializeField] private Sprite iceCrystal_0_SnowTransition;
        [SerializeField] private Sprite iceCrystal_1_SnowTransition;
        [SerializeField] private Sprite iceCrystal_2_SnowTransition;
        [SerializeField] private Sprite iceCrystal_3_SnowTransition;
        [SerializeField] private Sprite iceCrystal_4_SnowTransition;

        private void OnValidate()
        {
            Sprite selectedSprite = null;
            Sprite selectedShadow = null;
            Sprite selectedSnowTransition = null;

            switch (selection)
            {
                case IceCrystal.IceCrystal_0:
                    selectedSprite = iceCrystal_0;
                    selectedShadow = iceCrystal_0_Shadow;
                    selectedSnowTransition = iceCrystal_0_SnowTransition;
                    break;
                case IceCrystal.IceCrystal_1:
                    selectedSprite = iceCrystal_1;
                    selectedShadow = iceCrystal_1_Shadow;
                    selectedSnowTransition = iceCrystal_1_SnowTransition;
                    break;
                case IceCrystal.IceCrystal_2:
                    selectedSprite = iceCrystal_2;
                    selectedShadow = iceCrystal_2_Shadow;
                    selectedSnowTransition = iceCrystal_2_SnowTransition;
                    break;
                case IceCrystal.IceCrystal_3:
                    selectedSprite = iceCrystal_3;
                    selectedShadow = iceCrystal_3_Shadow;
                    selectedSnowTransition = iceCrystal_3_SnowTransition;
                    break;
                case IceCrystal.IceCrystal_4:
                    selectedSprite = iceCrystal_4;
                    selectedShadow = iceCrystal_4_Shadow;
                    selectedSnowTransition = iceCrystal_4_SnowTransition;
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

        private enum IceCrystal
        {
            IceCrystal_0,
            IceCrystal_1,
            IceCrystal_2,
            IceCrystal_3,
            IceCrystal_4,
        }

        private enum SnowTransition
        {
            NoTransition,
            Transition,
        }
    }
}