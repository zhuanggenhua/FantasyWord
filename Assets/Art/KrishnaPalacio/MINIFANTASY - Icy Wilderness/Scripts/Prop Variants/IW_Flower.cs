using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Minifantasy.IcyWilderness
{
    public class IW_Flower : MonoBehaviour
    {
        [Tooltip("Select a Flower.")]
        [SerializeField] private Flower selection = Flower.Pink;
        [SerializeField] private SnowTransition transitionSelection = SnowTransition.Transition;

        [Header("Sprites")]
        [SerializeField] private Sprite pinkFlower;
        [SerializeField] private Sprite redFlower;

        [Header("Snow Transitions")]
        [SerializeField] private Sprite pinkFlowerSnowTransition;
        [SerializeField] private Sprite redFlowerSnowTransition;

        private void OnValidate()
        {
            Sprite selectedSprite = null;
            Sprite selectedSnowTransition = null;

            switch (selection)
            {
                case Flower.Pink:
                    selectedSprite = pinkFlower;
                    selectedSnowTransition = pinkFlowerSnowTransition;
                    break;
                case Flower.Red:
                    selectedSprite = redFlower;
                    selectedSnowTransition = redFlowerSnowTransition;
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
            transform.Find("Snow Transition").GetComponent<SpriteRenderer>().sprite = selectedSnowTransition;
        }

        private enum Flower
        {
            Pink,
            Red,
        }

        private enum SnowTransition
        {
            NoTransition,
            Transition,
        }
    }
}