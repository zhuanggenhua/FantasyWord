using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Minifantasy.TownsI
{
    public class T1_Chimney : MonoBehaviour
    {
        [Tooltip("Select a Prop Variant.\nBased on roof position.")]
        [SerializeField] private ChimneySelection selection = ChimneySelection.Left;

        [Header("Sprites")]
        [SerializeField] private Sprite chimney1;
        [SerializeField] private Sprite chimney2;
        [SerializeField] private Sprite chimney3;

        private void OnValidate()
        {
            Sprite selectedSprite = null;

            switch (selection)
            {
                case ChimneySelection.Left:
                    selectedSprite = chimney1;
                    break;
                case ChimneySelection.Right:
                    selectedSprite = chimney2;
                    break;
                case ChimneySelection.Flat:
                    selectedSprite = chimney3;
                    break;
            }
            GetComponent<SpriteRenderer>().sprite = selectedSprite;
        }

        private enum ChimneySelection
        {
            Left,
            Right,
            Flat,
        }
    }
}