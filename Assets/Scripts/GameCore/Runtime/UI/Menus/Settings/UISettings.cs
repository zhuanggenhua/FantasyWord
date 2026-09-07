using Sirenix.OdinInspector;
using Unity.Mathematics;
using UnityEngine;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 音量设置菜单面板。
    /// 它负责把按钮回调转换成 AudioSystem 音量调整，并刷新主音量和各通道音量显示。
    /// </summary>
    public class UISettings : UIKitMenuPanelBase
    {
        [SerializeField]
        [LabelText("主音量控件")]
        [Tooltip("负责显示和调整全局主音量的 UI 行。默认焦点也来自这个控件。")]
        private UISettingsMasterVolume m_masterVolume = null;

        [SerializeField]
        [LabelText("通道音量控件")]
        [Tooltip("每个音频通道对应一个音量 UI 行。通道身份由 UISettingsChannelVolume 自己声明。")]
        private UISettingsChannelVolume[] m_channelVolumes = null;

        [Header("音量显示")]
        [SerializeField, Min(0f)]
        [LabelText("显示最大值")]
        [Tooltip("把 0-1 音量比例转换成作者可见数字时使用的显示上限。")]
        private float m_maxVolume = 10.0f;

        [SerializeField]
        [LabelText("显示后缀")]
        [Tooltip("音量数值后显示的文本，例如“ / 10”。")]
        private string m_volumeSuffix = " / 10";

        [SerializeField, Min(0.01f)]
        [LabelText("调节步长")]
        [Tooltip("每次点击增加/减少按钮时调整的 0-1 音量比例。必须大于 0，避免四舍五入计算失效。")]
        private float m_volumeStep = 0.1f;

        /// <summary>注册主音量和通道音量按钮回调；注销在销毁时统一收口。</summary>
        protected override void OnPanelInit()
        {
            m_masterVolume.RegisterCallbacks(OnMasterVolumeDecreased, OnMasterVolumeIncreased);

            foreach (UISettingsChannelVolume channelVolume in m_channelVolumes)
            {
                channelVolume.RegisterCallbacks(OnChannelVolumeDecreased, OnChannelVolumeIncreased);
            }
        }

        /// <summary>面板显示时按当前 AudioSystem 状态刷新所有音量行。</summary>
        protected override void OnPanelShown(UIKitMenuOpenData openData)
        {
            UpdateUI();
        }

        /// <summary>销毁时注销按钮回调，避免旧设置面板继续持有 AudioSystem 操作入口。</summary>
        private void OnDestroy()
        {
            m_masterVolume.UnregisterCallbacks();

            foreach (UISettingsChannelVolume channelVolume in m_channelVolumes)
            {
                channelVolume.UnregisterCallbacks();
            }
        }

        /// <summary>默认焦点落到主音量控件，保证设置菜单打开后手柄/键盘有稳定入口。</summary>
        protected override GameObject ResolveDefaultFocusTarget()
        {
            return m_masterVolume.GetDefaultFocusTarget();
        }

        /// <summary>按步长调整音量并裁剪到 0-1；四舍五入让显示值和实际比例保持一致。</summary>
        private float ComputeVolumeChange(float volume, float stepScale)
        {
            float step = m_volumeStep * stepScale;
            return math.saturate(math.round((volume + step) * (1.0f / step)) * step);
        }

        private float ComputeVolumeIncrement(float volume) => ComputeVolumeChange(volume, +1.0f);

        private float ComputeVolumeDecrement(float volume) => ComputeVolumeChange(volume, -1.0f);

        /// <summary>提升主音量后刷新 UI；主音量真相仍由 AudioSystem 保存。</summary>
        private void OnMasterVolumeIncreased()
        {
            GameManager.AudioSystem.SetMasterVolume(
                ComputeVolumeIncrement(
                    GameManager.AudioSystem.GetMasterVolume()
                )
            );

            UpdateUI();
        }

        /// <summary>降低主音量后刷新 UI；这里不直接处理持久化。</summary>
        private void OnMasterVolumeDecreased()
        {
            GameManager.AudioSystem.SetMasterVolume(
                ComputeVolumeDecrement(
                    GameManager.AudioSystem.GetMasterVolume()
                )
            );

            UpdateUI();
        }

        /// <summary>提升指定音频通道音量比例，并立即刷新所有通道显示。</summary>
        private void OnChannelVolumeIncreased(EAudioChannel channel)
        {
            AudioSystem audioSystem = GameManager.AudioSystem;
            float targetVolumeScale = ComputeVolumeIncrement(audioSystem.GetChannelVolumeScale(channel));
            audioSystem.SetChannelVolumeScale(channel, targetVolumeScale);
            UpdateUI();
        }

        /// <summary>降低指定音频通道音量比例，并立即刷新所有通道显示。</summary>
        private void OnChannelVolumeDecreased(EAudioChannel channel)
        {
            AudioSystem audioSystem = GameManager.AudioSystem;
            float targetVolumeScale = ComputeVolumeDecrement(audioSystem.GetChannelVolumeScale(channel));
            audioSystem.SetChannelVolumeScale(channel, targetVolumeScale);
            UpdateUI();
        }

        /// <summary>把 AudioSystem 当前音量转换成显示整数，写回主音量和各通道音量行。</summary>
        private void UpdateUI()
        {
            m_masterVolume.UpdateUI((int)math.round(GameManager.AudioSystem.GetMasterVolume() * m_maxVolume), m_volumeSuffix);

            foreach (UISettingsChannelVolume channelVolume in m_channelVolumes)
            {
                float volumeScale = GameManager.AudioSystem.GetChannelVolumeScale(channelVolume.audioChannel) * m_maxVolume;
                channelVolume.UpdateUI((int)math.round(volumeScale), m_volumeSuffix);
            }
        }
    }
}
