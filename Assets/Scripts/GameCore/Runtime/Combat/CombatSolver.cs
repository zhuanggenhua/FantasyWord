namespace FantasyWord.GameCore
{
    /// <summary>
    /// 战斗目标关系的最小判断入口。
    /// 伤害、目标捕获、AI 选敌和效果筛选都应复用这里的可命中/敌我关系合同，
    /// 避免每条链路各自解释无敌、死亡和中立阵营。
    /// </summary>
    public static class CombatSolver
    {
        /// <summary>
        /// 判断 defender 是否是 attacker 当前可以攻击的敌对目标。
        /// 这里同时要求基础可命中和阵营相异，中立单位是否主动敌对由 IsHostileTowards 单独表达。
        /// </summary>
        public static bool IsJudiciousTarget(CharacterBase attacker, CharacterBase defender) => CanTarget(attacker, defender) && AreEnemies(attacker, defender);

        /// <summary>
        /// 用已结算的伤害输出判断目标是否仍可被命中。
        /// 如果伤害来源没有角色，说明来源可能是环境或脚本效果，基础可命中规则只由目标自身状态决定。
        /// </summary>
        public static bool CanTarget(DamageOutputDescriptor damageOutput, CharacterBase defender)
        {
            if (damageOutput.TryGetSourceCharacter(out CharacterBase attacker))
            {
                return CanTarget(attacker, defender);
            }

            return true;
        }

        /// <summary>
        /// 判断 b 是否能被 a 作为效果目标。
        /// 自己可以命中自己的无敌状态，用来允许治疗、清理或状态自检这类自作用效果；
        /// 攻击者死亡、目标死亡都会直接拒绝，避免死亡流程后继续叠加新战斗结果。
        /// </summary>
        public static bool CanTarget(CharacterBase a, CharacterBase b)
        {
            return
                (!b.invincible || a == b) &&
                (a == null || !a.dead) &&
                !b.dead;
        }

        /// <summary>
        /// 只比较阵营是否一致，不额外判断死亡、无敌或中立语义。
        /// 调用方如果要判断真实可作用目标，必须先走 CanTarget。
        /// </summary>
        public static bool AreAllies(CharacterBase a, CharacterBase b)
        {
            return a.currentAlignment == b.currentAlignment;
        }

        /// <summary>
        /// 只比较阵营是否不同，Neutral 与任意非 Neutral 也会被算作不同阵营。
        /// 需要“主动敌对”语义时使用 IsHostileTowards。
        /// </summary>
        public static bool AreEnemies(CharacterBase a, CharacterBase b)
        {
            return a.currentAlignment != b.currentAlignment;
        }

        /// <summary>
        /// 判断 a 是否对 b 构成主动敌对关系。
        /// Neutral 不主动敌对任何阵营，用于 AI 选敌和仇恨判断这类需要排除中立目标的入口。
        /// </summary>
        public static bool IsHostileTowards(CharacterBase a, CharacterBase b)
        {
            return
                AreEnemies(a, b) &&
                a.currentAlignment != EAlignment.Neutral &&
                b.currentAlignment != EAlignment.Neutral;
        }
    }
}
