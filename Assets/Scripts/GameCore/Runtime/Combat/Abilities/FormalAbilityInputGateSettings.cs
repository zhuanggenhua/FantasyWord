using System;
using Sirenix.OdinInspector;
using UnityEngine;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 正式 GAS 能力的本地输入触发模式。
    /// 它只描述玩家输入如何进入 EX-GAS Ability，不承载命中、伤害或表现真相。
    /// </summary>
    public enum EFormalAbilityInputTriggerMode
    {
        /// <summary>每次触发后必须松开按键，避免长按自动重复进入能力。</summary>
        SemiAuto,

        /// <summary>按住期间允许本地门控在后摇结束后再次提交能力请求。</summary>
        Auto,

        /// <summary>按下进入蓄力或准备阶段，松开时提交释放请求。</summary>
        HoldRelease
    }

    /// <summary>
    /// 正式 GAS 能力的本地输入门控状态。状态机只管理输入节奏和本地资源，不保存生命值、阵营、经验等 RPG 规则真相。
    /// </summary>
    public enum EFormalAbilityInputGateState
    {
        /// <summary>没有待处理输入或正在执行的本地门控。</summary>
        Idle,

        /// <summary>输入刚进入门控，等待后续状态决定是否前摇、出手或蓄力。</summary>
        Start,

        /// <summary>按住释放类技能正在等待松手提交。</summary>
        Charging,

        /// <summary>本地前摇阶段，EX-GAS Timeline 仍然是最终出手时点真相。</summary>
        DelayBeforeUse,

        /// <summary>本地门控允许提交一次正式能力使用请求。</summary>
        Use,

        /// <summary>本地后摇或两次使用之间的节奏间隔。</summary>
        DelayBetweenUses,

        /// <summary>本地输入流程收束，等待回到空闲态。</summary>
        Stop,

        /// <summary>本地弹匣不足，需要先进入换弹流程。</summary>
        ReloadNeeded,

        /// <summary>换弹流程刚开始，用于区分输入触发和实际换弹计时。</summary>
        ReloadStart,

        /// <summary>本地换弹计时中，只管理弹匣节奏，不改写 RPG 资源规则。</summary>
        Reload,

        /// <summary>换弹流程结束，等待门控回到可输入状态。</summary>
        ReloadStop,

        /// <summary>外部状态打断了本地输入流程，例如死亡、硬直或动作禁用。</summary>
        Interrupted
    }

    /// <summary>
    /// 正式 GAS 技能仍由 GameCore 接收本地输入，但只保留输入触发、缓冲和松手中断语义。
    /// 出手前摇、命中时点、后摇和规则结算必须来自 EX-GAS Timeline。
    /// </summary>
    [Serializable]
    public sealed class FormalAbilityInputGateConfig
    {
        [SerializeField]
        [LabelText("触发模式"), Tooltip("半自动需要松开后才能再次触发；自动允许持续按住后按 Timeline 后摇重复触发；按住释放会在按下时蓄力、松开时释放。")]
        private EFormalAbilityInputTriggerMode m_triggerMode = EFormalAbilityInputTriggerMode.SemiAuto;

        [SerializeField]
        [LabelText("启用输入缓冲"), Tooltip("技能忙碌期间是否记录下一次输入。")]
        private bool m_bufferInput = true;

        [SerializeField]
        [LabelText("新输入延长缓冲"), Tooltip("再次按键是否刷新输入缓冲时间。")]
        private bool m_newInputExtendsBuffer = true;

        [SerializeField]
        [Min(0.0f)]
        [LabelText("最大缓冲时间"), Tooltip("输入缓冲保留的最长时间，单位秒。")]
        private float m_maximumBufferDuration = 0.25f;

        [SerializeField]
        [LabelText("前摇松手打断"), Tooltip("Timeline 前摇期间松开按键是否取消本次技能。")]
        private bool m_delayBeforeUseReleaseInterruption = true;

        [SerializeField]
        [LabelText("后摇松手打断"), Tooltip("Timeline 后摇期间松开按键是否立刻结束本地输入门控。")]
        private bool m_timeBetweenUsesReleaseInterruption = true;

        [SerializeField]
        [LabelText("开火时更新朝向"), Tooltip("触发技能时是否把角色朝向更新为当前目标方向。这里只属于本地输入/瞄准桥，不承担 GAS 激活规则。")]
        private bool m_updateLookAtDirectionOnFire = true;

        public FormalAbilityInputGateConfig()
        {
        }

        public FormalAbilityInputGateConfig(
            EFormalAbilityInputTriggerMode triggerMode,
            bool bufferInput,
            bool newInputExtendsBuffer,
            float maximumBufferDuration,
            bool delayBeforeUseReleaseInterruption,
            bool timeBetweenUsesReleaseInterruption,
            bool updateLookAtDirectionOnFire)
        {
            m_triggerMode = triggerMode;
            m_bufferInput = bufferInput;
            m_newInputExtendsBuffer = newInputExtendsBuffer;
            m_maximumBufferDuration = Mathf.Max(0.0f, maximumBufferDuration);
            m_delayBeforeUseReleaseInterruption = delayBeforeUseReleaseInterruption;
            m_timeBetweenUsesReleaseInterruption = timeBetweenUsesReleaseInterruption;
            m_updateLookAtDirectionOnFire = updateLookAtDirectionOnFire;
        }

        public EFormalAbilityInputTriggerMode triggerMode => m_triggerMode;
        public bool bufferInput => m_bufferInput;
        public bool newInputExtendsBuffer => m_newInputExtendsBuffer;
        public float maximumBufferDuration => Mathf.Max(0.0f, m_maximumBufferDuration);
        public bool delayBeforeUseReleaseInterruption => m_delayBeforeUseReleaseInterruption;
        public bool timeBetweenUsesReleaseInterruption => m_timeBetweenUsesReleaseInterruption;
        public bool updateLookAtDirectionOnFire => m_updateLookAtDirectionOnFire;
    }

    /// <summary>
    /// 正式 GAS 能力的本地输入门控参数。
    /// 这里只保存输入缓冲、按住释放、本地前后摇门控和弹匣类本地节奏；
    /// 真正的命中时点、目标捕获、伤害、状态和表现仍由 EX-GAS Timeline / GameplayEffect / Cue 结算。
    /// </summary>
    [Serializable]
    public sealed class FormalAbilityInputGateSettings
    {
        [Header("输入")]
        [SerializeField]
        [LabelText("触发模式"), Tooltip("半自动需要松开后才能再次开火；自动允许持续按住后按攻击间隔重复开火；按住释放会在按下时蓄力、松开时释放。")]
        private EFormalAbilityInputTriggerMode m_triggerMode = EFormalAbilityInputTriggerMode.SemiAuto;

        [SerializeField]
        [LabelText("启用输入缓冲"), Tooltip("攻击期间是否记录下一次输入，适合近战连段或提前按键。")]
        private bool m_bufferInput = true;

        [SerializeField]
        [LabelText("新输入延长缓冲"), Tooltip("再次按键是否刷新输入缓冲时间。")]
        private bool m_newInputExtendsBuffer = true;

        [SerializeField]
        [Min(0.0f)]
        [LabelText("最大缓冲时间"), Tooltip("输入缓冲保留的最长时间，单位秒。")]
        private float m_maximumBufferDuration = 0.25f;

        [Header("节奏")]
        [SerializeField]
        [Min(0.0f)]
        [LabelText("前摇时间"), Tooltip("输入成立后到真正出手前的前摇时间，单位秒。")]
        private float m_delayBeforeUse = 0.0f;

        [SerializeField]
        [LabelText("前摇松手打断"), Tooltip("前摇期间松开按键是否取消本次攻击。")]
        private bool m_delayBeforeUseReleaseInterruption = true;

        [SerializeField]
        [Min(0.0f)]
        [LabelText("出手间隔"), Tooltip("两次出手之间的最小间隔，单位秒。")]
        private float m_timeBetweenUses = 0.25f;

        [SerializeField]
        [LabelText("后摇松手打断"), Tooltip("后摇期间松开按键是否立刻收招。")]
        private bool m_timeBetweenUsesReleaseInterruption = true;

        [Header("连发")]
        [SerializeField]
        [LabelText("启用连发"), Tooltip("一次输入是否触发多次出手。")]
        private bool m_useBurstMode = false;

        [SerializeField]
        [Min(1)]
        [LabelText("连发次数"), Tooltip("连发模式下，一次输入触发的出手次数。")]
        private int m_burstLength = 3;

        [SerializeField]
        [Min(0.0f)]
        [LabelText("连发间隔"), Tooltip("连发模式中两次出手之间的间隔，单位秒。")]
        private float m_burstTimeBetweenShots = 0.1f;

        [Header("弹匣")]
        [SerializeField]
        [LabelText("启用弹匣"), Tooltip("是否启用弹匣。关闭时不消耗本地弹匣，只由 RPG 规则决定资源消耗。")]
        private bool m_magazineBased = false;

        [SerializeField]
        [Min(1)]
        [LabelText("弹匣容量"), Tooltip("弹匣容量。")]
        private int m_magazineSize = 30;

        [SerializeField]
        [Min(1)]
        [LabelText("每次消耗弹药"), Tooltip("每次出手消耗的弹匣数量。")]
        private int m_ammoConsumedPerUse = 1;

        [SerializeField]
        [LabelText("弹匣空时自动换弹"), Tooltip("弹匣不足时，按开火是否自动换弹。")]
        private bool m_autoReload = true;

        [SerializeField]
        [LabelText("最后一发后自动换弹"), Tooltip("最后一发结束后是否无需输入自动换弹。")]
        private bool m_noInputReload = false;

        [SerializeField]
        [Min(0.0f)]
        [LabelText("换弹时间"), Tooltip("换弹耗时，单位秒。")]
        private float m_reloadTime = 1.0f;

        public EFormalAbilityInputTriggerMode triggerMode => m_triggerMode;
        public bool bufferInput => m_bufferInput;
        public bool newInputExtendsBuffer => m_newInputExtendsBuffer;
        public float maximumBufferDuration => Mathf.Max(0.0f, m_maximumBufferDuration);
        public float delayBeforeUse => Mathf.Max(0.0f, m_delayBeforeUse);
        public bool delayBeforeUseReleaseInterruption => m_delayBeforeUseReleaseInterruption;
        public float timeBetweenUses => Mathf.Max(0.0f, m_timeBetweenUses);
        public bool timeBetweenUsesReleaseInterruption => m_timeBetweenUsesReleaseInterruption;
        public bool useBurstMode => m_useBurstMode;
        public int burstLength => Mathf.Max(1, m_burstLength);
        public float burstTimeBetweenShots => Mathf.Max(0.0f, m_burstTimeBetweenShots);
        public bool magazineBased => m_magazineBased;
        public int magazineSize => Mathf.Max(1, m_magazineSize);
        public int ammoConsumedPerUse => Mathf.Max(1, m_ammoConsumedPerUse);
        public bool autoReload => m_autoReload;
        public bool noInputReload => m_noInputReload;
        public float reloadTime => Mathf.Max(0.0f, m_reloadTime);

        /// <summary>
        /// 从 EX-GAS Timeline 的前摇/后摇时长生成本地门控配置。
        /// 这里会复用输入触发与缓冲规则，但关闭弹匣和连发，避免本地节奏覆盖 Timeline 的正式技能结构。
        /// </summary>
        public static FormalAbilityInputGateSettings CreateTimelineGate(
            FormalAbilityInputGateConfig inputSettings,
            float delayBeforeUse,
            float timeBetweenUses)
        {
            FormalAbilityInputGateSettings settings = new();
            if (inputSettings != null)
            {
                settings.m_triggerMode = inputSettings.triggerMode;
                settings.m_bufferInput = inputSettings.bufferInput;
                settings.m_newInputExtendsBuffer = inputSettings.newInputExtendsBuffer;
                settings.m_maximumBufferDuration = inputSettings.maximumBufferDuration;
                settings.m_delayBeforeUseReleaseInterruption = inputSettings.delayBeforeUseReleaseInterruption;
                settings.m_timeBetweenUsesReleaseInterruption = inputSettings.timeBetweenUsesReleaseInterruption;
            }

            settings.m_delayBeforeUse = Mathf.Max(0.0f, delayBeforeUse);
            settings.m_timeBetweenUses = Mathf.Max(0.0f, timeBetweenUses);
            settings.m_magazineBased = false;
            settings.m_useBurstMode = false;
            return settings;
        }
    }
}

