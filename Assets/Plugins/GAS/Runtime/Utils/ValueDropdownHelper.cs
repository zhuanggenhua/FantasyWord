#if UNITY_EDITOR
using System.Collections.Generic;
using System.Linq;
using NaughtyAttributes;

namespace GAS.Runtime
{
    public static class GasInspectorChoiceProvider
    {
        /// <summary>
        /// 提供所有属性集名称，供项目侧 Inspector 下拉选择器读取。
        /// </summary>
        public static IEnumerable<string> AttributeSetChoices => ReflectionHelper.AttributeSetNames;

        /// <summary>
        /// 提供所有属性名称，供项目侧 Inspector 下拉选择器读取。
        /// </summary>
        public static IEnumerable<string> AttributeChoices => ReflectionHelper.AttributeNames;

        private static KeyValuePair<string, object>[] _gameplayTagChoices;

        /// <summary>
        /// 提供所有 GameplayTag，显示文本使用标签名，写回值使用 GameplayTag 本体。
        /// </summary>
        public static IEnumerable<KeyValuePair<string, object>> GameplayTagChoices
        {
            get
            {
                _gameplayTagChoices ??= ReflectionHelper.GameplayTags
                    .Select(gameplayTag => new KeyValuePair<string, object>(gameplayTag.Name, gameplayTag))
                    .ToArray();
                return _gameplayTagChoices;
            }
        }
    }
}
#endif
