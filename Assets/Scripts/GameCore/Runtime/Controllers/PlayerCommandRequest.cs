using UnityEngine;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 玩家输入被归一化后的命令类型。
    /// 输入系统只负责生成这些请求，实际执行由玩家控制系统判定。
    /// </summary>
    public enum EPlayerCommandKind
    {
        /// <summary>执行当前交互目标。</summary>
        Interact,

        /// <summary>打开游戏菜单。</summary>
        OpenGameMenu,

        /// <summary>方向移动输入。</summary>
        Move,

        /// <summary>停止当前移动意图。</summary>
        StopMove,

        /// <summary>点击世界坐标移动。</summary>
        ClickMove,

        /// <summary>在方向移动和点击移动之间切换。</summary>
        ToggleMovementControlMode,

        /// <summary>触发指定技能槽。</summary>
        FireAbility,

        /// <summary>停止指定技能槽的持续输入。</summary>
        StopFireAbility
    }

    /// <summary>
    /// 玩家命令执行失败原因。
    /// 用于诊断和 UI 提示，避免只返回 false 丢失是哪道门禁拒绝。
    /// </summary>
    public enum EPlayerCommandFailureReason
    {
        /// <summary>没有失败，命令执行成功。</summary>
        None,

        /// <summary>未知或当前执行器不支持的命令类型。</summary>
        InvalidCommand,

        /// <summary>玩家系统没有当前输入目标。</summary>
        MissingInputTarget,

        /// <summary>当前控制角色为空或不可用。</summary>
        InvalidControlledCharacter,

        /// <summary>命令缺少必需目标，例如点击移动没有世界坐标。</summary>
        InvalidTarget,

        /// <summary>命令上下文指定的 Actor 与实际执行角色不一致。</summary>
        ActorMismatch,

        /// <summary>执行器或目标组件当前没有启用。</summary>
        NotRunning,

        /// <summary>角色当前不能被玩家控制。</summary>
        ControlLocked,

        /// <summary>交互动作被状态或组件门禁锁住。</summary>
        InteractionLocked,

        /// <summary>角色状态阻挡了该命令，例如死亡、硬直、动作门禁或模式不匹配。</summary>
        BlockedByState,

        /// <summary>请求的技能槽没有可执行能力。</summary>
        MissingAbility,

        /// <summary>能力系统拒绝本次技能触发，例如冷却、资源或 Formal GAS 门禁未通过。</summary>
        AbilityRejected
    }

    /// <summary>
    /// 一次玩家命令请求。
    /// 它把动作类型、方向、点击位置、技能槽和交互目标打包，执行层再统一校验 Actor。
    /// </summary>
    public readonly struct PlayerCommandRequest
    {
        public PlayerCommandRequest(
            GameCommandContext commandContext,
            EPlayerCommandKind kind,
            Vector2 direction = default,
            Vector2? worldPosition = null,
            int abilityIndex = -1,
            CharacterBase targetCharacter = null,
            GameObject interactionTarget = null)
        {
            CommandContext = commandContext;
            Kind = kind;
            Direction = direction;
            WorldPosition = worldPosition;
            AbilityIndex = abilityIndex;
            TargetCharacter = targetCharacter;
            InteractionTarget = interactionTarget;
        }

        /// <summary>命令上下文，携带 actor、来源和后续归属信息。</summary>
        public GameCommandContext CommandContext { get; }

        /// <summary>上下文中的执行角色。</summary>
        public CharacterBase Actor => CommandContext.Actor;

        /// <summary>玩家命令类型。</summary>
        public EPlayerCommandKind Kind { get; }

        /// <summary>方向输入或技能瞄准方向。</summary>
        public Vector2 Direction { get; }

        /// <summary>命令是否带世界坐标。</summary>
        public bool HasWorldPosition => WorldPosition.HasValue;

        /// <summary>点击移动、世界目标或技能瞄准使用的世界坐标。</summary>
        public Vector2? WorldPosition { get; }

        /// <summary>技能槽索引；非技能命令通常为 -1。</summary>
        public int AbilityIndex { get; }

        /// <summary>技能或命令指定的目标角色。</summary>
        public CharacterBase TargetCharacter { get; }

        /// <summary>显式交互目标；为空时交互组件会按范围和朝向自行解析。</summary>
        public GameObject InteractionTarget { get; }
    }

    /// <summary>
    /// 玩家命令执行结果。
    /// 成功时保留原请求，失败时额外给出失败原因。
    /// </summary>
    public readonly struct PlayerCommandResult
    {
        private PlayerCommandResult(
            PlayerCommandRequest request,
            bool succeeded,
            EPlayerCommandFailureReason failureReason)
        {
            Request = request;
            Succeeded = succeeded;
            FailureReason = failureReason;
        }

        public PlayerCommandRequest Request { get; }

        /// <summary>命令是否执行成功。</summary>
        public bool Succeeded { get; }

        /// <summary>失败原因；成功时固定为 <see cref="EPlayerCommandFailureReason.None"/>。</summary>
        public EPlayerCommandFailureReason FailureReason { get; }

        /// <summary>
        /// 创建成功结果。
        /// </summary>
        public static PlayerCommandResult Success(PlayerCommandRequest request)
        {
            return new PlayerCommandResult(request, true, EPlayerCommandFailureReason.None);
        }

        /// <summary>
        /// 创建失败结果。
        /// </summary>
        public static PlayerCommandResult Failed(
            PlayerCommandRequest request,
            EPlayerCommandFailureReason failureReason)
        {
            return new PlayerCommandResult(request, false, failureReason);
        }
    }
}
