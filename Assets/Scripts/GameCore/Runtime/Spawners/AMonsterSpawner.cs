using System;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;

namespace FantasyWord.GameCore
{
    [Serializable]
    public struct MonsterSpawn
    {
        [SerializeField] private GameObject m_prefab;
        [SerializeField] private int m_rate;

        public GameObject Prefab => m_prefab;
        public int Rate => m_rate;
    }

    [Serializable]
    public class MonsterSpawnerDataBlock : PersistableDataBlock
    {
        public CharacterRuntimeStateData[] monsters;
        public int[] monsterIndices; // so we know which monster is which
        public float spawnTimer;
        public int totalSpawnedMonsterCount;
    }

    internal struct SpawnedMonster
    {
        public Monster Monster { get; set; }
        public int Index { get; set; }
    }

    public abstract class AMonsterSpawner : Persistable
    {
        [Header("General Settings")]
        [SerializeField] private MonsterSpawn[] m_monsters = null;
        [SerializeField][Range(Constants.MinLevel, Constants.MaxLevel)] private int m_minLevel = Constants.MinLevel;
        [SerializeField][Range(Constants.MinLevel, Constants.MaxLevel)] private int m_maxLevel = Constants.MaxLevel;

        [Header("Spawn Settings")]
        [SerializeField] private float m_spawnCooldown = 5.0f;
        [SerializeField] private int m_monstersToPrespawn = 4;
        [SerializeField] private int m_maxSimulatenousMonsterCount = 4;

        [Header("Spawn Limitations")]
        [SerializeField] private bool m_limitMonsterCount = false;
        [SerializeField][Min(1)] private int m_maxMonsterCount = 1;

        private HashSet<SpawnedMonster> m_spawnedMonsters = new();

        // Private Members
        private float m_spawnTimer = 0.0f;
        private bool m_valid = false;

        private int m_totalSpawnedMonsterCount = 0;

        private bool m_isFirstUpdate = true;
        private bool m_disablePrespawn = false;

        protected abstract Vector2 FindSpawnLocation();

        private bool Validate()
        {
            int rateSum = 0;

            foreach (MonsterSpawn monster in m_monsters)
            {
                rateSum += monster.Rate;
            }

            return m_valid = rateSum == 100;
        }

        private void Prespawn()
        {
            for (int i = 0; i < m_monstersToPrespawn; ++i)
            {
                TrySpawn();
            }
        }

        private void ResetSpawnTimer()
        {
            m_spawnTimer = m_spawnCooldown;
        }

        private void Update()
        {
            if (m_isFirstUpdate)
            {
                bool isValid = Validate();
                Debug.Assert(isValid, "MonsterSpawner validation failed. Make sure the total spawn rate is equal to 100");
                Array.Sort(m_monsters, (a, b) => a.Rate.CompareTo(b.Rate));
                if (!m_disablePrespawn)
                {
                    Prespawn();
                }
                m_isFirstUpdate = false;
            }

            if (CanSpawn())
            {
                m_spawnTimer -= Time.deltaTime;

                if (m_spawnTimer <= 0.0f)
                {
                    TrySpawn();
                    ResetSpawnTimer();
                }
            }
            else
            {
                ResetSpawnTimer();
            }
        }

        private int FindMonsterIndexToSpawn()
        {
            int randomNumber = UnityEngine.Random.Range(0, 100);

            for (int i = 0; i < m_monsters.Length; ++i)
            {
                MonsterSpawn monster = m_monsters[i];

                if (randomNumber <= monster.Rate)
                {
                    return i;
                }
                else
                {
                    randomNumber -= monster.Rate;
                }
            }

            return -1;
        }

        private bool CanSpawn()
        {
            bool simulatenousMonsterCountReached = m_spawnedMonsters.Count >= m_maxSimulatenousMonsterCount;
            bool maxMonsterCountReached = m_limitMonsterCount && m_totalSpawnedMonsterCount >= m_maxMonsterCount;
            return m_valid && !simulatenousMonsterCountReached && !maxMonsterCountReached;
        }

        private void TrySpawn()
        {
            if (CanSpawn())
            {
                Spawn();
            }
        }

        private void SpawnBack(CharacterRuntimeStateData runtimeState, int indexOfMonsterToSpawn)
        {
            MonsterSpawn monsterSpawn = m_monsters[indexOfMonsterToSpawn];
            Monster monster = Spawn(monsterSpawn.Prefab, indexOfMonsterToSpawn, runtimeState.position, runtimeState.rotation);
            monster.LoadRuntimeState(runtimeState);
        }

        private Monster Spawn(GameObject prefab, int indexOfMonsterToSpawn, Vector3 position, Quaternion rotation)
        {
            Monster monster = GameManager.PersistenceSystem.InstantiateCustom<Monster>(prefab, position, rotation);

            monster.AddDestroyedListener(() => m_spawnedMonsters.RemoveWhere(sm => sm.Monster == monster));

            m_spawnedMonsters.Add(new()
            {
                Monster = monster,
                Index = indexOfMonsterToSpawn
            });

            return monster;
        }

        private void Spawn()
        {
            Vector2 position = FindSpawnLocation();
            int monsterIndex = FindMonsterIndexToSpawn();

            if (monsterIndex != -1)
            {
                Monster monster = Spawn(m_monsters[monsterIndex].Prefab, monsterIndex, position, Quaternion.identity);
                ++m_totalSpawnedMonsterCount;
                monster.SetLevel(UnityEngine.Random.Range(m_minLevel, m_maxLevel));
            }
            else
            {
                Debug.LogError("Couldn't find a monster to spawn, please check your spawn rates and make sure their sum is 100");
            }
        }

        protected override Type GetDataBlockType() => typeof(MonsterSpawnerDataBlock);

        protected override void OnLoad(PersistableDataBlock block)
        {
            base.OnLoad(block);
            var dataBlock = block.As<MonsterSpawnerDataBlock>();

            m_disablePrespawn = true; // <-- skip prespawning monsters

            m_spawnTimer = dataBlock.spawnTimer;

            for (int i = 0; i < dataBlock.monsters.Length; ++i)
            {
                SpawnBack(dataBlock.monsters[i], dataBlock.monsterIndices[i]);
            }

            m_totalSpawnedMonsterCount = dataBlock.totalSpawnedMonsterCount;
        }

        protected override void OnSave(PersistableDataBlock block)
        {
            base.OnSave(block);
            var dataBlock = block.As<MonsterSpawnerDataBlock>();
            dataBlock.monsters = m_spawnedMonsters.Select(m => m.Monster.CreateRuntimeState()).ToArray();
            dataBlock.monsterIndices = m_spawnedMonsters.Select(m => m.Index).ToArray();
            dataBlock.spawnTimer = m_spawnTimer;
            dataBlock.totalSpawnedMonsterCount = m_totalSpawnedMonsterCount;
        }
    }
}

