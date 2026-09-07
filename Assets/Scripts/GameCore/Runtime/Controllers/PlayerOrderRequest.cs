using UnityEngine;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 正式玩家订单的目标范围。
    /// 它表达“订单应该只作用于主控成员，还是分发给当前控制组全部可批准成员”，
    /// 不再让每个调用方自己猜某个命令是不是群发。
    /// </summary>
    public enum EPlayerOrderTargetScope
    {
        /// <summary>只由当前主控成员执行。</summary>
        PrimaryMemberOnly,

        /// <summary>分发给当前控制组中可执行该订单的成员。</summary>
        ControlledGroup
    }

    /// <summary>
    /// 正式玩家订单的排队模式。
    /// 当前第一阶段先把替换、停止和最小可排队移动语义显式化；后续 RTS 队列可继续沿同一合同扩到更多订单族。
    /// </summary>
    public enum EPlayerOrderQueueMode
    {
        /// <summary>替换当前正在执行或等待的订单。</summary>
        ReplaceCurrent,

        /// <summary>追加到当前订单队列尾部。</summary>
        Append,

        /// <summary>停止当前订单或当前移动意图。</summary>
        StopCurrent
    }

    /// <summary>
    /// 批量空间订单的正式落点策略。
    /// 当前先收口“所有成员都挤到同一点”之外的最小正式语义，后续若引入更复杂编队，继续沿这条合同扩展。
    /// </summary>
    public enum EPlayerOrderSpatialPolicy
    {
        /// <summary>不做空间分配，所有执行者使用原始目标。</summary>
        None,

        /// <summary>围绕目标点分配环形落点，避免多个成员挤在同一坐标。</summary>
        DistributedRing
    }

    /// <summary>
    /// 批量空间订单的落点合同。
    /// 这里只描述运行时如何分配成员目标点，不让 UI 或调用方各自硬编码偏移量。
    /// </summary>
    public readonly struct PlayerOrderSpatialContract
    {
        public PlayerOrderSpatialContract(
            EPlayerOrderSpatialPolicy policy,
            float spacing)
        {
            Policy = policy;
            Spacing = Mathf.Max(0.05f, spacing);
        }

        /// <summary>空间分配策略。</summary>
        public EPlayerOrderSpatialPolicy Policy { get; }

        /// <summary>成员落点之间的最小间距，构造时会限制到不低于 0.05。</summary>
        public float Spacing { get; }

        /// <summary>是否需要为不同成员生成分散世界坐标。</summary>
        public bool UsesDistributedWorldPositions => Policy != EPlayerOrderSpatialPolicy.None;

        /// <summary>不启用空间分配的默认合同。</summary>
        public static PlayerOrderSpatialContract None => default;
    }

    /// <summary>
    /// 从玩家输入请求投影出来的正式订单对象。
    /// 它只描述“命令是什么、发给谁、以什么排队语义进入运行时”，
    /// 不直接承接 UI 细节。
    /// </summary>
    public readonly struct PlayerOrderRequest
    {
        public PlayerOrderRequest(
            PlayerCommandRequest commandRequest,
            EPlayerOrderTargetScope targetScope,
            EPlayerOrderQueueMode queueMode,
            PlayerOrderSpatialContract spatialContract = default)
        {
            CommandRequest = commandRequest;
            TargetScope = targetScope;
            QueueMode = queueMode;
            SpatialContract = spatialContract;
        }

        /// <summary>原始玩家命令请求。</summary>
        public PlayerCommandRequest CommandRequest { get; }

        /// <summary>命令类型。</summary>
        public EPlayerCommandKind Kind => CommandRequest.Kind;

        /// <summary>命令上下文。</summary>
        public GameCommandContext CommandContext => CommandRequest.CommandContext;

        /// <summary>命令指定的 actor。</summary>
        public CharacterBase Actor => CommandRequest.Actor;

        /// <summary>方向输入或瞄准方向。</summary>
        public Vector2 Direction => CommandRequest.Direction;

        /// <summary>订单是否带世界坐标。</summary>
        public bool HasWorldPosition => CommandRequest.HasWorldPosition;

        /// <summary>点击移动、世界目标或技能瞄准使用的世界坐标。</summary>
        public Vector2? WorldPosition => CommandRequest.WorldPosition;

        /// <summary>技能槽索引。</summary>
        public int AbilityIndex => CommandRequest.AbilityIndex;

        /// <summary>目标角色。</summary>
        public CharacterBase TargetCharacter => CommandRequest.TargetCharacter;

        /// <summary>显式交互目标。</summary>
        public GameObject InteractionTarget => CommandRequest.InteractionTarget;

        /// <summary>该订单作用于主控成员还是控制组。</summary>
        public EPlayerOrderTargetScope TargetScope { get; }

        /// <summary>该订单进入运行时队列时的模式。</summary>
        public EPlayerOrderQueueMode QueueMode { get; }

        /// <summary>控制组空间分配合同。</summary>
        public PlayerOrderSpatialContract SpatialContract { get; }

        /// <summary>当前订单是否是可排队移动订单。</summary>
        public bool IsQueueableMovementOrder => Kind == EPlayerCommandKind.ClickMove;

        /// <summary>当前订单是否表示停止当前动作或移动。</summary>
        public bool IsStopOrder => Kind == EPlayerCommandKind.StopMove;

        /// <summary>当前订单是否需要给控制组成员分配不同世界坐标。</summary>
        public bool UsesDistributedWorldPositions =>
            TargetScope == EPlayerOrderTargetScope.ControlledGroup &&
            HasWorldPosition &&
            SpatialContract.UsesDistributedWorldPositions;

        /// <summary>
        /// 从单条玩家命令创建默认正式订单。
        /// 默认目标范围、队列模式和空间合同都集中在这里解析，避免调用方各自复制规则。
        /// </summary>
        public static PlayerOrderRequest FromCommandRequest(PlayerCommandRequest commandRequest)
        {
            return new PlayerOrderRequest(
                commandRequest,
                ResolveTargetScope(commandRequest.Kind),
                ResolveQueueMode(commandRequest.Kind),
                ResolveSpatialContract(commandRequest.Kind));
        }

        /// <summary>
        /// 创建一个替换目标范围的新订单。
        /// </summary>
        public PlayerOrderRequest WithTargetScope(EPlayerOrderTargetScope targetScope)
        {
            return new PlayerOrderRequest(CommandRequest, targetScope, QueueMode, SpatialContract);
        }

        /// <summary>
        /// 创建一个替换队列模式的新订单。
        /// </summary>
        public PlayerOrderRequest WithQueueMode(EPlayerOrderQueueMode queueMode)
        {
            return new PlayerOrderRequest(CommandRequest, TargetScope, queueMode, SpatialContract);
        }

        /// <summary>
        /// 创建一个替换空间分配合同的新订单。
        /// </summary>
        public PlayerOrderRequest WithSpatialContract(PlayerOrderSpatialContract spatialContract)
        {
            return new PlayerOrderRequest(CommandRequest, TargetScope, QueueMode, spatialContract);
        }

        /// <summary>
        /// 解析默认目标范围。
        /// 移动类命令默认作用于控制组，其它命令默认只由主控成员执行。
        /// </summary>
        private static EPlayerOrderTargetScope ResolveTargetScope(EPlayerCommandKind kind)
        {
            return kind switch
            {
                EPlayerCommandKind.Move => EPlayerOrderTargetScope.ControlledGroup,
                EPlayerCommandKind.StopMove => EPlayerOrderTargetScope.ControlledGroup,
                EPlayerCommandKind.ClickMove => EPlayerOrderTargetScope.ControlledGroup,
                EPlayerCommandKind.ToggleMovementControlMode => EPlayerOrderTargetScope.ControlledGroup,
                _ => EPlayerOrderTargetScope.PrimaryMemberOnly
            };
        }

        /// <summary>
        /// 解析默认队列模式。
        /// 当前只有停止移动直接进入停止模式，其它命令默认替换当前订单。
        /// </summary>
        private static EPlayerOrderQueueMode ResolveQueueMode(EPlayerCommandKind kind)
        {
            return kind switch
            {
                EPlayerCommandKind.StopMove => EPlayerOrderQueueMode.StopCurrent,
                _ => EPlayerOrderQueueMode.ReplaceCurrent
            };
        }

        /// <summary>
        /// 解析默认空间分配合同。
        /// 点击移动给控制组成员分配环形落点，避免所有成员重叠在目标坐标。
        /// </summary>
        private static PlayerOrderSpatialContract ResolveSpatialContract(EPlayerCommandKind kind)
        {
            return kind switch
            {
                EPlayerCommandKind.ClickMove => new PlayerOrderSpatialContract(
                    EPlayerOrderSpatialPolicy.DistributedRing,
                    0.65f),
                _ => PlayerOrderSpatialContract.None
            };
        }
    }

    /// <summary>
    /// 正式订单分发结果。
    /// 当前阶段先记录分发到多少成员，以及最后一次成员执行结果；后续队列/编队阶段可继续扩展。
    /// </summary>
    public readonly struct PlayerOrderResult
    {
        private PlayerOrderResult(
            PlayerOrderRequest orderRequest,
            int dispatchedMemberCount,
            bool succeeded,
            bool wasQueued,
            int queuedOrderCount,
            PlayerCommandResult lastCommandResult)
        {
            OrderRequest = orderRequest;
            DispatchedMemberCount = dispatchedMemberCount;
            Succeeded = succeeded;
            WasQueued = wasQueued;
            QueuedOrderCount = queuedOrderCount;
            LastCommandResult = lastCommandResult;
        }

        /// <summary>原始订单。</summary>
        public PlayerOrderRequest OrderRequest { get; }

        /// <summary>本次实际分发到的成员数量。</summary>
        public int DispatchedMemberCount { get; }

        /// <summary>订单是否成功执行或成功入队。</summary>
        public bool Succeeded { get; }

        /// <summary>订单是否进入队列等待执行。</summary>
        public bool WasQueued { get; }

        /// <summary>入队后的队列订单数量。</summary>
        public int QueuedOrderCount { get; }

        /// <summary>最后一次成员命令执行结果。</summary>
        public PlayerCommandResult LastCommandResult { get; }

        /// <summary>
        /// 创建立即成功的订单结果。
        /// </summary>
        public static PlayerOrderResult Success(
            PlayerOrderRequest orderRequest,
            int dispatchedMemberCount,
            PlayerCommandResult lastCommandResult)
        {
            return new PlayerOrderResult(orderRequest, dispatchedMemberCount, true, false, 0, lastCommandResult);
        }

        /// <summary>
        /// 创建立即失败的订单结果。
        /// </summary>
        public static PlayerOrderResult Failed(
            PlayerOrderRequest orderRequest,
            int dispatchedMemberCount,
            PlayerCommandResult lastCommandResult)
        {
            return new PlayerOrderResult(orderRequest, dispatchedMemberCount, false, false, 0, lastCommandResult);
        }

        /// <summary>
        /// 创建成功入队的订单结果。
        /// 入队还没执行具体角色命令，因此 last command result 使用原始命令的成功占位。
        /// </summary>
        public static PlayerOrderResult Queued(
            PlayerOrderRequest orderRequest,
            int queuedOrderCount)
        {
            return new PlayerOrderResult(
                orderRequest,
                0,
                true,
                true,
                queuedOrderCount,
                PlayerCommandResult.Success(orderRequest.CommandRequest));
        }
    }
}
