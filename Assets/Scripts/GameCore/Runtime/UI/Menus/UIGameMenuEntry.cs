using TMPro;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.SceneManagement;
using UnityEngine.UI;

namespace FantasyWord.GameCore
{
    public class UIGameMenuEntry : MonoBehaviour, ISelectHandler, IDeselectHandler
    {
        public enum EGameMenuAction
        {
            None,
            OpenInventory,
            OpenJournal,
            OpenSaveMenu,
            OpenAbilities,
            OpenCharacter,
            OpenCraft,
            OpenSettings,
            GoToMainMenu
        }

        [Header("Settings")]
        [SerializeField] private EGameMenuAction m_action = EGameMenuAction.None;

        [Header("References")]
        [SerializeField] private Button m_button = null;
        [SerializeField] private TextMeshProUGUI m_text = null;

        private UIGameMenu m_menu = null;

        private void Awake()
        {
            m_menu = GetComponentInParent<UIGameMenu>();
            Debug.Assert(m_menu != null, $"{nameof(UIGameMenuEntry)} requires a parent {nameof(UIGameMenu)}.");
            m_button.onClick.AddListener(OnButtonClicked);
            m_text.enabled = false;

            // Disable this menu entry if no "On The Go" CraftingStation has been provided
            if (m_action == EGameMenuAction.OpenCraft && GameManager.Config.onTheGoCraftingStation == null)
            {
                gameObject.SetActive(false);
            }
        }

        public void OnDeselect(BaseEventData eventData)
        {
            m_text.enabled = false;
        }

        public void OnSelect(BaseEventData eventData)
        {
            m_text.enabled = true;
            m_menu.HandleGameMenuEntrySelected(this);
        }

        internal GameObject GetFocusTarget() => m_button != null ? m_button.gameObject : gameObject;

        private void OnButtonClicked()
        {
            switch (m_action)
            {
                case EGameMenuAction.OpenJournal:
                    GameRuntimeEvents.RequestMenu(EMenu.Journal);
                    break;

                case EGameMenuAction.OpenCharacter:
                    CharacterBase characterMenuActor = GameManager.PlayerSystem.GetCurrentControlledCharacterOrPlayerInstance();
                    GameRuntimeEvents.RequestCharacterMenu(CharacterMenuContext.ViewCharacter(characterMenuActor));
                    break;

                case EGameMenuAction.OpenCraft:
                    Debug.Assert(GameManager.Config.onTheGoCraftingStation != null, "Cannot open the craft menu with a default recipe book defined in the game config!");
                    CharacterBase craftingActor = GameManager.PlayerSystem.GetCurrentControlledCharacterOrPlayerInstance();
                    GameRuntimeEvents.RequestCraft(
                        GameManager.Config.onTheGoCraftingStation,
                        GameCommandContext.ResolveForActor(craftingActor));
                    break;

                case EGameMenuAction.OpenSaveMenu:
                    GameRuntimeEvents.RequestMenu(EMenu.Save);
                    break;

                case EGameMenuAction.OpenInventory:
                    CharacterBase inventoryActor = GameManager.PlayerSystem.GetCurrentControlledCharacterOrPlayerInstance();
                    GameRuntimeEvents.RequestInventory(InventoryMenuContext.ViewCharacter(inventoryActor));
                    break;

                case EGameMenuAction.OpenAbilities:
                    CharacterBase abilitiesMenuActor = GameManager.PlayerSystem.GetCurrentControlledCharacterOrPlayerInstance();
                    GameRuntimeEvents.RequestAbilitiesMenu(CharacterMenuContext.ViewCharacter(abilitiesMenuActor));
                    break;

                case EGameMenuAction.OpenSettings:
                    GameRuntimeEvents.RequestMenu(EMenu.Settings);
                    break;

                case EGameMenuAction.GoToMainMenu:
                    SceneManager.LoadScene(GameManager.Config.mainMenuSceneName);
                    break;
            }
        }
    }
}

