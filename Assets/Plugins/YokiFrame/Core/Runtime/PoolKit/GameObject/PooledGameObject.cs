using UnityEngine;

namespace YokiFrame
{
    public sealed class PooledGameObject : MonoBehaviour
    {
        public string PoolKey { get; private set; }
        public bool InPool { get; private set; }

        internal void Initialize(string poolKey)
        {
            PoolKey = poolKey ?? string.Empty;
        }

        internal void MarkRented()
        {
            InPool = false;
        }

        internal void MarkReturned()
        {
            InPool = true;
        }

        public bool ReturnToPool()
        {
            return GameObjectPoolService.Return(gameObject);
        }
    }
}
