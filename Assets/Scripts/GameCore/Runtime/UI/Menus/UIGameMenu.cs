using Sirenix.OdinInspector;
using UnityEngine;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 游戏暂停菜单面板。
    /// 它只负责菜单栈进入/退出时的暂停反馈、面板显隐和默认焦点，不持有具体子菜单的业务状态。
    /// </summary>
    public class UIGameMenu : UIKitMenuPanelBase
    {
        [Header("菜单配置与反馈")]
        [SerializeField]
        [LabelText("菜单入口列表")]
        [Tooltip("暂停菜单内的入口项。选中项会作为默认焦点来源。")]
        private UIGameMenuEntry[] m_menus;

        [SerializeField]
        [LabelText("打开时隐藏对象")]
        [Tooltip("菜单打开期间需要隐藏的 HUD 或场景 UI。关闭菜单时会重新启用。")]
        private GameObject[] m_disableWhileOpened = null;

        [SerializeField]
        [LabelText("状态效果列表")]
        [Tooltip("暂停菜单打开时同步显示的角色状态效果列表。")]
        private UIEffectList m_effectList = null;

        [SerializeField]
        [LabelText("暂停音效")]
        [Tooltip("菜单压入 UI 栈时播放的音频解析配置。")]
        private AudioClipResolver m_pauseSound;

        [SerializeField]
        [LabelText("恢复音效")]
        [Tooltip("菜单从 UI 栈弹出时播放的音频解析配置。")]
        private AudioClipResolver m_resumeSound;

        private UIGameMenuEntry m_selected = null;

        /// <summary>菜单进入栈时播放暂停反馈；具体暂停状态仍由菜单栈和游戏系统负责。</summary>
        protected override void OnPushedToMenuStack()
        {
            GameRuntimeEvents.RequestAudioPlayback(m_pauseSound);
        }

        /// <summary>菜单退出栈时播放恢复反馈；这里只提交音频请求，不直接改写游戏时间。</summary>
        protected override void OnPoppedFromMenuStack()
        {
            GameRuntimeEvents.RequestAudioPlayback(m_resumeSound);
        }

        /// <summary>面板显示时隐藏指定 HUD，并显示状态效果列表，避免暂停菜单和 HUD 信息重叠。</summary>
        protected override void OnPanelShown(UIKitMenuOpenData openData)
        {
            foreach (GameObject gameObject in m_disableWhileOpened)
            {
                gameObject.SetActive(false);
            }

            m_effectList.Show();
        }

        /// <summary>面板隐藏时恢复被隐藏的对象，并收起状态效果列表。</summary>
        protected override void OnPanelHidden()
        {
            foreach (GameObject gameObject in m_disableWhileOpened)
            {
                gameObject.SetActive(true);
            }

            m_effectList.Hide();
        }

        /// <summary>返回最近选中的菜单项作为默认焦点；没有选中过时交给菜单框架处理。</summary>
        protected override GameObject ResolveDefaultFocusTarget()
        {
            if (m_selected)
            {
                return m_selected.GetFocusTarget();
            }

            return null;
        }

        /// <summary>记录当前选中的菜单入口，供下次打开菜单时恢复焦点。</summary>
        public void HandleGameMenuEntrySelected(UIGameMenuEntry selected)
        {
            m_selected = selected;
        }
    }
}
