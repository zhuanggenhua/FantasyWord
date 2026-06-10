using System;
using System.Collections;
using System.Collections.Generic;
using System.Runtime.Serialization;
using UnityEngine;

/// <summary>
/// 可序列化字典的非泛型基类，用于让 Unity 自定义属性绘制器统一识别字典字段。
/// </summary>
[Serializable]
public abstract class SerializableDictionaryBase : ISerializationCallbackReceiver
{
    public const string KeysFieldName = "keys";
    public const string ValuesFieldName = "values";

    /// <summary>
    /// 同步运行时字典到 Unity 可序列化列表。
    /// </summary>
    public abstract void OnBeforeSerialize();

    /// <summary>
    /// 从 Unity 可序列化列表恢复运行时字典。
    /// </summary>
    public abstract void OnAfterDeserialize();
}

/// <summary>
/// 字典绘制设置。本地复刻 Odin 公开的 DictionaryDrawerSettings 命名和核心字段，不引入 Sirenix 依赖。
/// </summary>
[AttributeUsage(AttributeTargets.Field)]
public sealed class DictionaryDrawerSettingsAttribute : PropertyAttribute
{
    /// <summary>
    /// Key 列标题。
    /// </summary>
    public string KeyLabel { get; set; } = "Key";

    /// <summary>
    /// Value 列标题。
    /// </summary>
    public string ValueLabel { get; set; } = "Value";

    /// <summary>
    /// Key 列宽度；小于等于 0 时由 drawer 自动分配。
    /// </summary>
    public float KeyColumnWidth { get; set; }

    /// <summary>
    /// 字典展示模式。
    /// </summary>
    public DictionaryDisplayOptions DisplayMode { get; set; } = DictionaryDisplayOptions.Foldout;

    /// <summary>
    /// 是否在 Inspector 中只读显示。
    /// </summary>
    public bool IsReadOnly { get; set; }
}

/// <summary>
/// 字典展示模式。命名对齐 Odin 常用公开枚举，Drawer 按当前项目需要实现对应交互。
/// </summary>
public enum DictionaryDisplayOptions
{
    OneLine,
    Foldout,
    CollapsedFoldout,
    ExpandedFoldout,
}

/// <summary>
/// 多态引用绘制设置。本地复刻 Odin 常用的 PolymorphicDrawerSettings 对齐面，不引入 Sirenix 依赖。
/// </summary>
[AttributeUsage(AttributeTargets.Field)]
public sealed class PolymorphicDrawerSettingsAttribute : PropertyAttribute
{
    /// <summary>
    /// 是否在类型头部同时显示基类名和当前具体类型名。
    /// </summary>
    public bool ShowBaseType { get; set; }

    /// <summary>
    /// 引用不为空时是否只读显示；用于对齐 Odin 文档里的已创建引用锁定行为。
    /// </summary>
    public bool ReadOnlyIfNotNullReference { get; set; }

    /// <summary>
    /// 自定义多态实例创建函数名。函数签名应为 `object/基类名 MethodName(Type type)`。
    /// </summary>
    public string CreateInstanceFunction { get; set; }

    /// <summary>
    /// 当候选类型没有默认构造函数时，控制类型选择器与实例创建策略。
    /// </summary>
    public NonDefaultConstructorPreference NonDefaultConstructorPreference { get; set; } = NonDefaultConstructorPreference.ConstructIdeal;
}

/// <summary>
/// 多态值没有默认构造函数时的创建偏好；命名对齐 Odin 公开枚举。
/// </summary>
public enum NonDefaultConstructorPreference
{
    Exclude,
    ConstructIdeal,
    PreferUninitialized,
    LogWarning,
}

/// <summary>
/// 类型选择弹窗绘制设置。本地复刻 Odin TypeSelectorSettings 的当前对齐面，用于控制多态类型选择器表现。
/// </summary>
[AttributeUsage(AttributeTargets.Field)]
public sealed class TypeSelectorSettingsAttribute : PropertyAttribute
{
    /// <summary>
    /// 是否显示类型分类标题。
    /// </summary>
    public bool ShowCategories { get; set; } = true;

    /// <summary>
    /// 开启分类时是否优先按命名空间分组；关闭后按程序集名分组。
    /// </summary>
    public bool PreferNamespaces { get; set; } = true;

    /// <summary>
    /// 是否显示空值项。
    /// </summary>
    public bool ShowNoneItem { get; set; } = true;

    /// <summary>
    /// 自定义类型过滤函数名。函数签名应为 `bool MethodName(Type type)`。
    /// </summary>
    public string FilterTypesFunction { get; set; }
}

/// <summary>
/// 多态类型显示名配置。用于让 SerializableDictionary 的多态头部和类型选择器显示更接近 Odin 的可读类型名。
/// </summary>
[AttributeUsage(AttributeTargets.Class | AttributeTargets.Struct)]
public sealed class ManagedReferenceTypeDisplayNameAttribute : Attribute
{
    /// <summary>
    /// 自定义类型显示名。
    /// </summary>
    public string DisplayName { get; }

    /// <summary>
    /// 自定义类型副标题；为空时由 drawer 自动回退到完整类型名。
    /// </summary>
    public string Subtitle { get; }

    public ManagedReferenceTypeDisplayNameAttribute(string displayName)
        : this(displayName, null)
    {
    }

    public ManagedReferenceTypeDisplayNameAttribute(string displayName, string subtitle)
    {
        DisplayName = displayName;
        Subtitle = subtitle;
    }
}

/// <summary>
/// 可序列化字典运行时基类，统一维护字典 API、Unity 序列化列表和反序列化恢复逻辑。
/// </summary>
[Serializable]
public abstract class SerializableDictionaryRuntimeBase<TKey, TValue> : SerializableDictionaryBase, IDictionary<TKey, TValue>, IReadOnlyDictionary<TKey, TValue>
{
    [SerializeField] private List<TKey> keys = new List<TKey>();

    [NonSerialized] private Dictionary<TKey, TValue> dictionary = new Dictionary<TKey, TValue>();

    /// <summary>
    /// 真实参与 Unity 序列化的 value 列表；普通字典走 SerializeField，多态字典走 SerializeReference。
    /// </summary>
    protected abstract List<TValue> SerializedValues { get; }

    /// <summary>
    /// 确保子类维护的 value 列表已初始化。
    /// </summary>
    protected abstract void EnsureSerializedValueStorage();

    /// <summary>
    /// 字典 key 集合。
    /// </summary>
    public ICollection<TKey> Keys => Dictionary.Keys;

    /// <summary>
    /// 字典 value 集合。
    /// </summary>
    public ICollection<TValue> Values => Dictionary.Values;

    /// <summary>
    /// 字典元素数量。
    /// </summary>
    public int Count => Dictionary.Count;

    /// <summary>
    /// 本字典是否只读。运行时代码始终允许写入，Inspector 只读由 DictionaryDrawerSettings 控制。
    /// </summary>
    public bool IsReadOnly => false;

    IEnumerable<TKey> IReadOnlyDictionary<TKey, TValue>.Keys => Keys;

    IEnumerable<TValue> IReadOnlyDictionary<TKey, TValue>.Values => Values;

    /// <summary>
    /// 运行时字典实例。用于需要直接调用 Dictionary API 的旧 JKFrame 代码路径。
    /// </summary>
    public Dictionary<TKey, TValue> Dictionary
    {
        get
        {
            EnsureDictionary();
            return dictionary;
        }
    }

    /// <summary>
    /// 获取或设置指定 key 的 value。
    /// </summary>
    public TValue this[TKey key]
    {
        get => Dictionary[key];
        set
        {
            Dictionary[key] = value;
            SyncSerializedListsFromDictionary();
        }
    }

    protected SerializableDictionaryRuntimeBase()
    {
    }

    protected SerializableDictionaryRuntimeBase(IDictionary<TKey, TValue> source)
    {
        if (source == null)
        {
            return;
        }

        foreach (KeyValuePair<TKey, TValue> pair in source)
        {
            Dictionary[pair.Key] = pair.Value;
        }

        SyncSerializedListsFromDictionary();
    }

    /// <summary>
    /// 添加键值对。
    /// </summary>
    public void Add(TKey key, TValue value)
    {
        Dictionary.Add(key, value);
        SyncSerializedListsFromDictionary();
    }

    /// <summary>
    /// 添加或覆盖键值对。
    /// </summary>
    public void Set(TKey key, TValue value)
    {
        Dictionary[key] = value;
        SyncSerializedListsFromDictionary();
    }

    /// <summary>
    /// 判断是否包含指定 key。
    /// </summary>
    public bool ContainsKey(TKey key)
    {
        return Dictionary.ContainsKey(key);
    }

    /// <summary>
    /// 删除指定 key。
    /// </summary>
    public bool Remove(TKey key)
    {
        bool removed = Dictionary.Remove(key);
        if (removed)
        {
            SyncSerializedListsFromDictionary();
        }

        return removed;
    }

    /// <summary>
    /// 尝试读取指定 key 的 value。
    /// </summary>
    public bool TryGetValue(TKey key, out TValue value)
    {
        return Dictionary.TryGetValue(key, out value);
    }

    /// <summary>
    /// 添加键值对。
    /// </summary>
    public void Add(KeyValuePair<TKey, TValue> item)
    {
        Add(item.Key, item.Value);
    }

    /// <summary>
    /// 清空字典。
    /// </summary>
    public void Clear()
    {
        Dictionary.Clear();
        SyncSerializedListsFromDictionary();
    }

    /// <summary>
    /// 判断字典是否包含指定键值对。
    /// </summary>
    public bool Contains(KeyValuePair<TKey, TValue> item)
    {
        return ((ICollection<KeyValuePair<TKey, TValue>>)Dictionary).Contains(item);
    }

    /// <summary>
    /// 复制字典键值对到目标数组。
    /// </summary>
    public void CopyTo(KeyValuePair<TKey, TValue>[] array, int arrayIndex)
    {
        ((ICollection<KeyValuePair<TKey, TValue>>)Dictionary).CopyTo(array, arrayIndex);
    }

    /// <summary>
    /// 删除指定键值对。
    /// </summary>
    public bool Remove(KeyValuePair<TKey, TValue> item)
    {
        bool removed = ((ICollection<KeyValuePair<TKey, TValue>>)Dictionary).Remove(item);
        if (removed)
        {
            SyncSerializedListsFromDictionary();
        }

        return removed;
    }

    /// <summary>
    /// 遍历字典内容。
    /// </summary>
    public IEnumerator<KeyValuePair<TKey, TValue>> GetEnumerator()
    {
        return Dictionary.GetEnumerator();
    }

    IEnumerator IEnumerable.GetEnumerator()
    {
        return GetEnumerator();
    }

    [OnSerializing]
    private void OnSerializing(StreamingContext context)
    {
        OnBeforeSerialize();
    }

    [OnDeserialized]
    private void OnDeserialized(StreamingContext context)
    {
        OnAfterDeserialize();
    }

    /// <summary>
    /// Unity 序列化前保持 key/value 列表作为序列化真源，避免 Inspector 改动被旧运行时缓存覆盖。
    /// </summary>
    public override void OnBeforeSerialize()
    {
        EnsureSerializedLists();
    }

    /// <summary>
    /// Unity 反序列化后用 key/value 列表重建运行时字典。
    /// </summary>
    public override void OnAfterDeserialize()
    {
        EnsureSerializedLists();
        dictionary = new Dictionary<TKey, TValue>();

        int count = Mathf.Min(keys.Count, SerializedValues.Count);
        for (int i = 0; i < count; i++)
        {
            dictionary[keys[i]] = SerializedValues[i];
        }

        SyncSerializedListsFromDictionary();
    }

    private void EnsureDictionary()
    {
        if (dictionary == null)
        {
            dictionary = new Dictionary<TKey, TValue>();
        }
    }

    private void EnsureSerializedLists()
    {
        if (keys == null)
        {
            keys = new List<TKey>();
        }

        EnsureSerializedValueStorage();
    }

    private void SyncSerializedListsFromDictionary()
    {
        EnsureDictionary();
        EnsureSerializedLists();

        keys.Clear();
        SerializedValues.Clear();
        foreach (KeyValuePair<TKey, TValue> pair in dictionary)
        {
            keys.Add(pair.Key);
            SerializedValues.Add(pair.Value);
        }
    }
}

/// <summary>
/// 可序列化字典，通过 key/value 列表保存 Unity 不原生支持的泛型字典数据。
/// </summary>
/// <remarks>如果后续改用 URP/HDRP 内置字典类型，应先确认 UnityEngine.Rendering.SerializedDictionary 的可用包和序列化兼容性。</remarks>
[Serializable]
public class SerializableDictionary<TKey, TValue> : SerializableDictionaryRuntimeBase<TKey, TValue>
{
    [SerializeField] private List<TValue> values = new List<TValue>();

    protected override List<TValue> SerializedValues => values;

    public SerializableDictionary()
    {
    }

    public SerializableDictionary(IDictionary<TKey, TValue> source) : base(source)
    {
    }

    protected override void EnsureSerializedValueStorage()
    {
        if (values == null)
        {
            values = new List<TValue>();
        }
    }
}

/// <summary>
/// 支持 SerializeReference 多态值的可序列化字典；用于接口/抽象基类到具体派生类型的 Inspector 配置场景。
/// </summary>
/// <remarks>仅适用于普通托管引用类型；不要用它保存 UnityEngine.Object 引用。</remarks>
[Serializable]
public class SerializableReferenceDictionary<TKey, TValue> : SerializableDictionaryRuntimeBase<TKey, TValue> where TValue : class
{
    [SerializeField, SerializeReference] private List<TValue> values = new List<TValue>();

    protected override List<TValue> SerializedValues => values;

    public SerializableReferenceDictionary()
    {
    }

    public SerializableReferenceDictionary(IDictionary<TKey, TValue> source) : base(source)
    {
    }

    protected override void EnsureSerializedValueStorage()
    {
        if (values == null)
        {
            values = new List<TValue>();
        }
    }
}
