using Sirenix.OdinInspector;
using UnityEngine;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 角色背包通道，决定查询主背包、武器背包还是快捷栏背包。
    /// </summary>
    public enum ECharacterInventoryChannel
    {
        /// <summary>常规物品背包。</summary>
        Main,

        /// <summary>武器或装备切换用背包。</summary>
        Weapon,

        /// <summary>快捷栏或热键槽使用的背包。</summary>
        Hotbar
    }

    /// <summary>
    /// 角色背包归属配置组件，决定各背包通道归角色独占还是落到队伍共享背包。
    /// </summary>
    /// <remarks>
    /// 这个组件只解析“谁是背包 owner”，不直接存储物品列表。
    /// 真正的物品数据、增删、转移和装备操作仍由 <see cref="InventorySystem"/> 持有。
    /// </remarks>
    [DisallowMultipleComponent]
    [RequireComponent(typeof(CharacterBase))]
    public sealed class CharacterInventory : MonoBehaviour
    {
        [Header("背包归属")]
        [SerializeField]
        [LabelText("角色引用")]
        [Tooltip("拥有独立背包时使用的角色引用；通常自动取同物体上的 CharacterBase。")]
        private CharacterBase m_character = null;

        [SerializeField]
        [LabelText("主背包归角色所有")]
        [Tooltip("关闭后，主背包入口会解析到默认队伍背包。")]
        private bool m_ownsMainInventory = true;

        [SerializeField]
        [LabelText("武器背包归角色所有")]
        [Tooltip("关闭后，武器背包入口会解析到默认队伍背包。")]
        private bool m_ownsWeaponInventory = true;

        [SerializeField]
        [LabelText("快捷栏归角色所有")]
        [Tooltip("关闭后，快捷栏入口会解析到默认队伍背包。")]
        private bool m_ownsHotbarInventory = true;

        /// <summary>角色独占背包使用的角色 owner。</summary>
        public CharacterBase Character => m_character;

        /// <summary>主背包是否归该角色独占。</summary>
        public bool OwnsMainInventory => m_ownsMainInventory;

        /// <summary>武器背包是否归该角色独占。</summary>
        public bool OwnsWeaponInventory => m_ownsWeaponInventory;

        /// <summary>快捷栏背包是否归该角色独占。</summary>
        public bool OwnsHotbarInventory => m_ownsHotbarInventory;

        /// <summary>
        /// 解析主背包的所有者句柄。
        /// 结果可能是当前角色，也可能是默认队伍背包。
        /// </summary>
        public InventoryOwnerHandle ResolveMainInventoryOwner()
        {
            return ResolveOwner(m_ownsMainInventory);
        }

        /// <summary>
        /// 解析武器背包的所有者句柄。
        /// 武器背包独立存在时，后续可以承接 TopDown 风格的武器轮换；当前仍交给 InventorySystem 存储。
        /// </summary>
        public InventoryOwnerHandle ResolveWeaponInventoryOwner()
        {
            return ResolveOwner(m_ownsWeaponInventory);
        }

        /// <summary>
        /// 解析快捷栏背包的所有者句柄。
        /// 快捷栏共享时会落到默认队伍背包，方便队伍控制后继续复用同一套物品入口。
        /// </summary>
        public InventoryOwnerHandle ResolveHotbarInventoryOwner()
        {
            return ResolveOwner(m_ownsHotbarInventory);
        }

        /// <summary>
        /// 按背包通道解析对应的所有者句柄。
        /// </summary>
        public InventoryOwnerHandle ResolveOwner(ECharacterInventoryChannel channel)
        {
            return channel switch
            {
                ECharacterInventoryChannel.Weapon => ResolveWeaponInventoryOwner(),
                ECharacterInventoryChannel.Hotbar => ResolveHotbarInventoryOwner(),
                _ => ResolveMainInventoryOwner()
            };
        }

        /// <summary>
        /// 根据通道配置返回角色 owner 或默认队伍 owner。
        /// 如果配置为角色独占但缺少 <see cref="CharacterBase"/>，这是 Prefab 接线错误，必须直接暴露。
        /// </summary>
        private InventoryOwnerHandle ResolveOwner(bool ownedByCharacter)
        {
            if (!ownedByCharacter)
            {
                return InventoryOwnerHandle.DefaultParty;
            }

            if (m_character == null)
            {
                throw new MissingComponentException(
                    $"[{nameof(CharacterInventory)}] Character-owned inventory requires {nameof(CharacterBase)} on the same GameObject.");
            }

            return InventoryOwnerHandle.ForCharacter(m_character);
        }

        /// <summary>
        /// 运行时启动时补齐角色引用。
        /// </summary>
        private void Awake()
        {
            EnsureCharacterReference();
        }

        /// <summary>
        /// 组件重置时自动补齐同物体角色引用。
        /// </summary>
        private void Reset()
        {
            EnsureCharacterReference();
        }

        /// <summary>
        /// Inspector 修改后刷新引用，避免 Prefab 作者漏绑。
        /// </summary>
        private void OnValidate()
        {
            EnsureCharacterReference();
        }

        /// <summary>
        /// 只从同物体解析角色，不做场景搜索，保证背包 owner 明确。
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
