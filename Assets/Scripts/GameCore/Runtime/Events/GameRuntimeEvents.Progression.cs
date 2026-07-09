namespace FantasyWord.GameCore
{
    /// <summary>
    /// 非召唤怪物死亡时发送的领域事件。它只描述被击杀的怪物表，不处理奖励、任务内容或 UI 日志。
    /// </summary>
    public readonly struct MonsterKilledEvent
    {
        public MonsterKilledEvent(MonsterSheet monster)
        {
            Monster = monster;
        }

        public MonsterSheet Monster { get; }
    }

    /// <summary>
    /// 玩家长期 Hero 获得经验时发送的成长事件。它只描述数值变化，不决定 UI 日志、任务可用性或等级规则。
    /// </summary>
    public readonly struct HeroExperienceGainedEvent
    {
        public HeroExperienceGainedEvent(int amount)
        {
            Amount = amount;
        }

        public int Amount { get; }
    }

    /// <summary>
    /// 玩家长期 Hero 升级时发送的成长事件。等级规则仍由 Hero/CharacterBase 负责，监听者只响应结果。
    /// </summary>
    public readonly struct HeroLevelUpEvent
    {
        public HeroLevelUpEvent(int level)
        {
            Level = level;
        }

        public int Level { get; }
    }

    public static partial class GameRuntimeEvents
    {
        public static void NotifyMonsterKilled(MonsterSheet monster)
        {
            if (!monster)
            {
                return;
            }

            Publish(new MonsterKilledEvent(monster));
        }

        public static void NotifyHeroExperienceGained(int amount)
        {
            Publish(new HeroExperienceGainedEvent(amount));
        }

        public static void NotifyHeroLevelUp(int level)
        {
            Publish(new HeroLevelUpEvent(level));
        }
    }
}
