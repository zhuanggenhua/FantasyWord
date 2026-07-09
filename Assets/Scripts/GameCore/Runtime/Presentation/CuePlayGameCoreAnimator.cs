using System;
using GAS.Runtime;
using UnityEngine;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 项目侧 EX-GAS 自定义动画 Cue 的运行解释。
    /// EX-GAS Timeline 仍只配置动作键；角色动作由角色 Animator 播放，
    /// 武器攻击和武器自带特效由 EquipmentRenderer 按同一个动作键同步。
    /// </summary>
    public sealed class CuePlayGameCoreAnimator : GameplayCueBase<XParamAnimator>
    {
        private Component m_animationController;
        private MethodInfoCache m_methods;

        public override void OnAdd(float time)
        {
            base.OnAdd(time);
            m_animationController = ResolveAnimationController();
            m_methods = MethodInfoCache.Create(m_animationController);
        }

        public override void OnActivate(float time)
        {
            base.OnActivate(time);
            string animationKey = Parameter?.AnimationName?.Trim();
            if (string.IsNullOrWhiteSpace(animationKey))
            {
                return;
            }

            if (TryPlayEquipmentAnimation(animationKey))
            {
                return;
            }

            if (RequiresEquipmentAnimation(animationKey))
            {
                Debug.LogWarning(
                    $"EX-GAS 动画 Cue 请求装备动作 {animationKey}，但未能进入装备系统。"
                    + "已拒绝回退普通 Animator，避免角色动作和武器攻击/特效脱节。",
                    _abilitySystemCell?.GameObject);
                return;
            }

            TryPlayAnimatorFallback(animationKey);
        }

        public override void OnRemove(float time)
        {
            base.OnRemove(time);
            m_animationController = null;
            m_methods = default;
        }

#if UNITY_EDITOR
        public override void OnPreview(GameObject target, int frame, int startFrame, int endFrame)
        {
            base.OnPreview(target, frame, startFrame, endFrame);

            string animationKey = Parameter?.AnimationName?.Trim();
            if (target == null || string.IsNullOrWhiteSpace(animationKey))
            {
                return;
            }

            float normalizedTime = endFrame > startFrame
                ? Mathf.Clamp01((float)(frame - startFrame) / (endFrame - startFrame))
                : 0f;

            Component animationController = ResolveAnimationController(target);
            MethodInfoCache methods = MethodInfoCache.Create(animationController);
            if (TryPlayEquipmentAnimation(animationController, methods, animationKey, normalizedTime))
            {
                RefreshEquipmentRenderers(target);
                UnityEditor.SceneView.RepaintAll();
                return;
            }

            if (!RequiresEquipmentAnimation(animationKey))
            {
                TryPlayAnimatorFallback(target, animationKey);
                UnityEditor.SceneView.RepaintAll();
            }
        }
#endif

        private Component ResolveAnimationController()
        {
            GameObject go = _abilitySystemCell?.GameObject;
            if (go == null)
            {
                return null;
            }

            Transform root = string.IsNullOrWhiteSpace(Parameter?.AnimatorNodePath)
                ? go.transform
                : go.transform.Find(Parameter.AnimatorNodePath);
            if (root == null)
            {
                return null;
            }

            Type animationControllerType = Type.GetType(
                "AnimationController");
            return animationControllerType == null
                ? null
                : root.GetComponentInChildren(animationControllerType, true);
        }

        private bool TryPlayEquipmentAnimation(string animationKey)
        {
            return TryPlayEquipmentAnimation(m_animationController, m_methods, animationKey, null);
        }

        private bool TryPlayEquipmentAnimation(
            Component animationController,
            MethodInfoCache methods,
            string animationKey,
            float? previewNormalizedTime)
        {
            if (animationController == null || !methods.IsValid)
            {
                return false;
            }

            object database = methods.AnimationDatabaseGetter?.GetValue(animationController);
            if (database == null)
            {
                return false;
            }

            object animationType = methods.GetByKey?.Invoke(database, new object[] { animationKey });
            if (animationType == null)
            {
                return false;
            }

            bool supportsAnimation = true;
            if (methods.SupportsAnimation != null)
            {
                object supports = methods.SupportsAnimation.Invoke(animationController, new[] { animationType });
                supportsAnimation = supports is true;
            }

            if (!supportsAnimation)
            {
                return false;
            }

            methods.SetAnimation?.Invoke(animationController, new[] { animationType });
            if (previewNormalizedTime.HasValue)
            {
                PreviewAnimatorState(animationController, methods, animationType, previewNormalizedTime.Value);
            }

            return true;
        }

        private void TryPlayAnimatorFallback(string animationKey)
        {
            GameObject go = _abilitySystemCell?.GameObject;
            if (go == null)
            {
                return;
            }

            Transform root = string.IsNullOrWhiteSpace(Parameter?.AnimatorNodePath)
                ? go.transform
                : go.transform.Find(Parameter.AnimatorNodePath);
            Animator animator = root != null ? root.GetComponentInChildren<Animator>(true) : null;
            if (animator == null)
            {
                return;
            }

            animator.Play(animationKey, 0, 0f);
        }

        private void TryPlayAnimatorFallback(GameObject target, string animationKey)
        {
            Transform root = string.IsNullOrWhiteSpace(Parameter?.AnimatorNodePath)
                ? target.transform
                : target.transform.Find(Parameter.AnimatorNodePath);
            Animator animator = root != null ? root.GetComponentInChildren<Animator>(true) : null;
            if (animator == null)
            {
                return;
            }

            animator.Play(animationKey, 0, 0f);
            animator.Update(0f);
        }

        private static void PreviewAnimatorState(
            Component animationController,
            MethodInfoCache methods,
            object animationType,
            float normalizedTime)
        {
            if (methods.AnimatorGetter == null || methods.ResolvePlayableStateName == null)
            {
                return;
            }

            object animatorValue = methods.AnimatorGetter.GetValue(animationController);
            if (animatorValue is not Animator animator || animator.layerCount <= 0)
            {
                return;
            }

            object stateNameValue = methods.ResolvePlayableStateName.Invoke(animationController, new[] { animationType });
            if (stateNameValue is not string stateName || string.IsNullOrWhiteSpace(stateName))
            {
                return;
            }

            animator.Play(Animator.StringToHash(stateName), 0, Mathf.Clamp01(normalizedTime));
            animator.Update(0f);
        }

        private Component ResolveAnimationController(GameObject target)
        {
            Transform root = string.IsNullOrWhiteSpace(Parameter?.AnimatorNodePath)
                ? target.transform
                : target.transform.Find(Parameter.AnimatorNodePath);
            if (root == null)
            {
                return null;
            }

            Type animationControllerType = Type.GetType(
                "AnimationController");
            return animationControllerType == null
                ? null
                : root.GetComponentInChildren(animationControllerType, true);
        }

        private static void RefreshEquipmentRenderers(GameObject target)
        {
            Type equipmentRendererType = Type.GetType(
                "EquipmentRenderer");
            if (equipmentRendererType == null)
            {
                return;
            }

            Component[] renderers = target.GetComponentsInChildren(equipmentRendererType, true);
            for (int i = 0; i < renderers.Length; i++)
            {
                Component renderer = renderers[i];
                equipmentRendererType.GetMethod(
                        "LateUpdate",
                        System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.NonPublic)
                    ?.Invoke(renderer, null);
            }
        }

        private static bool RequiresEquipmentAnimation(string animationKey)
        {
            return animationKey switch
            {
                "Attack" => true,
                "ChargedAttack" => true,
                _ => false
            };
        }

        private readonly struct MethodInfoCache
        {
            public readonly System.Reflection.PropertyInfo AnimationDatabaseGetter;
            public readonly System.Reflection.PropertyInfo AnimatorGetter;
            public readonly System.Reflection.MethodInfo GetByKey;
            public readonly System.Reflection.MethodInfo SetAnimation;
            public readonly System.Reflection.MethodInfo SupportsAnimation;
            public readonly System.Reflection.MethodInfo ResolvePlayableStateName;

            private MethodInfoCache(
                System.Reflection.PropertyInfo animationDatabaseGetter,
                System.Reflection.PropertyInfo animatorGetter,
                System.Reflection.MethodInfo getByKey,
                System.Reflection.MethodInfo setAnimation,
                System.Reflection.MethodInfo supportsAnimation,
                System.Reflection.MethodInfo resolvePlayableStateName)
            {
                AnimationDatabaseGetter = animationDatabaseGetter;
                AnimatorGetter = animatorGetter;
                GetByKey = getByKey;
                SetAnimation = setAnimation;
                SupportsAnimation = supportsAnimation;
                ResolvePlayableStateName = resolvePlayableStateName;
            }

            public bool IsValid => AnimationDatabaseGetter != null && GetByKey != null && SetAnimation != null;

            public static MethodInfoCache Create(Component animationController)
            {
                if (animationController == null)
                {
                    return default;
                }

                Type controllerType = animationController.GetType();
                System.Reflection.PropertyInfo databaseGetter = controllerType.GetProperty("AnimationDatabase");
                Type databaseType = databaseGetter?.PropertyType;
                System.Reflection.MethodInfo getByKey = databaseType?.GetMethod("GetByKey", new[] { typeof(string) });
                Type animationType = getByKey?.ReturnType;
                if (animationType == null)
                {
                    return default;
                }

                System.Reflection.PropertyInfo animatorGetter = controllerType.GetProperty("Animator");
                System.Reflection.MethodInfo setAnimation = controllerType.GetMethod("SetAnimation", new[] { animationType });
                System.Reflection.MethodInfo supportsAnimation = controllerType.GetMethod("SupportsAnimation", new[] { animationType });
                System.Reflection.MethodInfo resolvePlayableStateName = controllerType.GetMethod(
                    "ResolvePlayableStateName",
                    new[] { animationType });
                return new MethodInfoCache(
                    databaseGetter,
                    animatorGetter,
                    getByKey,
                    setAnimation,
                    supportsAnimation,
                    resolvePlayableStateName);
            }
        }
    }
}
