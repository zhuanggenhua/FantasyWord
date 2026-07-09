using System;
using System.Collections.Generic;
using Newtonsoft.Json;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// Mod 内容包的最小描述文件，迁自 Chris.ModInfo。
    /// 文件通常来自 Mod 目录下的 cfg/json 内容清单，运行时路径不写回清单本体。
    /// </summary>
    [Serializable]
    public class ModInfo
    {
        public string apiVersion;
        public string authorName;
        public string modName;
        public string version;
        public string description;
        public byte[] modIconBytes;
        public Dictionary<string, string> metaData = new();

        [JsonIgnore] public string FilePath { get; set; }
        [JsonIgnore] public string FullName => $"{modName}-{version}-{apiVersion}";
    }
}
