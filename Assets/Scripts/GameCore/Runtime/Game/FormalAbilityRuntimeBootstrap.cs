using System;
using System.Linq;
using System.Reflection;
using GAS.Runtime;
using GAS.General;
using UnityEngine;

namespace FantasyWord.GameCore
{
    internal static class FormalAbilityRuntimeBootstrap
    {
        private static bool s_initialized;
        private static bool s_gameCoreGasExtensionsRegistered;

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
        private static void ResetSubsystemState()
        {
            s_initialized = false;
            s_gameCoreGasExtensionsRegistered = false;
        }

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.BeforeSceneLoad)]
        private static void InitializeBeforeSceneLoad()
        {
            EnsureInitialized();
        }

        public static void EnsureInitialized()
        {
            EnsureResourceLoaderRegistered();

            if (s_initialized && GASManager.ExWorld != null && GASManager.ExWorld.IsCreated)
            {
                EnsureGameCoreGasExtensionsRegistered();
                GASManager.Run();
                return;
            }

            EnsureGeneratedConfigTablesInitialized();
            GASManager.Initialize();
            s_gameCoreGasExtensionsRegistered = false;
            EnsureGameCoreGasExtensionsRegistered();
            GASManager.Run();
            EnsureGeneratedGasCachesInitialized();

            CharacterAbilitySet.EnsureFormalAbilityRuleLogicRegistered();
            CharacterAbilitySet.EnsureFormalRuleSupportTypesRegistered();

            s_initialized = true;
        }

        private static void EnsureResourceLoaderRegistered()
        {
            GASResourceLoader.Register(
                FormalGasAbilityResourceLoader.LoadSync,
                FormalGasAbilityResourceLoader.LoadAsync,
                FormalGasAbilityResourceLoader.Release);
        }

        private static void EnsureGeneratedConfigTablesInitialized()
        {
            const string integrationType = "GAS.Runtime.FormalGasAbilityDescriptionGeneratedRuntime";
            const string initializeMethod = "InitializeConfigTables";

            object result = InvokeRequiredStaticMethod(integrationType, initializeMethod);
            if (result is not true)
            {
                throw new InvalidOperationException(
                    "EX-GAS 生成配置表初始化失败。"
                    + "请检查 FantasyWord.GAS.GeneratedRuntime 程序集、gas-config YooAsset 收集组和配置表内容。");
            }
        }

        private static void EnsureGameCoreGasExtensionsRegistered()
        {
            if (s_gameCoreGasExtensionsRegistered ||
                GASManager.ExWorld == null ||
                !GASManager.ExWorld.IsCreated)
            {
                return;
            }

            var instantEffectGroup = GASManager.ExWorld.GetExistingSystemManaged<SGInstantEffect>();
            if (instantEffectGroup == null)
            {
                return;
            }

            var damageSystem = GASManager.ExWorld.GetOrCreateSystemManaged<SExecuteFormalDamageEffectsManaged>();
            instantEffectGroup.AddSystemToUpdateList(damageSystem);
            instantEffectGroup.SortSystems();
            s_gameCoreGasExtensionsRegistered = true;
        }

        private static void EnsureGeneratedGasCachesInitialized()
        {
            if (ReflectionHelper.TypeExists("GAS.Runtime.XLauncher"))
            {
                ReflectionHelper.InvokeStaticMethod("GAS.Runtime.XLauncher", "InitCache");
            }

            if (ReflectionHelper.TypeExists("GAS.Runtime.XTag"))
            {
                ReflectionHelper.InvokeStaticMethod("GAS.Runtime.XTag", "InitTagList");
            }

#if UNITY_EDITOR
            if (ReflectionHelper.TypeExists("GAS.Runtime.XLuban"))
            {
                ReflectionHelper.InvokeStaticMethod("GAS.Runtime.XLuban", "LoadTablesForEditor");
            }
#endif
        }

        private static object InvokeRequiredStaticMethod(string fullTypeName, string methodName)
        {
            Type type = TryFindStaticType(fullTypeName) ?? throw new InvalidOperationException(
                $"缺少 EX-GAS 生成配置入口 {fullTypeName}。请检查生成运行时程序集是否已编译。");
            MethodInfo method = type.GetMethod(
                methodName,
                BindingFlags.Static | BindingFlags.Public | BindingFlags.NonPublic) ?? throw new InvalidOperationException(
                $"缺少 EX-GAS 生成配置方法 {fullTypeName}.{methodName}。请重新生成或修复 GAS 配置代码。");

            try
            {
                return method.Invoke(null, null);
            }
            catch (TargetInvocationException exception) when (exception.InnerException != null)
            {
                throw new InvalidOperationException(
                    $"调用 EX-GAS 生成配置入口 {fullTypeName}.{methodName} 失败。",
                    exception.InnerException);
            }
        }

        private static Type TryFindStaticType(string fullTypeName)
        {
            return Type.GetType(fullTypeName) ?? AppDomain.CurrentDomain
                .GetAssemblies()
                .Select(assembly => assembly.GetType(fullTypeName, throwOnError: false))
                .FirstOrDefault(type => type != null);
        }
    }
}
