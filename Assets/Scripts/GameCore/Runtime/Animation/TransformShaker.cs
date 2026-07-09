using System.Collections;
using Unity.Mathematics;
using UnityEngine;

namespace FantasyWord.GameCore
{
    public readonly struct ShakeHandler
    {
        private readonly Transform m_target;
        private readonly Vector3 m_initialPosition;
        private readonly Coroutine m_coroutine;

        internal ShakeHandler(Transform target, Vector3 initialPosition, Coroutine coroutine)
        {
            m_target = target;
            m_initialPosition = initialPosition;
            m_coroutine = coroutine;
        }

        internal Transform Target => m_target;
        internal Vector3 InitialPosition => m_initialPosition;
        internal Coroutine Coroutine => m_coroutine;
    }

    public static class TransformShaker
    {
        public static ShakeHandler Shake(Transform target, float amplitude, float2 frequency, float duration)
        {
            return new ShakeHandler(
                target,
                target.localPosition,
                GameManager.Instance.StartCoroutine(
                    ShakeCoroutine(target, amplitude, frequency, duration)
                ));
        }

        public static bool InterruptShakeIfInProgress(ShakeHandler handler)
        {
            if (handler.Coroutine != null)
            {
                GameManager.Instance.StopCoroutine(handler.Coroutine);

                if (handler.Target)
                {
                    handler.Target.localPosition = handler.InitialPosition;
                }

                return true;
            }

            return false;
        }

        private static IEnumerator ShakeCoroutine(Transform target, float amplitude, float2 frequency, float duration)
        {
            float elapsedTime = 0f;
            Vector3 initialPosition = target.localPosition;

            while (elapsedTime < duration)
            {
                float2 offset = math.sin(frequency * elapsedTime) * amplitude;
                target.localPosition = new(initialPosition.x + offset.x, initialPosition.y + offset.y, initialPosition.z);
                elapsedTime += Time.deltaTime;
                yield return null;
            }

            target.localPosition = initialPosition;
        }
    }
}

