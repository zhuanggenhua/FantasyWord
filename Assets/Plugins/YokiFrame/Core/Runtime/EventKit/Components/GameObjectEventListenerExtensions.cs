using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.Events;

namespace YokiFrame
{
    public static class GameObjectEventListenerExtensions
    {
        public static GameObjectEventListener ListenPointerEnter(this Component target, UnityAction<PointerEventData> action) => AddListener(target, action, listener => listener.PointerEntered);
        public static GameObjectEventListener ListenPointerExit(this Component target, UnityAction<PointerEventData> action) => AddListener(target, action, listener => listener.PointerExited);
        public static GameObjectEventListener ListenPointerClick(this Component target, UnityAction<PointerEventData> action) => AddListener(target, action, listener => listener.PointerClicked);
        public static GameObjectEventListener ListenPointerDown(this Component target, UnityAction<PointerEventData> action) => AddListener(target, action, listener => listener.PointerDown);
        public static GameObjectEventListener ListenPointerUp(this Component target, UnityAction<PointerEventData> action) => AddListener(target, action, listener => listener.PointerUp);
        public static GameObjectEventListener ListenBeginDrag(this Component target, UnityAction<PointerEventData> action) => AddListener(target, action, listener => listener.BeginDrag);
        public static GameObjectEventListener ListenDrag(this Component target, UnityAction<PointerEventData> action) => AddListener(target, action, listener => listener.Drag);
        public static GameObjectEventListener ListenEndDrag(this Component target, UnityAction<PointerEventData> action) => AddListener(target, action, listener => listener.EndDrag);
        public static GameObjectEventListener ListenCollisionEnter(this Component target, UnityAction<Collision> action) => AddListener(target, action, listener => listener.CollisionEntered);
        public static GameObjectEventListener ListenCollisionStay(this Component target, UnityAction<Collision> action) => AddListener(target, action, listener => listener.CollisionStayed);
        public static GameObjectEventListener ListenCollisionExit(this Component target, UnityAction<Collision> action) => AddListener(target, action, listener => listener.CollisionExited);
        public static GameObjectEventListener ListenTriggerEnter(this Component target, UnityAction<Collider> action) => AddListener(target, action, listener => listener.TriggerEntered);
        public static GameObjectEventListener ListenTriggerStay(this Component target, UnityAction<Collider> action) => AddListener(target, action, listener => listener.TriggerStayed);
        public static GameObjectEventListener ListenTriggerExit(this Component target, UnityAction<Collider> action) => AddListener(target, action, listener => listener.TriggerExited);
        public static GameObjectEventListener ListenCollisionEnter2D(this Component target, UnityAction<Collision2D> action) => AddListener(target, action, listener => listener.Collision2DEntered);
        public static GameObjectEventListener ListenCollisionStay2D(this Component target, UnityAction<Collision2D> action) => AddListener(target, action, listener => listener.Collision2DStayed);
        public static GameObjectEventListener ListenCollisionExit2D(this Component target, UnityAction<Collision2D> action) => AddListener(target, action, listener => listener.Collision2DExited);
        public static GameObjectEventListener ListenTriggerEnter2D(this Component target, UnityAction<Collider2D> action) => AddListener(target, action, listener => listener.Trigger2DEntered);
        public static GameObjectEventListener ListenTriggerStay2D(this Component target, UnityAction<Collider2D> action) => AddListener(target, action, listener => listener.Trigger2DStayed);
        public static GameObjectEventListener ListenTriggerExit2D(this Component target, UnityAction<Collider2D> action) => AddListener(target, action, listener => listener.Trigger2DExited);
        public static GameObjectEventListener ListenDestroyed(this Component target, UnityAction<GameObject> action) => AddListener(target, action, listener => listener.Destroyed);
        public static void RemovePointerClickListener(this Component target, UnityAction<PointerEventData> action) => RemoveListener(target, action, listener => listener.PointerClicked);
        public static void RemoveDestroyedListener(this Component target, UnityAction<GameObject> action) => RemoveListener(target, action, listener => listener.Destroyed);

        public static void ClearGameObjectEventListeners(this Component target)
        {
            if (target == null || !target.TryGetComponent(out GameObjectEventListener listener))
            {
                return;
            }

            listener.ClearRuntimeListeners();
        }

        private static GameObjectEventListener AddListener<T>(
            Component target,
            UnityAction<T> action,
            System.Func<GameObjectEventListener, UnityEvent<T>> getEvent)
        {
            if (target == null || action == null)
            {
                return null;
            }

            var listener = GameObjectEventListener.GetOrAdd(target.gameObject);
            getEvent(listener).AddListener(action);
            return listener;
        }

        private static void RemoveListener<T>(
            Component target,
            UnityAction<T> action,
            System.Func<GameObjectEventListener, UnityEvent<T>> getEvent)
        {
            if (target == null || action == null || !target.TryGetComponent(out GameObjectEventListener listener))
            {
                return;
            }

            getEvent(listener).RemoveListener(action);
        }
    }
}
