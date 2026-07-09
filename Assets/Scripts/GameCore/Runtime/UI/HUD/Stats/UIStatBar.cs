using TMPro;
using Unity.Mathematics;
using UnityEngine;
using UnityEngine.UI;

namespace FantasyWord.GameCore
{
    public class UIStatBar : MonoBehaviour
    {
        [Header("References")]
        [SerializeField] private TextMeshProUGUI m_label = null;
        [SerializeField] private Slider m_slider = null;
        [SerializeField] private TextMeshProUGUI m_sliderText = null;
        [Tooltip("留空时跟随当前控制角色；只有明确指定时，才固定显示某个角色的数值。")]
        [SerializeField] private CharacterBase m_target = null;

        [Header("General Settings")]
        [SerializeField] private EStat m_stat;

        [Header("Visual Settings")]
        [SerializeField] private bool m_shakeOnDecrease = false;
        [SerializeField] private float m_shakeAmplitude = 5.0f;
        [SerializeField] private float2 m_shakeFrequency = new(30.0f, 25.0f);
        [SerializeField] private float m_shakeDuration = 0.2f;

        private ShakeHandler? m_shakeHandler = null;
        private bool m_followCurrentControlledCharacter = false;
        private bool m_hasDisplayedBoundValue = false;

        private void Awake()
        {
            m_followCurrentControlledCharacter = m_target == null;
        }

        private void Start()
        {
            if (m_followCurrentControlledCharacter)
            {
                GameManager.PlayerSystem.AddCurrentControlledCharacterChangedListener(OnCurrentControlledCharacterChanged);
                OnCurrentControlledCharacterChanged(GameManager.PlayerSystem.GetCurrentControlledCharacterOrPlayerInstance());
            }
            else
            {
                CharacterBase configuredTarget = m_target;
                m_target = null;
                BindTarget(configuredTarget);
            }

        }

        private void OnStatsChanged(Stats previous)
        {
            UpdateUI();
        }

        private void OnDestroy()
        {
            if (m_followCurrentControlledCharacter && GameManager.Exists() && GameManager.HasSystem<PlayerSystem>())
            {
                GameManager.PlayerSystem.RemoveCurrentControlledCharacterChangedListener(OnCurrentControlledCharacterChanged);
            }

            UnbindTarget();
        }

        private void OnCurrentControlledCharacterChanged(CharacterBase character)
        {
            BindTarget(character);
        }

        private void UpdateUI()
        {
            if (m_target == null)
            {
                m_slider.minValue = 0;
                m_slider.maxValue = 0;
                m_slider.value = 0;
                m_sliderText.text = string.Empty;
                m_label.text = GameManager.Config.GetTermDefinition(m_stat).shortName;
                m_hasDisplayedBoundValue = false;
                return;
            }

            m_label.text = GameManager.Config.GetTermDefinition(m_stat).shortName;

            int current = m_target.GetCurrentStatValue(m_stat);
            int max = m_target.GetStatValue(m_stat);

            float previousSliderValue = m_slider.value;

            m_slider.minValue = 0;
            m_slider.maxValue = max;
            m_slider.value = current;

            if (m_hasDisplayedBoundValue && m_slider.value < previousSliderValue && m_shakeOnDecrease)
            {
                Shake();
            }

            m_sliderText.text = StringFormatter.Format("{0}/{1}", current, max);
            m_hasDisplayedBoundValue = true;
        }

        private void Shake()
        {
            if (m_shakeHandler.HasValue)
            {
                TransformShaker.InterruptShakeIfInProgress(m_shakeHandler.Value);
                m_shakeHandler = null;
            }

            m_shakeHandler = TransformShaker.Shake(
                target: m_slider.transform,
                amplitude: m_shakeAmplitude,
                frequency: m_shakeFrequency,
                duration: m_shakeDuration
            );
        }

        private void BindTarget(CharacterBase character)
        {
            if (ReferenceEquals(m_target, character))
            {
                return;
            }

            UnbindTarget();
            m_target = character;
            m_hasDisplayedBoundValue = false;

            if (m_target == null)
            {
                UpdateUI();
                return;
            }

            m_target.AddStatsChangedListener(OnStatsChanged);
            m_target.AddCurrentStatsChangedListener(OnStatsChanged);
            UpdateUI();
        }

        private void UnbindTarget()
        {
            if (m_target != null)
            {
                m_target.RemoveStatsChangedListener(OnStatsChanged);
                m_target.RemoveCurrentStatsChangedListener(OnStatsChanged);
            }
        }
    }
}

