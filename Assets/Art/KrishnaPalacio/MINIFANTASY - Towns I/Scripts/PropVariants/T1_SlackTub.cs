using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Minifantasy.TownsI
{
    public class T1_SlackTub : MonoBehaviour
    {
        [Tooltip("Select a Prop Variant.")]
        [SerializeField] private SlackTubSelection selection = SlackTubSelection.SlackTubVertical;

        [Header("Sprites")]
        [SerializeField] private Sprite slackTubVertical;
        [SerializeField] private Sprite slackTubHorizontal;

        [Header("Shadows")]
        [SerializeField] private Sprite shadowSlackTubVertical;
        [SerializeField] private Sprite shadowSlackTubHorizontal;

        private void OnValidate()
        {
            Sprite selectedSprite = null;
            Sprite selectedShadow = null;

            switch (selection)
            {
                case SlackTubSelection.SlackTubVertical:
                    selectedSprite = slackTubVertical;
                    selectedShadow = shadowSlackTubVertical;
                    break;
                case SlackTubSelection.SlackTubHorizontal:
                    selectedSprite = slackTubHorizontal;
                    selectedShadow = shadowSlackTubHorizontal;
                    break;
            }
            GetComponent<SpriteRenderer>().sprite = selectedSprite;
            transform.Find("Shadow").GetComponent<SpriteRenderer>().sprite = selectedShadow;
        }

        private enum SlackTubSelection
        {
            SlackTubVertical,
            SlackTubHorizontal,
        }
    }
}