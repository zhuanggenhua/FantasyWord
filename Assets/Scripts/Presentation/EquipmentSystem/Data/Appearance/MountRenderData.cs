using System;
using System.Collections.Generic;
using FantasyWord.GameCore;
using UnityEngine;

/// <summary>
/// 坐骑动作语义。
/// 它是角色动作和坐骑素材动作之间的中间层，用来避免把普通角色 Idle/Walk 直接当成坐骑素材动作名。
/// </summary>
public enum MountActionSemantic
{
    [InspectorName("未指定")]
    Unspecified = 0,

    [InspectorName("站立/待机")]
    Stand = 1,

    [InspectorName("移动")]
    Move = 2,

    [InspectorName("攻击")]
    Attack = 3,

    [InspectorName("受伤")]
    Hurt = 4,

    [InspectorName("死亡")]
    Die = 5,

    [InspectorName("上坐骑")]
    MountUp = 6,

    [InspectorName("下坐骑")]
    MountDown = 7,

    [InspectorName("自定义")]
    Custom = 8,
}

public enum MountDirectionMode
{
    [InspectorName("四向独立帧")]
    FourDirections = 0,

    [InspectorName("四向共用 SE 帧")]
    SharedSouthEast = 1,
}

public enum MountLayerEmptyBehavior
{
    [InspectorName("必须有帧")]
    Required = 0,

    [InspectorName("保持上一帧")]
    KeepPrevious = 1,

    [InspectorName("隐藏图层")]
    Hide = 2,
}

public enum MountActionCompletionBehavior
{
    [InspectorName("停在最后一帧")]
    HoldLastFrame = 0,

    [InspectorName("返回角色当前动作")]
    ReturnToCharacterAction = 1,

    [InspectorName("卸下坐骑")]
    ClearMount = 2,
}

public static class MountFrameLayout
{
    public static bool TryResolveFrameCount(
        int mountFrameCount,
        int riderFrameCount,
        MountLayerEmptyBehavior mountEmptyBehavior,
        MountLayerEmptyBehavior riderEmptyBehavior,
        out int frameCount)
    {
        frameCount = 0;
        bool hasMountFrames = mountFrameCount > 0;
        bool hasRiderFrames = riderFrameCount > 0;
        if (!hasMountFrames && mountEmptyBehavior == MountLayerEmptyBehavior.Required)
            return false;
        if (!hasRiderFrames && riderEmptyBehavior == MountLayerEmptyBehavior.Required)
            return false;
        if (!hasMountFrames && !hasRiderFrames)
            return false;
        if (hasMountFrames && hasRiderFrames && mountFrameCount != riderFrameCount)
            return false;

        frameCount = Mathf.Max(mountFrameCount, riderFrameCount);
        return frameCount > 0;
    }
}

/// <summary>
/// 一次坐骑动作请求。
/// 标准动作只使用语义；特殊动作额外保留作者动作键，避免所有特殊动作都命中同一个 Custom。
/// </summary>
public readonly struct MountActionRequest
{
    public MountActionRequest(MountActionSemantic semantic, string customKey = null)
    {
        Semantic = MountActionResolver.Normalize(semantic);
        CustomKey = Semantic == MountActionSemantic.Custom
            ? customKey?.Trim() ?? string.Empty
            : string.Empty;
    }

    public MountActionSemantic Semantic { get; }
    public string CustomKey { get; }
}

/// <summary>
/// 角色动作到坐骑动作语义的解析规则。
/// 坐骑素材可以叫“行走、移动、飞行、冲浪、爬行”，运行时统一按 Move 语义播放。
/// </summary>
public static class MountActionResolver
{
    public static MountActionRequest ResolveRequest(string animationKey)
    {
        string key = animationKey?.Trim();
        MountActionSemantic semantic = ResolveSemantic(key);
        return new MountActionRequest(
            semantic,
            semantic == MountActionSemantic.Custom ? key : string.Empty);
    }

    public static MountActionSemantic FromCharacterAnimationKey(string animationKey)
    {
        return ResolveRequest(animationKey).Semantic;
    }

    static MountActionSemantic ResolveSemantic(string key)
    {
        if (string.IsNullOrEmpty(key))
            return MountActionSemantic.Stand;

        return key.ToLowerInvariant() switch
        {
            "idle" or "wait" => MountActionSemantic.Stand,
            "walk" or "run" or "move" => MountActionSemantic.Move,
            "attack" or "slashattack" or "chargedattack" => MountActionSemantic.Attack,
            "dmg" or "dmg2" or "damage" or "hurt" => MountActionSemantic.Hurt,
            "die" or "spindie" or "souldie" or "death" => MountActionSemantic.Die,
            "mountup" => MountActionSemantic.MountUp,
            "mountdown" => MountActionSemantic.MountDown,
            _ => MountActionSemantic.Custom,
        };
    }

    public static MountActionSemantic Normalize(MountActionSemantic action)
    {
        return action == MountActionSemantic.Unspecified
            ? MountActionSemantic.Stand
            : action;
    }

    public static string ToKey(MountActionSemantic action)
    {
        return Normalize(action) switch
        {
            MountActionSemantic.Move => "Move",
            MountActionSemantic.Attack => "Attack",
            MountActionSemantic.Hurt => "Hurt",
            MountActionSemantic.Die => "Die",
            MountActionSemantic.MountUp => "MountUp",
            MountActionSemantic.MountDown => "MountDown",
            MountActionSemantic.Custom => "Custom",
            _ => "Stand",
        };
    }
}

/// <summary>
/// 坐骑表现数据。
/// 坐骑本体和骑手层来自作者已经对齐好的同画布逐帧图层，运行时只同步动作、方向和帧索引。
/// </summary>
[CreateAssetMenu(fileName = "坐骑表现", menuName = "Equipment System/Mount Render Data")]
public sealed class MountRenderData : EquipmentVisualAsset
{
    [Header("坐骑身份")]
    [InspectorName("坐骑标识")]
    [Tooltip("稳定标识，仅用于调试和资源管理；不要用它替代装备资产引用。")]
    [SerializeField] private string mountId;

    [InspectorName("显示名称")]
    [Tooltip("面向内容作者的坐骑名称。")]
    [SerializeField] private string displayName;

    [Header("骑手换装")]
    [InspectorName("骑手帧数据")]
    [Tooltip("骑乘姿态下的角色帧数据。装备、肤色、武器锚点都基于这个帧数据渲染。")]
    [SerializeField] private CharacterFrameData riderFrameData;

    [InspectorName("默认坐骑动作")]
    [Tooltip("角色动作不能命中坐骑素材动作时回退到的坐骑动作语义。")]
    [SerializeField] private MountActionSemantic fallbackAction = MountActionSemantic.Stand;

    [InspectorName("默认动作键")]
    [Tooltip("旧资产兼容字段：当前角色动作没有对应坐骑语义时，最后再尝试这个旧动作键。新坐骑优先配置默认坐骑动作。")]
    [SerializeField] private string fallbackAnimationKey = "Idle";

    [Header("动画")]
    [InspectorName("坐骑动画列表")]
    [Tooltip("每个动作保存坐骑本体和骑手基础层的逐帧序列。")]
    [SerializeField] private List<MountAnimationData> animations = new();

    public string MountId => mountId;
    public string DisplayName => string.IsNullOrWhiteSpace(displayName) ? name : displayName;
    public CharacterFrameData RiderFrameData => riderFrameData;
    public MountActionSemantic FallbackAction => MountActionResolver.Normalize(fallbackAction);
    public string FallbackAnimationKey => string.IsNullOrWhiteSpace(fallbackAnimationKey) ? "Idle" : fallbackAnimationKey.Trim();
    public IReadOnlyList<MountAnimationData> Animations => animations;

    public bool TryGetAnimation(string animationKey, out MountAnimationData animation)
    {
        return TryGetAnimation(MountActionResolver.ResolveRequest(animationKey), out animation, out _);
    }

    public bool TryGetAnimation(
        MountActionSemantic action,
        string legacyAnimationKey,
        out MountAnimationData animation)
    {
        MountActionRequest request = new(
            action,
            action == MountActionSemantic.Custom ? legacyAnimationKey : string.Empty);
        if (TryGetAnimation(request, out animation, out _))
            return true;

        string key = legacyAnimationKey?.Trim();
        if (string.IsNullOrEmpty(key))
            return false;

        for (int i = 0; i < animations.Count; i++)
        {
            MountAnimationData candidate = animations[i];
            if (candidate != null && candidate.MatchesLegacyAnimationKey(key))
            {
                animation = candidate;
                return true;
            }
        }

        return false;
    }

    public bool TryGetAnimation(
        MountActionRequest request,
        out MountAnimationData animation,
        out bool usedFallback)
    {
        animation = null;
        usedFallback = false;
        if (animations == null || animations.Count == 0)
            return false;

        for (int i = 0; i < animations.Count; i++)
        {
            MountAnimationData candidate = animations[i];
            if (candidate != null && candidate.MatchesRequest(request))
            {
                animation = candidate;
                return true;
            }
        }

        MountActionSemantic fallbackActionValue = FallbackAction;
        if (fallbackActionValue != request.Semantic)
        {
            for (int i = 0; i < animations.Count; i++)
            {
                MountAnimationData candidate = animations[i];
                if (candidate != null && candidate.MatchesAction(fallbackActionValue))
                {
                    animation = candidate;
                    usedFallback = true;
                    return true;
                }
            }
        }

        string fallbackKey = FallbackAnimationKey;
        if (!string.IsNullOrEmpty(fallbackKey))
        {
            for (int i = 0; i < animations.Count; i++)
            {
                MountAnimationData candidate = animations[i];
                if (candidate != null && candidate.MatchesLegacyAnimationKey(fallbackKey))
                {
                    animation = candidate;
                    usedFallback = true;
                    return true;
                }
            }
        }

        return false;
    }
}

/// <summary>
/// 坐骑单个动作的逐帧数据。
/// </summary>
[Serializable]
public sealed class MountAnimationData
{
    [InspectorName("坐骑动作语义")]
    [Tooltip("优先使用这个语义和角色动作对接，例如 Stand / Move / Attack / Hurt / Die / MountUp / MountDown。")]
    [SerializeField] private MountActionSemantic mountAction = MountActionSemantic.Unspecified;

    [InspectorName("自定义动作键")]
    [Tooltip("坐骑动作语义为 Custom 时必填，例如 Jump、Sleep、ShellIn。")]
    [SerializeField] private string customActionKey;

    [InspectorName("动作类型")]
    [Tooltip("旧资产兼容字段。普通换装仍用 AnimationTypeDatabase；坐骑运行时优先按坐骑动作语义查找。")]
    [SerializeField] private AnimationTypeItem animationType;

    [InspectorName("每帧秒数（旧兼容）")]
    [Tooltip("旧资产兼容字段。新坐骑优先配置动作周期；动作周期为 0 时才用本值乘以当前动作帧数。")]
    [SerializeField] private float secondsPerFrame = 0.2f;

    [InspectorName("动作周期秒数")]
    [Tooltip("同一个动作语义完成一轮所需时间。马 4 帧 Move 和河马 6 帧 Move 应配置同一周期，由播放器按进度采样各自帧数；0 表示沿用旧每帧秒数。")]
    [SerializeField] private float cycleDurationSeconds = 0f;

    [InspectorName("循环播放")]
    [Tooltip("移动和待机通常循环，死亡等动作通常不循环。")]
    [SerializeField] private bool loop = true;

    [InspectorName("非循环动作完成后")]
    [Tooltip("主动请求的上坐骑、下坐骑和特殊动作播完后的处理。")]
    [SerializeField] private MountActionCompletionBehavior completionBehavior = MountActionCompletionBehavior.HoldLastFrame;

    [InspectorName("方向帧模式")]
    [Tooltip("四向素材必须分别配置；只有作者明确提供单向共用动作时才选择共用 SE 帧。")]
    [SerializeField] private MountDirectionMode directionMode = MountDirectionMode.FourDirections;

    [InspectorName("坐骑本体缺帧处理")]
    [Tooltip("上下坐骑只有骑手层时可保持坐骑上一帧；普通动作应保持必须有帧。")]
    [SerializeField] private MountLayerEmptyBehavior mountEmptyBehavior = MountLayerEmptyBehavior.Required;

    [InspectorName("骑手层缺帧处理")]
    [Tooltip("坐骑死亡等没有骑手层的动作可隐藏骑手；普通动作应保持必须有帧。")]
    [SerializeField] private MountLayerEmptyBehavior riderEmptyBehavior = MountLayerEmptyBehavior.Required;

    [InspectorName("坐骑本体帧")]
    [Tooltip("坐骑底层动画，四向每行已经与骑手层对齐。")]
    [SerializeField] private MountDirectionalFrames mountFrames = new();

    [InspectorName("骑手基础帧")]
    [Tooltip("作者提供的骑手层，作为骑乘状态下的新角色基础身体动画。")]
    [SerializeField] private MountDirectionalFrames riderFrames = new();

    public MountActionSemantic ActionSemantic => mountAction;
    public string CustomActionKey => customActionKey?.Trim() ?? string.Empty;
    public MountActionSemantic EffectiveAction => mountAction != MountActionSemantic.Unspecified
        ? mountAction
        : MountActionResolver.FromCharacterAnimationKey(animationType != null ? animationType.name : string.Empty);
    public string MountActionKey => MountActionResolver.ToKey(EffectiveAction);
    public AnimationTypeItem AnimationType => animationType;
    public string AnimationKey => animationType != null ? animationType.name : MountActionKey;
    public float SecondsPerFrame => Mathf.Max(0.01f, secondsPerFrame);
    public bool Loop => loop;
    public MountActionCompletionBehavior CompletionBehavior => completionBehavior;
    public MountDirectionMode DirectionMode => directionMode;
    public MountLayerEmptyBehavior MountEmptyBehavior => mountEmptyBehavior;
    public MountLayerEmptyBehavior RiderEmptyBehavior => riderEmptyBehavior;
    public MountDirectionalFrames MountFrames => mountFrames;
    public MountDirectionalFrames RiderFrames => riderFrames;

    public bool MatchesAction(MountActionSemantic action)
    {
        if (MountActionResolver.Normalize(action) == MountActionSemantic.Custom &&
            mountAction == MountActionSemantic.Unspecified)
        {
            return false;
        }

        return MountActionResolver.Normalize(EffectiveAction) == MountActionResolver.Normalize(action);
    }

    public bool MatchesRequest(MountActionRequest request)
    {
        if (request.Semantic != MountActionSemantic.Custom)
            return MatchesAction(request.Semantic);

        if (EffectiveAction != MountActionSemantic.Custom || string.IsNullOrWhiteSpace(request.CustomKey))
            return false;

        if (!string.IsNullOrWhiteSpace(CustomActionKey))
        {
            return string.Equals(
                CustomActionKey,
                request.CustomKey,
                StringComparison.OrdinalIgnoreCase);
        }

        return MatchesLegacyAnimationKey(request.CustomKey);
    }

    public bool MatchesKey(string key)
    {
        return MatchesLegacyAnimationKey(key);
    }

    public bool MatchesLegacyAnimationKey(string key)
    {
        return !string.IsNullOrWhiteSpace(key)
            && animationType != null
            && string.Equals(animationType.name, key.Trim(), StringComparison.OrdinalIgnoreCase);
    }

    public int GetFrameCount(int directionIndex)
    {
        int resolvedDirection = ResolveDirectionIndex(directionIndex);
        int mountCount = mountFrames != null ? mountFrames.GetFrameCount(resolvedDirection) : 0;
        int riderCount = riderFrames != null ? riderFrames.GetFrameCount(resolvedDirection) : 0;
        return MountFrameLayout.TryResolveFrameCount(
            mountCount,
            riderCount,
            mountEmptyBehavior,
            riderEmptyBehavior,
            out int frameCount)
                ? frameCount
                : 0;
    }

    public Sprite GetMountFrame(int directionIndex, int frameIndex)
    {
        return mountFrames?.GetFrame(ResolveDirectionIndex(directionIndex), frameIndex);
    }

    public Sprite GetRiderFrame(int directionIndex, int frameIndex)
    {
        return riderFrames?.GetFrame(ResolveDirectionIndex(directionIndex), frameIndex);
    }

    int ResolveDirectionIndex(int directionIndex)
    {
        return directionMode == MountDirectionMode.SharedSouthEast
            ? CharacterAnimationDirections.SouthEast
            : directionIndex;
    }

    public float GetCycleDurationSeconds(int directionIndex)
    {
        if (cycleDurationSeconds > 0f)
            return Mathf.Max(0.01f, cycleDurationSeconds);

        int frameCount = GetFrameCount(directionIndex);
        return Mathf.Max(0.01f, SecondsPerFrame * Mathf.Max(1, frameCount));
    }

    public int ResolveFrameIndex(float elapsedSeconds, int directionIndex)
    {
        int frameCount = GetFrameCount(directionIndex);
        if (frameCount <= 0)
            return -1;

        float cycleDuration = GetCycleDurationSeconds(directionIndex);
        float normalizedProgress;
        if (loop)
        {
            float wrappedTime = Mathf.Repeat(Mathf.Max(0f, elapsedSeconds), cycleDuration);
            normalizedProgress = wrappedTime / cycleDuration;
        }
        else
        {
            normalizedProgress = Mathf.Clamp01(Mathf.Max(0f, elapsedSeconds) / cycleDuration);
        }

        return Mathf.Min(Mathf.FloorToInt(normalizedProgress * frameCount), frameCount - 1);
    }
}

/// <summary>
/// 四向逐帧 Sprite 集合。方向索引沿用 CharacterAnimationDirections：SE/SW/NE/NW。
/// </summary>
[Serializable]
public sealed class MountDirectionalFrames
{
    [InspectorName("SE 帧")]
    [SerializeField] private Sprite[] southEast = Array.Empty<Sprite>();

    [InspectorName("SW 帧")]
    [SerializeField] private Sprite[] southWest = Array.Empty<Sprite>();

    [InspectorName("NE 帧")]
    [SerializeField] private Sprite[] northEast = Array.Empty<Sprite>();

    [InspectorName("NW 帧")]
    [SerializeField] private Sprite[] northWest = Array.Empty<Sprite>();

    public Sprite[] SouthEast => southEast;
    public Sprite[] SouthWest => southWest;
    public Sprite[] NorthEast => northEast;
    public Sprite[] NorthWest => northWest;

    public Sprite[] GetFrames(int directionIndex)
    {
        return directionIndex switch
        {
            CharacterAnimationDirections.SouthEast => southEast,
            CharacterAnimationDirections.SouthWest => southWest,
            CharacterAnimationDirections.NorthEast => northEast,
            CharacterAnimationDirections.NorthWest => northWest,
            _ => Array.Empty<Sprite>(),
        };
    }

    public int GetFrameCount(int directionIndex)
    {
        Sprite[] frames = GetFrames(directionIndex);
        return frames != null ? frames.Length : 0;
    }

    public Sprite GetFrame(int directionIndex, int frameIndex)
    {
        Sprite[] frames = GetFrames(directionIndex);
        if (frames == null
            || frames.Length == 0
            || frameIndex < 0
            || frameIndex >= frames.Length)
        {
            return null;
        }

        return frames[frameIndex];
    }
}
