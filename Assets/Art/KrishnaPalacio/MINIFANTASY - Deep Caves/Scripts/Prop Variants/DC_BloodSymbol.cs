using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Minifantasy.DeepCaves
{
    public class DC_BloodSymbol : MonoBehaviour
    {
        [Tooltip("Select a Prop Variant.")]
        [SerializeField] private BloodSymbol bloodSymbolSelection = BloodSymbol.Pentagram;

        [Header("Sprites")]
        [SerializeField] private Sprite bloodSymbol0;
        [SerializeField] private Sprite bloodSymbol1;
        [SerializeField] private Sprite bloodSymbol2;

        private void OnValidate()
        {
            Sprite selectedSprite = null;

            switch (bloodSymbolSelection)
            {
                case BloodSymbol.Pentagram:
                    selectedSprite = bloodSymbol0;
                    break;
                case BloodSymbol.RitualisticCircle:
                    selectedSprite = bloodSymbol1;
                    break;
                case BloodSymbol.Circle:
                    selectedSprite = bloodSymbol2;
                    break;
            }
            GetComponent<SpriteRenderer>().sprite = selectedSprite;
        }

        private enum BloodSymbol
        {
            Pentagram,
            RitualisticCircle,
            Circle
        }
    }
}