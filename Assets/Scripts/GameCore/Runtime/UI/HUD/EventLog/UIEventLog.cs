using UnityEngine;
using azixMcAze.SerializableDictionary;
using YokiFrame;

namespace FantasyWord.GameCore
{
    [System.Serializable]
    public struct UIEventSettings
    {
        public bool enabled;
        public string text;
        public Color color;
    }

    public class UIEventLog : MonoBehaviour
    {
        // Inspector Settings
        [Header("Global Parameters")]
        [SerializeField] private float m_logDuration = 3.0f;
        [SerializeField] private float m_characterTypingDuration = 0.025f;
        [SerializeField] private int m_linePoolSize = 5;
        [SerializeField] private GameObject m_linePrefab = null;
        [SerializeField] private SerializableHashSet<EItemTransferType> m_itemTransferTypesToLog = null;

        [Header("Event Settings")]
        [SerializeField] private UIEventSettings m_experienceAdded;
        [SerializeField] private UIEventSettings m_levelUp;
        [SerializeField] private UIEventSettings m_moneyAdded;
        [SerializeField] private UIEventSettings m_moneyRemoved;
        [SerializeField] private UIEventSettings m_itemAdded;
        [SerializeField] private UIEventSettings m_itemRemoved;
        [SerializeField] private UIEventSettings m_abilityAdded;
        [SerializeField] private UIEventSettings m_abilityRemoved;
        [SerializeField] private UIEventSettings m_questStarted;
        [SerializeField] private UIEventSettings m_questUpdated;
        [SerializeField] private UIEventSettings m_questCompleted;

        private UIEventLogLine[] m_lines = null;

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

        private void OnDestroy()
        {
            ReturnLines();
        }

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

        private bool ShouldLog(InventoryOwnerHandle owner, EItemTransferType transferType) =>
            IsPlayerVisibleInventoryOwner(owner) && m_itemTransferTypesToLog.Contains(transferType);

        private static bool IsPlayerVisibleInventoryOwner(InventoryOwnerHandle owner)
        {
            return owner.Kind == EInventoryOwnerKind.Party || owner.Kind == EInventoryOwnerKind.Character;
        }

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
                    Debug.LogError("No available line, consider expanding the pool");
                }
            }
        }

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

        private void ConfigureLinePool()
        {
            if (m_linePrefab == null)
            {
                return;
            }

            GameObjectPoolService.SetMaxCapacity(m_linePrefab, m_linePoolSize);
            GameObjectPoolService.Prewarm(m_linePrefab, m_linePoolSize);
        }

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
    }
}
