using UnityEngine.Events;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 主音量设置行。
    /// 它只绑定主音量增减按钮，不携带音频通道参数，具体音量读写由 UISettings 负责。
    /// </summary>
    public class UISettingsMasterVolume : UISettingsVolume
    {
        private UnityAction m_decreaseCallback;
        private UnityAction m_increaseCallback;

        /// <summary>注册主音量增减按钮回调；重复注册前会先清理旧监听。</summary>
        public void RegisterCallbacks(UnityAction decrease, UnityAction increase)
        {
            UnregisterCallbacks();
            m_decreaseCallback = decrease;
            m_increaseCallback = increase;
            m_decreaseButton.onClick.AddListener(m_decreaseCallback);
            m_increaseButton.onClick.AddListener(m_increaseCallback);
        }

        /// <summary>注销主音量按钮监听，避免设置面板销毁后仍被按钮回调持有。</summary>
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
