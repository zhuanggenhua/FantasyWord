using System;
using ContextSteering2D;
using Sirenix.OdinInspector;
using UnityEngine;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// AI 状态层的身体朝向模式。它只决定角色身体朝向，不替代移动求解、技能目标方向或武器瞄准。
    /// </summary>
    internal enum AICharacterFacingMode2D
    {
        [LabelText("保持当前朝向")]
        KeepCurrent,

        [LabelText("面向目标")]
        FaceTarget,

        [LabelText("面向移动方向")]
        FaceMovement
    }

    /// <summary>
    /// AI 控制器的存档状态，保留归位点、当前目标和关键冷却计时器。
    /// </summary>
    [Serializable]
    public class AIControllerDataBlock : ControllerDataBlock
    {
        /// <summary>
        /// AI 启动时的初始位置，用于目标丢失后回到活动范围。
        /// </summary>
        public Vector3 initialPosition;

        /// <summary>
        /// 当前战斗目标的持久化引用。
        /// </summary>
        public PersistableReference<CharacterBase> target;

        /// <summary>
        /// 重新寻找目标前的剩余冷却时间。
        /// </summary>
        public float retargetCooldownTimer;

        /// <summary>
        /// 攻击再次触发前的剩余冷却时间。
        /// </summary>
        public float attackCooldownTimer;

        /// <summary>
        /// 距离最后一次看见目标已经经过的时间。
        /// </summary>
        public float timeSinceTargetLastSeen;
    }

    /// <summary>
    /// 角色 AI 控制器，使用 ContextSteering2D 追踪目标、回到活动范围并触发攻击。
    /// </summary>
    [Serializable]
    public partial class AIController : AController<CharacterBase>
    {
        private const string DefaultTargetOrbitSteeringGroupId = "orbit";

        [SerializeField]
        [LabelText("主控实体"), Tooltip("可选的跟随或守护对象；配置后 AI 的归位点优先取该实体位置。")]
        private Entity m_master = null;

        [Header("追踪设置")]
        [SerializeField, Min(1.0f)]
        [LabelText("发现半径"), Tooltip("AI 搜索可攻击目标的最大半径。")]
        private float m_detectionRadius = 5.0f;

        [SerializeField, Min(1.0f)]
        [LabelText("离初始点重置半径"), Tooltip("AI 距离初始点超过该半径后，会倾向重置或返回活动范围。")]
        private float m_resetFromInitialPositionRadius = 10.0f;

        [SerializeField, Min(1.0f)]
        [LabelText("离目标重置半径"), Tooltip("AI 与目标距离超过该半径后，会放弃或重新寻找目标。")]
        private float m_resetFromTargetDistanceRadius = 10.0f;

        [SerializeField, Min(0.5f)]
        [LabelText("越界重新选敌冷却"), Tooltip("目标离开范围后，等待该秒数再尝试重新寻找目标。")]
        private float m_targetOutOfRangeRetargetCooldown = 3.0f;

        [SerializeField, Min(0.1f)]
        [LabelText("距离主控目标期望距离"), Tooltip("存在主控实体时，AI 尝试保持在主控目标附近的距离。")]
        private float m_soughtDistanceFromMasterTarget = 1.0f;

        [SerializeField, Min(0.1f)]
        [LabelText("距离目标期望距离"), Tooltip("追击目标时希望保持的距离，用于近战或环绕行为。")]
        private float m_soughtDistanceFromTarget = 1.0f;

        [Header("转向设置")]
        [SerializeField]
        [LabelText("转向配置"), Tooltip("ContextSteering2D 使用的方向评分配置。")]
        private ContextSteeringProfile2D m_steeringProfile = null;

        [SerializeField]
        [LabelText("通行转向组"), Tooltip("非战斗移动时使用的转向组 ID。")]
        private string m_transitSteeringGroupId = "transit";

        [SerializeField]
        [LabelText("追击转向组"), Tooltip("追击目标时使用的转向组 ID。")]
        private string m_targetPursuitSteeringGroupId = "predictive-target";

        [SerializeField]
        [LabelText("追击身体朝向"), Tooltip("追击目标时身体朝向的状态层裁决：可保持当前、面向目标，或面向移动方向。")]
        private AICharacterFacingMode2D m_targetPursuitFacingMode = AICharacterFacingMode2D.FaceTarget;

        [SerializeField]
        [LabelText("启用战斗游走"), Tooltip("开启后，敌人进入游走范围便按参考行为随机左右游走；关闭时只使用原追击流程。")]
        private bool m_useCombatWander = false;

        [SerializeField, Min(0.1f)]
        [LabelText("战斗游走范围"), Tooltip("目标进入该范围时，允许使用战斗游走。")]
        private float m_combatWanderRange = 3.0f;

        [SerializeField, Min(0.0f)]
        [LabelText("战斗游走速度倍率"), Tooltip("对应参考配置中的游走速度倍率。")]
        private float m_combatWanderSpeedMultiplier = 1.0f;

        [SerializeField]
        [LabelText("战斗游走转向组"), Tooltip("战斗游走使用的行为组 ID。")]
        private string m_combatWanderSteeringGroupId = "combat-wander";

        [SerializeField]
        [LabelText("战斗游走身体朝向"), Tooltip("战斗游走开启后身体朝向的状态层裁决；默认保持当前，避免游走行为强制锁脸。")]
        private AICharacterFacingMode2D m_combatWanderFacingMode = AICharacterFacingMode2D.KeepCurrent;

        [SerializeField]
        [LabelText("启用近身环绕"), Tooltip("目标进入保持距离后切换到近身环绕组。关闭时继续使用追击组，并由 Arrive 在攻击距离附近停住。")]
        private bool m_useTargetOrbitSteeringAtSoughtDistance = true;

        [SerializeField]
        [LabelText("近身环绕转向组"), Tooltip("目标进入保持距离后使用的行为组 ID；默认 orbit，不应包含 Arrive。")]
        private string m_targetOrbitSteeringGroupId = DefaultTargetOrbitSteeringGroupId;

        [SerializeField, Min(0.1f)]
        [LabelText("重新寻路间隔"), Tooltip("导航目标刷新路径的最小间隔秒数。")]
        private float m_navigationRepathInterval = 0.5f;

        [SerializeField, Min(0.05f)]
        [LabelText("目标移动重算阈值"), Tooltip("目标移动超过该距离后触发重新规划路径。")]
        private float m_navigationTargetMoveThreshold = 0.5f;

        [SerializeField, Min(0.05f)]
        [LabelText("路径点容差"), Tooltip("AI 距离当前路径点小于该值时视为已到达。")]
        private float m_navigationWaypointTolerance = 0.2f;

        [SerializeField, Min(0.1f)]
        [LabelText("丢失目标后重置时间"), Tooltip("看不见目标持续超过该时间后，AI 会进入重置或重新选敌流程。")]
        private float m_timeBeforeResetAfterTargetSightLost = 3.0f;

        [SerializeField, Min(0.1f)]
        [LabelText("不可见目标重新选敌冷却"), Tooltip("目标不可见后再次尝试选敌的冷却时间。")]
        private float m_cannotSeeTargetRetargetCooldown = 1.0f;

        [Header("攻击设置")]
        [SerializeField]
        [LabelText("攻击触发半径"), Tooltip("目标进入该距离后 AI 可尝试触发攻击。")]
        public float m_attackTriggerRadius = 1.0f;

        [SerializeField]
        [LabelText("攻击冷却"), Tooltip("两次攻击尝试之间的最小间隔秒数。")]
        public float m_attackCooldown = 1.0f;

        [SerializeField]
        [LabelText("攻击前要求对准目标"), Tooltip("开启后，AI 进入攻击触发半径时先面向目标，身体朝向完成后下一次判断才会开火。")]
        private bool m_requireTargetFacingBeforeAttack = true;

        [SerializeField, Range(0.0f, 45.0f)]
        [LabelText("攻击对准完成角度"), Tooltip("参考 duolafashi turnToTargetDetal 的 5 度完成判定；只用于攻击前对准门禁。")]
        private float m_attackFacingCompletionAngleDegrees = 5.0f;

        private Transform transform => m_subject.transform;

        private Vector2 m_homePosition =>
            m_master ?
            (Vector2)m_master.transform.position :
            m_initialPosition;

        private bool ShouldUseTargetOrbitSteeringAtSoughtDistance =>
            m_useTargetOrbitSteeringAtSoughtDistance;

        private bool ShouldUseCombatWander => m_useCombatWander;

        private AICharacterFacingMode2D TargetPursuitFacingMode => m_targetPursuitFacingMode;

        private AICharacterFacingMode2D CombatWanderFacingMode => m_combatWanderFacingMode;

        private bool ShouldRequireTargetFacingBeforeAttack => m_requireTargetFacingBeforeAttack;

        private float AttackFacingCompletionAngleDegrees => Mathf.Clamp(m_attackFacingCompletionAngleDegrees, 0.0f, 45.0f);

        private string TargetOrbitSteeringGroupIdValue =>
            string.IsNullOrWhiteSpace(m_targetOrbitSteeringGroupId)
                ? DefaultTargetOrbitSteeringGroupId
                : m_targetOrbitSteeringGroupId;

        // 当前战斗目标。它是 AI 控制器自己的运行时追敌真相，存档时再转成 PersistableReference。
        private CharacterBase m_target = null;
        // 重新搜索目标前的冷却，避免目标刚丢失时每个 FixedUpdate 都扫检测列表。
        private float m_retargetCooldownTimer = 0.0f;
        // 攻击尝试冷却。只有正式能力成功接收释放请求后才会重置。
        private float m_attackCooldownTimer = 0.0f;
        // AI 激活时记录的初始点；存在主控实体时归位点会优先跟随主控实体。
        private Vector2 m_initialPosition;
        // 目标最近一次不可见后的累计时间，用于延迟丢失目标，而不是视线断开就立刻停追。
        private float m_timeSinceTargetLastSeen = 0.0f;

        // 行为运行时延迟创建，避免控制器只被反序列化但未激活时提前创建转向适配器。
        private BehaviourRuntime m_behaviourRuntime = null;
        private BehaviourRuntime behaviourRuntime => m_behaviourRuntime ??= new BehaviourRuntime(this);

        /// <summary>
        /// 判断当前身体朝向是否已经满足攻击前对准；角度完成值来自参考的转向完成语义。
        /// </summary>
        internal static bool IsAttackFacingAligned(
            Vector2 currentFacing,
            Vector2 attackDirection,
            float completionAngleDegrees)
        {
            if (currentFacing.sqrMagnitude <= 0.0001f ||
                attackDirection.sqrMagnitude <= 0.0001f)
            {
                return false;
            }

            float completedAngle = Mathf.Clamp(completionAngleDegrees, 0.0f, 45.0f);
            return Vector2.Angle(currentFacing, attackDirection) < completedAngle;
        }

        /// <summary>
        /// 初始化 AI 行为运行时，并记录归位基准点。
        /// 转向组映射也在这里校验，配置错误会尽早暴露在控制器启用阶段。
        /// </summary>
        protected override void OnInitialize()
        {
            behaviourRuntime.Initialize();
        }

        /// <summary>
        /// 控制器启动时监听受挑衅事件，让被攻击的 AI 可以临时锁定挑衅来源。
        /// </summary>
        protected override void OnStart()
        {
            m_subject.AddProvokedListener(OnProvoked);
        }

        /// <summary>
        /// 控制器停止时清理事件订阅、当前路径和转向输出，避免下次接管时沿用旧目标状态。
        /// </summary>
        protected override void OnStop()
        {
            m_subject.RemoveProvokedListener(OnProvoked);
            behaviourRuntime.Stop();
        }

        /// <summary>
        /// 控制器销毁时释放转向运行时资源。
        /// </summary>
        protected override void OnTerminate() => m_behaviourRuntime?.Dispose();

        /// <summary>
        /// 设置 AI 的主控实体，并可临时覆盖跟随主控目标的期望距离。
        /// </summary>
        public void SetMaster(Entity master, float? soughtDistanceFromMaster = null)
        {
            m_soughtDistanceFromMasterTarget = soughtDistanceFromMaster ?? m_soughtDistanceFromMasterTarget;
            m_master = master;
        }

        /// <summary>
        /// 尝试把指定角色设为战斗目标；目标必须对当前主体是合理敌对目标。
        /// </summary>
        public bool TrySetCombatTarget(CharacterBase target)
        {
            if (!target || m_subject == null || !CombatSolver.IsJudiciousTarget(m_subject, target))
            {
                return false;
            }

            m_target = target;
            m_retargetCooldownTimer = 0.0f;
            m_timeSinceTargetLastSeen = 0.0f;
            return true;
        }

        /// <summary>
        /// 受挑衅时把来源交给行为运行时裁决。
        /// 这里不直接改目标，避免绕过冷却、敌我和视线等统一规则。
        /// </summary>
        private void OnProvoked(CharacterBase source)
        {
            behaviourRuntime.TryHandleProvoked(source);
        }

        /// <summary>
        /// 固定步推进 AI 行为。
        /// 移动、寻敌和攻击都依赖物理检测与 FixedUpdate 节奏保持一致。
        /// </summary>
        protected override void OnFixedUpdate()
        {
            behaviourRuntime.Tick();
        }

        /// <summary>
        /// 返回 AI 控制器自己的存档块类型。
        /// </summary>
        protected override Type GetDataBlockType() => typeof(AIControllerDataBlock);

        /// <summary>
        /// 从控制器存档块恢复目标、归位点和关键冷却计时器。
        /// 目标引用解析失败时会自然回到空目标状态，由下一次 Tick 重新选敌。
        /// </summary>
        protected override void OnLoad(IControllerDataBlock block)
        {
            base.OnLoad(block);
            var aiControllerDataBlock = block.As<AIControllerDataBlock>();
            m_initialPosition = aiControllerDataBlock.initialPosition;
            m_target = aiControllerDataBlock.target.ResolveOrNull();
            m_retargetCooldownTimer = aiControllerDataBlock.retargetCooldownTimer;
            m_attackCooldownTimer = aiControllerDataBlock.attackCooldownTimer;
            m_timeSinceTargetLastSeen = aiControllerDataBlock.timeSinceTargetLastSeen;
        }

        /// <summary>
        /// 保存 AI 控制器的轻量运行时状态。
        /// 转向路径和临时 steering 输出不写盘，读档后由 BehaviourRuntime 重新计算。
        /// </summary>
        protected override void OnSave(IControllerDataBlock block)
        {
            base.OnSave(block);
            var aiControllerDataBlock = block.As<AIControllerDataBlock>();
            aiControllerDataBlock.initialPosition = m_initialPosition;
            aiControllerDataBlock.target = m_target;
            aiControllerDataBlock.retargetCooldownTimer = m_retargetCooldownTimer;
            aiControllerDataBlock.attackCooldownTimer = m_attackCooldownTimer;
            aiControllerDataBlock.timeSinceTargetLastSeen = m_timeSinceTargetLastSeen;
        }
    }
}
