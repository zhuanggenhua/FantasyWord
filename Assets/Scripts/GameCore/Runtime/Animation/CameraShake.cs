using Unity.Mathematics;
using UnityEngine;
using YokiFrame;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 镜头震动表现入口。
    /// 当前只消费 GameCore 正式反馈门面广播出的受击上下文，不再直接监听全局伤害通知来反推业务语义。
    /// </summary>
    public class CameraShake : MonoBehaviour
    {
        [Header("Settings")]
        [SerializeField] private float m_amplitude = 0.05f;
        [SerializeField] private float2 m_frequency = new(60.0f, 50.0f);
        [SerializeField] private float m_duration = 0.2f;
        [SerializeField] private float m_criticalHitAmplitudeModifier = 2.0f;

        private ShakeHandler? m_shakeHandler = null;

        private void OnEnable()
        {
            EventKit.Type.Register<DamageTakenPresentationEvent>(OnDamageTakenPresentation);
        }

        private void OnDisable()
        {
            EventKit.Type.UnRegister<DamageTakenPresentationEvent>(OnDamageTakenPresentation);
        }

        private bool IsCameraAllowedToShake()
        {
            return GameManager.Config.cameraShakeSources != ECameraShakeSources.None;
        }

        private bool IsValidShakeSource(DamageTakenFeedbackContext context)
        {
            CharacterBase currentControlledCharacter = GameManager.PlayerSystem.GetCurrentControlledCharacterOrPlayerInstance();

            return !context.damageInput.silent && (
                (
                    GameManager.Config.cameraShakeSources.HasFlag(ECameraShakeSources.PlayerReceiveDamage) &&
                    context.target == currentControlledCharacter
                )
                ||
                (
                    GameManager.Config.cameraShakeSources.HasFlag(ECameraShakeSources.AnyCharacterReceiveDamageFromPlayer) &&
                    context.sourceCharacter == currentControlledCharacter
                ));
        }

        private void OnDamageTakenPresentation(DamageTakenPresentationEvent presentationEvent)
        {
            DamageTakenFeedbackContext context = presentationEvent.Context;

            if (IsCameraAllowedToShake() && IsValidShakeSource(context) && !context.visualFlags.HasFlag(EEffectVisualFlags.NoCameraShake))
            {
                if (!context.damageInput.IsMissed)
                {
                    if (m_shakeHandler.HasValue)
                    {
                        TransformShaker.InterruptShakeIfInProgress(m_shakeHandler.Value);
                        m_shakeHandler = null;
                    }

                    bool isCriticalHit = context.damageInput.IsCriticalHit;
                    float amplitude = isCriticalHit ? m_amplitude * m_criticalHitAmplitudeModifier : m_amplitude;
                    transform.localPosition = new Vector3(0.0f, 0.0f, transform.localPosition.z);
                    m_shakeHandler = TransformShaker.Shake(transform, amplitude, m_frequency, m_duration);
                }
            }
        }
    }
}

