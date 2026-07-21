using UnityEngine;
using azixMcAze.SerializableDictionary;
using Sirenix.OdinInspector;
using YokiFrame;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 单类事件日志的显示配置。
    /// </summary>
    [System.Serializable]
    public struct UIEventSettings
    {
        [LabelText("启用"), Tooltip("是否显示这类事件日志。")]
        public bool enabled;

        [LabelText("文本模板"), Tooltip("事件日志文本模板，参数由对应事件处理函数传入。")]
        public string text;

        [LabelText("颜色"), Tooltip("这类事件日志显示时使用的文本颜色。")]
        public Color color;
    }

    /// <summary>
    /// HUD 事件日志面板，监听经验、背包、能力和任务事件并复用日志行展示短提示。
    /// </summary>
    public class UIEventLog : MonoBehaviour
    {
        #region Inspector 配置

        [Header("全局参数")]
        [SerializeField, Min(0f)]
        [LabelText("日志停留时长"), Tooltip("单条日志完整显示后的停留秒数。")]
        private float m_logDuration = 3.0f;

        [SerializeField, Min(0f)]
        [LabelText("单字打字时长"), Tooltip("日志逐字出现时，每个非空白字符的显示间隔秒数。")]
        private float m_characterTypingDuration = 0.025f;

        [SerializeField, Min(1)]
        [LabelText("日志行池大小"), Tooltip("事件日志最多同时保留的行数，超出后复用最早一行。")]
        private int m_linePoolSize = 5;

        [SerializeField]
        [LabelText("日志行预制体"), Tooltip("对象池使用的日志行预制体，必须包含 UIEventLogLine。")]
        private GameObject m_linePrefab = null;

        [SerializeField]
        [LabelText("记录的物品转移类型"), Tooltip("只有这些物品转移类型会显示为物品获得/移除日志，未配置会导致物品日志过滤失败。")]
        private SerializableHashSet<EItemTransferType> m_itemTransferTypesToLog = null;

        [Header("事件设置")]
        [SerializeField]
        [LabelText("经验获得日志"), Tooltip("角色获得经验时显示的日志模板配置。")]
        private UIEventSettings m_experienceAdded;

        [SerializeField]
        [LabelText("角色升级日志"), Tooltip("角色升级时显示的日志模板配置。")]
        private UIEventSettings m_levelUp;

        [SerializeField]
        [LabelText("金钱增加日志"), Tooltip("玩家可见背包获得金钱时显示的日志模板配置。")]
        private UIEventSettings m_moneyAdded;

        [SerializeField]
        [LabelText("金钱减少日志"), Tooltip("玩家可见背包失去金钱时显示的日志模板配置。")]
        private UIEventSettings m_moneyRemoved;

        [SerializeField]
        [LabelText("物品获得日志"), Tooltip("玩家可见背包获得物品时显示的日志模板配置。")]
        private UIEventSettings m_itemAdded;

        [SerializeField]
        [LabelText("物品移除日志"), Tooltip("玩家可见背包移除物品时显示的日志模板配置。")]
        private UIEventSettings m_itemRemoved;

        [SerializeField]
        [LabelText("能力获得日志"), Tooltip("角色获得能力时显示的日志模板配置。")]
        private UIEventSettings m_abilityAdded;

        [SerializeField]
        [LabelText("能力移除日志"), Tooltip("角色失去能力时显示的日志模板配置。")]
        private UIEventSettings m_abilityRemoved;

        [SerializeField]
        [LabelText("任务开始日志"), Tooltip("任务开始时显示的日志模板配置。")]
        private UIEventSettings m_questStarted;

        [SerializeField]
        [LabelText("任务更新日志"), Tooltip("任务进度更新时显示的日志模板配置。")]
        private UIEventSettings m_questUpdated;

        [SerializeField]
        [LabelText("任务完成日志"), Tooltip("任务完成时显示的日志模板配置。")]
        private UIEventSettings m_questCompleted;

        #endregion

        /// <summary>对象池租出的日志行缓存；销毁 UI 时必须统一归还，避免池内保留失效实例。</summary>
        private UIEventLogLine[] m_lines = null;

        #region 生命周期

        /// <summary>
        /// 预热事件日志行对象池，并把租出的行初始化为隐藏状态。
        /// 这里要求预制体配置正确，否则事件到达时无法显示日志。
        /// </summary>
        private void Awake()
        {
            ConfigureLinePool();
            m_lines = new UIEventLogLine[m_linePoolSize];

            for (int i = 0; i < m_linePoolSize; ++i)
            {
                GameObject instance = GameObjectPoolService.Rent(m_linePrefab, transform);
                if (instance == null)
                {
                    Debug.LogWarning("没有可用的事件日志行实例，请检查事件日志对象池容量。", this);
                    continue;
                }

                if (!instance.TryGetComponent(out UIEventLogLine line))
                {
                    Debug.LogError($"事件日志行预制体缺少 {nameof(UIEventLogLine)} 组件。", instance);
                    GameObjectPoolService.Return(instance);
                    continue;
                }

                m_lines[i] = line;
                instance.SetActive(false);
            }
        }

        /// <summary>
        /// 事件日志属于纯表现层，订阅周期应与 UI 本身的启停保持一致。
        /// 否则 UI 隐藏后仍继续吃全局日志事件，会留下重复监听或脏状态。
        /// </summary>
        private void OnEnable()
        {
            EventKit.Type.Register<CharacterExperienceGainedEvent>(OnCharacterExperienceGained);
            EventKit.Type.Register<CharacterLevelUpEvent>(OnCharacterLevelUp);
            EventKit.Type.Register<InventoryMoneyAddedEvent>(OnMoneyAdded);
            EventKit.Type.Register<InventoryMoneyRemovedEvent>(OnMoneyRemoved);
            EventKit.Type.Register<InventoryItemAddedEvent>(OnItemAdded);
            EventKit.Type.Register<InventoryItemRemovedEvent>(OnItemRemoved);
            EventKit.Type.Register<CharacterAbilityAddedEvent>(OnAbilityAdded);
            EventKit.Type.Register<CharacterAbilityRemovedEvent>(OnAbilityRemoved);
            EventKit.Type.Register<QuestStartedEvent>(OnQuestStarted);
            EventKit.Type.Register<QuestProgressionUpdatedEvent>(OnQuestUpdated);
            EventKit.Type.Register<QuestCompletedEvent>(OnQuestCompleted);
        }

        /// <summary>禁用时对称退订全局事件，避免 HUD 重新启用后同一条事件被重复写入。</summary>
        private void OnDisable()
        {
            EventKit.Type.UnRegister<CharacterExperienceGainedEvent>(OnCharacterExperienceGained);
            EventKit.Type.UnRegister<CharacterLevelUpEvent>(OnCharacterLevelUp);
            EventKit.Type.UnRegister<InventoryMoneyAddedEvent>(OnMoneyAdded);
            EventKit.Type.UnRegister<InventoryMoneyRemovedEvent>(OnMoneyRemoved);
            EventKit.Type.UnRegister<InventoryItemAddedEvent>(OnItemAdded);
            EventKit.Type.UnRegister<InventoryItemRemovedEvent>(OnItemRemoved);
            EventKit.Type.UnRegister<CharacterAbilityAddedEvent>(OnAbilityAdded);
            EventKit.Type.UnRegister<CharacterAbilityRemovedEvent>(OnAbilityRemoved);
            EventKit.Type.UnRegister<QuestStartedEvent>(OnQuestStarted);
            EventKit.Type.UnRegister<QuestProgressionUpdatedEvent>(OnQuestUpdated);
            EventKit.Type.UnRegister<QuestCompletedEvent>(OnQuestCompleted);
        }

        /// <summary>销毁时归还已租出的日志行；对象池本身由全局池服务维护。</summary>
        private void OnDestroy()
        {
            ReturnLines();
        }

        #endregion

        #region 事件处理

        private void OnCharacterExperienceGained(CharacterExperienceGainedEvent characterExperienceGainedEvent) =>
            OnExperienceGained(characterExperienceGainedEvent.Amount);

        private void OnCharacterLevelUp(CharacterLevelUpEvent characterLevelUpEvent) =>
            OnLevelUp(characterLevelUpEvent.Level);
        private void OnExperienceGained(int experience) => Log(m_experienceAdded, experience);
        private void OnLevelUp(int level) => Log(m_levelUp, level);
        private void OnMoneyAdded(InventoryMoneyAddedEvent inventoryMoneyAddedEvent)
        {
            if (IsPlayerVisibleInventoryOwner(inventoryMoneyAddedEvent.Owner))
            {
                Log(m_moneyAdded, inventoryMoneyAddedEvent.Amount);
            }
        }

        private void OnMoneyRemoved(InventoryMoneyRemovedEvent inventoryMoneyRemovedEvent)
        {
            if (IsPlayerVisibleInventoryOwner(inventoryMoneyRemovedEvent.Owner))
            {
                Log(m_moneyRemoved, inventoryMoneyRemovedEvent.Amount);
            }
        }
        private void OnAbilityAdded(CharacterAbilityAddedEvent abilityAddedEvent) =>
            Log(m_abilityAdded, abilityAddedEvent.DisplayName, ResolveCharacterDisplayName(abilityAddedEvent.Character));

        private void OnAbilityRemoved(CharacterAbilityRemovedEvent abilityRemovedEvent) =>
            Log(m_abilityRemoved, abilityRemovedEvent.DisplayName, ResolveCharacterDisplayName(abilityRemovedEvent.Character));
        private void OnQuestStarted(QuestStartedEvent questStartedEvent) => Log(m_questStarted, questStartedEvent.Quest.title);
        private void OnQuestUpdated(QuestProgressionUpdatedEvent questProgressionUpdatedEvent) => Log(m_questUpdated, questProgressionUpdatedEvent.Quest.title);
        private void OnQuestCompleted(QuestCompletedEvent questCompletedEvent) => Log(m_questCompleted, questCompletedEvent.Quest.title);

        /// <summary>只显示玩家能感知的背包 owner，并继续按配置过滤物品转移类型。</summary>
        private bool ShouldLog(InventoryOwnerHandle owner, EItemTransferType transferType) =>
            IsPlayerVisibleInventoryOwner(owner) && m_itemTransferTypesToLog.Contains(transferType);

        /// <summary>事件日志面向玩家 HUD，只展示队伍或角色背包的变化，避免箱子、商店等系统背包刷屏。</summary>
        private static bool IsPlayerVisibleInventoryOwner(InventoryOwnerHandle owner)
        {
            return owner.Kind == EInventoryOwnerKind.Party || owner.Kind == EInventoryOwnerKind.Character;
        }

        /// <summary>能力日志需要角色名兜底；缺配置时返回可读中文，避免 HUD 暴露空字符串。</summary>
        private static string ResolveCharacterDisplayName(CharacterBase character)
        {
            if (!character)
            {
                return "未知角色";
            }

            return character.characterSheet ? character.characterSheet.displayName : character.name;
        }

        private void OnItemAdded(InventoryItemAddedEvent inventoryItemAddedEvent)
        {
            if (ShouldLog(inventoryItemAddedEvent.Owner, inventoryItemAddedEvent.TransferType))
            {
                Log(m_itemAdded, inventoryItemAddedEvent.Item.displayName, inventoryItemAddedEvent.Quantity);
            }
        }

        private void OnItemRemoved(InventoryItemRemovedEvent inventoryItemRemovedEvent)
        {
            if (ShouldLog(inventoryItemRemovedEvent.Owner, inventoryItemRemovedEvent.TransferType))
            {
                Log(m_itemRemoved, inventoryItemRemovedEvent.Item.displayName, inventoryItemRemovedEvent.Quantity);
            }
        }

        #endregion

        #region 日志输出与对象池

        /// <summary>
        /// 按事件配置格式化并显示一条日志。
        /// 模板参数由具体事件处理器负责传入，模板和参数不匹配时会直接暴露到 HUD 日志链路。
        /// </summary>
        private void Log(UIEventSettings settings, params object[] args)
        {
            if (settings.enabled)
            {
                UIEventLogLine line = FindAvailableLine();

                if (line)
                {
                    line.Show(settings.color, StringFormatter.Format(settings.text, args), m_characterTypingDuration, m_logDuration);
                }
                else
                {
                    Debug.LogError("没有可用的事件日志行，请扩大事件日志行池。", this);
                }
            }
        }

        /// <summary>优先使用空闲日志行；全部占用时复用最早一行，保持 HUD 日志实例数量稳定。</summary>
        private UIEventLogLine FindAvailableLine()
        {
            foreach (UIEventLogLine line in m_lines)
            {
                if (line != null && !line.gameObject.activeSelf)
                {
                    return line;
                }
            }

            // 所有日志行都在显示时复用最早的行，保持事件日志容量固定且不扩张实例数。
            return m_lines.Length > 0 ? m_lines[0] : null;
        }

        /// <summary>按当前配置预热事件日志行对象池，避免第一条日志出现时临时实例化。</summary>
        private void ConfigureLinePool()
        {
            if (m_linePrefab == null)
            {
                return;
            }

            GameObjectPoolService.SetMaxCapacity(m_linePrefab, m_linePoolSize);
            GameObjectPoolService.Prewarm(m_linePrefab, m_linePoolSize);
        }

        /// <summary>销毁 HUD 时把租出的日志行归还池中，避免跨场景池缓存引用旧 UI 层级。</summary>
        private void ReturnLines()
        {
            if (m_lines == null)
            {
                return;
            }

            foreach (UIEventLogLine line in m_lines)
            {
                if (line)
                {
                    GameObjectPoolService.Return(line.gameObject);
                }
            }
        }

        #endregion
    }
}
