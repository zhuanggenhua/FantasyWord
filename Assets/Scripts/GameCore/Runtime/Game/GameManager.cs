using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.EventSystems;

namespace FantasyWord.GameCore
{
    public partial class GameManager : MonoBehaviour
    {
        // Inspector Settings
        [Header("Global Settings")]
        [SerializeField] private GameConfig m_config = null;

        // Public Static Members
        /// <summary>
        /// 项目侧正式 UI 输入入口。
        /// 除唯一节点诊断和第三方 UIKit 内部实现外，其它 GameCore 代码不再直接读取 EventSystem.current。
        /// </summary>
        public static EventSystem EventSystem => EventSystem.current;
        /// <summary>
        /// 当前正式玩法相机入口。
        /// 现阶段仍跟随 Unity 主相机语义，后续若切到模式相机或多相机入口，只改这里。
        /// </summary>
        public static Camera MainCamera => Camera.main;
        public static GameConfig Config => _instance.m_config;
        public static DatabaseRegistry Database => _instance.m_config.GetDatabaseRegistry();
        public static GameManager Instance => _instance;

        // System Access Shortcuts
        public static AudioSystem AudioSystem => GetSystem<AudioSystem>();
        public static DialogueSystem DialogueSystem => GetSystem<DialogueSystem>();
        public static GameFlagSystem GameFlagSystem => GetSystem<GameFlagSystem>();
        public static GameStateSystem GameStateSystem => GetSystem<GameStateSystem>();
        public static InputSystem InputSystem => GetSystem<InputSystem>();
        public static InventorySystem InventorySystem => GetSystem<InventorySystem>();
        public static JournalSystem JournalSystem => GetSystem<JournalSystem>();
        public static SaveSystem SaveSystem => GetSystem<SaveSystem>();
        public static MapSystem MapSystem => GetSystem<MapSystem>();
        public static PlayerSystem PlayerSystem => GetSystem<PlayerSystem>();
        public static PersistenceSystem PersistenceSystem => GetSystem<PersistenceSystem>();
        public static TransitionSystem TransitionSystem => GetSystem<TransitionSystem>();
        public static UISystem UISystem => GetSystem<UISystem>();

        // Private Static Members
        private static GameManager _instance = null;
        private Dictionary<Type, AGameSystem> m_systems = null;
        private bool m_lifecycleEventsEnabled = false;
        private bool m_startInvoked = false;

        private void Awake()
        {
            FormalAbilityRuntimeBootstrap.EnsureInitialized();
            _instance = this;

            FindSystems();
            InitializeSystems();
        }

        private void OnEnable()
        {
            m_lifecycleEventsEnabled = true;
            if (m_startInvoked)
            {
                StartSystems();
            }
        }

        private void Start()
        {
            m_startInvoked = true;
            StartSystems();
        }

        private void OnDisable()
        {
            if (m_startInvoked)
            {
                StopSystems();
            }

            m_lifecycleEventsEnabled = false;
        }

        public static bool Exists() => _instance;
    }
}

