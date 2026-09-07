namespace FantasyWord.GameCore
{
    /// <summary>
    /// 角色菜单打开上下文，决定面板查看固定角色还是跟随当前控制角色。
    /// 它只保存查看目标，不持有角色状态，也不直接刷新 UI。
    /// </summary>
    public readonly struct CharacterMenuContext
    {
        private CharacterMenuContext(CharacterBase actor)
        {
            Actor = actor;
        }

        /// <summary>固定查看的角色；为空时表示跟随当前控制角色。</summary>
        public CharacterBase Actor { get; }

        /// <summary>是否在面板显示期间监听当前控制角色变化。</summary>
        public bool FollowsCurrentControlledCharacter => Actor == null;

        /// <summary>创建跟随当前控制角色的默认上下文。</summary>
        public static CharacterMenuContext CurrentControlledCharacter()
        {
            return new CharacterMenuContext(null);
        }

        /// <summary>创建查看指定角色的上下文；传空时回退到当前控制角色模式。</summary>
        public static CharacterMenuContext ViewCharacter(CharacterBase actor)
        {
            return actor == null
                ? CurrentControlledCharacter()
                : new CharacterMenuContext(actor);
        }

        /// <summary>解析当前菜单应该展示的角色。</summary>
        public CharacterBase ResolveActor()
        {
            if (Actor != null)
            {
                return Actor;
            }

            return GameManager.TryGetSystem(out PlayerSystem playerSystem)
                ? playerSystem.GetCurrentControlledCharacterOrPlayerInstance()
                : null;
        }
    }
}
