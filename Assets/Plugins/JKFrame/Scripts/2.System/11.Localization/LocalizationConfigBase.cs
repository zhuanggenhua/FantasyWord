using System;
using JKFrame;

public abstract class LocalizationConfigSuperBase : ConfigBase
{

}

[Serializable]
public class LocalizationLanguageMap<TLanguage> : SerializableReferenceDictionary<TLanguage, LocalizationDataBase>
    where TLanguage : Enum
{
}

public abstract class LocalizationConfigBase<TLanguage> : LocalizationConfigSuperBase where TLanguage : Enum
{
    [DictionaryDrawerSettings(DisplayMode = DictionaryDisplayOptions.CollapsedFoldout)]
    public SerializableDictionary<string, LocalizationLanguageMap<TLanguage>> config = new();

    /// <summary>
    /// 按键和语言获取本地化内容。
    /// </summary>
    public T GetContent<T>(string key, TLanguage languageType) where T : LocalizationDataBase
    {
        LocalizationDataBase content = null;
        if (config.TryGetValue(key, out LocalizationLanguageMap<TLanguage> dic))
        {
            dic.TryGetValue(languageType, out content);
        }
        return (T)content;
    }
}
