using Sirenix.OdinInspector;
using TMPro;
using Unity.Mathematics;
using UnityEngine;
using UnityEngine.UI;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// HUD 数值条，显示目标角色某个属性的当前值与上限。
    /// 它可以固定绑定指定角色，也可以跟随玩家当前控制角色切换。
    /// </summary>
    public class UIStatBar : MonoBehaviour
    {
        #region Inspector 配置

        [Header("引用")]
        [SerializeField]
        [LabelText("名称文本")]
        [Tooltip("显示属性简称的 TMP 文本。")]
        private TextMeshProUGUI m_label = null;

        [SerializeField]
        [LabelText("数值滑条")]
        [Tooltip("按当前值和上限显示比例的 Slider。")]
        private Slider m_slider = null;

        [SerializeField]
        [LabelText("数值文本")]
        [Tooltip("显示 当前值/上限 的 TMP 文本。")]
        private TextMeshProUGUI m_sliderText = null;

        [SerializeField]
        [LabelText("目标角色")]
        [Tooltip("留空时跟随当前控制角色；只有明确指定时，才固定显示某个角色的数值。")]
        private CharacterBase m_target = null;

        [SerializeField]
        [LabelText("数值类型")]
        [Tooltip("要显示的角色属性，例如生命、魔力或其他配置表里的属性。")]
        private EStat m_stat;

        [Header("降低时抖动")]
        [SerializeField]
        [LabelText("数值降低时抖动")]
        [Tooltip("开启后，当前值低于上一次显示值时会触发滑条抖动反馈。")]
        private bool m_shakeOnDecrease = false;

        [SerializeField, Min(0f)]
        [LabelText("抖动幅度")]
        [Tooltip("滑条抖动的位移幅度。")]
        private float m_shakeAmplitude = 5.0f;

        [SerializeField]
        [LabelText("抖动频率")]
        [Tooltip("X/Y 两个方向的抖动频率。")]
        private float2 m_shakeFrequency = new(30.0f, 25.0f);

        [SerializeField, Min(0f)]
        [LabelText("抖动时长")]
        [Tooltip("一次降低反馈持续的秒数。")]
        private float m_shakeDuration = 0.2f;

        #endregion

        private ShakeHandler? m_shakeHandler = null;
        private bool m_followCurrentControlledCharacter = false;
        private bool m_hasDisplayedBoundValue = false;
        private CharacterBase m_configuredTarget = null;
        private bool m_currentControlledCharacterListening = false;

        /// <summary>记录初始绑定模式；显式目标会缓存起来，等待生命周期正式绑定。</summary>
        private void Awake()
        {
            m_followCurrentControlledCharacter = m_target == null;
            if (!m_followCurrentControlledCharacter)
            {
                m_configuredTarget = m_target;
                m_target = null;
            }
        }

        /// <summary>启用时尝试绑定目标；PlayerSystem 可能尚未准备好，所以还会在 Start 再尝试一次。</summary>
        private void OnEnable()
        {
            BindInitialTargetIfReady();
        }

        /// <summary>补一次初始绑定，覆盖 UI 早于 PlayerSystem 初始化的场景。</summary>
        private void Start()
        {
            BindInitialTargetIfReady();
        }

        /// <summary>禁用时停止抖动、取消当前控制角色监听，并解绑目标属性事件。</summary>
        private void OnDisable()
        {
            StopShake();
            StopCurrentControlledCharacterListening();
            UnbindTarget();
        }

        /// <summary>销毁时重复执行清理，保证对象绕过禁用流程时也能释放监听。</summary>
        private void OnDestroy()
        {
            StopShake();
            StopCurrentControlledCharacterListening();
            UnbindTarget();
        }

        #region 目标绑定

        /// <summary>根据 Inspector 配置决定跟随当前控制角色，还是绑定固定角色。</summary>
        private void BindInitialTargetIfReady()
        {
            if (m_followCurrentControlledCharacter)
            {
                StartCurrentControlledCharacterListeningIfReady();
            }
            else
            {
                BindTarget(m_configuredTarget);
            }
        }

        /// <summary>PlayerSystem 可用后开始监听当前控制角色变化，并立即绑定一次当前角色。</summary>
        private void StartCurrentControlledCharacterListeningIfReady()
        {
            if (m_currentControlledCharacterListening)
            {
                return;
            }

            if (!GameManager.Exists() || !GameManager.HasSystem<PlayerSystem>())
            {
                return;
            }

            m_currentControlledCharacterListening = true;
            GameManager.PlayerSystem.AddCurrentControlledCharacterChangedListener(OnCurrentControlledCharacterChanged);
            OnCurrentControlledCharacterChanged(GameManager.PlayerSystem.GetCurrentControlledCharacterOrPlayerInstance());
        }

        /// <summary>停止监听当前控制角色变化；GameManager 已释放时直接跳过注销入口。</summary>
        private void StopCurrentControlledCharacterListening()
        {
            if (!m_currentControlledCharacterListening)
            {
                return;
            }

            m_currentControlledCharacterListening = false;
            if (GameManager.Exists() && GameManager.HasSystem<PlayerSystem>())
            {
                GameManager.PlayerSystem.RemoveCurrentControlledCharacterChangedListener(OnCurrentControlledCharacterChanged);
            }
        }

        /// <summary>基础属性或当前属性变化后刷新 UI；previous 只用于事件合同，本控件不直接读取。</summary>
        private void OnStatsChanged(Stats previous)
        {
            UpdateUI();
        }

        /// <summary>玩家当前控制角色变化后重新绑定目标属性事件。</summary>
        private void OnCurrentControlledCharacterChanged(CharacterBase character)
        {
            BindTarget(character);
        }

        /// <summary>切换目标角色，并维护属性变化监听，避免旧角色继续驱动这个 HUD。</summary>
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

        /// <summary>解绑当前目标的属性监听；目标为空时保持安全空操作。</summary>
        private void UnbindTarget()
        {
            if (m_target != null)
            {
                m_target.RemoveStatsChangedListener(OnStatsChanged);
                m_target.RemoveCurrentStatsChangedListener(OnStatsChanged);
            }

            m_target = null;
        }

        #endregion

        #region UI 刷新与反馈

        /// <summary>根据目标当前属性刷新滑条、文本和降低抖动反馈。</summary>
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

        /// <summary>触发一次滑条抖动；已有抖动会先中断，避免多个句柄叠加。</summary>
        private void Shake()
        {
            if (m_shakeHandler.HasValue)
            {
                TransformShaker.InterruptShakeIfInProgress(m_shakeHandler.Value);
                m_shakeHandler = null;
            }

            m_shakeHandler = TransformShaker.Shake(
                owner: this,
                target: m_slider.transform,
                amplitude: m_shakeAmplitude,
                frequency: m_shakeFrequency,
                duration: m_shakeDuration
            );
        }

        /// <summary>停止正在进行的滑条抖动，并释放抖动句柄。</summary>
        private void StopShake()
        {
            if (!m_shakeHandler.HasValue)
            {
                return;
            }

            TransformShaker.InterruptShakeIfInProgress(m_shakeHandler.Value);
            m_shakeHandler = null;
        }

        #endregion
    }
}
