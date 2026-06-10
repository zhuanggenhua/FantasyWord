using System.Collections.Generic;
using UnityEngine;

namespace JKFrame
{
    /// <summary>
    /// 随机数来源；规则概率、抽取等跨游戏随机逻辑应通过该合同进入，便于测试、回放和未来权威收口。
    /// </summary>
    public interface IRandomSource
    {
        /// <summary>
        /// 返回 [0, 1) 区间的随机数。
        /// </summary>
        float Next01();
    }

    /// <summary>
    /// 使用 Unity 随机数的默认运行时来源；只由 RandomTool 统一持有，避免业务规则散落直接调用。
    /// </summary>
    public sealed class UnityRandomSource : IRandomSource
    {
        public float Next01()
        {
            return UnityEngine.Random.value;
        }
    }

    /// <summary>
    /// 确定性种子随机数来源；用于可复现验证、回放和后续需要固定序列的规则环境。
    /// </summary>
    public sealed class SeededRandomSource : IRandomSource
    {
        private uint state;

        public SeededRandomSource(string seed)
        {
            state = HashSeed(seed);
            if (state == 0)
            {
                state = 0x6D2B79F5u;
            }
        }

        public float Next01()
        {
            uint x = state;
            x ^= x << 13;
            x ^= x >> 17;
            x ^= x << 5;
            state = x == 0 ? 0x6D2B79F5u : x;
            return (state & 0x00FFFFFFu) / 16777216f;
        }

        private static uint HashSeed(string seed)
        {
            const uint fnvOffset = 2166136261u;
            const uint fnvPrime = 16777619u;
            uint hash = fnvOffset;
            string value = seed ?? string.Empty;
            for (int i = 0; i < value.Length; i++)
            {
                hash ^= value[i];
                hash *= fnvPrime;
            }

            return hash;
        }
    }

    /// <summary>
    /// 队列随机数来源；测试和自动化可以精确控制下一批随机结果，并断言消费数量。
    /// </summary>
    public sealed class QueuedRandomSource : IRandomSource
    {
        private readonly Queue<float> queue = new();
        private readonly IRandomSource fallback;

        public QueuedRandomSource(IRandomSource fallback = null)
        {
            this.fallback = fallback ?? new UnityRandomSource();
        }

        public int ConsumedCount { get; private set; }
        public int QueueLength => queue.Count;
        public bool HasQueue => queue.Count > 0;

        public void SetQueue(IEnumerable<float> values)
        {
            queue.Clear();
            Enqueue(values);
            ConsumedCount = 0;
        }

        public void Enqueue(IEnumerable<float> values)
        {
            if (values == null)
            {
                return;
            }

            foreach (float value in values)
            {
                queue.Enqueue(Mathf.Clamp01(value));
            }
        }

        public void Clear()
        {
            queue.Clear();
            ConsumedCount = 0;
        }

        public float Next01()
        {
            if (queue.Count > 0)
            {
                ConsumedCount++;
                return queue.Dequeue();
            }

            return fallback.Next01();
        }
    }

    /// <summary>
    /// 随机数工具；集中提供概率判定和随机源替换，但不占用任何游戏系统生命周期。
    /// </summary>
    public static class RandomTool
    {
        private static readonly IRandomSource FallbackSource = new UnityRandomSource();
        private static IRandomSource overrideSource;

        /// <summary>
        /// 返回 [0, 1) 随机数；优先使用测试/自动化覆盖源，否则使用 Unity 运行时随机源。
        /// </summary>
        public static float Next01()
        {
            return ResolveSource().Next01();
        }

        /// <summary>
        /// 返回 [min, max) 区间的随机浮点数；参数顺序写反时会自动归一化。
        /// </summary>
        public static float Range(float min, float max)
        {
            float lower = Mathf.Min(min, max);
            float upper = Mathf.Max(min, max);
            if (Mathf.Approximately(lower, upper))
            {
                return lower;
            }

            return lower + Next01() * (upper - lower);
        }

        /// <summary>
        /// 返回 [minInclusive, maxInclusive] 区间的随机整数；参数顺序写反时会自动归一化。
        /// </summary>
        public static int RangeInclusive(int minInclusive, int maxInclusive)
        {
            int lower = Mathf.Min(minInclusive, maxInclusive);
            int upper = Mathf.Max(minInclusive, maxInclusive);
            return Mathf.FloorToInt(Range(lower, upper + 1f));
        }

        /// <summary>
        /// 按 0~1 概率判定是否成功。0% 永不成功且不消耗随机数；100% 永远成功且不消耗随机数；中间值使用 roll &lt; probability。
        /// </summary>
        public static bool RollChance01(float probability01)
        {
            return RollChance01(probability01, out _);
        }

        /// <summary>
        /// 按 0~1 概率判定是否成功，并返回实际使用的 roll；未消耗随机数时 roll 为 NaN。
        /// </summary>
        public static bool RollChance01(float probability01, out float roll01)
        {
            roll01 = float.NaN;
            if (probability01 <= 0f)
            {
                return false;
            }

            if (probability01 >= 1f)
            {
                return true;
            }

            roll01 = Next01();
            return roll01 < probability01;
        }

        /// <summary>
        /// 设置全局覆盖随机源；测试、回放和自动化脚本可用，生产流程不应长期持有覆盖源。
        /// </summary>
        public static void SetOverrideSource(IRandomSource source)
        {
            overrideSource = source;
        }

        /// <summary>
        /// 清理全局覆盖随机源，恢复默认 Unity 随机源。
        /// </summary>
        public static void ClearOverrideSource()
        {
            overrideSource = null;
        }

        /// <summary>
        /// 使用队列随机源覆盖全局随机入口，返回队列对象以便测试断言消费情况。
        /// </summary>
        public static QueuedRandomSource UseQueuedOverride(params float[] values)
        {
            QueuedRandomSource queued = new();
            queued.SetQueue(values);
            SetOverrideSource(queued);
            return queued;
        }

        private static IRandomSource ResolveSource()
        {
            return overrideSource ?? FallbackSource;
        }
    }
}
