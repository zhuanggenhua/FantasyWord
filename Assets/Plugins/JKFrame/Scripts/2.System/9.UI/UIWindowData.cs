using NaughtyAttributes;
using System;
using UnityEngine;

namespace JKFrame
{
    /// <summary>
    /// UI元素数据
    /// </summary>
    [Serializable]
    public class UIWindowData
    {
        [Label("是否需要缓存")] public bool isCache;
        [Label("预制体Path或AssetKey")] public string assetPath;
        [Label("UI层级")] public int layerNum;
        /// <summary>
        /// 这个元素的窗口对象
        /// </summary>
        [Label("窗口实例")] public UI_WindowBase instance;

        public UIWindowData(bool isCache, string assetPath, int layerNum)
        {
            this.isCache = isCache;
            this.assetPath = assetPath;
            this.layerNum = layerNum;
            instance = null;
        }
    }
}
