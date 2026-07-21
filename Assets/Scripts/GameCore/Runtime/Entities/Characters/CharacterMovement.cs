using Sirenix.OdinInspector;
using UnityEngine;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 角色移动输入适配组件。
    /// 负责把玩家命令或控制器命令转成 <see cref="CharacterBase"/> / <see cref="Movable"/> 能理解的移动意图。
    /// </summary>
    /// <remarks>
    /// 这个组件只处理“怎么移动到目标”的角色侧入口，不拥有玩家身份、地图真相或导航数据。
    /// 点击移动优先使用当前地图注册的 <see cref="TerrainNavigationMap"/>；没有导航图时退回到
    /// <see cref="Movable.NearestValidDestination(Vector2)"/> 和直线移动，保持基础测试场景可用。
    /// </remarks>
    [DisallowMultipleComponent]
    [RequireComponent(typeof(CharacterBase))]
    public sealed class CharacterMovement : MonoBehaviour
    {
        [Header("移动控制")]
        [SerializeField]
        [LabelText("角色引用"), Tooltip("接收移动意图的角色本体；通常自动取同物体上的 CharacterBase。")]
        private CharacterBase m_character = null;

        [SerializeField]
        [LabelText("朝向基准点"), Tooltip("计算指针瞄准方向时使用的起点；为空时使用角色 Transform。")]
        private Transform m_directionPivot = null;

        [SerializeField]
        [LabelText("闲置时朝向指针"), Tooltip("启用后，角色没有移动意图时会让技能朝向跟随鼠标/指针。")]
        private bool m_castAbilitiesInPointerDirection = false;

        [SerializeField]
        [LabelText("移动控制模式"), Tooltip("Directional 使用方向输入；ClickToMove 使用世界坐标点击移动。")]
        private EPlayerMovementControlMode m_movementControlMode = EPlayerMovementControlMode.Directional;

        [SerializeField]
        [LabelText("点击移动停止距离"), Tooltip("点击移动到目标附近多少距离内视为到达，单位为世界坐标。")]
        private float m_clickMoveStoppingDistance = 0.05f;

        /// <summary>
        /// 当前玩家移动控制模式。
        /// </summary>
        public EPlayerMovementControlMode MovementControlMode => m_movementControlMode;

        /// <summary>
        /// 指针瞄准使用的基准点。
        /// 武器、手部或身体中心可以单独配置；未配置时用角色根节点，保证旧 Prefab 仍能工作。
        /// </summary>
        private Transform directionPivot => m_directionPivot != null ? m_directionPivot : m_character.transform;

        /// <summary>
        /// 在角色没有移动输入时，尝试用当前指针位置刷新技能目标方向。
        /// </summary>
        /// <returns>本帧是否成功写入目标方向。</returns>
        public bool TryUpdateIdlePointerTargetDirection()
        {
            if (!m_character ||
                !m_castAbilitiesInPointerDirection ||
                m_character.HasActiveMovementIntent() ||
                !GameManager.InputSystem.IsPointerActive(EActionMap.Gameplay))
            {
                return false;
            }

            Camera camera = GameManager.MainCamera;
            if (camera == null)
            {
                return false;
            }

            Vector2 pointerPosition = GameManager.InputSystem.ReadPointerScreenPosition(EActionMap.Gameplay);
            Vector2 pointerWorldPosition = camera.ScreenToWorldPoint(pointerPosition);
            Vector2 characterToPointerDirection = pointerWorldPosition - (Vector2)directionPivot.position;
            if (characterToPointerDirection.sqrMagnitude <= 0.0001f)
            {
                return false;
            }

            m_character.SetTargetDirection(characterToPointerDirection.normalized);
            return true;
        }

        /// <summary>
        /// 处理方向移动输入。
        /// 只有当前模式是 <see cref="EPlayerMovementControlMode.Directional"/> 时才会写入移动方向。
        /// </summary>
        public bool HandleDirectionalMove(Vector2 direction)
        {
            if (!m_character || m_movementControlMode != EPlayerMovementControlMode.Directional)
            {
                return false;
            }

            m_character.SetMovementDirection(direction);
            return true;
        }

        /// <summary>
        /// 停止当前移动意图。
        /// 用于松开方向键、命令取消、控制目标切换等场景。
        /// </summary>
        public bool StopMovement()
        {
            if (!m_character)
            {
                return false;
            }

            m_character.ResetMovement();
            return true;
        }

        /// <summary>
        /// 处理点击移动命令。
        /// 优先走地图导航路径；没有导航图时走角色最近合法目标点和直线移动。
        /// </summary>
        public bool HandleClickMove(Vector2 worldPosition)
        {
            if (!m_character ||
                m_movementControlMode != EPlayerMovementControlMode.ClickToMove ||
                !m_character.Can(EActionFlags.Move))
            {
                return false;
            }

            if (TryGetTerrainNavigationMap(out TerrainNavigationMap terrainNavigationMap))
            {
                // 地图有正式导航图时，点击移动必须先构建世界路径；路径失败表示目标不可达，直接停下。
                if (!terrainNavigationMap.TryBuildWorldPath(
                        m_character.transform.position,
                        worldPosition,
                        out Vector2[] worldPath))
                {
                    m_character.ResetMovement();
                    return false;
                }

                m_character.SetMovementDirection(Vector2.zero);
                m_character.MoveAlongPath(worldPath, m_clickMoveStoppingDistance);
                return true;
            }

            // 没有导航图的早期场景仍允许基础点击移动，但目标点要经过 Movable 的合法位置修正。
            Vector3 resolvedDestination = m_character.NearestValidDestination(worldPosition);
            Vector2 destination = resolvedDestination;

            m_character.SetMovementDirection(Vector2.zero);
            m_character.MoveTo(destination, m_clickMoveStoppingDistance);
            return true;
        }

        /// <summary>
        /// 尝试取得当前地图的地形导航图。
        /// 地图和导航数据属于 <see cref="MapSystem"/>，角色移动组件只读取当前活动入口。
        /// </summary>
        private static bool TryGetTerrainNavigationMap(out TerrainNavigationMap terrainNavigationMap)
        {
            terrainNavigationMap = null;
            if (!GameManager.Exists() ||
                !GameManager.TryGetSystem(out MapSystem mapSystem))
            {
                return false;
            }

            return mapSystem.TryGetActiveTerrainNavigationMap(out terrainNavigationMap);
        }

        /// <summary>
        /// 在方向移动和点击移动之间切换。
        /// 切换后会清掉旧模式留下的移动意图。
        /// </summary>
        public bool ToggleMovementControlMode()
        {
            EPlayerMovementControlMode nextMode = m_movementControlMode == EPlayerMovementControlMode.Directional
                ? EPlayerMovementControlMode.ClickToMove
                : EPlayerMovementControlMode.Directional;

            return SetMovementControlMode(nextMode);
        }

        /// <summary>
        /// 设置玩家移动控制模式。
        /// 模式没变时返回 false，避免 UI 或调试面板误以为发生了真实切换。
        /// </summary>
        public bool SetMovementControlMode(EPlayerMovementControlMode mode)
        {
            if (!m_character || m_movementControlMode == mode)
            {
                return false;
            }

            m_movementControlMode = mode;
            m_character.ResetMovement();
            return true;
        }

        /// <summary>
        /// 运行时启动时补齐角色引用。
        /// </summary>
        private void Awake()
        {
            EnsureCharacterReference();
        }

        /// <summary>
        /// 新挂组件或重置 Inspector 时补齐同物体角色引用。
        /// </summary>
        private void Reset()
        {
            EnsureCharacterReference();
        }

        /// <summary>
        /// Inspector 修改后刷新引用，降低 Prefab 作者漏绑概率。
        /// </summary>
        private void OnValidate()
        {
            EnsureCharacterReference();
        }

        /// <summary>
        /// 只从同物体解析角色，保证移动意图不会误写到场景里其它角色。
        /// </summary>
        private void EnsureCharacterReference()
        {
            if (m_character == null)
            {
                TryGetComponent(out m_character);
            }
        }
    }
}
