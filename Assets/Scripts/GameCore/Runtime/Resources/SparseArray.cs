using System;
using System.Collections;
using System.Collections.Generic;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 稀疏数组，迁自 Chris 的资源句柄实现。
    /// 这里用于保存 Addressables 异步操作，使外部拿到的轻量句柄在释放后不会误指向新操作。
    /// </summary>
    internal sealed class SparseArray<T> : IEnumerable<T>
    {
        private struct FreeListLink
        {
            public int Last;
            public int Next;
            public T Value;
        }

        private readonly List<FreeListLink> m_data;
        private readonly List<bool> m_allocationFlags;
        private readonly int m_capacity;
        private int m_firstFreeIndex;
        private int m_numFreeIndices;

        public int Count => m_data.Count - m_numFreeIndices;

        public T this[int index]
        {
            get => IsAllocated(index) ? m_data[index].Value : default;
            set
            {
                if (!IsAllocated(index))
                {
                    return;
                }

                FreeListLink link = m_data[index];
                link.Value = value;
                m_data[index] = link;
            }
        }

        public SparseArray(int length, int capacity)
        {
            m_capacity = capacity;
            m_data = new List<FreeListLink>(length);
            m_allocationFlags = new List<bool>(length);

            for (int i = 0; i < length; ++i)
            {
                m_data.Add(new FreeListLink
                {
                    Last = i - 1,
                    Value = default,
                    Next = i + 1 >= length ? -1 : i + 1
                });
                m_allocationFlags.Add(false);
            }

            m_firstFreeIndex = length > 0 ? 0 : -1;
            m_numFreeIndices = length;
        }

        public int Add(T element)
        {
            int index;
            if (m_numFreeIndices > 0)
            {
                index = m_firstFreeIndex;
                FreeListLink link = m_data[index];
                int next = link.Next;

                link.Value = element;
                link.Next = -1;
                m_data[index] = link;

                if (next != -1)
                {
                    FreeListLink nextLink = m_data[next];
                    nextLink.Last = -1;
                    m_data[next] = nextLink;
                }

                m_allocationFlags[index] = true;
                m_firstFreeIndex = next;
                m_numFreeIndices--;
            }
            else
            {
                index = m_data.Count;
                if (m_data.Count == m_capacity)
                {
                    throw new ArgumentOutOfRangeException(nameof(element), $"Sparse array should not exceed capacity {m_capacity}.");
                }

                m_data.Add(new FreeListLink
                {
                    Value = element,
                    Last = -1,
                    Next = -1
                });
                m_allocationFlags.Add(true);
            }

            return index;
        }

        public void RemoveAt(int index)
        {
            if (!IsAllocated(index))
            {
                return;
            }

            FreeListLink link = m_data[index];
            link.Value = default;
            link.Last = -1;
            m_allocationFlags[index] = false;

            if (m_firstFreeIndex == -1)
            {
                link.Next = -1;
            }
            else
            {
                FreeListLink head = m_data[m_firstFreeIndex];
                head.Last = index;
                m_data[m_firstFreeIndex] = head;
                link.Next = m_firstFreeIndex;
            }

            m_data[index] = link;
            m_firstFreeIndex = index;
            m_numFreeIndices++;
        }

        public bool IsAllocated(int index)
        {
            return index >= 0 && index < m_allocationFlags.Count && m_allocationFlags[index];
        }

        public IEnumerator<T> GetEnumerator()
        {
            for (int i = 0; i < m_data.Count; ++i)
            {
                if (m_allocationFlags[i])
                {
                    yield return m_data[i].Value;
                }
            }
        }

        IEnumerator IEnumerable.GetEnumerator()
        {
            return GetEnumerator();
        }
    }
}
