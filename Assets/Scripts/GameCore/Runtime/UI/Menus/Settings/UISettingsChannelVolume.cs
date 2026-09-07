using Sirenix.OdinInspector;
using UnityEngine;
using UnityEngine.Events;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 单个音频通道的音量设置行。
    /// 它负责声明自己绑定的音频通道，并把按钮点击回调包装成带通道参数的设置请求。
    /// </summary>
    public class UISettingsChannelVolume : UISettingsVolume
    {
        [SerializeField]
        [LabelText("音频通道")]
        [Tooltip("该设置行控制的 AudioSystem 通道。配置错误会让按钮调整到错误音频分类。")]
        private EAudioChannel m_audioChannel;

        /// <summary>该音量行绑定的项目音频通道，供设置面板读取当前音量并刷新显示。</summary>
        public EAudioChannel audioChannel => m_audioChannel;

        private UnityAction m_decreaseCallback;
        private UnityAction m_increaseCallback;

        /// <summary>注册带通道参数的增减音量回调；重复注册前会先清理旧监听。</summary>
        public void RegisterCallbacks(UnityAction<EAudioChannel> decrease, UnityAction<EAudioChannel> increase)
        {
            UnregisterCallbacks();
            m_decreaseCallback = () => decrease(m_audioChannel);
            m_increaseCallback = () => increase(m_audioChannel);
            m_decreaseButton.onClick.AddListener(m_decreaseCallback);
            m_increaseButton.onClick.AddListener(m_increaseCallback);
        }

        /// <summary>注销增减按钮监听，避免设置面板销毁后仍被按钮回调持有。</summary>
        public void UnregisterCallbacks()
        {
            if (m_decreaseCallback != null)
            {
                m_decreaseButton.onClick.RemoveListener(m_decreaseCallback);
                m_decreaseCallback = null;
            }

            if (m_increaseCallback != null)
            {
                m_increaseButton.onClick.RemoveListener(m_increaseCallback);
                m_increaseCallback = null;
            }
        }
    }
}
