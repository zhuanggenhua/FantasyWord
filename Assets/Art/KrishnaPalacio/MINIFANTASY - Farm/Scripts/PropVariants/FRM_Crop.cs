using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Minifantasy.Farms
{
    public class FRM_Crop : MonoBehaviour
    {
        [Tooltip("Select a Crop.")]
        [SerializeField] private Crop cropSelection = Crop.Pumpkin;

        [Tooltip("Select a CropState.")]
        [SerializeField] private CropState cropStateSelection = CropState.SeedsPackIcon;

        [Header("Sprites - Pumpkin")]
        [SerializeField] private Sprite pumpkin_SeedsPackIcon;
        [SerializeField] private Sprite pumpkin_SingleSeed;
        [SerializeField] private Sprite pumpkin_MultipleSeeds;
        [SerializeField] private Sprite pumpkin_GrowingState_1;
        [SerializeField] private Sprite pumpkin_GrowingState_2;
        [SerializeField] private Sprite pumpkin_GrowingState_3;
        [SerializeField] private Sprite pumpkin_Grown;

        [Header("Sprites - Eggplant")]
        [SerializeField] private Sprite eggplant_SeedsPackIcon;
        [SerializeField] private Sprite eggplant_SingleSeed;
        [SerializeField] private Sprite eggplant_MultipleSeeds;
        [SerializeField] private Sprite eggplant_GrowingState_1;
        [SerializeField] private Sprite eggplant_GrowingState_2;
        [SerializeField] private Sprite eggplant_GrowingState_3;
        [SerializeField] private Sprite eggplant_Grown;

        [Header("Sprites - Berry")]
        [SerializeField] private Sprite berry_SeedsPackIcon;
        [SerializeField] private Sprite berry_SingleSeed;
        [SerializeField] private Sprite berry_MultipleSeeds;
        [SerializeField] private Sprite berry_GrowingState_1;
        [SerializeField] private Sprite berry_GrowingState_2;
        [SerializeField] private Sprite berry_GrowingState_3;
        [SerializeField] private Sprite berry_Grown;

        [Header("Sprites - Beet")]
        [SerializeField] private Sprite beet_SeedsPackIcon;
        [SerializeField] private Sprite beet_SingleSeed;
        [SerializeField] private Sprite beet_MultipleSeeds;
        [SerializeField] private Sprite beet_GrowingState_1;
        [SerializeField] private Sprite beet_GrowingState_2;
        [SerializeField] private Sprite beet_GrowingState_3;
        [SerializeField] private Sprite beet_Grown;

        [Header("Sprites - Wheat")]
        [SerializeField] private Sprite wheat_SeedsPackIcon;
        [SerializeField] private Sprite wheat_SingleSeed;
        [SerializeField] private Sprite wheat_MultipleSeeds;
        [SerializeField] private Sprite wheat_GrowingState_1;
        [SerializeField] private Sprite wheat_GrowingState_2;
        [SerializeField] private Sprite wheat_GrowingState_3;
        [SerializeField] private Sprite wheat_Grown;

        [Header("Sprites - Tomato")]
        [SerializeField] private Sprite tomato_SeedsPackIcon;
        [SerializeField] private Sprite tomato_SingleSeed;
        [SerializeField] private Sprite tomato_MultipleSeeds;
        [SerializeField] private Sprite tomato_GrowingState_1;
        [SerializeField] private Sprite tomato_GrowingState_2;
        [SerializeField] private Sprite tomato_GrowingState_3;
        [SerializeField] private Sprite tomato_Grown;

        [Header("Sprites - Sunflower")]
        [SerializeField] private Sprite sunflower_SeedsPackIcon;
        [SerializeField] private Sprite sunflower_SingleSeed;
        [SerializeField] private Sprite sunflower_MultipleSeeds;
        [SerializeField] private Sprite sunflower_GrowingState_1;
        [SerializeField] private Sprite sunflower_GrowingState_2;
        [SerializeField] private Sprite sunflower_GrowingState_3;
        [SerializeField] private Sprite sunflower_Grown;

        [Header("Sprites - Corn")]
        [SerializeField] private Sprite corn_SeedsPackIcon;
        [SerializeField] private Sprite corn_SingleSeed;
        [SerializeField] private Sprite corn_MultipleSeeds;
        [SerializeField] private Sprite corn_GrowingState_1;
        [SerializeField] private Sprite corn_GrowingState_2;
        [SerializeField] private Sprite corn_GrowingState_3;
        [SerializeField] private Sprite corn_Grown;

        [Header("Sprites - Rice")]
        [SerializeField] private Sprite rice_SeedsPackIcon;
        [SerializeField] private Sprite rice_SingleSeed;
        [SerializeField] private Sprite rice_MultipleSeeds;
        [SerializeField] private Sprite rice_GrowingState_1;
        [SerializeField] private Sprite rice_GrowingState_2;
        [SerializeField] private Sprite rice_GrowingState_3;
        [SerializeField] private Sprite rice_Grown;

        [Header("Sprites - Lettuce")]
        [SerializeField] private Sprite lettuce_SeedsPackIcon;
        [SerializeField] private Sprite lettuce_SingleSeed;
        [SerializeField] private Sprite lettuce_MultipleSeeds;
        [SerializeField] private Sprite lettuce_GrowingState_1;
        [SerializeField] private Sprite lettuce_GrowingState_2;
        [SerializeField] private Sprite lettuce_GrowingState_3;
        [SerializeField] private Sprite lettuce_Grown;

        [Header("Sprites - Potato")]
        [SerializeField] private Sprite potato_SeedsPackIcon;
        [SerializeField] private Sprite potato_SingleSeed;
        [SerializeField] private Sprite potato_MultipleSeeds;
        [SerializeField] private Sprite potato_GrowingState_1;
        [SerializeField] private Sprite potato_GrowingState_2;
        [SerializeField] private Sprite potato_GrowingState_3;
        [SerializeField] private Sprite potato_Grown;

        [Header("Sprites - Radish")]
        [SerializeField] private Sprite radish_SeedsPackIcon;
        [SerializeField] private Sprite radish_SingleSeed;
        [SerializeField] private Sprite radish_MultipleSeeds;
        [SerializeField] private Sprite radish_GrowingState_1;
        [SerializeField] private Sprite radish_GrowingState_2;
        [SerializeField] private Sprite radish_GrowingState_3;
        [SerializeField] private Sprite radish_Grown;

        [Header("Sprites - Garlic")]
        [SerializeField] private Sprite garlic_SeedsPackIcon;
        [SerializeField] private Sprite garlic_SingleSeed;
        [SerializeField] private Sprite garlic_MultipleSeeds;
        [SerializeField] private Sprite garlic_GrowingState_1;
        [SerializeField] private Sprite garlic_GrowingState_2;
        [SerializeField] private Sprite garlic_GrowingState_3;
        [SerializeField] private Sprite garlic_Grown;

        [Header("Sprites - Cauliflower")]
        [SerializeField] private Sprite cauliflower_SeedsPackIcon;
        [SerializeField] private Sprite cauliflower_SingleSeed;
        [SerializeField] private Sprite cauliflower_MultipleSeeds;
        [SerializeField] private Sprite cauliflower_GrowingState_1;
        [SerializeField] private Sprite cauliflower_GrowingState_2;
        [SerializeField] private Sprite cauliflower_GrowingState_3;
        [SerializeField] private Sprite cauliflower_Grown;

        [Header("Sprites - Pepper")]
        [SerializeField] private Sprite pepper_SeedsPackIcon;
        [SerializeField] private Sprite pepper_SingleSeed;
        [SerializeField] private Sprite pepper_MultipleSeeds;
        [SerializeField] private Sprite pepper_GrowingState_1;
        [SerializeField] private Sprite pepper_GrowingState_2;
        [SerializeField] private Sprite pepper_GrowingState_3;
        [SerializeField] private Sprite pepper_Grown;

        private void OnValidate()
        {
            Sprite selectedSprite = null;

            switch (cropSelection)
            {
                case Crop.Pumpkin:
                    switch (cropStateSelection)
                    {
                        case CropState.SeedsPackIcon:
                            selectedSprite = pumpkin_SeedsPackIcon;
                            break;
                        case CropState.SingleSeed:
                            selectedSprite = pumpkin_SingleSeed;
                            break;
                        case CropState.MultipleSeeds:
                            selectedSprite = pumpkin_MultipleSeeds;
                            break;
                        case CropState.GrowingState1:
                            selectedSprite = pumpkin_GrowingState_1;
                            break;
                        case CropState.GrowingState2:
                            selectedSprite = pumpkin_GrowingState_2;
                            break;
                        case CropState.GrowingState3:
                            selectedSprite = pumpkin_GrowingState_3;
                            break;
                        case CropState.Grown:
                            selectedSprite = pumpkin_Grown;
                            break;
                    }
                    break;
                case Crop.Eggplant:
                    switch (cropStateSelection)
                    {
                        case CropState.SeedsPackIcon:
                            selectedSprite = eggplant_SeedsPackIcon;
                            break;
                        case CropState.SingleSeed:
                            selectedSprite = eggplant_SingleSeed;
                            break;
                        case CropState.MultipleSeeds:
                            selectedSprite = eggplant_MultipleSeeds;
                            break;
                        case CropState.GrowingState1:
                            selectedSprite = eggplant_GrowingState_1;
                            break;
                        case CropState.GrowingState2:
                            selectedSprite = eggplant_GrowingState_2;
                            break;
                        case CropState.GrowingState3:
                            selectedSprite = eggplant_GrowingState_3;
                            break;
                        case CropState.Grown:
                            selectedSprite = eggplant_Grown;
                            break;
                    }
                    break;
                case Crop.Berry:
                    switch (cropStateSelection)
                    {
                        case CropState.SeedsPackIcon:
                            selectedSprite = berry_SeedsPackIcon;
                            break;
                        case CropState.SingleSeed:
                            selectedSprite = berry_SingleSeed;
                            break;
                        case CropState.MultipleSeeds:
                            selectedSprite = berry_MultipleSeeds;
                            break;
                        case CropState.GrowingState1:
                            selectedSprite = berry_GrowingState_1;
                            break;
                        case CropState.GrowingState2:
                            selectedSprite = berry_GrowingState_2;
                            break;
                        case CropState.GrowingState3:
                            selectedSprite = berry_GrowingState_3;
                            break;
                        case CropState.Grown:
                            selectedSprite = berry_Grown;
                            break;
                    }
                    break;
                case Crop.Beet:
                    switch (cropStateSelection)
                    {
                        case CropState.SeedsPackIcon:
                            selectedSprite = beet_SeedsPackIcon;
                            break;
                        case CropState.SingleSeed:
                            selectedSprite = beet_SingleSeed;
                            break;
                        case CropState.MultipleSeeds:
                            selectedSprite = beet_MultipleSeeds;
                            break;
                        case CropState.GrowingState1:
                            selectedSprite = beet_GrowingState_1;
                            break;
                        case CropState.GrowingState2:
                            selectedSprite = beet_GrowingState_2;
                            break;
                        case CropState.GrowingState3:
                            selectedSprite = beet_GrowingState_3;
                            break;
                        case CropState.Grown:
                            selectedSprite = beet_Grown;
                            break;
                    }
                    break;
                case Crop.Wheat:
                    switch (cropStateSelection)
                    {
                        case CropState.SeedsPackIcon:
                            selectedSprite = wheat_SeedsPackIcon;
                            break;
                        case CropState.SingleSeed:
                            selectedSprite = wheat_SingleSeed;
                            break;
                        case CropState.MultipleSeeds:
                            selectedSprite = wheat_MultipleSeeds;
                            break;
                        case CropState.GrowingState1:
                            selectedSprite = wheat_GrowingState_1;
                            break;
                        case CropState.GrowingState2:
                            selectedSprite = wheat_GrowingState_2;
                            break;
                        case CropState.GrowingState3:
                            selectedSprite = wheat_GrowingState_3;
                            break;
                        case CropState.Grown:
                            selectedSprite = wheat_Grown;
                            break;
                    }
                    break;
                case Crop.Tomato:
                    switch (cropStateSelection)
                    {
                        case CropState.SeedsPackIcon:
                            selectedSprite = tomato_SeedsPackIcon;
                            break;
                        case CropState.SingleSeed:
                            selectedSprite = tomato_SingleSeed;
                            break;
                        case CropState.MultipleSeeds:
                            selectedSprite = tomato_MultipleSeeds;
                            break;
                        case CropState.GrowingState1:
                            selectedSprite = tomato_GrowingState_1;
                            break;
                        case CropState.GrowingState2:
                            selectedSprite = tomato_GrowingState_2;
                            break;
                        case CropState.GrowingState3:
                            selectedSprite = tomato_GrowingState_3;
                            break;
                        case CropState.Grown:
                            selectedSprite = tomato_Grown;
                            break;
                    }
                    break;
                case Crop.Sunflower:
                    switch (cropStateSelection)
                    {
                        case CropState.SeedsPackIcon:
                            selectedSprite = sunflower_SeedsPackIcon;
                            break;
                        case CropState.SingleSeed:
                            selectedSprite = sunflower_SingleSeed;
                            break;
                        case CropState.MultipleSeeds:
                            selectedSprite = sunflower_MultipleSeeds;
                            break;
                        case CropState.GrowingState1:
                            selectedSprite = sunflower_GrowingState_1;
                            break;
                        case CropState.GrowingState2:
                            selectedSprite = sunflower_GrowingState_2;
                            break;
                        case CropState.GrowingState3:
                            selectedSprite = sunflower_GrowingState_3;
                            break;
                        case CropState.Grown:
                            selectedSprite = sunflower_Grown;
                            break;
                    }
                    break;
                case Crop.Corn:
                    switch (cropStateSelection)
                    {
                        case CropState.SeedsPackIcon:
                            selectedSprite = corn_SeedsPackIcon;
                            break;
                        case CropState.SingleSeed:
                            selectedSprite = corn_SingleSeed;
                            break;
                        case CropState.MultipleSeeds:
                            selectedSprite = corn_MultipleSeeds;
                            break;
                        case CropState.GrowingState1:
                            selectedSprite = corn_GrowingState_1;
                            break;
                        case CropState.GrowingState2:
                            selectedSprite = corn_GrowingState_2;
                            break;
                        case CropState.GrowingState3:
                            selectedSprite = corn_GrowingState_3;
                            break;
                        case CropState.Grown:
                            selectedSprite = corn_Grown;
                            break;
                    }
                    break;
                case Crop.Rice:
                    switch (cropStateSelection)
                    {
                        case CropState.SeedsPackIcon:
                            selectedSprite = rice_SeedsPackIcon;
                            break;
                        case CropState.SingleSeed:
                            selectedSprite = rice_SingleSeed;
                            break;
                        case CropState.MultipleSeeds:
                            selectedSprite = rice_MultipleSeeds;
                            break;
                        case CropState.GrowingState1:
                            selectedSprite = rice_GrowingState_1;
                            break;
                        case CropState.GrowingState2:
                            selectedSprite = rice_GrowingState_2;
                            break;
                        case CropState.GrowingState3:
                            selectedSprite = rice_GrowingState_3;
                            break;
                        case CropState.Grown:
                            selectedSprite = rice_Grown;
                            break;
                    }
                    break;
                case Crop.Lettuce:
                    switch (cropStateSelection)
                    {
                        case CropState.SeedsPackIcon:
                            selectedSprite = lettuce_SeedsPackIcon;
                            break;
                        case CropState.SingleSeed:
                            selectedSprite = lettuce_SingleSeed;
                            break;
                        case CropState.MultipleSeeds:
                            selectedSprite = lettuce_MultipleSeeds;
                            break;
                        case CropState.GrowingState1:
                            selectedSprite = lettuce_GrowingState_1;
                            break;
                        case CropState.GrowingState2:
                            selectedSprite = lettuce_GrowingState_2;
                            break;
                        case CropState.GrowingState3:
                            selectedSprite = lettuce_GrowingState_3;
                            break;
                        case CropState.Grown:
                            selectedSprite = lettuce_Grown;
                            break;
                    }
                    break;
                case Crop.Potato:
                    switch (cropStateSelection)
                    {
                        case CropState.SeedsPackIcon:
                            selectedSprite = potato_SeedsPackIcon;
                            break;
                        case CropState.SingleSeed:
                            selectedSprite = potato_SingleSeed;
                            break;
                        case CropState.MultipleSeeds:
                            selectedSprite = potato_MultipleSeeds;
                            break;
                        case CropState.GrowingState1:
                            selectedSprite = potato_GrowingState_1;
                            break;
                        case CropState.GrowingState2:
                            selectedSprite = potato_GrowingState_2;
                            break;
                        case CropState.GrowingState3:
                            selectedSprite = potato_GrowingState_3;
                            break;
                        case CropState.Grown:
                            selectedSprite = potato_Grown;
                            break;
                    }
                    break;
                case Crop.Radish:
                    switch (cropStateSelection)
                    {
                        case CropState.SeedsPackIcon:
                            selectedSprite = radish_SeedsPackIcon;
                            break;
                        case CropState.SingleSeed:
                            selectedSprite = radish_SingleSeed;
                            break;
                        case CropState.MultipleSeeds:
                            selectedSprite = radish_MultipleSeeds;
                            break;
                        case CropState.GrowingState1:
                            selectedSprite = radish_GrowingState_1;
                            break;
                        case CropState.GrowingState2:
                            selectedSprite = radish_GrowingState_2;
                            break;
                        case CropState.GrowingState3:
                            selectedSprite = radish_GrowingState_3;
                            break;
                        case CropState.Grown:
                            selectedSprite = radish_Grown;
                            break;
                    }
                    break;
                case Crop.Garlic:
                    switch (cropStateSelection)
                    {
                        case CropState.SeedsPackIcon:
                            selectedSprite = garlic_SeedsPackIcon;
                            break;
                        case CropState.SingleSeed:
                            selectedSprite = garlic_SingleSeed;
                            break;
                        case CropState.MultipleSeeds:
                            selectedSprite = garlic_MultipleSeeds;
                            break;
                        case CropState.GrowingState1:
                            selectedSprite = garlic_GrowingState_1;
                            break;
                        case CropState.GrowingState2:
                            selectedSprite = garlic_GrowingState_2;
                            break;
                        case CropState.GrowingState3:
                            selectedSprite = garlic_GrowingState_3;
                            break;
                        case CropState.Grown:
                            selectedSprite = garlic_Grown;
                            break;
                    }
                    break;
                case Crop.Cauliflower:
                    switch (cropStateSelection)
                    {
                        case CropState.SeedsPackIcon:
                            selectedSprite = cauliflower_SeedsPackIcon;
                            break;
                        case CropState.SingleSeed:
                            selectedSprite = cauliflower_SingleSeed;
                            break;
                        case CropState.MultipleSeeds:
                            selectedSprite = cauliflower_MultipleSeeds;
                            break;
                        case CropState.GrowingState1:
                            selectedSprite = cauliflower_GrowingState_1;
                            break;
                        case CropState.GrowingState2:
                            selectedSprite = cauliflower_GrowingState_2;
                            break;
                        case CropState.GrowingState3:
                            selectedSprite = cauliflower_GrowingState_3;
                            break;
                        case CropState.Grown:
                            selectedSprite = cauliflower_Grown;
                            break;
                    }
                    break;
                case Crop.Pepper:
                    switch (cropStateSelection)
                    {
                        case CropState.SeedsPackIcon:
                            selectedSprite = pepper_SeedsPackIcon;
                            break;
                        case CropState.SingleSeed:
                            selectedSprite = pepper_SingleSeed;
                            break;
                        case CropState.MultipleSeeds:
                            selectedSprite = pepper_MultipleSeeds;
                            break;
                        case CropState.GrowingState1:
                            selectedSprite = pepper_GrowingState_1;
                            break;
                        case CropState.GrowingState2:
                            selectedSprite = pepper_GrowingState_2;
                            break;
                        case CropState.GrowingState3:
                            selectedSprite = pepper_GrowingState_3;
                            break;
                        case CropState.Grown:
                            selectedSprite = pepper_Grown;
                            break;
                    }
                    break;
            }
            GetComponent<SpriteRenderer>().sprite = selectedSprite;
        }

        private enum Crop
        {
            Pumpkin,
            Eggplant,
            Berry,
            Beet,
            Wheat,
            Tomato,
            Sunflower,
            Corn,
            Rice,
            Lettuce,
            Potato,
            Radish,
            Garlic,
            Cauliflower,
            Pepper
        }

        private enum CropState
        {
            SeedsPackIcon,
            SingleSeed,
            MultipleSeeds,
            GrowingState1,
            GrowingState2,
            GrowingState3,
            Grown
        }
    }
}