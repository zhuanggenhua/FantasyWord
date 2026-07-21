using Sirenix.OdinInspector;
using TMPro;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 暂停菜单中的单个入口。
    /// 它负责焦点提示、把选中状态回传给父菜单，并在点击时转成具体菜单请求。
    /// </summary>
    public class UIGameMenuEntry : MonoBehaviour, ISelectHandler, IDeselectHandler
    {
        /// <summary>
        /// 暂停菜单入口可触发的动作。枚举值会暴露给内容作者配置，所以每个选项都提供中文显示名。
        /// </summary>
        public enum EGameMenuAction
        {
            [LabelText("无动作")]
            None,

            [LabelText("打开背包")]
            OpenInventory,

            [LabelText("打开日志")]
            OpenJournal,

            [LabelText("打开存档菜单")]
            OpenSaveMenu,

            [LabelText("打开能力菜单")]
            OpenAbilities,

            [LabelText("打开角色菜单")]
            OpenCharacter,

            [LabelText("打开随身制作")]
            OpenCraft,

            [LabelText("打开设置")]
            OpenSettings,

            [LabelText("返回主菜单")]
            GoToMainMenu
        }

        [SerializeField]
        [LabelText("菜单动作")]
        [Tooltip("点击该条目时执行的菜单动作。")]
        private EGameMenuAction m_action = EGameMenuAction.None;

        [SerializeField]
        [LabelText("按钮")]
        [Tooltip("接收点击和焦点的按钮。")]
        private Button m_button = null;

        [SerializeField]
        [LabelText("文本")]
        [Tooltip("条目选中时显示的文本提示。")]
        private TextMeshProUGUI m_text = null;

        private UIGameMenu m_menu = null;

        /// <summary>缓存父级暂停菜单并注册按钮点击；随身制作入口缺少默认制作台时直接隐藏该项。</summary>
        private void Awake()
        {
            m_menu = GetComponentInParent<UIGameMenu>();
            Debug.Assert(m_menu != null, $"{nameof(UIGameMenuEntry)} requires a parent {nameof(UIGameMenu)}.");
            m_button.onClick.AddListener(OnButtonClicked);
            m_text.enabled = false;

            // 没有默认随身制作台时，制作入口没有可打开的真相源，直接隐藏该菜单项。
            if (m_action == EGameMenuAction.OpenCraft && GameManager.Config.onTheGoCraftingStation == null)
            {
                gameObject.SetActive(false);
            }
        }

        /// <summary>销毁时注销点击回调，避免按钮继续引用已经卸载的菜单入口。</summary>
        private void OnDestroy()
        {
            if (m_button)
            {
                m_button.onClick.RemoveListener(OnButtonClicked);
            }
        }

        /// <summary>失去焦点时隐藏该入口的文本提示。</summary>
        public void OnDeselect(BaseEventData eventData)
        {
            m_text.enabled = false;
        }

        /// <summary>获得焦点时显示文本提示，并通知父菜单记录最近选中的入口。</summary>
        public void OnSelect(BaseEventData eventData)
        {
            m_text.enabled = true;
            m_menu.HandleGameMenuEntrySelected(this);
        }

        /// <summary>返回可被菜单系统聚焦的按钮对象；按钮缺失时退回当前节点，便于暴露配置问题。</summary>
        internal GameObject GetFocusTarget() => m_button != null ? m_button.gameObject : gameObject;

        /// <summary>把作者配置的菜单动作转换成游戏运行时菜单请求，不在入口里直接持有目标菜单状态。</summary>
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
                    GameRuntimeEvents.RequestReturnToMainMenu();
                    break;
            }
        }
    }
}
