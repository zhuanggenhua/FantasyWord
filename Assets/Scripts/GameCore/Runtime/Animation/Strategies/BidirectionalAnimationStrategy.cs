using System;
using UnityEngine;
using UnityEngine.Scripting.APIUpdating;

namespace FantasyWord.GameCore
{
    public enum EBidrectionalAnimationDirection
    {
        Right,
        Left
    }

    [MovedFrom(true, "FantasyWord.GameCore.Strategies", "FantasyWord.GameCore", null)]
    [Serializable]
    public class BidirectionalAnimationStrategy : AAnimationStrategy
    {
        [Header("Bidirectional Animation Settings")]
        [SerializeField] private EBidrectionalAnimationDirection m_defaultDirection = EBidrectionalAnimationDirection.Right;

        public override void SetLookAtDirection(Vector2 direction)
        {
            base.SetLookAtDirection(direction);

            if (m_spriteRenderer && direction.x != 0.0f)
            {
                m_spriteRenderer.flipX =
                    m_defaultDirection == EBidrectionalAnimationDirection.Right ?
                    direction.x < 0.0f :
                    direction.x > 0.0f;
            }
        }
    }
}
