using System;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.Events;

namespace YokiFrame
{
    public sealed class GameObjectEventListener : MonoBehaviour,
        IPointerEnterHandler,
        IPointerExitHandler,
        IPointerClickHandler,
        IPointerDownHandler,
        IPointerUpHandler,
        IBeginDragHandler,
        IDragHandler,
        IEndDragHandler
    {
        [Serializable] public sealed class PointerEvent : UnityEvent<PointerEventData> { }
        [Serializable] public sealed class CollisionEvent : UnityEvent<Collision> { }
        [Serializable] public sealed class Collision2DEvent : UnityEvent<Collision2D> { }
        [Serializable] public sealed class ColliderEvent : UnityEvent<Collider> { }
        [Serializable] public sealed class Collider2DEvent : UnityEvent<Collider2D> { }
        [Serializable] public sealed class GameObjectEvent : UnityEvent<GameObject> { }

        [Header("Pointer")]
        [SerializeField] private PointerEvent mPointerEntered = new();
        [SerializeField] private PointerEvent mPointerExited = new();
        [SerializeField] private PointerEvent mPointerClicked = new();
        [SerializeField] private PointerEvent mPointerDown = new();
        [SerializeField] private PointerEvent mPointerUp = new();
        [SerializeField] private PointerEvent mBeginDrag = new();
        [SerializeField] private PointerEvent mDrag = new();
        [SerializeField] private PointerEvent mEndDrag = new();

        [Header("Physics 3D")]
        [SerializeField] private CollisionEvent mCollisionEntered = new();
        [SerializeField] private CollisionEvent mCollisionStayed = new();
        [SerializeField] private CollisionEvent mCollisionExited = new();
        [SerializeField] private ColliderEvent mTriggerEntered = new();
        [SerializeField] private ColliderEvent mTriggerStayed = new();
        [SerializeField] private ColliderEvent mTriggerExited = new();

        [Header("Physics 2D")]
        [SerializeField] private Collision2DEvent mCollision2DEntered = new();
        [SerializeField] private Collision2DEvent mCollision2DStayed = new();
        [SerializeField] private Collision2DEvent mCollision2DExited = new();
        [SerializeField] private Collider2DEvent mTrigger2DEntered = new();
        [SerializeField] private Collider2DEvent mTrigger2DStayed = new();
        [SerializeField] private Collider2DEvent mTrigger2DExited = new();

        [Header("Lifecycle")]
        [SerializeField] private GameObjectEvent mDestroyed = new();

        public PointerEvent PointerEntered => mPointerEntered;
        public PointerEvent PointerExited => mPointerExited;
        public PointerEvent PointerClicked => mPointerClicked;
        public PointerEvent PointerDown => mPointerDown;
        public PointerEvent PointerUp => mPointerUp;
        public PointerEvent BeginDrag => mBeginDrag;
        public PointerEvent Drag => mDrag;
        public PointerEvent EndDrag => mEndDrag;
        public CollisionEvent CollisionEntered => mCollisionEntered;
        public CollisionEvent CollisionStayed => mCollisionStayed;
        public CollisionEvent CollisionExited => mCollisionExited;
        public ColliderEvent TriggerEntered => mTriggerEntered;
        public ColliderEvent TriggerStayed => mTriggerStayed;
        public ColliderEvent TriggerExited => mTriggerExited;
        public Collision2DEvent Collision2DEntered => mCollision2DEntered;
        public Collision2DEvent Collision2DStayed => mCollision2DStayed;
        public Collision2DEvent Collision2DExited => mCollision2DExited;
        public Collider2DEvent Trigger2DEntered => mTrigger2DEntered;
        public Collider2DEvent Trigger2DStayed => mTrigger2DStayed;
        public Collider2DEvent Trigger2DExited => mTrigger2DExited;
        public GameObjectEvent Destroyed => mDestroyed;

        public static GameObjectEventListener GetOrAdd(GameObject target)
        {
            if (target == null)
            {
                return null;
            }

            if (!target.TryGetComponent(out GameObjectEventListener listener))
            {
                listener = target.AddComponent<GameObjectEventListener>();
            }

            return listener;
        }

        public void OnPointerEnter(PointerEventData eventData) => mPointerEntered.Invoke(eventData);
        public void OnPointerExit(PointerEventData eventData) => mPointerExited.Invoke(eventData);
        public void OnPointerClick(PointerEventData eventData) => mPointerClicked.Invoke(eventData);
        public void OnPointerDown(PointerEventData eventData) => mPointerDown.Invoke(eventData);
        public void OnPointerUp(PointerEventData eventData) => mPointerUp.Invoke(eventData);
        public void OnBeginDrag(PointerEventData eventData) => mBeginDrag.Invoke(eventData);
        public void OnDrag(PointerEventData eventData) => mDrag.Invoke(eventData);
        public void OnEndDrag(PointerEventData eventData) => mEndDrag.Invoke(eventData);

        private void OnCollisionEnter(Collision collision) => mCollisionEntered.Invoke(collision);
        private void OnCollisionStay(Collision collision) => mCollisionStayed.Invoke(collision);
        private void OnCollisionExit(Collision collision) => mCollisionExited.Invoke(collision);
        private void OnTriggerEnter(Collider other) => mTriggerEntered.Invoke(other);
        private void OnTriggerStay(Collider other) => mTriggerStayed.Invoke(other);
        private void OnTriggerExit(Collider other) => mTriggerExited.Invoke(other);
        private void OnCollisionEnter2D(Collision2D collision) => mCollision2DEntered.Invoke(collision);
        private void OnCollisionStay2D(Collision2D collision) => mCollision2DStayed.Invoke(collision);
        private void OnCollisionExit2D(Collision2D collision) => mCollision2DExited.Invoke(collision);
        private void OnTriggerEnter2D(Collider2D other) => mTrigger2DEntered.Invoke(other);
        private void OnTriggerStay2D(Collider2D other) => mTrigger2DStayed.Invoke(other);
        private void OnTriggerExit2D(Collider2D other) => mTrigger2DExited.Invoke(other);

        private void OnDestroy()
        {
            mDestroyed.Invoke(gameObject);
            ClearRuntimeListeners();
        }

        public void ClearRuntimeListeners()
        {
            mPointerEntered.RemoveAllListeners();
            mPointerExited.RemoveAllListeners();
            mPointerClicked.RemoveAllListeners();
            mPointerDown.RemoveAllListeners();
            mPointerUp.RemoveAllListeners();
            mBeginDrag.RemoveAllListeners();
            mDrag.RemoveAllListeners();
            mEndDrag.RemoveAllListeners();
            mCollisionEntered.RemoveAllListeners();
            mCollisionStayed.RemoveAllListeners();
            mCollisionExited.RemoveAllListeners();
            mTriggerEntered.RemoveAllListeners();
            mTriggerStayed.RemoveAllListeners();
            mTriggerExited.RemoveAllListeners();
            mCollision2DEntered.RemoveAllListeners();
            mCollision2DStayed.RemoveAllListeners();
            mCollision2DExited.RemoveAllListeners();
            mTrigger2DEntered.RemoveAllListeners();
            mTrigger2DStayed.RemoveAllListeners();
            mTrigger2DExited.RemoveAllListeners();
            mDestroyed.RemoveAllListeners();
        }
    }
}
