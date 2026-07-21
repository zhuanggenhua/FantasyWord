using Sirenix.OdinInspector;
using UnityEngine;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 游戏 UI 根节点系统。
    /// 它只负责实例化和显示场景 UI 预制体，不持有具体菜单状态，也不替代各 UI 面板自己的刷新逻辑。
    /// </summary>
    public class UISystem : AGameSystem
    {
        [SerializeField]
        [LabelText("UI 根预制体")]
        [Tooltip("正式 UI 根节点预制体。存档载入或系统启动时会挂到本系统节点下，只保留一个运行时实例。")]
        private GameObject m_uiPrefab;

        private GameObject m_uiInstance = null;

        /// <summary>系统启动时确保 UI 根节点存在，让主菜单、HUD 或加载后 UI 能进入正常生命周期。</summary>
        public override void OnSystemStart()
        {
            ShowUI();
        }

        /// <summary>
        /// 存档载入后再次确保 UI 可见。
        /// 部分 UI 依赖角色、背包或世界状态，必须等玩法初始化完成后再让根节点参与刷新。
        /// </summary>
        public override void OnSaveFileLoaded()
        {
            ShowUI();
        }

        /// <summary>显示或创建 UI 根实例，并在正式场景里检查是否存在重复单例节点。</summary>
        public void ShowUI()
        {
            if (m_uiInstance == null)
            {
                m_uiInstance = Instantiate(m_uiPrefab, transform);
            }
            else
            {
                m_uiInstance.SetActive(true);
            }

            // 正式场景不允许继续靠运行时重复节点而“看起来能跑”。
            FormalSceneSingletonConflictDiagnostics.ReportFormalSceneSingletonConflicts($"{nameof(UISystem)}.{nameof(ShowUI)}");
        }

        /// <summary>隐藏 UI 根实例但保留对象，避免面板和对象池状态在同一场景内被反复销毁重建。</summary>
        public void HideUI()
        {
            if (m_uiInstance != null)
            {
                m_uiInstance.SetActive(false);
            }
        }
    }
}
