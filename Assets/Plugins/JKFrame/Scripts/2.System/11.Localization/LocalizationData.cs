using System;
using UnityEngine;

[Serializable]
public abstract class LocalizationDataBase
{
}

[Serializable]
public class LocalizationStringData : LocalizationDataBase
{
    public string content;
}

[Serializable]
public class LocalizationImageData : LocalizationDataBase
{
    public Sprite content;
}
