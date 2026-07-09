using System.Collections.Generic;
using System.Linq;
using TMPro;
using UnityEngine;
using azixMcAze.SerializableDictionary;
using YokiFrame;

namespace FantasyWord.GameCore
{
    public enum EAbilityType
    {
        Passive,
        Active
    }

    public class UIAbilities : UIKitMenuPanelBase, IAbilityMenuEventReceiver
    {
        [Header("References")]
        [SerializeField] private GameObject m_abilityBarEntryPrefab = null;
        [SerializeField] private GameObject m_abilityListRoot = null;
        [SerializeField] private CanvasGroup m_listCanvasGroup = null;
        [SerializeField] private TextMeshProUGUI m_description = null;
        [SerializeField] private UIAbilityBar m_abilityBar = null;
        [SerializeField] private SerializableDictionary<EAbilityType, UIAbilityCategory> m_categories = null;
        [SerializeField] private List<GameObject> m_toEnableWhenEquippingAnAbility = null;
        [SerializeField] private int m_abilityListEntryPoolSize = 16;

        [Header("Settings")]
        [SerializeField][TextArea] private string m_activeAbilityDescription;
        [SerializeField][TextArea] private string m_passiveAbilityDescription;

        private UIAbilityListEntry[] m_entries = System.Array.Empty<UIAbilityListEntry>();
        private UIAbilityListEntry m_abilitySelected = null;
        private CharacterBase m_currentCharacter = null;
        private CharacterMenuContext m_context = CharacterMenuContext.CurrentControlledCharacter();
        private EAbilityType m_selectedCategory = EAbilityType.Active;
        private readonly List<GameObject> m_activeAbilityEntries = new();

        protected override bool HandleBackRequested()
        {
            if (m_abilitySelected != null)
            {
                ExitEquipMode(m_abilitySelected);
                return true;
            }

            return false;
        }

        protected override void OnPanelInit()
        {
            ConfigureAbilityEntryPool();
            GameManager.PlayerSystem.AddCurrentControlledCharacterChangedListener(OnCurrentControlledCharacterChanged);
            BindCharacter(m_context.ResolveActor());
        }

        private void OnDestroy()
        {
            if (GameManager.Exists() && GameManager.HasSystem<PlayerSystem>())
            {
                GameManager.PlayerSystem.RemoveCurrentControlledCharacterChangedListener(OnCurrentControlledCharacterChanged);
            }

            ReturnAbilityEntries();
        }

        private int GetAbilityCount(EAbilityType type)
        {
            if (m_currentCharacter == null)
            {
                return 0;
            }

            return
                type == EAbilityType.Active ?
                m_currentCharacter.GetActiveAbilityMenuEntrySnapshots().Length :
                0;
        }

        protected override GameObject ResolveDefaultFocusTarget()
        {
            foreach (UIAbilityListEntry entry in m_entries)
            {
                if (entry != null)
                {
                    return entry.gameObject;
                }
            }

            return base.ResolveDefaultFocusTarget();
        }

        protected override void OnPanelShown(UIKitMenuOpenData openData)
        {
            m_context = TryResolveCharacterMenuContext(openData, out CharacterMenuContext context)
                ? context
                : CharacterMenuContext.CurrentControlledCharacter();
            m_abilityBar.Init();
            BindCharacter(m_context.ResolveActor());
            if (m_context.FollowsCurrentControlledCharacter)
            {
                m_abilityBar.FollowCurrentControlledCharacter();
            }
            else
            {
                m_abilityBar.PresentCharacter(m_currentCharacter);
            }
            m_abilityBar.UpdateUI();
            SelectCategory(m_selectedCategory);
            UpdateUI();
        }

        protected override void OnPanelHidden()
        {
            ExitEquipMode();
        }

        private void UpdateUI()
        {
            foreach (var category in m_categories)
            {
                category.Value.SetCategory(category.Key, GetAbilityCount(category.Key));
            }
        }

        private void ClearSpellBookList() => ReturnAbilityEntries();

        private void FillSpellBookList(EAbilityType type = EAbilityType.Active)
        {
            CharacterAbilityMenuEntry[] abilities =
                m_currentCharacter == null ?
                System.Array.Empty<CharacterAbilityMenuEntry>() :
                type == EAbilityType.Active ?
                m_currentCharacter.GetActiveAbilityMenuEntrySnapshots() :
                System.Array.Empty<CharacterAbilityMenuEntry>();

            m_entries = new UIAbilityListEntry[abilities.Length];

            for (int i = 0; i < abilities.Length; ++i)
            {
                CharacterAbilityMenuEntry ability = abilities[i];

                GameObject entryInstance = GameObjectPoolService.Rent(m_abilityBarEntryPrefab, m_abilityListRoot.transform);
                if (entryInstance == null)
                {
                    Debug.LogWarning("没有可用的能力列表条目实例，请检查能力列表对象池容量。", this);
                    continue;
                }

                if (!entryInstance.TryGetComponent(out UIAbilityListEntry entry))
                {
                    Debug.LogError("能力列表条目预制体缺少 UIAbilityListEntry 组件。", entryInstance);
                    GameObjectPoolService.Return(entryInstance);
                    continue;
                }

                entry.Initialize(ability, type);
                m_entries[i] = entry;
                m_activeAbilityEntries.Add(entryInstance);
            }
        }

        private void EnterEquipMode(UIAbilityListEntry ability)
        {
            m_abilitySelected = ability;

            if (!GameManager.InputSystem.IsPointerActive(EActionMap.UI))
            {
                m_abilityBar.SelectFirstElement();
            }

            m_toEnableWhenEquippingAnAbility.ForEach(go => go.SetActive(true));
            m_listCanvasGroup.interactable = false;
        }

        private void ExitEquipMode(UIAbilityListEntry toSelect = null)
        {
            m_toEnableWhenEquippingAnAbility.ForEach(go => go.SetActive(false));
            m_abilitySelected = null;
            m_listCanvasGroup.interactable = true;

            if (toSelect != null && !GameManager.InputSystem.IsPointerActive(EActionMap.UI))
            {
                toSelect.ForceSelection();
            }
        }

        public void HandleAbilityHovered(CharacterAbilityMenuEntry entry)
        {
            if (!entry.HasDisplaySource)
            {
                HandleNullAbilityHovered();
                return;
            }

            List<AbilityDescriptionLine> lines = new();
            entry.GenerateAdditionalDescriptionLines(lines);
            SetAbilityDescriptionText(entry.Description, lines);
        }

        public void HandleAbilityHovered(CharacterEquippedAbilitySlotView slot)
        {
            if (!slot.HasDisplaySource)
            {
                HandleNullAbilityHovered();
                return;
            }

            List<AbilityDescriptionLine> lines = new();
            if (slot.HasFormalGasAbility)
            {
                FormalGasAbilityDescriptionResolver.TryAppendFormalDamageLines(slot.FormalGasAbilityCode, lines);
            }

            SetAbilityDescriptionText(slot.Description, lines);
        }

        private void SetAbilityDescriptionText(string description, List<AbilityDescriptionLine> lines)
        {
            m_description.text = description ?? string.Empty;

            // 额外说明和主描述之间保留一行空白，避免菜单文本粘连。
            if (lines.Count > 0)
            {
                m_description.text += "\n";
            }

            foreach (var line in lines)
            {
                string header = !string.IsNullOrEmpty(line.header) ? $"<u>{line.header}</u>: " : string.Empty;
                m_description.text += $"\n{header}{line.content}";
            }
        }

        public void HandleNullAbilityHovered()
        {
            m_description.text = string.Empty;
        }

        public void HandleAbilitySelectedFromList(UIAbilityListEntry ability) => EnterEquipMode(ability);

        public void HandleAbilityCategorySelected(EAbilityType type) => SelectCategory(type);

        private void SelectCategory(EAbilityType type)
        {
            m_selectedCategory = type;

            foreach (var entry in m_categories)
            {
                entry.Value.SetHighlight(false);
            }

            m_categories[type].SetHighlight(true);

            ClearSpellBookList();
            FillSpellBookList(type);
        }

        public void HandleAbilityCategoryHovered(EAbilityType type)
        {
            m_description.text =
                type == EAbilityType.Active ?
                m_activeAbilityDescription :
                m_passiveAbilityDescription;
        }

        public void HandleAbilitySlotClicked(int abilityIndex)
        {
            if (m_currentCharacter == null)
            {
                return;
            }

            if (m_abilitySelected == null)
            {
                m_currentCharacter.ClearEquippedAbilitySlot(abilityIndex);
            }
            else
            {
                CharacterAbilityMenuEntry ability = m_abilitySelected.GetTarget();
                if (ability.HasFormalGasAbility)
                {
                    m_currentCharacter.TryEquipFormalGasAbilityCodeToSlot(ability.FormalGasAbilityCode, abilityIndex);
                }
                ExitEquipMode(m_abilitySelected);
            }
        }

        private void OnCurrentControlledCharacterChanged(CharacterBase character)
        {
            if (m_context.FollowsCurrentControlledCharacter)
            {
                BindCharacter(m_context.ResolveActor());
            }
        }

        private void BindCharacter(CharacterBase character)
        {
            if (ReferenceEquals(m_currentCharacter, character))
            {
                return;
            }

            m_currentCharacter = character;

            if (!gameObject.activeInHierarchy)
            {
                return;
            }

            ExitEquipMode();
            SelectCategory(m_selectedCategory);
            UpdateUI();
        }

        private static bool TryResolveCharacterMenuContext(UIKitMenuOpenData openData, out CharacterMenuContext context)
        {
            context = CharacterMenuContext.CurrentControlledCharacter();
            if (openData == null || openData.ArgumentCount != 1)
            {
                return false;
            }

            return openData.TryGetArgument(0, out context);
        }

        private void ConfigureAbilityEntryPool()
        {
            if (m_abilityBarEntryPrefab == null)
            {
                return;
            }

            GameObjectPoolService.SetMaxCapacity(m_abilityBarEntryPrefab, m_abilityListEntryPoolSize);
            GameObjectPoolService.Prewarm(m_abilityBarEntryPrefab, m_abilityListEntryPoolSize);
        }

        private void ReturnAbilityEntries()
        {
            foreach (GameObject entry in m_activeAbilityEntries)
            {
                if (entry)
                {
                    GameObjectPoolService.Return(entry);
                }
            }

            m_activeAbilityEntries.Clear();
            m_entries = System.Array.Empty<UIAbilityListEntry>();
        }
    }
}

