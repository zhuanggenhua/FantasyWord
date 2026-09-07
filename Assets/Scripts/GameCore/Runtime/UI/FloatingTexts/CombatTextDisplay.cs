using Sirenix.OdinInspector;
using UnityEngine;
using YokiFrame;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 战斗浮字显示器，消费正式表现事件并把文字、颜色和动画参数交给浮字池。
    /// 它只处理表现开关与文案选择，伤害、治疗、魔力和持续效果真相来自事件上下文。
    /// </summary>
    [RequireComponent(typeof(FloatingTextPool))]
    public class CombatTextDisplay : MonoBehaviour
    {
        #region Inspector 配置

        [Header("生命浮字")]
        [SerializeField]
        [LabelText("显示伤害")]
        [Tooltip("开启后显示普通、暴击、未命中等伤害浮字。")]
        private bool m_showDamages = true;

        [SerializeField]
        [LabelText("显示治疗")]
        [Tooltip("开启后显示生命恢复浮字。")]
        private bool m_showHeals = true;

        [SerializeField]
        [LabelText("显示零治疗")]
        [Tooltip("开启后即使恢复值为 0 也显示治疗浮字。")]
        private bool m_showNullHeals = true;

        [Header("魔力浮字")]
        [SerializeField]
        [LabelText("显示消耗魔力")]
        [Tooltip("开启后显示魔力消耗浮字。")]
        private bool m_showConsumedMana = false;

        [SerializeField]
        [LabelText("显示恢复魔力")]
        [Tooltip("开启后显示魔力恢复浮字。")]
        private bool m_showRecoveredMana = true;

        [SerializeField]
        [LabelText("显示零消耗魔力")]
        [Tooltip("开启后即使消耗值为 0 也显示魔力消耗浮字。")]
        private bool m_showNullManaConsumption = false;

        [SerializeField]
        [LabelText("显示零恢复魔力")]
        [Tooltip("开启后即使恢复值为 0 也显示魔力恢复浮字。")]
        private bool m_showNullManaRecovery = true;

        [SerializeField]
        [LabelText("显示持续效果")]
        [Tooltip("开启后在持续效果应用时显示效果简称浮字。")]
        private bool m_showTemporalEffects = true;

        [Header("浮字颜色")]
        [SerializeField]
        [LabelText("伤害颜色")]
        [Tooltip("普通有效伤害的浮字颜色。")]
        private Color m_damageColor = Color.white;

        [SerializeField]
        [LabelText("静默伤害颜色")]
        [Tooltip("静默应用命中时的伤害浮字颜色。")]
        private Color m_silentDamageColor = Color.red;

        [SerializeField]
        [LabelText("未命中颜色")]
        [Tooltip("攻击未命中时显示的浮字颜色。")]
        private Color m_missDamageColor = Color.white;

        [SerializeField]
        [LabelText("暴击颜色")]
        [Tooltip("暴击伤害的浮字颜色。")]
        private Color m_criticalDamageColor = Color.yellow;

        [SerializeField]
        [LabelText("治疗颜色")]
        [Tooltip("生命恢复浮字颜色。")]
        private Color m_healColor = Color.green;

        [SerializeField]
        [LabelText("魔力消耗颜色")]
        [Tooltip("魔力消耗浮字颜色。")]
        private Color m_manaConsumedColor = Color.cyan;

        [SerializeField]
        [LabelText("魔力恢复颜色")]
        [Tooltip("魔力恢复浮字颜色。")]
        private Color m_manaRecoveredColor = Color.cyan;

        [SerializeField]
        [LabelText("持续效果颜色")]
        [Tooltip("持续效果应用提示的浮字颜色。")]
        private Color m_temporalEffectAppliedColor = Color.white;

        [SerializeField]
        [LabelText("未命中文案")]
        [Tooltip("伤害输入标记为未命中时显示的文本。")]
        private string m_missText = "Miss";

        [SerializeField]
        [LabelText("动画参数")]
        [Tooltip("传给 FloatingText Animator 的触发参数。")]
        private string m_textAnimationParameter = "bounce";

        #endregion

        private FloatingTextPool m_floatingTextPool = null;

        #region 生命周期

        /// <summary>缓存同物体上的浮字池；RequireComponent 保证运行时应当存在该组件。</summary>
        private void Awake()
        {
            m_floatingTextPool = GetComponent<FloatingTextPool>();
        }

        /// <summary>
        /// 注册正式表现事件。
        /// 浮字只消费表现上下文，不回读旧通知中心或战斗系统内部状态。
        /// </summary>
        private void OnEnable()
        {
            EventKit.Type.Register<DamageTakenPresentationEvent>(OnDamageTakenPresentation);
            EventKit.Type.Register<HealthRecoveredPresentationEvent>(OnHealthRecoveredPresentation);
            EventKit.Type.Register<ManaConsumedPresentationEvent>(OnManaConsumedPresentation);
            EventKit.Type.Register<ManaRecoveredPresentationEvent>(OnManaRecoveredPresentation);
            EventKit.Type.Register<TemporalEffectPresentationEvent>(OnTemporalEffectPresentation);
        }

        /// <summary>注销正式表现事件，避免禁用后的 HUD 继续收到浮字请求。</summary>
        private void OnDisable()
        {
            EventKit.Type.UnRegister<DamageTakenPresentationEvent>(OnDamageTakenPresentation);
            EventKit.Type.UnRegister<HealthRecoveredPresentationEvent>(OnHealthRecoveredPresentation);
            EventKit.Type.UnRegister<ManaConsumedPresentationEvent>(OnManaConsumedPresentation);
            EventKit.Type.UnRegister<ManaRecoveredPresentationEvent>(OnManaRecoveredPresentation);
            EventKit.Type.UnRegister<TemporalEffectPresentationEvent>(OnTemporalEffectPresentation);
        }

        #endregion

        #region 表现事件处理

        /// <summary>根据伤害表现上下文选择伤害文本和颜色，并交给浮字池排队播放。</summary>
        private void OnDamageTakenPresentation(DamageTakenPresentationEvent presentationEvent)
        {
            DamageTakenFeedbackContext context = presentationEvent.Context;

            if (m_showDamages && !context.visualFlags.HasFlag(EEffectVisualFlags.NoFloatingText))
            {
                string text = context.damageInput.IsMissed ? m_missText : context.damageInput.damage.ToString();

                Color color =
                    context.damageInput.IsMissed ? m_missDamageColor :
                    context.damageInput.IsCriticalHit ? m_criticalDamageColor :
                    (context.damageInput.IsSilentAppliedHit ? m_silentDamageColor : m_damageColor);

                m_floatingTextPool.ShowText(text, context.target.transform.position, color, m_textAnimationParameter);
            }
        }

        /// <summary>根据生命恢复表现上下文显示治疗浮字，零值是否显示由 Inspector 配置控制。</summary>
        private void OnHealthRecoveredPresentation(HealthRecoveredPresentationEvent presentationEvent)
        {
            CharacterValuePresentationContext context = presentationEvent.Context;

            if (m_showHeals && !context.visualFlags.HasFlag(EEffectVisualFlags.NoFloatingText) && (m_showNullHeals || context.value > 0))
            {
                m_floatingTextPool.ShowText(context.value.ToString(), context.position, m_healColor, m_textAnimationParameter);
            }
        }

        /// <summary>根据魔力消耗表现上下文显示消耗浮字，零值是否显示由 Inspector 配置控制。</summary>
        private void OnManaConsumedPresentation(ManaConsumedPresentationEvent presentationEvent)
        {
            CharacterValuePresentationContext context = presentationEvent.Context;

            if (m_showConsumedMana && !context.visualFlags.HasFlag(EEffectVisualFlags.NoFloatingText) && (m_showNullManaConsumption || context.value > 0))
            {
                m_floatingTextPool.ShowText(context.value.ToString(), context.position, m_manaConsumedColor, m_textAnimationParameter);
            }
        }

        /// <summary>根据魔力恢复表现上下文显示恢复浮字，零值是否显示由 Inspector 配置控制。</summary>
        private void OnManaRecoveredPresentation(ManaRecoveredPresentationEvent presentationEvent)
        {
            CharacterValuePresentationContext context = presentationEvent.Context;

            if (m_showRecoveredMana && !context.visualFlags.HasFlag(EEffectVisualFlags.NoFloatingText) && (m_showNullManaRecovery || context.value > 0))
            {
                m_floatingTextPool.ShowText(context.value.ToString(), context.position, m_manaRecoveredColor, m_textAnimationParameter);
            }
        }

        /// <summary>持续效果有表现配置时显示效果简称，方便玩家看到 Buff/Debuff 进入。</summary>
        private void OnTemporalEffectPresentation(TemporalEffectPresentationEvent presentationEvent)
        {
            TemporalEffectPresentationContext context = presentationEvent.Context;

            if (m_showTemporalEffects &&
                !context.visualFlags.HasFlag(EEffectVisualFlags.NoFloatingText) &&
                context.snapshot.HasPresentation)
            {
                m_floatingTextPool.ShowText(context.snapshot.Info.ShortName, context.position, m_temporalEffectAppliedColor, m_textAnimationParameter);
            }
        }

        #endregion
    }
}
