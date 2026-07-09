using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Minifantasy.TownsI
{
    public class T1_Sign : MonoBehaviour
    {
        [Tooltip("Select a Prop Variant.")]
        [SerializeField] private SignSelection selection = SignSelection.Sign1;

        [Header("Sprites")]
        [SerializeField] private Sprite Sign1;
        [SerializeField] private Sprite Sign2;

        [Header("Shadows")]
        [SerializeField] private Sprite shadowSign1;
        [SerializeField] private Sprite shadowSign2;

        private void OnValidate()
        {
            Sprite selectedSprite = null;
            Sprite selectedShadow = null;

            switch (selection)
            {
                case SignSelection.Sign1:
                    selectedSprite = Sign1;
                    selectedShadow = shadowSign1;
                    break;
                case SignSelection.Sign2:
                    selectedSprite = Sign2;
                    selectedShadow = shadowSign2;
                    break;
            }
            GetComponent<SpriteRenderer>().sprite = selectedSprite;
            transform.Find("Shadow").GetComponent<SpriteRenderer>().sprite = selectedShadow;
        }

        private enum SignSelection
        {
            Sign1,
            Sign2,
        }
    }
}