using System;
using UnityEngine;
using UnityEngine.U2D.Animation;
using azixMcAze.SerializableDictionary;

namespace FantasyWord.GameCore
{
    // Only represent half of the possible directions,
    // as the other half can be derived from these using symmetry (flipping sprite on X)
    enum EAnimationDirection
    {
        Up,
        UpRight,
        Right,
        DownRight,
        Down,
        DownLeft,
        Left,
        UpLeft
    }

    [Serializable]
    public struct AnimationDirectionOverride
    {
        public SpriteLibraryAsset spriteLibrary;
        public bool flipSprite;
        public float priority;
    }

    [Serializable]
    public class PolydirectionalAnimationStrategy : AAnimationStrategy
    {
        [Header("Polydirectional Animation Settings")]
        [SerializeField] protected SpriteLibrary m_spriteLibrary = null;
        [SerializeField] private SerializableDictionary<EAnimationDirection, AnimationDirectionOverride> m_animationDirectionOverrides = new();

        public override void Initialize()
        {
            base.Initialize();
            Debug.Assert(m_spriteRenderer, ErrorMessages.InspectorMissingComponentReference<SpriteLibrary>());
        }

        private AnimationDirectionOverride? GetAnimationOverride(Vector2 direction)
        {
            // Default to Top if the dictionary is empty
            if (m_animationDirectionOverrides.Count == 0)
            {
                return null;
            }

            // Normalize the direction to ensure consistency
            direction.Normalize();

            // Ignore the sign of direction.x
            float x = direction.x;
            float y = direction.y;

            // Thresholds for each direction
            EAnimationDirection bestDirection = EAnimationDirection.Up;
            float bestScore = float.MaxValue;
            float secondBestScore = float.MaxValue;
            EAnimationDirection secondBestDirection = EAnimationDirection.Up;

            foreach (var entry in m_animationDirectionOverrides)
            {
                Vector2 directionVector = DirectionToVector(entry.Key);
                float distance = Vector2.Distance(directionVector, new Vector2(x, y));

                if (distance < bestScore)
                {
                    secondBestScore = bestScore;
                    secondBestDirection = bestDirection;

                    bestScore = distance;
                    bestDirection = entry.Key;
                }
                else if (distance < secondBestScore)
                {
                    secondBestScore = distance;
                    secondBestDirection = entry.Key;
                }
            }

            // Check if the two closest directions are within epsilon
            if (Mathf.Abs(bestScore - secondBestScore) < Constants.Epsilon)
            {
                float highestPriority = m_animationDirectionOverrides[bestDirection].priority;
                float secondHighestPriority = m_animationDirectionOverrides[secondBestDirection].priority;

                // Choose the direction with the highest priority
                bestDirection = highestPriority >= secondHighestPriority ? bestDirection : secondBestDirection;
            }

            // Return the best-matched value
            return m_animationDirectionOverrides[bestDirection];
        }

        private Vector2 DirectionToVector(EAnimationDirection direction)
        {
            // Map each enum value to its corresponding normalized direction vector
            switch (direction)
            {
                case EAnimationDirection.Up: return Vector2.up;
                case EAnimationDirection.UpRight: return (Vector2.up + Vector2.right).normalized;
                case EAnimationDirection.Right: return Vector2.right;
                case EAnimationDirection.DownRight: return (Vector2.down + Vector2.right).normalized;
                case EAnimationDirection.Down: return Vector2.down;
                case EAnimationDirection.DownLeft: return (Vector2.down + Vector2.left).normalized;
                case EAnimationDirection.Left: return Vector2.left;
                case EAnimationDirection.UpLeft: return (Vector2.up + Vector2.left).normalized;
            }

            Debug.LogError("Invalid direction!");
            return Vector2.zero;
        }

        public override void SetLookAtDirection(Vector2 direction)
        {
            base.SetLookAtDirection(direction);

            if (m_spriteLibrary && m_animationDirectionOverrides.Count > 0)
            {
                AnimationDirectionOverride? animationDirectionOverride = GetAnimationOverride(direction);
                if (animationDirectionOverride != null)
                {
                    m_spriteLibrary.spriteLibraryAsset = animationDirectionOverride.Value.spriteLibrary;
                    m_spriteRenderer.flipX = animationDirectionOverride.Value.flipSprite;
                }
            }
        }
    }
}

