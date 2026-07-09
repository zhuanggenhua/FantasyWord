using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Minifantasy.IcyWilderness
{
    public class IW_TreeBranch : MonoBehaviour
    {
        [Tooltip("Select a Tree Branch.")]
        [SerializeField] private TreeBranch selection = TreeBranch.TreeBranch_0;
        [SerializeField] private SnowTransition transitionSelection = SnowTransition.Transition;

        [Header("Sprites")]
        [SerializeField] private Sprite treeBranch_0;
        [SerializeField] private Sprite treeBranch_1;

        [Header("Shadows")]
        [SerializeField] private Sprite treeBranch_0_Shadow;
        [SerializeField] private Sprite treeBranch_1_Shadow;

        [Header("Snow Transitions")]
        [SerializeField] private Sprite treeBranch_0_SnowTransition;
        [SerializeField] private Sprite treeBranch_1_SnowTransition;

        private void OnValidate()
        {
            Sprite selectedSprite = null;
            Sprite selectedShadow = null;
            Sprite selectedSnowTransition = null;

            switch (selection)
            {
                case TreeBranch.TreeBranch_0:
                    selectedSprite = treeBranch_0;
                    selectedShadow = treeBranch_0_Shadow;
                    selectedSnowTransition = treeBranch_0_SnowTransition;
                    break;
                case TreeBranch.TreeBranch_1:
                    selectedSprite = treeBranch_1;
                    selectedShadow = treeBranch_1_Shadow;
                    selectedSnowTransition = treeBranch_1_SnowTransition;
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
            transform.Find("Snow Transition").GetComponent<SpriteRenderer>().sprite = selectedSnowTransition;
        }

        private enum TreeBranch
        {
            TreeBranch_0,
            TreeBranch_1,
        }
        private enum SnowTransition
        {
            NoTransition,
            Transition,
        }
    }
}