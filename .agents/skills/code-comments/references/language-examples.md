# Language-Specific Documentation Patterns

本文件只保留通用格式提示。FantasyWord 当前以 Unity/C# 为主，正式项目侧注释优先服从 `code-comments/SKILL.md` 的中文规则。

## C# / Unity

```csharp
/// <summary>
/// 播放一次性音效，并把实例挂到音效总线下统一受控。
/// 调用方不需要持有返回对象；停止、淡出和池化由音频系统负责。
/// </summary>
public void PlayOneShot(AudioClip clip, Vector3 worldPosition)
{
    // 这里走总线入口，而不是直接 AudioSource.PlayClipAtPoint，
    // 是为了让暂停、静音和音量分层在所有音效上保持一致。
}
```

```csharp
using NaughtyAttributes;
using UnityEngine;

public sealed class AudioEmitterSettings : ScriptableObject
{
    [BoxGroup("播放策略")]
    [Label("默认音量")]
    [Tooltip("作为音效未显式指定音量时的兜底值，运行时会再叠加总线音量。")]
    [Range(0f, 1f)]
    [SerializeField]
    private float defaultVolume = 1f;
}
```
