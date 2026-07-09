using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Minifantasy.TownsI
{
    public class T1_Smokestack : MonoBehaviour
    {
        [Tooltip("Select a Prop Variant.")]
        [SerializeField] private SmokestackSelection selection = SmokestackSelection.Smokestack1;

        [Header("Sprites")]
        [SerializeField] private Sprite smokestack1;
        [SerializeField] private Sprite smokestack2;
        [SerializeField] private Sprite smokestack3;

        private void OnValidate()
        {
            Sprite selectedSprite = null;

            switch (selection)
            {
                case SmokestackSelection.Smokestack1:
                    selectedSprite = smokestack1;
                    break;
                case SmokestackSelection.Smokestack2:
                    selectedSprite = smokestack2;
                    break;
                case SmokestackSelection.Smokestack3:
                    selectedSprite = smokestack3;
                    break;
            }
            GetComponent<SpriteRenderer>().sprite = selectedSprite;
        }

        private enum SmokestackSelection
        {
            Smokestack1,
            Smokestack2,
            Smokestack3,
        }
    }
}