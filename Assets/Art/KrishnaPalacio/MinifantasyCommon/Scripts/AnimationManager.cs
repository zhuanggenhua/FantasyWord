using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Minifantasy
{
    public class AnimationManager : MonoBehaviour
    {
        [SerializeField] private List<Animator> animators = new List<Animator>();
        private string lastAnimationName;

        // still need a way to check if the anim parameter exists and continue the loop

        public void SetAnimationParamaters(string animationName)
        {
            ResetAnimationParameters();
            foreach (Animator animator in animators)
            {
                foreach (AnimatorControllerParameter parameter in animator.parameters)
                {
                    if (parameter.name == animationName) { animator.SetBool(animationName, true); }
                }
            }
            lastAnimationName = animationName;
        }

        private void ResetAnimationParameters()
        {
            foreach (Animator animator in animators)
            {
                foreach (AnimatorControllerParameter parameter in animator.parameters)
                {
                    if (parameter.name == lastAnimationName) { animator.SetBool(lastAnimationName, false); }
                }
            }
        }

        public void ToggleXDirection(float x)
        {
            foreach (Animator animator in animators)
            {
                foreach (AnimatorControllerParameter parameter in animator.parameters)
                {
                    if (parameter.name == "X") { animator.SetFloat("X", x); }
                }
            }
        }
        public void ToggleYDirection(float y)
        {
            foreach (Animator animator in animators)
            {
                foreach (AnimatorControllerParameter parameter in animator.parameters)
                {
                    if (parameter.name == "Y") { animator.SetFloat("Y", y); }
                }
            }
        }
    }
}