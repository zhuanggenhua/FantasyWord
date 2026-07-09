using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Minifantasy.IcyWilderness
{
    public class IW_Bush : MonoBehaviour
    {
        [Tooltip("Select a Bush Type.")]
        [SerializeField] private Bush selection = Bush.NoSnow;
        [SerializeField] private SnowTransition transitionSelection = SnowTransition.Transition;

        [Header("Sprites")]
        [SerializeField] private Sprite bush;
        [SerializeField] private Sprite snowBush;

        private void OnValidate()
        {
            Sprite selectedSprite = null;

            switch (selection)
            {
                case Bush.NoSnow:
                    selectedSprite = bush;
                    break;
                case Bush.Snow:
                    selectedSprite = snowBush;
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
        }

        private enum Bush
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