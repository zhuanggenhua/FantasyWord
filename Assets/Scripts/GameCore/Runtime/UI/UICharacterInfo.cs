using System.Collections.Generic;
using Sirenix.OdinInspector;
using TMPro;
using UnityEngine;
using UnityEngine.UI;
using YokiFrame;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 角色信息面板。
    /// 它订阅单个 CharacterBase 的资源、等级和持续效果展示事件，只刷新 UI 文本、血蓝条和状态图标，不拥有角色属性或效果生命周期。
    /// </summary>
    public class UICharacterInfo : MonoBehaviour
    {
        [Header("引用")]
        [SerializeField]
        [LabelText("名称文本")]
        [Tooltip("显示角色名称和等级的 TMP 文本。初始文本会作为格式模板缓存，支持 {name} 和 {level} 占位。")]
        private TextMeshProUGUI m_nameText = null;

        [SerializeField]
        [LabelText("生命滑条")]
        [Tooltip("显示目标当前生命和生命上限的 Slider。为空或未启用时会跳过刷新。")]
        private Slider m_healthSlider = null;

        [SerializeField]
        [LabelText("魔力滑条")]
        [Tooltip("显示目标当前魔力和魔力上限的 Slider。为空或未启用时会跳过刷新。")]
        private Slider m_manaSlider = null;

        [SerializeField]
        [LabelText("状态图标根节点")]
        [Tooltip("持续效果图标的挂载位置。为空时回退到本组件 Transform。")]
        private Transform m_effectIconRoot = null;

        [SerializeField]
        [LabelText("状态图标预制体")]
        [Tooltip("持续效果展示图标预制体，必须带 UIEffectIcon 组件。为空时不会创建状态图标。")]
        private GameObject m_effectIconPrefab = null;

        [SerializeField, Min(0)]
        [LabelText("状态图标池容量")]
        [Tooltip("为状态图标预热的对象池容量。容量太小会导致新增效果图标失败并打印警告。")]
        private int m_effectIconPoolSize = 10;

        [SerializeField]
        [LabelText("目标角色")]
        [Tooltip("面板要监听的角色。切换目标需要外部重新绑定或重建面板，避免监听旧角色事件。")]
        private CharacterBase m_target = null;

        private string m_nameAndLevelFormat = string.Empty;
        private bool m_targetListening = false;

        private readonly Dictionary<int, UIEffectIcon> m_effectIcons = new();

        /// <summary>预热状态图标池，并缓存名称文本模板，避免事件刷新时丢失占位格式。</summary>
        private void Awake()
        {
            ConfigureEffectIconPool();
            CacheNameAndLevelFormat();
        }

        /// <summary>启用时尝试订阅目标角色；目标可能由场景序列化或外部启动流程提前绑定。</summary>
        private void OnEnable()
        {
            StartTargetListeningIfReady();
        }

        /// <summary>Start 再兜一次订阅，兼容目标在同帧稍晚初始化的场景搭建顺序。</summary>
        private void Start()
        {
            StartTargetListeningIfReady();
        }

        /// <summary>禁用时注销角色事件并归还所有图标，防止隐藏面板继续接收角色事件。</summary>
        private void OnDisable()
        {
            StopTargetListening();
            ReturnAllEffectIcons();
        }

        /// <summary>销毁时重复收口订阅和对象池归还，覆盖禁用顺序异常或场景卸载路径。</summary>
        private void OnDestroy()
        {
            StopTargetListening();
            ReturnAllEffectIcons();
        }

        /// <summary>从目标角色读取当前生命/魔力并写入 UI；滑条缺失时跳过，不改变角色资源。</summary>
        public void UpdateResourceBars()
        {
            if (m_target == null)
            {
                return;
            }

            if (m_healthSlider?.isActiveAndEnabled ?? false)
            {
                m_healthSlider.minValue = 0;
                m_healthSlider.maxValue = m_target.GetMaxHealth();
                m_healthSlider.value = m_target.GetCurrentHealth();
            }

            if (m_manaSlider?.isActiveAndEnabled ?? false)
            {
                m_manaSlider.minValue = 0;
                m_manaSlider.maxValue = m_target.GetMaxMana();
                m_manaSlider.value = m_target.GetCurrentMana();
            }
        }

        /// <summary>按缓存模板刷新名称和等级，模板由预制体文案提供，不在运行时硬编码布局文案。</summary>
        public void UpdateNameAndLevel()
        {
            if (m_target != null && (m_nameText?.isActiveAndEnabled ?? false))
            {
                m_nameText.text = StringFormatter.Format(m_nameAndLevelFormat).Replace("{name}", m_target.characterSheet.displayName).Replace("{level}", m_target.level.ToString());
            }
        }

        private void OnStatsChanged(Stats previous) => UpdateResourceBars();

        /// <summary>角色新增带展示信息的持续效果时，从对象池租用图标并按 runtimeKey 记录，确保后续能精准归还。</summary>
        private void OnTemporalEffectAdded(CharacterTemporalEffectPresentationSnapshot effect)
        {
            if (!effect.HasPresentation || m_effectIconPrefab == null || m_effectIcons.ContainsKey(effect.RuntimeKey))
            {
                return;
            }

            GameObject instance = GameObjectPoolService.Rent(m_effectIconPrefab, GetEffectIconRoot());
            if (instance == null)
            {
                Debug.LogWarning("没有可用的角色状态图标实例，请检查效果图标对象池容量。", this);
                return;
            }

            if (!instance.TryGetComponent(out UIEffectIcon effectIcon))
            {
                Debug.LogError("角色状态图标预制体缺少 UIEffectIcon 组件。", instance);
                GameObjectPoolService.Return(instance);
                return;
            }

            m_effectIcons[effect.RuntimeKey] = effectIcon;
            effectIcon.Show(effect.Info.Icon);
        }

        /// <summary>角色移除持续效果展示时按 runtimeKey 归还图标，避免同名或同图标效果互相误删。</summary>
        private void OnTemporalEffectRemoved(CharacterTemporalEffectPresentationSnapshot effect)
        {
            if (m_effectIcons.TryGetValue(effect.RuntimeKey, out UIEffectIcon effectIcon))
            {
                GameObjectPoolService.Return(effectIcon.gameObject);
                m_effectIcons.Remove(effect.RuntimeKey);
            }
        }

        private void OnLevelUpped(int level) => UpdateNameAndLevel();

        private Transform GetEffectIconRoot() => m_effectIconRoot ? m_effectIconRoot : transform;

        /// <summary>配置并预热持续效果图标池。对象池容量来自 Inspector，方便按 HUD 密度调参。</summary>
        private void ConfigureEffectIconPool()
        {
            if (m_effectIconPrefab == null)
            {
                return;
            }

            GameObjectPoolService.SetMaxCapacity(m_effectIconPrefab, m_effectIconPoolSize);
            GameObjectPoolService.Prewarm(m_effectIconPrefab, m_effectIconPoolSize);
        }

        /// <summary>把本面板租出的所有效果图标归还对象池，并清空 runtimeKey 到图标的映射。</summary>
        private void ReturnAllEffectIcons()
        {
            foreach (UIEffectIcon effectIcon in m_effectIcons.Values)
            {
                if (effectIcon)
                {
                    GameObjectPoolService.Return(effectIcon.gameObject);
                }
            }

            m_effectIcons.Clear();
        }

        /// <summary>订阅目标角色事件，并立即同步当前资源、等级和已存在的持续效果展示。</summary>
        private void StartTargetListeningIfReady()
        {
            if (m_targetListening || m_target == null)
            {
                return;
            }

            m_targetListening = true;
            m_target.AddStatsChangedListener(OnStatsChanged);
            m_target.AddCurrentStatsChangedListener(OnStatsChanged);
            m_target.AddTemporalEffectPresentationAddedListener(OnTemporalEffectAdded);
            m_target.AddTemporalEffectPresentationRemovedListener(OnTemporalEffectRemoved);
            m_target.AddLevelUppedListener(OnLevelUpped);

            UpdateResourceBars();
            UpdateNameAndLevel();

            foreach (CharacterTemporalEffectPresentationSnapshot effect in m_target.GetTemporalEffectPresentationSnapshots())
            {
                OnTemporalEffectAdded(effect);
            }
        }

        /// <summary>注销目标角色事件。目标已销毁时只更新监听标记，不再访问缺失对象。</summary>
        private void StopTargetListening()
        {
            if (!m_targetListening)
            {
                return;
            }

            m_targetListening = false;
            if (m_target == null)
            {
                return;
            }

            m_target.RemoveStatsChangedListener(OnStatsChanged);
            m_target.RemoveCurrentStatsChangedListener(OnStatsChanged);
            m_target.RemoveTemporalEffectPresentationAddedListener(OnTemporalEffectAdded);
            m_target.RemoveTemporalEffectPresentationRemovedListener(OnTemporalEffectRemoved);
            m_target.RemoveLevelUppedListener(OnLevelUpped);
        }

        /// <summary>缓存预制体上的名称模板；文本为空时后续刷新会得到空字符串，不额外猜测默认格式。</summary>
        private void CacheNameAndLevelFormat()
        {
            m_nameAndLevelFormat = m_nameText != null ? m_nameText.text : string.Empty;
        }
    }
}
