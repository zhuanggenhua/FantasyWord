using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
#if UNITY_EDITOR
using UnityEditor;
#endif

namespace JKFrame
{
    /// <summary>
    /// 整个游戏只有一个Update、LateUpdate等
    /// </summary>
    public class MonoSystem : MonoBehaviour
    {
        private MonoSystem() { }
        private static MonoSystem instance;
        private Action updateEvent;
        private Action lateUpdateEvent;
        private Action fixedUpdateEvent;

        public static bool IsInitialized => instance != null;

        /// <summary>
        /// 确保 MonoSystem 可用；允许项目侧只使用 JKFrame 状态机/协程调度能力时，不必强依赖完整 JKFrameRoot 场景预置。
        /// </summary>
        public static void EnsureInitialized()
        {
            if (instance != null)
            {
                return;
            }

            GameObject host;
            if (JKFrameRoot.RootTransform != null)
            {
                host = JKFrameRoot.RootTransform.gameObject;
            }
            else
            {
                host = new GameObject("JKFrameRuntime");
                if (Application.isPlaying)
                {
                    DontDestroyOnLoad(host);
                }
#if UNITY_EDITOR
                else
                {
                    // EditMode 下状态机/工具链仍可能借用 MonoSystem，但这里不能调用 DontDestroyOnLoad，
                    // 也不能把临时宿主写进当前场景，因此改为隐藏且不落盘的编辑器临时对象。
                    host.hideFlags = HideFlags.HideAndDontSave;
                    EditorApplication.playModeStateChanged -= HandleEditorPlayModeStateChanged;
                    EditorApplication.playModeStateChanged += HandleEditorPlayModeStateChanged;
                }
#endif
            }

            instance = host.GetComponent<MonoSystem>();
            if (instance == null)
            {
                instance = host.AddComponent<MonoSystem>();
            }

            instance.updateEvent = null;
            instance.lateUpdateEvent = null;
            instance.fixedUpdateEvent = null;
        }

#if UNITY_EDITOR
        private static void HandleEditorPlayModeStateChanged(PlayModeStateChange state)
        {
            if (state != PlayModeStateChange.ExitingEditMode
                && state != PlayModeStateChange.EnteredEditMode)
            {
                return;
            }

            if (instance == null)
            {
                return;
            }

            GameObject host = instance.gameObject;
            if (host == null || host.name != "JKFrameRuntime")
            {
                return;
            }

            if ((host.hideFlags & HideFlags.HideAndDontSave) == 0)
            {
                return;
            }

            if (state == PlayModeStateChange.ExitingEditMode)
            {
                UnityEngine.Object.DestroyImmediate(host);
                instance = null;
                return;
            }

            host.hideFlags = HideFlags.HideAndDontSave;
        }
#endif

        public static void Init()
        {
            EnsureInitialized();
        }

        #region 生命周期函数
        /// <summary>
        /// 添加Update监听
        /// </summary>
        /// <param name="action"></param>
        public static void AddUpdateListener(Action action)
        {
            EnsureInitialized();
            instance.updateEvent += action;
        }

        /// <summary>
        /// 移除Update监听
        /// </summary>
        /// <param name="action"></param>
        public static void RemoveUpdateListener(Action action)
        {
            if (instance == null)
            {
                return;
            }

            instance.updateEvent -= action;
        }

        /// <summary>
        /// 添加LateUpdate监听
        /// </summary>
        /// <param name="action"></param>
        public static void AddLateUpdateListener(Action action)
        {
            EnsureInitialized();
            instance.lateUpdateEvent += action;
        }

        /// <summary>
        /// 移除LateUpdate监听
        /// </summary>
        /// <param name="action"></param>
        public static void RemoveLateUpdateListener(Action action)
        {
            if (instance == null)
            {
                return;
            }

            instance.lateUpdateEvent -= action;
        }

        /// <summary>
        /// 添加FixedUpdate监听
        /// </summary>
        /// <param name="action"></param>
        public static void AddFixedUpdateListener(Action action)
        {
            EnsureInitialized();
            instance.fixedUpdateEvent += action;
        }

        /// <summary>
        /// 移除FixedUpdate监听
        /// </summary>
        /// <param name="action"></param>
        public static void RemoveFixedUpdateListener(Action action)
        {
            if (instance == null)
            {
                return;
            }

            instance.fixedUpdateEvent -= action;
        }

        private void Update()
        {
            updateEvent?.Invoke();
        }
        private void LateUpdate()
        {
            lateUpdateEvent?.Invoke();
        }
        private void FixedUpdate()
        {
            fixedUpdateEvent?.Invoke();
        }

        #endregion
        #region 协程
        private Dictionary<object, List<Coroutine>> coroutineDic = new Dictionary<object, List<Coroutine>>();
        private static ObjectPoolModule poolModule = new ObjectPoolModule();

        /// <summary>
        /// 启动一个协程序
        /// </summary>
        public static Coroutine Start_Coroutine(IEnumerator coroutine)
        {
            EnsureInitialized();
            return instance.StartCoroutine(coroutine);
        }

        /// <summary>
        /// 启动一个协程序并且绑定某个对象
        /// </summary>
        public static Coroutine Start_Coroutine(object obj, IEnumerator coroutine)
        {
            EnsureInitialized();
            Coroutine _coroutine = instance.StartCoroutine(coroutine);
            if (!instance.coroutineDic.TryGetValue(obj, out List<Coroutine> coroutineList))
            {
                coroutineList = poolModule.GetObject<List<Coroutine>>();
                if (coroutineList == null) coroutineList = new List<Coroutine>();
                instance.coroutineDic.Add(obj, coroutineList);
            }
            coroutineList.Add(_coroutine);
            return _coroutine;
        }

        /// <summary>
        /// 停止一个协程序并基于某个对象
        /// </summary>
        public static void Stop_Coroutine(object obj, Coroutine routine)
        {
            if (instance == null || routine == null)
            {
                return;
            }

            if (instance.coroutineDic.TryGetValue(obj, out List<Coroutine> coroutineList))
            {
                instance.StopCoroutine(routine);
                coroutineList.Remove(routine);
            }
        }

        /// <summary>
        /// 停止一个协程序
        /// </summary>
        public static void Stop_Coroutine(Coroutine routine)
        {
            if (instance == null || routine == null)
            {
                return;
            }

            instance.StopCoroutine(routine);
        }

        /// <summary>
        /// 停止某个对象的全部协程
        /// </summary>
        public static void StopAllCoroutine(object obj)
        {
            if (instance == null)
            {
                return;
            }

            if (instance.coroutineDic.Remove(obj, out List<Coroutine> coroutineList))
            {
                for (int i = 0; i < coroutineList.Count; i++)
                {
                    instance.StopCoroutine(coroutineList[i]);
                }
                coroutineList.Clear();
                poolModule.PushObject(coroutineList);
            }
        }

        /// <summary>
        /// 整个系统全部协程都会停止
        /// </summary>
        public static void StopAllCoroutine()
        {
            if (instance == null)
            {
                return;
            }

            // 全部数据都会无效
            foreach (List<Coroutine> item in instance.coroutineDic.Values)
            {
                item.Clear();
                poolModule.PushObject(item);
            }
            instance.coroutineDic.Clear();
            instance.StopAllCoroutines();
        }
        #endregion
    }
}
