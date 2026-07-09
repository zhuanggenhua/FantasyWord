using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Minifantasy
{
    public class SetAnimatorParameterBasic : MonoBehaviour
    {
        private Animator animator;

        public string parameterName = "Idle";

        private void Start()
        {
            animator = GetComponentInChildren<Animator>();
            Invoke("ToggleAnimatorParameter", 0);
        }

        public void ToggleAnimatorParameter()
        {
            animator.SetBool(parameterName, true);
        }
    }
}