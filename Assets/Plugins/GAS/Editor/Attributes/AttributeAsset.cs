using System;
using System.Collections.Generic;
using System.Linq;
using GAS.Editor.General;
using GAS.General;
using GAS.General.Validation;
using GAS.Runtime;
using NaughtyAttributes;
using UnityEditor;
using UnityEngine;

namespace GAS.Editor
{
    [FilePath(GasDefine.GAS_ATTRIBUTE_ASSET_PATH)]
    public class AttributeAsset : ScriptableSingleton<AttributeAsset>
    {
                [ShowIf("ExistDuplicatedAttribute")]
                [NonSerialized]
        public string Warning_DuplicatedAttribute = "";
        
                                [OnValueChanged("@OnValueChanged()")]
                public List<AttributeAccessor> attributes = new List<AttributeAccessor>();

        private void OnValueChanged()
        {
            Debug.Log("OnListChanged");
            SaveAsset();
        }

        private void OnCollectionChanged()
        {
            Debug.Log("OnCollectionChanged");
            SaveAsset();
        }

        [Button("按名称排序")]
        private void SortAttributes()
        {
            attributes = attributes.OrderBy(x => x.Name).ToList();
            SaveAsset();
        }

        public List<string> AttributeNames =>
            (from attr in attributes where !string.IsNullOrEmpty(attr.Name) select attr.Name).ToList();

        private void OnEnable()
        {
            AttributeAccessor.ParentAsset = this;
        }

                        [Button(GASTextDefine.BUTTON_GenerateAttributeCollection)]
        void GenCode()
        {
            if (ExistEmptyAttribute() || ExistDuplicatedAttribute())
            {
                EditorUtility.DisplayDialog("Warning", "Please check the warning message!\n" +
                                                       "Fix the Attribute Error!\n", "OK");
                return;
            }

            SaveAsset();
            AttributeCollectionGen.Gen();
            AssetDatabase.Refresh();
        }

        private void SaveAsset()
        {
            Debug.Log("[EX] Attribute Asset save!");
            EditorUtility.SetDirty(this);
            UpdateAsset(this);
            Save();
        }

        private int OnRemoveElement(AttributeAccessor attribute)
        {
            var result = EditorUtility.DisplayDialog("Confirmation",
                $"Are you sure you want to REMOVE Attribute:{attribute.Name}?",
                "Yes", "No");

            if (!result) return -1;

            Debug.Log($"[EX] Attribute Asset remove element:{attribute.Name} !");
            SaveAsset();
            return attributes.IndexOf(attribute);
        }

        private int OnRemoveIndex(int index)
        {
            var attribute = attributes[index];
            var result = EditorUtility.DisplayDialog("Confirmation",
                $"Are you sure you want to REMOVE Attribute:{attribute.Name}?",
                "Yes", "No");

            if (!result) return -1;

            attributes.RemoveAt(index);
            Debug.Log($"[EX] Attribute Asset remove element:{attribute.Name} !");
            SaveAsset();
            return index;
        }

        private void OnAddAttribute()
        {
            StringEditWindow.OpenWindow("创建新属性", null, newName =>
            {
                var validateVariableName = Validations.ValidateVariableName(newName);

                if (validateVariableName.IsValid == false)
                {
                    return validateVariableName;
                }

                if (attributes.Exists(x => x.Name == newName))
                {
                    return ValidationResult.Invalid($"属性名已存在: \"{newName}\"!");
                }

                return ValidationResult.Valid;
            }, x =>
            {
                attributes.Add(new AttributeAccessor { Name = x });
                SaveAsset();
                Debug.Log("[EX] Attribute Asset add element!");
            });
            GUIUtility.ExitGUI(); // In order to solve: "EndLayoutGroup: BeginLayoutGroup must be called first."
        }

        private bool ExistEmptyAttribute()
        {
            return attributes.Any(attribute => string.IsNullOrEmpty(attribute.Name));
        }

        private bool ExistDuplicatedAttribute()
        {
            var duplicates = attributes
                .Where(a => !string.IsNullOrEmpty(a.Name))
                .GroupBy(a => a.Name)
                .Where(group => group.Count() > 1)
                .Select(group => group.Key)
                .ToList();

            if (duplicates.Count > 0)
            {
                var duplicatedAttributes = duplicates.Aggregate("", (current, d) => current + d + ",");
                duplicatedAttributes = duplicatedAttributes.Remove(duplicatedAttributes.Length - 1, 1);
                Warning_DuplicatedAttribute =
                    string.Format(GASTextDefine.TIP_Warning_DuplicatedAttribute, duplicatedAttributes);
            }

            return duplicates.Count > 0;
        }

        [Serializable]
        public class AttributeAccessor
        {
            private const int LabelWidth = 100;
            public static AttributeAsset ParentAsset;

            private string DisplayName => $"{Name} - {Comment}";

            [Foldout("$DisplayName")]
                        [ValidateInput("@OnNameChanged($value)", "Attribute name is invalid!")]
                        public string Name = "Unnamed";

            private bool OnNameChanged(string value)
            {
                if (ParentAsset == null) return true;

                return Validations.IsValidVariableName(value);
            }

            [Foldout("$DisplayName")]
                        public string Comment = "";

            [Foldout("$DisplayName")]
                        [OnValueChanged("@OnCalculateModeChanged()")]
                        public CalculateMode CalculateMode = CalculateMode.Stacking;

            private void OnCalculateModeChanged()
            {
                if (CalculateMode is CalculateMode.MinValueOnly or CalculateMode.MaxValueOnly)
                {
                    SupportedOperation = SupportedOperation.Override;
                }
            }

            [Foldout("$DisplayName")]
                        [DisableIf(
                "@CalculateMode == GAS.Runtime.CalculateMode.MinValueOnly || CalculateMode == GAS.Runtime.CalculateMode.MaxValueOnly")]
                        public SupportedOperation SupportedOperation = SupportedOperation.All;

            [Foldout("$DisplayName")]
                                                public float DefaultValue = 0f;

            [Foldout("$DisplayName")]
                                                            public bool LimitMinValue = false;

            [Foldout("$DisplayName")]
                                                [EnableIf("LimitMinValue")]
                        public float MinValue = float.MinValue;

            [Foldout("$DisplayName")]
                                                public bool LimitMaxValue = false;

            [Foldout("$DisplayName")]
                                                [EnableIf("LimitMaxValue")]
                        public float MaxValue = float.MaxValue;
        }
    }
}
