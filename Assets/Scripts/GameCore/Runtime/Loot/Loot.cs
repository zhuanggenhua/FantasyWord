using System;
using UnityEngine;
using MackySoft.SerializeReferenceExtensions;

namespace FantasyWord.GameCore
{
    [Serializable]
    public struct Loot
    {
        [SerializeReference, SubclassSelector] public ICondition condition;
        public Item item;
        public int quantity;
        public int dropRate;
        public int minimumMonsterLevel;
        public int minimumPlayerLevel;

        public bool IsAvailable() => condition?.Evaluate() ?? true;
        public bool ResolveDrop() => UnityEngine.Random.Range(1, 101) <= dropRate;
    }
}

