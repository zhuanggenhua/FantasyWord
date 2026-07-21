using System;
using Sirenix.OdinInspector;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.UI;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 主菜单入口面板。
    /// 它负责刷新存档槽、进入新游戏/读档流程和设置菜单取消键监听，不直接持有存档数据或场景初始化逻辑。
    /// </summary>
    public class UIMainMenu : MonoBehaviour, ISaveFileEventReceiver
    {
        [SerializeField]
        [LabelText("默认选中按钮")]
        [Tooltip("主菜单打开或刷新后恢复焦点的按钮。为空时控制器导航会失去默认入口。")]
        private Button m_defaultSelectedButton = null;

        [SerializeField]
        [LabelText("设置菜单")]
        [Tooltip("主菜单内嵌的设置面板。Start 时会初始化，取消键会优先关闭它。")]
        private UISettings m_settingsMenu = null;

        [SerializeField]
        [LabelText("存档槽位")]
        [Tooltip("主菜单展示的存档槽 UI。每次启用或擦除存档后都会刷新。")]
        private UISaveFile[] m_saveFiles = null;

        [SerializeField]
        [LabelText("擦除按钮")]
        [Tooltip("与存档槽位按索引对应的擦除按钮。没有对应按钮的槽位不会更新擦除状态。")]
        private Button[] m_eraseButtons = null;

        private bool m_cancelListening = false;

        /// <summary>初始化设置菜单并尝试注册取消键；输入系统可能稍后才可用，所以启用时还会再尝试一次。</summary>
        private void Start()
        {
            m_settingsMenu.Init();
            StartCancelListeningIfReady();
        }

        /// <summary>面板启用时刷新存档槽、恢复默认焦点，并确保取消键监听已接入。</summary>
        public void OnEnable()
        {
            UpdateUI();
            SelectDefaultButton();
            StartCancelListeningIfReady();
        }

        /// <summary>面板禁用时注销取消键，避免隐藏主菜单继续吞掉 UI 取消输入。</summary>
        private void OnDisable()
        {
            StopCancelListening();
        }

        /// <summary>销毁时重复注销监听，覆盖场景卸载或禁用顺序异常。</summary>
        private void OnDestroy()
        {
            StopCancelListening();
        }

        /// <summary>刷新每个存档槽和对应擦除按钮状态；存档数据真相仍来自 SaveSystem。</summary>
        private void UpdateUI()
        {
            for (int i = 0; i < m_saveFiles.Length; ++i)
            {
                UISaveFile saveFile = m_saveFiles[i];
                Button eraseButton = i < m_eraseButtons.Length ? m_eraseButtons[i] : null;
                saveFile.UpdateUI();
                eraseButton.interactable = saveFile.CanEraseSaveData();
            }
        }

        /// <summary>打开设置菜单；具体设置项的刷新和回调由 UISettings 自己负责。</summary>
        public void ShowSettingsMenu()
        {
            m_settingsMenu.Show();
        }

        /// <summary>UI 取消键回调。主菜单中取消键只用于收起设置菜单，不退出游戏或改写存档状态。</summary>
        private void OnCancel(UnityEngine.InputSystem.InputAction.CallbackContext context)
        {
            m_settingsMenu.Hide();
        }

        /// <summary>用指定默认存档开始新游戏；场景载入完成后才交给 SaveSystem 初始化默认数据。</summary>
        public void StartNewGameFromDefaultSaveFile(SaveFile saveFile)
        {
            LoadScenes(() =>
            {
                GameManager.SaveSystem.LoadDefaultSaveFile(saveFile);
            });
        }

        /// <summary>载入 M2D 引擎场景后执行存档动作，避免 UI 先访问未初始化的玩法系统。</summary>
        private void LoadScenes(Action onScenesLoaded)
        {
            SceneManager.LoadSceneAsync(Constants.M2DEngineSceneName).completed += (operation) =>
            {
                onScenesLoaded();
            };
        }

        /// <summary>恢复主菜单默认焦点，保证手柄/键盘导航有稳定起点。</summary>
        private void SelectDefaultButton()
        {
            m_defaultSelectedButton.Select();
        }

        /// <summary>擦除指定存档槽的数据，并刷新当前菜单状态；删除动作由 UISaveFile/SaveSystem 收口。</summary>
        public void EraseSaveFile(UISaveFile saveFile)
        {
            saveFile.EraseSaveData();
            UpdateUI();
            SelectDefaultButton();
        }

        /// <summary>响应存档槽点击，载入正式场景后按文件名交给 SaveSystem 读档。</summary>
        public void HandleSaveFileClicked(SaveFileActionDesc desc)
        {
            LoadScenes(() =>
            {
                GameManager.SaveSystem.LoadFromFile(desc.filename);
            });
        }

        /// <summary>在输入系统可用时注册 UI 取消键监听；重复调用只会注册一次。</summary>
        private void StartCancelListeningIfReady()
        {
            if (m_cancelListening ||
                !GameManager.Exists() ||
                !GameManager.HasSystem<InputSystem>())
            {
                return;
            }

            m_cancelListening = true;
            GameManager.InputSystem.AddUIActionListener(
                EUIInputAction.Cancel,
                EInputActionPhase.Performed,
                OnCancel);
        }

        /// <summary>注销 UI 取消键监听。输入系统已销毁时只清本地标记，不再访问缺失系统。</summary>
        private void StopCancelListening()
        {
            if (!m_cancelListening)
            {
                return;
            }

            m_cancelListening = false;
            if (!GameManager.Exists() ||
                !GameManager.HasSystem<InputSystem>())
            {
                return;
            }

            GameManager.InputSystem.RemoveUIActionListener(
                EUIInputAction.Cancel,
                EInputActionPhase.Performed,
                OnCancel);
        }
    }
}
