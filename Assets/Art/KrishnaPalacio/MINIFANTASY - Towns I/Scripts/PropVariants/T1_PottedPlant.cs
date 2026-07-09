using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Minifantasy.TownsI
{
    public class T1_PottedPlant : MonoBehaviour
    {
        [Tooltip("Select a Prop Variant.")]
        [SerializeField] private PottedPlantSelection selection = PottedPlantSelection.PottedPlant1;

        [Header("Sprites")]
        [SerializeField] private Sprite pottedPlant1;
        [SerializeField] private Sprite pottedPlant2;
        [SerializeField] private Sprite pottedPlant3;

        [Header("Shadows")]
        [SerializeField] private Sprite shadowPottedPlant1;
        [SerializeField] private Sprite shadowPottedPlant2;
        [SerializeField] private Sprite shadowPottedPlant3;

        private void OnValidate()
        {
            Sprite selectedSprite = null;
            Sprite selectedShadow = null;

            switch (selection)
            {
                case PottedPlantSelection.PottedPlant1:
                    selectedSprite = pottedPlant1;
                    selectedShadow = shadowPottedPlant1;
                    break;
                case PottedPlantSelection.PottedPlant2:
                    selectedSprite = pottedPlant2;
                    selectedShadow = shadowPottedPlant2;
                    break;
                case PottedPlantSelection.PottedPlant3:
                    selectedSprite = pottedPlant3;
                    selectedShadow = shadowPottedPlant3;
                    break;
            }
            GetComponent<SpriteRenderer>().sprite = selectedSprite;
            transform.Find("Shadow").GetComponent<SpriteRenderer>().sprite = selectedShadow;
        }

        private enum PottedPlantSelection
        {
            PottedPlant1,
            PottedPlant2,
            PottedPlant3,
        }
    }
}