namespace FantasyWord.GameCore
{
    public abstract partial class CharacterBase
    {
        /// <summary>
        /// 角色属性启动快照缓冲。
        /// 这里只服务 CharacterBase 自己在启动窗口里的 bootstrap 临时快照，
        /// 不再承担 Awake 结束后的正式 ASC 长期镜像真相。
        /// </summary>
        private sealed class AttributeBootstrapBuffer
        {
            // 启动窗口里的基础属性快照。正式运行期属性真相仍在 ASC，不在这里长期镜像。
            private Stats m_baseStats = new();
            // 启动窗口里的当前属性快照。它只跟随基础属性差额迁移，避免初始化期间当前值被直接覆盖。
            private Stats m_currentStats = new();

            /// <summary>
            /// 清空 bootstrap 临时快照。
            /// 角色重新初始化或读档切换时必须先清掉旧快照，避免旧对象残留影响 ASC 初始值。
            /// </summary>
            public void Clear()
            {
                m_baseStats = new Stats();
                m_currentStats = new Stats();
            }

            /// <summary>
            /// 替换基础属性，并把基础属性差额同步到当前属性快照。
            /// 这样等级或配置表刷新时，当前生命/法力能保留相对变化，不会被硬重置成新基础值。
            /// </summary>
            public void ReplaceBaseStats(Stats stats)
            {
                Stats nextBaseStats = stats?.Clone() ?? new Stats();
                Stats difference = nextBaseStats - m_baseStats;
                m_baseStats = nextBaseStats;
                m_currentStats += difference;
            }

            /// <summary>
            /// 读取启动窗口基础属性；缺失时返回 0，调用方再决定是否回退到正式 ASC。
            /// </summary>
            public int GetBaseStat(EStat stat) => m_baseStats?[stat] ?? 0;

            /// <summary>
            /// 读取启动窗口当前属性；缺失时返回 0，避免空 Stats 在早期生命周期抛异常。
            /// </summary>
            public int GetCurrentStat(EStat stat) => m_currentStats?[stat] ?? 0;

            /// <summary>
            /// 创建基础属性快照副本，避免外部直接修改缓冲内部 Stats。
            /// </summary>
            public Stats CreateBaseStatsSnapshot() => m_baseStats?.Clone() ?? new Stats();

            /// <summary>
            /// 创建当前属性快照副本，避免存档或恢复流程拿到内部可变引用。
            /// </summary>
            public Stats CreateCurrentStatsSnapshot() => m_currentStats?.Clone() ?? new Stats();

            /// <summary>
            /// 只在启动窗口仍允许 bootstrap 读取时，临时把 ASC 快照回填进旧缓冲。
            /// 这里统一接收一整份基础/当前快照，避免 CharacterBase 外层再散落逐项同步顺序。
            /// </summary>
            public void MirrorFromFormalSnapshots(Stats baseStats, Stats currentStats)
            {
                Stats safeBaseStats = baseStats?.Clone() ?? new Stats();
                Stats safeCurrentStats = currentStats?.Clone() ?? safeBaseStats.Clone();
                if (AreStatsEqual(m_baseStats, safeBaseStats) && AreStatsEqual(m_currentStats, safeCurrentStats))
                {
                    return;
                }

                m_baseStats = safeBaseStats;
                m_currentStats = safeCurrentStats;
            }
        }
    }
}
