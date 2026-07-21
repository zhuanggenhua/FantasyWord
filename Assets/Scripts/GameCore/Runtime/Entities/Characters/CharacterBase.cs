using System;
using System.Collections.Generic;
using GAS.Runtime;
using Sirenix.OdinInspector;
using UnityEngine;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 角色基类：所有角色（玩家、NPC、敌人）的抽象基类
    ///
    /// 核心职责：
    /// - 生命周期管理（生成、激活、死亡、复活、销毁）
    /// - 属性系统集成（通过 EX-GAS 的 ASC）
    /// - 行动系统（移动、攻击、受击、死亡动画）
    /// - 装备系统集成
    /// - 伤害与无敌状态管理
    /// - 玩家输入接口（可选）
    ///
    /// 设计说明：
    /// - 继承自 Movable（可移动实体基类）
    /// - 强制依赖 AbilitySystemComponent（EX-GAS 官方组件）
    /// - 强制依赖 CharacterAbilitySet（项目自定义能力封装层）
    /// - 使用 partial class 分离不同职责的代码（见 CharacterBase.*.cs）
    ///
    /// 关键状态：
    /// - dead：角色是否死亡（生命值为 0）
    /// - invincible：是否无敌（包含临时无敌、死亡无敌、动画无敌）
    /// - currentAlignment：当前阵营（可被效果临时覆盖）
    ///
    /// 注意事项：
    /// - OnDisable 可能来自对象池回收、场景切换或读档重建
    /// - 死亡流程可能被延迟处理（等待当前帧的属性变更完成）
    /// - 属性初始化有引导窗口期（m_isAttributeBootstrapReadWindowOpen）
    /// </summary>
    [RequireComponent(typeof(AbilitySystemComponent))]
    [RequireComponent(typeof(CharacterAbilitySet))]
    public abstract partial class CharacterBase : Movable
    {
        [Header("角色基础设置")]
        [SerializeField, Range(Constants.MinLevel, Constants.MaxLevel)]
        [LabelText("初始等级"), Tooltip("角色生成时使用的等级，必须落在项目允许等级范围内。")]
        protected int m_level = Constants.MinLevel;

        [SerializeField]
        [LabelText("受击时无敌"), Tooltip("开启后角色受到有效伤害时进入短暂无敌窗口。")]
        private bool m_invincibleOnHit = false;
        [SerializeField]
        [LabelText("复活时无敌"), Tooltip("开启后角色复活流程完成时进入短暂无敌窗口。")]
        private bool m_invincibleOnRevive = false;
        [SerializeField]
        [LabelText("永久无敌"), Tooltip("调试用永久无敌开关。正式玩法不要依赖它作为状态来源。")]
        private bool m_invincible = false;
        [SerializeField]
        [LabelText("升级恢复生命"), Tooltip("开启后等级提升时把当前生命恢复到新的上限。")]
        private bool m_restoreHealthOnLevelUp = true;
        [SerializeField]
        [LabelText("升级恢复魔法"), Tooltip("开启后等级提升时把当前魔法恢复到新的上限。")]
        private bool m_restoreManaOnLevelUp = true;

        /// <summary>角色配置表（子类必须实现）</summary>
        public abstract CharacterSheet characterSheet { get; }

        /// <summary>是否死亡（生命值为 0）</summary>
        public bool dead => GetCurrentHealth() == 0;

        /// <summary>当前等级</summary>
        public int level => m_level;

        /// <summary>受击时是否无敌</summary>
        public bool invincibleOnHit => m_invincibleOnHit;

        /// <summary>
        /// 当前阵营
        /// 优先使用变更效果的阵营覆盖，其次是运行时覆盖，最后是配置表阵营
        /// </summary>
        public EAlignment currentAlignment =>
            TryResolveAlterationAlignmentOverride(out EAlignment alterationAlignment)
                ? alterationAlignment
                : m_alignmentOverride ?? characterSheet.alignment;

        /// <summary>
        /// 是否无敌（综合判断）
        /// 包含：永久无敌、临时无敌、死亡无敌、动画无敌
        /// </summary>
        public bool invincible => m_invincible
            || m_temporaryInvincibilityTimer > 0.0f
            || dead
            || (m_animationStrategy?.IsInvincibleAnimationPlaying() ?? false);

        // 运行时状态
        private readonly CharacterActionStateRuntime m_actionRuntime = new();
        private readonly AttributeBootstrapBuffer m_attributeBootstrapBuffer = new();

        private EAlignment? m_alignmentOverride = null;                          // 阵营运行时覆盖
        private bool m_isAttributeBootstrapReadWindowOpen = true;                // 属性初始化引导窗口
        private bool m_isDeadAndDestroyed = false;                               // 是否已死亡并销毁
        private float m_temporaryInvincibilityTimer = 0.0f;                      // 临时无敌计时器

        protected bool m_isSummoned = false;                                     // 是否被召唤生成
        private CharacterBase m_lastEffectiveDamageSource = null;                // 最后有效伤害来源
        private bool m_hasDeathCommandContextOverride = false;                   // 是否有死亡命令上下文覆盖
        private GameCommandContext m_deathCommandContextOverride;                // 死亡命令上下文覆盖
        private TerrainSurfaceDamageSystem m_registeredTerrainSurfaceDamageSystem = null;  // 已注册的地形伤害系统
        private bool m_pendingDeathAfterFormalCurrentValueMutation = false;      // 延迟死亡标记（等待属性变更完成）
        private bool m_pendingActionInterruptAfterFormalDamage = false;          // 延迟行动打断标记（等待伤害处理完成）

        /// <summary>
        /// Awake：初始化角色的核心系统
        /// 执行顺序：
        /// 1. 调用基类 Awake（初始化 Movable）
        /// 2. 初始化属性（从配置表读取基础属性）
        /// 3. 初始化能力系统（创建技能实例）
        /// 4. 初始化 EX-GAS 的 ASC（从当前属性创建）
        /// 5. 关闭属性引导窗口
        /// </summary>
        protected override void Awake()
        {
            base.Awake();

            // 开启属性引导窗口，允许子类在此期间读取初始属性
            InitializeStats();
            InitializeAbilities();
            try
            {
                // 将当前属性同步到 EX-GAS 的 ASC
                InitializeFormalAbilitySystemFromCurrentAttributes();
            }
            finally
            {
                // 确保窗口关闭，防止后续错误读取
                CloseAttributeBootstrapReadWindow();
            }
        }

        /// <summary>
        /// OnEnable：激活角色时执行
        /// 可能的触发场景：
        /// - 首次生成
        /// - 对象池取出
        /// - 场景切换后恢复
        /// - 读档恢复
        /// </summary>
        protected override void OnEnable()
        {
            base.OnEnable();

            // 确保 ASC 已初始化（处理特殊情况：OnEnable 早于 Awake）
            EnsureFormalAbilitySystemInitializedAfterAwake();

            // 注册 EX-GAS 属性变化事件
            RegisterFormalAttributeEvents();

            // 注册到地形伤害系统（如毒沼、岩浆）
            TryRegisterTerrainSurfaceDamageTarget();
        }

        /// <summary>
        /// Update：每帧更新
        /// </summary>
        protected override void Update()
        {
            // 再次确保 ASC 已初始化（防御性编程）
            EnsureFormalAbilitySystemInitializedAfterAwake();
            TryRegisterTerrainSurfaceDamageTarget();

            // 处理延迟的行动打断和死亡（等待当前帧的属性变更完成）
            ProcessPendingActionInterruptAfterFormalDamage();
            ProcessPendingDeathAfterFormalCurrentValueMutation();

            // 已销毁的角色不再执行后续逻辑
            if (IsMarkedAsDestroyed())
            {
                return;
            }

            base.Update();
            AdvanceCharacterRuntime(Time.deltaTime);
        }

        /// <summary>
        /// 推进角色运行时系统
        /// 包括：临时无敌计时、能力系统更新、持续效果更新
        /// </summary>
        /// <param name="deltaTime">帧间隔时间</param>
        internal void AdvanceCharacterRuntime(float deltaTime)
        {
            // 先处理延迟的打断和死亡
            ProcessPendingActionInterruptAfterFormalDamage();
            ProcessPendingDeathAfterFormalCurrentValueMutation();
            if (IsMarkedAsDestroyed())
            {
                return;
            }

            float safeDeltaTime = Mathf.Max(0.0f, deltaTime);

            // 更新临时无敌计时器
            m_temporaryInvincibilityTimer = Mathf.Max(0.0f, m_temporaryInvincibilityTimer - safeDeltaTime);

            // 更新能力系统运行时
            AbilityRuntime.UpdateRuntime(safeDeltaTime);

            // 更新持续效果（DOT、HOT 等）
            AdvanceOwnedTemporalEffects(safeDeltaTime);
        }

        /// <summary>
        /// 确保 EX-GAS 的 ASC 已初始化
        /// 这是防御性措施，处理特殊情况（如 OnEnable 早于 Awake）
        /// </summary>
        private void EnsureFormalAbilitySystemInitializedAfterAwake()
        {
            // 如果已初始化，直接返回
            if (TryGetInitializedFormalAttributes(out _))
            {
                return;
            }

            // 重新执行初始化流程
            m_isAttributeBootstrapReadWindowOpen = true;
            InitializeStats();
            InitializeFormalAbilitySystemFromCurrentAttributes();
            CloseAttributeBootstrapReadWindow();
        }

        /// <summary>
        /// OnDisable：角色禁用时执行
        ///
        /// 触发场景：
        /// - 对象池回收
        /// - 场景切换
        /// - 读档重建
        /// - GameObject.SetActive(false)
        ///
        /// 注意事项：
        /// - EX-GAS 的 ASC 会在 OnDisable 清空能力、GameplayEffect 和 Tag
        /// - 项目侧的持续效果、动作锁、临时无敌也必须在这里同步清理
        /// </summary>
        protected override void OnDisable()
        {
            UnregisterTerrainSurfaceDamageTarget();
            UnregisterFormalAttributeEvents();
            CleanupOwnedTransientRuntimeState();
            base.OnDisable();
        }

        /// <summary>
        /// 死亡动画结束回调
        /// 防御性措施：避免 Animator 启停后重复发送结束消息
        /// </summary>
        protected override void OnDeathAnimationEnd()
        {
            // 死亡动画结束只能驱动一次正式销毁流程
            if (!m_isDeadAndDestroyed)
            {
                base.OnDeathAnimationEnd();
            }
        }

        /// <summary>
        /// 死亡时执行
        /// 标记角色已死亡并销毁
        /// </summary>
        protected override void OnDeath()
        {
            base.OnDeath();
            m_isDeadAndDestroyed = true;
        }

        /// <summary>
        /// 解析死亡命令上下文
        /// 用于确定死亡归属（谁杀死的）
        /// </summary>
        /// <returns>死亡命令上下文</returns>
        protected override GameCommandContext ResolveDeathCommandContext()
        {
            // 优先使用覆盖上下文（特殊死亡原因）
            if (TryConsumeDeathCommandContextOverride(out GameCommandContext overrideContext))
            {
                return overrideContext;
            }

            // 其次使用最后伤害来源
            if (!TryGetLastEffectiveDamageSource(out CharacterBase source))
            {
                // 找不到伤害来源，归类为脚本死亡
                return GameCommandContext.Script();
            }

            return GameCommandContext.ResolveForActor(source);
        }

        /// <summary>
        /// 获取死亡音效
        /// </summary>
        protected override AudioClipResolver GetDeathAudio() => characterSheet.deathAudio;

        /// <summary>
        /// 复活角色
        /// 流程：
        /// 1. 恢复满生命值和魔法值
        /// 2. 重置技能实例
        /// 3. 调用基类复活
        /// 4. 转移尸体物品回背包
        /// 5. 通知玩家系统
        /// 6. 播放无敌动画（如果配置了）
        /// </summary>
        public override void Revive()
        {
            Heal(int.MaxValue, EEffectVisualFlags.NoFloatingText);
            RecoverMana(int.MaxValue, EEffectVisualFlags.NoFloatingText);
            AbilityRuntime.ResetInstances();

            base.Revive();
            TransferCorpseInventoryToOwnedInventory();
            m_isDeadAndDestroyed = false;
            NotifyPlayerSystemAboutRevive();

            if (m_invincibleOnRevive)
            {
                m_animationStrategy?.PlayInvincibleAnimation();
            }
        }

        /// <summary>
        /// 获取说话者名称（用于对话系统）
        /// </summary>
        public override string GetSpeakerName() => characterSheet.displayName;

        /// <summary>
        /// 交互回调
        /// 如果角色已死亡，尝试拾取尸体物品；否则执行正常交互
        /// </summary>
        /// <param name="sender">发起交互的角色</param>
        public override void OnInteract(CharacterBase sender)
        {
            // 死亡状态：尝试拾取尸体物品
            if (dead && TryRequestCorpseInventory(sender))
            {
                return;
            }

            // 活着状态：转向交互者，执行正常交互
            LookAtTarget(sender.transform);
            base.OnInteract(sender);
        }

        /// <summary>
        /// 是否可以更新目标方向
        /// 当技能输入门限锁定方向时，不允许更新
        /// </summary>
        public override bool CanUpdateTargetDirection()
        {
            return base.CanUpdateTargetDirection() &&
                Can(EActionFlags.UpdateTargetDirection) &&
                (!TryGetOwnedAbilitySet(out CharacterAbilitySet abilitySet) ||
                 !abilitySet.ShouldLockTargetDirectionForInputGate());
        }

        /// <summary>
        /// 尝试播放受击动画
        /// </summary>
        /// <returns>是否成功播放</returns>
        protected virtual bool TryPlayHitAnimation()
        {
            return m_animationStrategy?.PlayHitAnimation() ?? false;
        }

        /// <summary>
        /// 是否可以移动
        /// 需要同时满足基类条件和移动行动标志
        /// </summary>
        public override bool CanMove() => base.CanMove() && Can(EActionFlags.Move);

        /// <summary>
        /// 计算移动速度
        /// 在基础速度上应用所有移动速度系数
        /// </summary>
        /// <returns>最终移动速度</returns>
        protected override float CalculateMoveSpeed()
        {
            float speed = base.CalculateMoveSpeed();

            // 应用所有移动速度系数（来自 Buff、装备等）
            foreach (float factor in m_actionRuntime.CreateMoveSpeedFactorSnapshot())
            {
                speed *= factor;
            }

            return speed;
        }

        /// <summary>
        /// 初始化属性
        /// 子类可以覆盖此方法来自定义初始属性
        /// </summary>
        protected virtual void InitializeStats()
        {
            Stats initial = new();
            initial[EStat.Health] = 1;  // 至少 1 点生命值
            initial += CreateEquipmentStatContributionSnapshot();  // 加上装备贡献
            SetResolvedBaseStats(initial);
        }

        /// <summary>
        /// 刷新装备带来的属性影响
        /// 当装备变化时，运行时调用此方法重新计算最终属性
        /// </summary>
        internal virtual void RefreshResolvedStatsForEquipmentRuntime()
        {
            InitializeStats();
        }

        /// <summary>
        /// 设置解析后的基础属性
        ///
        /// 重要说明：
        /// - 基础属性只允许由角色拥有者整体写回
        /// - CharacterActor 可以重建整份属性，但不再直接持有旧属性观察器细节
        /// - 初始化期间（属性引导窗口内）会缓存到 m_attributeBootstrapBuffer
        /// - 初始化完成后，直接应用到 EX-GAS 的 ASC
        /// </summary>
        /// <param name="stats">新的基础属性</param>
        protected void SetResolvedBaseStats(Stats stats)
        {
            Stats previousBaseStats = CreateStatsSnapshot();
            Stats previousCurrentStats = CreateCurrentStatsSnapshot();

            // 如果还在初始化期间，缓存到引导缓冲区
            if (!TryGetInitializedFormalAttributes(out _))
            {
                m_attributeBootstrapBuffer.ReplaceBaseStats(stats);
            }

            // 应用到 EX-GAS 的 ASC
            ApplyResolvedBaseStatsToFormalAbilitySystem(stats, previousBaseStats, previousCurrentStats);

            // 如果还在初始化期间，发布属性变化事件
            if (!TryGetInitializedFormalAttributes(out _))
            {
                PublishStatChanges(previousBaseStats, previousCurrentStats);
            }
        }

        /// <summary>
        /// 杀死角色
        /// 执行完整的死亡流程：
        /// 1. 播放死亡反馈效果
        /// 2. 通知游戏事件系统
        /// 3. 转移背包物品到尸体所有者
        /// 4. 调用基类 Kill（播放死亡动画等）
        /// 5. 转移装备到尸体所有者
        /// 6. 通知玩家系统
        /// 7. 清除 Buff/Debuff
        /// 8. 打断正在执行的技能
        /// </summary>
        public override void Kill()
        {
            if (IsMarkedAsDestroyed())
            {
                return;
            }

            m_pendingDeathAfterFormalCurrentValueMutation = false;

            // 播放死亡反馈（粒子、音效等）
            characterSheet.feedbacks.PlayDeath(transform.position);

            // 通知游戏运行时事件系统
            GameRuntimeEvents.NotifyDeathPresentation(new DeathPresentationContext(transform.position, this, m_lastEffectiveDamageSource));

            // 转移背包物品
            TransferOwnedInventoryToCorpseOwner();

            // 调用基类死亡逻辑
            base.Kill();

            // 转移装备
            TransferOwnedEquipmentToCorpseOwner();

            // 通知玩家系统（如果是玩家角色）
            NotifyPlayerSystemAboutDeath();

            // 清除所有 Buff 和 Debuff
            Cleanse(new[] { EEffectType.Buff, EEffectType.Debuff });

            // 打断所有正在执行的技能
            AbilityRuntime.InterruptInstances();
        }

        /// <summary>
        /// 延迟死亡处理
        /// 当 EX-GAS 的属性变更事件中检测到生命值归零时，标记延迟死亡
        /// 在当前帧的 Update 中实际执行死亡流程
        ///
        /// 为什么要延迟？
        /// - 避免在属性变更回调中直接执行死亡（可能导致状态不一致）
        /// - 确保当前帧的所有属性变更都完成后再处理死亡
        /// </summary>
        private void RequestDeathAfterFormalCurrentValueMutation()
        {
            m_pendingDeathAfterFormalCurrentValueMutation = true;
        }

        /// <summary>
        /// 延迟行动打断
        /// 当受到伤害时，标记延迟打断当前行动
        /// </summary>
        private void RequestActionInterruptAfterFormalDamage()
        {
            m_pendingActionInterruptAfterFormalDamage = true;
        }

        /// <summary>
        /// 处理延迟的行动打断
        /// 在 Update 中执行，确保伤害处理完成后再打断行动
        /// </summary>
        private void ProcessPendingActionInterruptAfterFormalDamage()
        {
            if (!m_pendingActionInterruptAfterFormalDamage ||
                IsMarkedAsDestroyed())
            {
                return;
            }

            m_pendingActionInterruptAfterFormalDamage = false;
            InterruptActions();
        }

        /// <summary>
        /// 处理延迟的死亡
        /// 在 Update 中执行，确保属性变更完成后再执行死亡流程
        /// </summary>
        private void ProcessPendingDeathAfterFormalCurrentValueMutation()
        {
            if (!m_pendingDeathAfterFormalCurrentValueMutation ||
                IsMarkedAsDestroyed() ||
                !dead)
            {
                return;
            }

            Kill();
        }

        public void Kill(GameCommandContext context)
        {
            if (IsMarkedAsDestroyed())
            {
                return;
            }

            m_hasDeathCommandContextOverride = true;
            m_deathCommandContextOverride = context;
            Kill();
        }

        public bool TryGetLastEffectiveDamageSource(out CharacterBase source)
        {
            source = m_lastEffectiveDamageSource;
            return source != null;
        }

        protected void SetLastEffectiveDamageSource(CharacterBase source)
        {
            if (source != null && source != this)
            {
                m_lastEffectiveDamageSource = source;
            }
        }

        private bool TryConsumeDeathCommandContextOverride(out GameCommandContext context)
        {
            context = m_deathCommandContextOverride;
            if (!m_hasDeathCommandContextOverride)
            {
                return false;
            }

            m_hasDeathCommandContextOverride = false;
            m_deathCommandContextOverride = default;
            return true;
        }

        private void CleanupOwnedTransientRuntimeState()
        {
            m_temporaryInvincibilityTimer = 0.0f;
            m_pendingActionInterruptAfterFormalDamage = false;
            m_animationStrategy?.OnInvincibleAnimationStop();
            AbilityRuntime.InterruptInstances();
            FinalizeOwnedTemporalEffects(
                RemoveOwnedTemporalEffectsByRuntimeKeySnapshot(
                    GetOwnedTemporalEffectRuntimeKeySnapshot()));
            ClearOwnedCharacterTransientState();
        }

        private CharacterAbilitySetRuntime AbilityRuntime =>
            TryGetOwnedAbilitySet(out CharacterAbilitySet abilitySet)
                ? abilitySet.Runtime
                : throw new InvalidOperationException(
                    $"[{nameof(CharacterBase)}] requires {nameof(CharacterAbilitySet)} as the formal ability runtime owner.");

        private bool TryGetAbilitySet(out CharacterAbilitySet abilitySet)
        {
            if (TryGetComponent(out abilitySet) && abilitySet != null)
            {
                return true;
            }

            abilitySet = null;
            return false;
        }

        public bool TryResolvePlayerInputTarget(out IPlayerInputTarget inputTarget)
        {
            inputTarget = null;

            if (!CanBePlayerControlled() ||
                !HasConfiguredPlayerInputTarget(out CharacterPlayerControl playerControl))
            {
                return false;
            }

            inputTarget = playerControl;
            return true;
        }

        public bool HasConfiguredPlayerInputTarget(out CharacterPlayerControl playerControl)
        {
            if (!TryGetComponent(out playerControl) ||
                playerControl == null ||
                !playerControl.AcceptsPlayerInput ||
                !playerControl.isActiveAndEnabled)
            {
                playerControl = null;
                return false;
            }

            return true;
        }

        internal Stats CreateEquipmentStatContributionSnapshot()
        {
            return TryGetComponent(out CharacterEquipment equipment) && equipment != null
                ? equipment.CreateStatContributionSnapshot()
                : new Stats();
        }

        internal CharacterEquipmentSlotData[] CreateEquipmentSlotDataSnapshot(DatabaseRegistry databaseRegistry)
        {
            return TryGetComponent(out CharacterEquipment equipment) && equipment != null
                ? equipment.CreateSlotDataSnapshot(databaseRegistry)
                : Array.Empty<CharacterEquipmentSlotData>();
        }

        internal bool RestoreEquipmentFromSlotData(
            IEnumerable<CharacterEquipmentSlotData> equipmentSlots,
            Func<DatabaseEntryReference<Equipment>, Equipment> resolveEquipment)
        {
            return TryGetComponent(out CharacterEquipment equipment) &&
                equipment != null &&
                equipment.RestoreFromSlotData(equipmentSlots, resolveEquipment);
        }

        internal bool TryGetOwnedAbilitySet(out CharacterAbilitySet abilitySet)
        {
            return TryGetAbilitySet(out abilitySet) &&
                abilitySet.OwnsAbilityComposition;
        }

        private void TransferOwnedInventoryToCorpseOwner()
        {
            GameManager.InventorySystem.TransferCharacterInventoryToCorpse(this);
        }

        private void TransferOwnedEquipmentToCorpseOwner()
        {
            GameManager.InventorySystem.TransferCharacterEquipmentToCorpse(this);
        }

        private void TransferCorpseInventoryToOwnedInventory()
        {
            GameManager.InventorySystem.TransferCorpseInventoryToCharacter(this);
        }

        private bool TryRequestCorpseInventory(CharacterBase looter)
        {
            if (!GameManager.Exists() || !GameManager.TryGetSystem(out InventorySystem inventorySystem) || looter == null)
            {
                return false;
            }

            InventoryOwnerHandle corpseOwner = inventorySystem.GetCorpseOwner(this);
            if (inventorySystem.GetBagEntries(corpseOwner).Length == 0)
            {
                return false;
            }

            GameRuntimeEvents.RequestInventory(InventoryMenuContext.TransferToCharacter(
                ResolveCorpseLootCommandContext(looter),
                looter,
                corpseOwner,
                EItemTransferType.Corpse));
            return true;
        }

        private static GameCommandContext ResolveCorpseLootCommandContext(CharacterBase looter)
        {
            return GameCommandContext.ResolveForActor(looter);
        }

        private void NotifyPlayerSystemAboutDeath()
        {
            GameManager.PlayerSystem.NotifyCharacterDied(this);
        }

        private void NotifyPlayerSystemAboutRevive()
        {
            GameManager.PlayerSystem.NotifyCharacterRevived(this);
        }

        private void TryRegisterTerrainSurfaceDamageTarget()
        {
            if (m_registeredTerrainSurfaceDamageSystem != null ||
                !GameManager.Exists() ||
                !GameManager.TryGetSystem(out TerrainSurfaceDamageSystem damageSystem))
            {
                return;
            }

            damageSystem.RegisterTarget(this);
            m_registeredTerrainSurfaceDamageSystem = damageSystem;
        }

        private void UnregisterTerrainSurfaceDamageTarget()
        {
            if (m_registeredTerrainSurfaceDamageSystem == null)
            {
                return;
            }

            m_registeredTerrainSurfaceDamageSystem.UnregisterTarget(this);
            m_registeredTerrainSurfaceDamageSystem = null;
        }

        private void CloseAttributeBootstrapReadWindow()
        {
            m_isAttributeBootstrapReadWindowOpen = false;
            m_attributeBootstrapBuffer.Clear();
        }

        /// <summary>
        /// 这些字段只描述当前实体实例的局部运行时状态，
        /// 禁用/回收后不能泄漏到下一次复用。
        /// </summary>
        private void ClearOwnedCharacterTransientState()
        {
            m_isDeadAndDestroyed = false;
            m_isSummoned = false;
            m_alignmentOverride = null;
            m_lastEffectiveDamageSource = null;
            m_hasDeathCommandContextOverride = false;
            m_deathCommandContextOverride = default;
        }
    }
}
