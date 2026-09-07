using Sirenix.OdinInspector;
using UnityEngine;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 背包菜单主面板，协调装备栏、背包格子和属性摘要三块 UI。
    /// 打开时可以跟随当前控制角色，也可以接收外部传入的 `InventoryMenuContext` 进入物品转移模式。
    /// </summary>
    public class UIInventory : UIKitMenuPanelBase, IInventoryBagItemClickHandler
    {
        #region Inspector 配置

        [Header("背包界面引用")]
        [SerializeField]
        [LabelText("装备栏面板"), Tooltip("显示角色当前装备槽，并负责装备格子的导航入口。")]
        private UIInventoryEquipment m_equipment = null;

        [SerializeField]
        [LabelText("背包格子面板"), Tooltip("显示当前背包 owner 的物品格子，并把物品点击回调给本面板。")]
        private UIInventoryBag m_bag = null;

        [SerializeField]
        [LabelText("属性摘要面板"), Tooltip("显示当前角色装备影响后的属性摘要。")]
        private UIInventoryStats m_stats = null;

        #endregion

        /// <summary>当前背包菜单上下文；默认跟随当前控制角色。</summary>
        private InventoryMenuContext m_context = InventoryMenuContext.CurrentControlledCharacter();

        /// <summary>是否已经监听当前控制角色变化，防止面板反复显示时重复注册。</summary>
        private bool m_currentControlledCharacterListening = false;

        #region 面板生命周期

        /// <summary>初始化子背包面板，缓存格子和分类按钮配置。</summary>
        protected override void OnPanelInit()
        {
            m_bag.Init();
        }

        /// <summary>销毁面板时退订当前控制角色变化，避免全局 PlayerSystem 持有旧 UI 引用。</summary>
        private void OnDestroy()
        {
            StopCurrentControlledCharacterListening();
        }

        /// <summary>
        /// 解析打开参数里的背包上下文。
        /// 没有传参时回到当前控制角色模式，这是主菜单打开背包的默认入口。
        /// </summary>
        protected override void OnPanelOpened(UIKitMenuOpenData openData)
        {
            m_context = TryResolveInventoryContext(openData, out InventoryMenuContext context)
                ? context
                : InventoryMenuContext.CurrentControlledCharacter();
        }

        /// <summary>面板显示时按上下文注册角色变化监听，并刷新三块 UI。</summary>
        protected override void OnPanelShown(UIKitMenuOpenData openData)
        {
            BindCurrentControlledCharacterListenerForContext();
            UpdateUI();
        }

        /// <summary>隐藏时停止监听，避免后台角色切换继续刷新不可见 UI。</summary>
        protected override void OnPanelHidden()
        {
            StopCurrentControlledCharacterListening();
        }

        #endregion

        #region UI 刷新与焦点

        /// <summary>优先把默认焦点放到背包首格；背包没有可用目标时回退到装备栏。</summary>
        protected override GameObject ResolveDefaultFocusTarget()
        {
            UINavigationCursorTarget bagNavigationTarget = m_bag.FindNavigationTarget();

            if (bagNavigationTarget && bagNavigationTarget.gameObject.activeInHierarchy)
            {
                return bagNavigationTarget.gameObject;
            }
            else
            {
                UINavigationCursorTarget equipmentNavigationTarget = m_equipment.FindNavigationTarget();

                if (equipmentNavigationTarget && equipmentNavigationTarget.isActiveAndEnabled)
                {
                    return equipmentNavigationTarget.gameObject;
                }
            }

            return null;
        }

        /// <summary>
        /// 按当前上下文刷新背包、装备和属性摘要。
        /// 子节点现在通过显式父级方法回调这里，不再依赖 SendMessageUpwards 字符串传播。
        /// </summary>
        private void UpdateUI()
        {
            CharacterBase actor = m_context.ResolveActor();
            InventoryOwnerHandle displayOwner = m_context.ResolveDisplayOwner();

            m_bag.UpdateSlots(displayOwner);
            m_equipment.UpdateSlots(actor);
            m_stats.UpdateUI(actor);
        }

        #endregion

        #region 物品点击处理

        /// <summary>统一收口背包格和装备格点击，交给面板任务包装器处理异步反馈。</summary>
        private void OnItemClicked(Item item, EItemLocation location)
        {
            RunPanelTaskAndReport(OnItemClickedAsync(item, location), nameof(OnItemClicked));
        }

        /// <summary>
        /// 处理物品点击。
        /// 转移模式只允许从背包格转移 1 个物品；使用模式则调用物品自己的 Use 入口。
        /// </summary>
        private async System.Threading.Tasks.Task OnItemClickedAsync(Item item, EItemLocation location)
        {
            CharacterBase actor = m_context.ResolveActor();
            if (actor == null)
            {
                return;
            }

            if (m_context.Mode == EInventoryMenuMode.TransferToDestination && location == EItemLocation.Bag)
            {
                InventoryTransferResult result = GameManager.InventorySystem.ExecuteTransfer(
                    m_context.CreateTransferRequest(item, 1));

                if (result.Succeeded)
                {
                    UpdateUI();
                }
                else
                {
                    Debug.LogWarning($"背包物品转移失败：{result.FailureReason}", this);
                    string prompt = result.FailureReason switch
                    {
                        EInventoryTransferFailureReason.ActorNotParticipant =>
                            MenuFeedbackPrompts.InventoryTransferActorNotParticipant,
                        EInventoryTransferFailureReason.ActorActionLocked =>
                            MenuFeedbackPrompts.InventoryTransferActionLocked,
                        _ => MenuFeedbackPrompts.InventoryTransferFailed
                    };
                    await GameManager.DialogueSystem.PlayNow(prompt, item.displayName);
                }

                return;
            }

            if (m_context.Mode != EInventoryMenuMode.UseOwnerItems)
            {
                return;
            }

            CharacterBase target = ResolveItemUseTarget(actor, item);
            await item.Use(actor, target, location);
            UpdateUI();
        }

        /// <summary>背包格点击入口；物品位置固定为背包。</summary>
        public void HandleBagItemClicked(Item item) => OnItemClicked(item, EItemLocation.Bag);

        /// <summary>装备格点击入口；物品位置固定为装备栏。</summary>
        public void HandleEquipmentItemClicked(Item item) => OnItemClicked(item, EItemLocation.Equipment);

        #endregion

        #region 当前控制角色监听

        /// <summary>跟随当前控制角色的上下文中，角色切换会立即刷新背包展示。</summary>
        private void OnCurrentControlledCharacterChanged(CharacterBase character)
        {
            if (m_context.FollowsCurrentControlledCharacter && gameObject.activeInHierarchy)
            {
                UpdateUI();
            }
        }

        /// <summary>根据当前上下文决定是否监听 PlayerSystem 的当前控制角色变化。</summary>
        private void BindCurrentControlledCharacterListenerForContext()
        {
            if (m_context.FollowsCurrentControlledCharacter)
            {
                StartCurrentControlledCharacterListeningIfReady();
            }
            else
            {
                StopCurrentControlledCharacterListening();
            }
        }

        /// <summary>PlayerSystem 尚未存在时不注册监听；面板下次显示会重新尝试。</summary>
        private void StartCurrentControlledCharacterListeningIfReady()
        {
            if (m_currentControlledCharacterListening)
            {
                return;
            }

            if (!GameManager.Exists() || !GameManager.HasSystem<PlayerSystem>())
            {
                return;
            }

            m_currentControlledCharacterListening = true;
            GameManager.PlayerSystem.AddCurrentControlledCharacterChangedListener(OnCurrentControlledCharacterChanged);
        }

        /// <summary>对称移除当前控制角色监听；GameManager 已销毁时只清本地标记。</summary>
        private void StopCurrentControlledCharacterListening()
        {
            if (!m_currentControlledCharacterListening)
            {
                return;
            }

            m_currentControlledCharacterListening = false;
            if (GameManager.Exists() && GameManager.HasSystem<PlayerSystem>())
            {
                GameManager.PlayerSystem.RemoveCurrentControlledCharacterChangedListener(OnCurrentControlledCharacterChanged);
            }
        }

        #endregion

        #region 上下文解析

        /// <summary>从菜单打开参数读取背包上下文；参数不完整时让调用方回退默认上下文。</summary>
        private static bool TryResolveInventoryContext(UIKitMenuOpenData openData, out InventoryMenuContext context)
        {
            context = InventoryMenuContext.CurrentControlledCharacter();
            if (openData == null || openData.ArgumentCount != 1)
            {
                return false;
            }

            return openData.TryGetArgument(0, out context);
        }

        /// <summary>
        /// 解析物品使用目标。
        /// 当前阶段物品默认作用于操作者自身，后续若做队友目标选择应从这里扩展。
        /// </summary>
        private static CharacterBase ResolveItemUseTarget(CharacterBase actor, Item item)
        {
            if (actor == null)
            {
                return null;
            }

            return actor;
        }

        #endregion
    }
}
