using System;
using System.Linq;
using UnityEngine;

namespace GAS.Runtime
{
    [Serializable]
    public struct GameplayTag : ISerializationCallbackReceiver
    {
        [SerializeField] private string _name;
        [SerializeField] private int _hashCode;
        [SerializeField] private string _shortName;
        [SerializeField] private int[] _ancestorHashCodes;
        [SerializeField] private string[] _ancestorNames;

        public GameplayTag(string name)
        {
            _name = name;
            _hashCode = 0;
            _shortName = string.Empty;
            _ancestorHashCodes = Array.Empty<int>();
            _ancestorNames = Array.Empty<string>();
            RebuildRuntimeData();
        }

        /// <summary>
        ///     Only For Show.
        /// </summary>
        public string Name => _name;

        /// <summary>
        ///     Only For Show.
        /// </summary>
        public string ShortName => _shortName;

        /// <summary>
        ///     Actually ,Use the hash code for compare.
        /// </summary>
        public int HashCode => _hashCode;

        public string[] AncestorNames => _ancestorNames;

        public bool Root => _ancestorHashCodes.Length == 0;

        public int[] AncestorHashCodes => _ancestorHashCodes;

        public bool IsDescendantOf(GameplayTag other)
        {
            return _ancestorHashCodes.Contains(other.HashCode);
        }

        public override bool Equals(object obj)
        {
            return obj is GameplayTag tag && this == tag;
        }

        public override int GetHashCode()
        {
            return HashCode;
        }

        public static bool operator ==(GameplayTag x, GameplayTag y)
        {
            return x.HashCode == y.HashCode
                && string.Equals(x._name, y._name, StringComparison.Ordinal);
        }

        public static bool operator !=(GameplayTag x, GameplayTag y)
        {
            return !(x == y);
        }

        public bool HasTag(GameplayTag tag)
        {
            if (this == tag)
            {
                return true;
            }

            foreach (var ancestorHashCode in _ancestorHashCodes)
                if (ancestorHashCode == tag.HashCode)
                    return true;

            if (_ancestorNames == null || string.IsNullOrEmpty(tag._name))
            {
                return false;
            }

            foreach (var ancestorName in _ancestorNames)
            {
                if (string.Equals(ancestorName, tag._name, StringComparison.Ordinal))
                {
                    return true;
                }
            }

            return false;
        }

        public void OnBeforeSerialize()
        {
            RebuildRuntimeData();
        }

        public void OnAfterDeserialize()
        {
            RebuildRuntimeData();
        }

        private void RebuildRuntimeData()
        {
            if (string.IsNullOrEmpty(_name))
            {
                _name = string.Empty;
                _hashCode = 0;
                _shortName = string.Empty;
                _ancestorNames = Array.Empty<string>();
                _ancestorHashCodes = Array.Empty<int>();
                return;
            }

            _hashCode = ComputeStableHash(_name);

            var tags = _name.Split('.');
            _shortName = tags.Length > 0 ? tags.Last() : _name;
            _ancestorNames = new string[Math.Max(0, tags.Length - 1)];
            _ancestorHashCodes = new int[_ancestorNames.Length];

            string ancestorTag = string.Empty;
            for (int i = 0; i < tags.Length - 1; i++)
            {
                ancestorTag += tags[i];
                _ancestorNames[i] = ancestorTag;
                _ancestorHashCodes[i] = ComputeStableHash(ancestorTag);
                ancestorTag += ".";
            }
        }

        private static int ComputeStableHash(string value)
        {
            unchecked
            {
                const int fnvPrime = 16777619;
                int hash = (int)2166136261;
                if (string.IsNullOrEmpty(value))
                {
                    return 0;
                }

                for (int i = 0; i < value.Length; i++)
                {
                    hash ^= value[i];
                    hash *= fnvPrime;
                }

                return hash;
            }
        }
    }
}
