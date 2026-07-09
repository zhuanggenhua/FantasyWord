using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Minifantasy.DesolateDesert
{
    public class DD_StandardCactus : MonoBehaviour
    {
        [Tooltip("Select a Cactus Type.")]
        [SerializeField] private Cactus selection = Cactus.Small1;

        [Header("Sprites")]
        [SerializeField] private Sprite cactusSmall1;
        [SerializeField] private Sprite cactusSmall2;
        [SerializeField] private Sprite cactusSmall3;
        [SerializeField] private Sprite cactusLarge1;
        [SerializeField] private Sprite cactusLarge2;

        [Header("Shadows")]
        [SerializeField] private Sprite cactusSmall1Shadow;
        [SerializeField] private Sprite cactusSmall2Shadow;
        [SerializeField] private Sprite cactusSmall3Shadow;
        [SerializeField] private Sprite cactusLarge1Shadow;
        [SerializeField] private Sprite cactusLarge2Shadow;

        private void OnValidate()
        {
            Sprite selectedSprite = null;
            Sprite selectedShadow = null;

            switch (selection)
            {
                case Cactus.Small1:
                    selectedSprite = cactusSmall1;
                    selectedShadow = cactusSmall1Shadow;
                    break;
                case Cactus.Small2:
                    selectedSprite = cactusSmall2;
                    selectedShadow = cactusSmall2Shadow;
                    break;
                case Cactus.Small3:
                    selectedSprite = cactusSmall3;
                    selectedShadow = cactusSmall3Shadow;
                    break;
                case Cactus.Large1:
                    selectedSprite = cactusLarge1;
                    selectedShadow = cactusLarge1Shadow;
                    break;
                case Cactus.Large2:
                    selectedSprite = cactusLarge2;
                    selectedShadow = cactusLarge2Shadow;
                    break;
            }
            GetComponent<SpriteRenderer>().sprite = selectedSprite;
            transform.Find("Shadow").GetComponent<SpriteRenderer>().sprite = selectedShadow;
        }

        private enum Cactus
        {
            Small1,
            Small2,
            Small3,
            Large1,
            Large2,
        }
    }
}