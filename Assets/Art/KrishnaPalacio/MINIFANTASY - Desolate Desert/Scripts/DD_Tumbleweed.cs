using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Minifantasy.DesolateDesert
{
    public class DD_Tumbleweed : MonoBehaviour
    {
        [SerializeField] private float speed = 2.5f;

        void Update()
        {
            MoveRight();
        }

        void MoveRight()
        {
            transform.Translate(Vector3.right * Time.deltaTime * speed);
        }
    }
}