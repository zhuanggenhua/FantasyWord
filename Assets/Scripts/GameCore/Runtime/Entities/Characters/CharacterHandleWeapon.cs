using Sirenix.OdinInspector;
using UnityEngine;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 角色武器挂点组件。
    /// 为能力、武器执行和弹丸生成提供稳定的角色侧 Transform 入口。
    /// </summary>
    /// <remarks>
    /// 这里不拥有装备槽、武器数据或攻击规则；装备真相在 <see cref="CharacterEquipment"/>，
    /// 能力执行仍由技能/武器运行时负责。该组件只回答“武器挂在哪里、弹丸从哪里出生”。
    /// </remarks>
    [DisallowMultipleComponent]
    [RequireComponent(typeof(CharacterBase))]
    public sealed class CharacterHandleWeapon : MonoBehaviour
    {
        [Header("武器挂点")]
        [SerializeField]
        [LabelText("角色引用"), Tooltip("持有武器挂点的角色；通常自动取同物体上的 CharacterBase。")]
        private CharacterBase m_character = null;

        [SerializeField]
        [LabelText("武器挂载点"), Tooltip("武器模型、特效或近战判定框的默认挂载位置；为空时使用角色 Transform。")]
        private Transform m_weaponAttachment = null;

        [SerializeField]
        [LabelText("弹丸出生点"), Tooltip("远程弹丸或投射物生成位置；为空时回退到武器挂载点。")]
        private Transform m_projectileSpawn = null;

        /// <summary>挂点所属角色。</summary>
        public CharacterBase Character => m_character;

        /// <summary>
        /// 武器挂载点。
        /// 未配置时回退到角色根节点，避免旧 Prefab 缺挂点时能力链直接空引用。
        /// </summary>
        public Transform WeaponAttachment => m_weaponAttachment ? m_weaponAttachment : transform;

        /// <summary>
        /// 弹丸出生点。
        /// 未配置独立出生点时回退到武器挂载点，让近战和远程能力共用同一挂点配置。
        /// </summary>
        public Transform ProjectileSpawn => m_projectileSpawn ? m_projectileSpawn : WeaponAttachment;

        /// <summary>当前解析出的弹丸出生世界坐标。</summary>
        public Vector3 ProjectileSpawnPosition => ProjectileSpawn.position;

        /// <summary>
        /// 尝试取得武器挂载点。
        /// 当前属性有角色根节点回退，因此只要组件存在通常会返回 true。
        /// </summary>
        public bool TryGetWeaponAttachment(out Transform attachment)
        {
            attachment = WeaponAttachment;
            return attachment != null;
        }

        /// <summary>
        /// 尝试取得弹丸出生点。
        /// </summary>
        public bool TryGetProjectileSpawn(out Transform spawn)
        {
            spawn = ProjectileSpawn;
            return spawn != null;
        }

        /// <summary>
        /// 解析弹丸出生世界坐标。
        /// 保留 transform 回退，是为了在组件或挂点配置异常时仍能返回可诊断的位置。
        /// </summary>
        public Vector3 ResolveProjectileSpawnPosition()
        {
            return TryGetProjectileSpawn(out Transform spawn) ? spawn.position : transform.position;
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
        /// Inspector 修改后刷新引用。
        /// </summary>
        private void OnValidate()
        {
            EnsureCharacterReference();
        }

        /// <summary>
        /// 只从同物体解析角色，保证挂点 owner 明确。
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
