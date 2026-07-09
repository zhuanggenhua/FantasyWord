using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace YokiFrame
{
    public static class CoroutineKit
    {
        private static readonly WaitForEndOfFrame sWaitForEndOfFrame = new();
        private static readonly WaitForFixedUpdate sWaitForFixedUpdate = new();
        private static readonly Dictionary<float, WaitForSeconds> sWaitForSeconds = new();
        private static readonly Dictionary<object, List<CoroutineHandle>> sOwnerCoroutines = new();

        public static WaitForEndOfFrame WaitForEndOfFrame => sWaitForEndOfFrame;

        public static WaitForFixedUpdate WaitForFixedUpdate => sWaitForFixedUpdate;

        public static WaitForSeconds WaitForSeconds(float seconds)
        {
            if (seconds <= 0f)
            {
                seconds = 0f;
            }

            if (!sWaitForSeconds.TryGetValue(seconds, out var wait))
            {
                wait = new WaitForSeconds(seconds);
                sWaitForSeconds.Add(seconds, wait);
            }

            return wait;
        }

        public static IEnumerator WaitForSecondsRealtime(float seconds)
        {
            if (seconds <= 0f)
            {
                yield break;
            }

            var elapsedTime = 0f;
            while (elapsedTime < seconds)
            {
                elapsedTime += Time.unscaledDeltaTime;
                yield return null;
            }
        }

        public static IEnumerator WaitForFrames(int frames = 1)
        {
            for (int i = 0; i < frames; ++i)
            {
                yield return null;
            }
        }

        public static IEnumerator ExecuteInXFrames(int frames, Action callback)
        {
            for (int i = 0; i < frames; ++i)
            {
                yield return null;
            }

            callback?.Invoke();
        }

        public static UnityEngine.Coroutine StartForOwner(object owner, IEnumerator routine)
        {
            if (owner == null)
            {
                throw new ArgumentNullException(nameof(owner));
            }

            if (routine == null)
            {
                throw new ArgumentNullException(nameof(routine));
            }

            var handle = new CoroutineHandle(CoroutineRunner.Instance);
            Register(owner, handle);
            handle.Coroutine = CoroutineRunner.StartCoroutineStatic(RunTracked(owner, routine, handle));
            return handle.Coroutine;
        }

        public static UnityEngine.Coroutine StartForOwner(MonoBehaviour runner, object owner, IEnumerator routine)
        {
            if (runner == null)
            {
                throw new ArgumentNullException(nameof(runner));
            }

            if (owner == null)
            {
                throw new ArgumentNullException(nameof(owner));
            }

            if (routine == null)
            {
                throw new ArgumentNullException(nameof(routine));
            }

            var handle = new CoroutineHandle(runner);
            Register(owner, handle);
            handle.Coroutine = runner.StartCoroutine(RunTracked(owner, routine, handle));
            return handle.Coroutine;
        }

        public static int StopForOwner(object owner)
        {
            if (owner == null || !sOwnerCoroutines.TryGetValue(owner, out var handles))
            {
                return 0;
            }

            var stoppedCount = 0;
            for (var i = handles.Count - 1; i >= 0; i--)
            {
                var handle = handles[i];
                if (handle.Runner != null && handle.Coroutine != null)
                {
                    handle.Runner.StopCoroutine(handle.Coroutine);
                    stoppedCount++;
                }
            }

            sOwnerCoroutines.Remove(owner);
            return stoppedCount;
        }

        public static bool StopForOwner(object owner, UnityEngine.Coroutine coroutine)
        {
            if (owner == null || coroutine == null || !sOwnerCoroutines.TryGetValue(owner, out var handles))
            {
                return false;
            }

            for (var i = handles.Count - 1; i >= 0; i--)
            {
                var handle = handles[i];
                if (handle.Coroutine != coroutine)
                {
                    continue;
                }

                if (handle.Runner != null)
                {
                    handle.Runner.StopCoroutine(handle.Coroutine);
                }

                handles.RemoveAt(i);
                if (handles.Count == 0)
                {
                    sOwnerCoroutines.Remove(owner);
                }

                return true;
            }

            return false;
        }

        public static int GetOwnerCoroutineCount(object owner)
        {
            return owner != null && sOwnerCoroutines.TryGetValue(owner, out var handles) ? handles.Count : 0;
        }

        private static IEnumerator RunTracked(object owner, IEnumerator routine, CoroutineHandle handle)
        {
            try
            {
                while (routine.MoveNext())
                {
                    yield return routine.Current;
                }
            }
            finally
            {
                Unregister(owner, handle);
            }
        }

        private static void Register(object owner, CoroutineHandle handle)
        {
            if (!sOwnerCoroutines.TryGetValue(owner, out var handles))
            {
                handles = new List<CoroutineHandle>();
                sOwnerCoroutines.Add(owner, handles);
            }

            handles.Add(handle);
        }

        private static void Unregister(object owner, CoroutineHandle handle)
        {
            if (owner == null || handle == null || !sOwnerCoroutines.TryGetValue(owner, out var handles))
            {
                return;
            }

            for (var i = handles.Count - 1; i >= 0; i--)
            {
                if (ReferenceEquals(handles[i], handle))
                {
                    handles.RemoveAt(i);
                    break;
                }
            }

            if (handles.Count == 0)
            {
                sOwnerCoroutines.Remove(owner);
            }
        }

        private sealed class CoroutineHandle
        {
            public CoroutineHandle(MonoBehaviour runner)
            {
                Runner = runner;
            }

            public MonoBehaviour Runner { get; }
            public UnityEngine.Coroutine Coroutine { get; set; }
        }
    }
}
