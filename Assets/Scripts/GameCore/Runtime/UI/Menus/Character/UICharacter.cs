using Sirenix.OdinInspector;
using TMPro;
using UnityEngine;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 角色菜单主面板，负责展示角色职业、等级、经验、自由属性点、货币和属性加点预览。
    /// 面板只维护本次打开期间的临时加点，真正写回角色必须通过 <see cref="Apply"/>。
    /// </summary>
    public class UICharacter : UIKitMenuPanelBase
    {
        #region Inspector 配置

        [Header("角色面板引用")]
        [SerializeField]
        [LabelText("职业文本"), Tooltip("显示角色配置表里的职业或名称。")]
        private TextMeshProUGUI m_class = null;

        [SerializeField]
        [LabelText("等级文本"), Tooltip("显示当前角色等级。")]
        private TextMeshProUGUI m_level = null;

        [SerializeField]
        [LabelText("经验文本"), Tooltip("显示距离下一级还需要的经验值。")]
        private TextMeshProUGUI m_experience = null;

        [SerializeField]
        [LabelText("自由属性点文本"), Tooltip("显示当前仍可分配的属性点数量。")]
        private TextMeshProUGUI m_skillPoints = null;

        [SerializeField]
        [LabelText("货币文本"), Tooltip("显示背包系统当前持有的货币数量。")]
        private TextMeshProUGUI m_currency = null;

        [SerializeField]
        [LabelText("属性行列表"), Tooltip("每一行负责展示一个属性，并接收本面板的加减点回调。")]
        private UICharacterStat[] m_stats = null;

        [SerializeField]
        [LabelText("应用按钮文本"), Tooltip("显示本次临时加点数量，点击按钮后才会写回角色。")]
        private TextMeshProUGUI m_applyButtonText = null;

        #endregion

        private CharacterActor m_currentCharacter = null;
        private CharacterMenuContext m_context = CharacterMenuContext.CurrentControlledCharacter();
        private bool m_currentControlledCharacterListening = false;

        // 本次打开期间的临时属性点，不直接改角色，方便玩家撤销单个属性点。
        private Stats m_tempStats;
        private int m_availablePoints = 0;
        private int m_totalAvailablePoints = 0;

        #region 面板生命周期

        /// <summary>初始化属性行按钮回调；回调只登记一次，具体角色会在显示阶段绑定。</summary>
        protected override void OnPanelInit()
        {
            foreach (UICharacterStat stat in m_stats)
            {
                stat.RegisterCallbacks(OnRemoveButtonPressed, OnAddButtonPressed);
            }
        }

        /// <summary>销毁时移除玩家系统监听和按钮回调，避免菜单关闭后继续收到事件。</summary>
        private void OnDestroy()
        {
            StopCurrentControlledCharacterListening();
            foreach (UICharacterStat stat in m_stats)
            {
                stat.UnregisterCallbacks();
            }
        }

        /// <summary>解析打开参数；没有传入上下文时默认跟随当前控制角色。</summary>
        protected override void OnPanelOpened(UIKitMenuOpenData openData)
        {
            m_context = TryResolveCharacterMenuContext(openData, out CharacterMenuContext context)
                ? context
                : CharacterMenuContext.CurrentControlledCharacter();
        }

        /// <summary>面板显示时绑定目标角色，并重置本次打开期间的临时加点状态。</summary>
        protected override void OnPanelShown(UIKitMenuOpenData openData)
        {
            BindCurrentControlledCharacterListenerForContext();
            BindCharacter(m_context.ResolveActor() as CharacterActor);
            m_tempStats = new();
            m_availablePoints = m_currentCharacter != null ? m_currentCharacter.availablePoints : 0;
            m_totalAvailablePoints = m_availablePoints;
            UpdateUI();
        }

        /// <summary>面板隐藏后停止监听当前控制角色变化，并清空临时 UI 状态。</summary>
        protected override void OnPanelHidden()
        {
            StopCurrentControlledCharacterListening();
            ClearPanelState();
        }

        #endregion

        #region 加点应用与刷新

        /// <summary>
        /// 将本次临时分配的属性点写回当前角色。
        /// 只有存在可写入角色且临时点数大于 0 时才记录消耗并应用，避免空点按钮改变角色状态。
        /// </summary>
        public void Apply()
        {
            if (m_currentCharacter != null && m_tempStats.GetTotal() > 0)
            {
                m_currentCharacter.LogUsedPoints(m_totalAvailablePoints - m_availablePoints);
                m_totalAvailablePoints = m_availablePoints;
                m_currentCharacter.AddCustomStats(m_tempStats);
                m_tempStats = new();

                UpdateUI();
            }
        }

        /// <summary>默认焦点落到第一条属性行，保证手柄/键盘打开菜单后能直接调整属性。</summary>
        protected override GameObject ResolveDefaultFocusTarget()
        {
            return m_stats.Length > 0 ? m_stats[0].GetDefaultFocusTarget() : base.ResolveDefaultFocusTarget();
        }

        /// <summary>刷新角色信息、属性行和应用按钮文本。</summary>
        private void UpdateUI()
        {
            UpdateInfoSection();
            UpdateStatsSection();
            m_applyButtonText.text = $"应用 {m_tempStats.GetTotal()} 点";
        }

        /// <summary>刷新角色基础信息；没有绑定角色时清空角色相关文本，但仍显示全局货币。</summary>
        private void UpdateInfoSection()
        {
            if (m_currentCharacter == null)
            {
                m_class.text = string.Empty;
                m_level.text = string.Empty;
                m_experience.text = string.Empty;
                m_skillPoints.text = "0";
                m_currency.text = StringFormatter.Format("{0}", GameManager.InventorySystem.money.ToString());
                return;
            }

            m_class.text = m_currentCharacter.characterSheet.displayName;
            m_level.text = m_currentCharacter.level.ToString();
            m_experience.text = StringFormatter.Format("{0}", m_currentCharacter.nextLevelExperience - m_currentCharacter.experience);
            m_skillPoints.text = m_availablePoints.ToString();
            m_currency.text = StringFormatter.Format("{0}", GameManager.InventorySystem.money.ToString());
        }

        /// <summary>把当前角色和临时加点转发给每条属性行，由属性行决定最终显示格式。</summary>
        private void UpdateStatsSection()
        {
            foreach (UICharacterStat stat in m_stats)
            {
                stat.UpdateUI(m_currentCharacter, m_tempStats);
            }
        }

        #endregion

        #region 属性加减

        /// <summary>尝试给指定属性加 1 点；没有角色或没有可用点数时保持 UI 状态不变。</summary>
        public void OnAddButtonPressed(EStat stat)
        {
            if (m_currentCharacter != null && m_availablePoints > 0)
            {
                m_tempStats[stat] += 1;
                --m_availablePoints;
                UpdateUI();
            }
        }

        /// <summary>尝试撤回指定属性的 1 个临时点数；已写回的点数不会被这里回退。</summary>
        public void OnRemoveButtonPressed(EStat stat)
        {
            if (m_currentCharacter != null && m_tempStats[stat] > 0)
            {
                m_tempStats[stat] -= 1;
                ++m_availablePoints;
                UpdateUI();
            }
        }

        #endregion

        #region 当前控制角色监听

        /// <summary>当前控制角色变化时，仅跟随模式需要重新绑定目标角色。</summary>
        private void OnCurrentControlledCharacterChanged(CharacterBase character)
        {
            if (m_context.FollowsCurrentControlledCharacter)
            {
                BindCharacter(m_context.ResolveActor() as CharacterActor);
            }
        }

        /// <summary>按打开上下文决定是否监听玩家系统的当前控制角色变化。</summary>
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

        /// <summary>玩家系统存在时才登记监听；系统还未就绪时保持静默，避免菜单初始化阶段误报。</summary>
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

        /// <summary>移除当前控制角色监听；玩家系统已销毁时只清理本地监听标记。</summary>
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

        #region 角色绑定与上下文

        /// <summary>绑定新的角色目标，并在面板可见时重置临时加点后刷新显示。</summary>
        private void BindCharacter(CharacterActor character)
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

            m_tempStats ??= new Stats();
            m_tempStats = new Stats();
            m_availablePoints = m_currentCharacter != null ? m_currentCharacter.availablePoints : 0;
            m_totalAvailablePoints = m_availablePoints;
            UpdateUI();
        }

        /// <summary>清理面板运行时状态；这里只影响 UI 缓存，不会回写角色属性。</summary>
        private void ClearPanelState()
        {
            m_currentCharacter = null;
            m_tempStats = new Stats();
            m_availablePoints = 0;
            m_totalAvailablePoints = 0;
        }

        /// <summary>从菜单打开参数中读取角色菜单上下文；参数数量不匹配时回到默认跟随模式。</summary>
        private static bool TryResolveCharacterMenuContext(UIKitMenuOpenData openData, out CharacterMenuContext context)
        {
            context = CharacterMenuContext.CurrentControlledCharacter();
            if (openData == null || openData.ArgumentCount != 1)
            {
                return false;
            }

            return openData.TryGetArgument(0, out context);
        }

        #endregion
    }
}
