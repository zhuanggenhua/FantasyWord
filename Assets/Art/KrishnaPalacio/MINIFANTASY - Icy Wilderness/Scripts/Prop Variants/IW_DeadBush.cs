using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Minifantasy.IcyWilderness
{
    public class IW_DeadBush : MonoBehaviour
    {
        [Tooltip("Select a Bush Type.")]
        [SerializeField] private DeadBush selection = DeadBush.NoSnow;
        [SerializeField] private SnowTransition transitionSelection = SnowTransition.Transition;

        [Header("Sprites")]
        [SerializeField] private Sprite deadBush;
        [SerializeField] private Sprite snowDeadBush;

        [Header("Shadows")]
        [SerializeField] private Sprite deadBushShadow;
        [SerializeField] private Sprite snowDeadBushShadow;

        private void OnValidate()
        {
            Sprite selectedSprite = null;
            Sprite selectedShadow = null;

            switch (selection)
            {
                case DeadBush.NoSnow:
                    selectedSprite = deadBush;
                    selectedShadow = deadBushShadow;
                    break;
                case DeadBush.Snow:
                    selectedSprite = snowDeadBush;
                    selectedShadow = snowDeadBushShadow;
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
        }

        private enum DeadBush
        {
            NoSnow,
            Snow,
        }

        private enum SnowTransition
        {
            NoTransition,
            Transition,
        }
    }
}