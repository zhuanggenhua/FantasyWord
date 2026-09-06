// URP 2D mobile pixel-art water compositor.
// The animated Tilemap sprite remains the base; a matching authored mask limits reflections to water pixels.
Shader "FantasyWord/Water Reflection Tilemap"
{
    Properties
    {
        [PerRendererData] _MainTex ("Animated Water Sprite", 2D) = "white" {}
        _Color ("Tint", Color) = (1,1,1,1)
        [NoScaleOffset] _WaterMaskTex ("Water Pixel Mask", 2D) = "black" {}
        [HideInInspector][NoScaleOffset] _WaterReflectionTexture ("Shared Reflection Texture", 2D) = "black" {}
        _ReflectionColor ("Reflection Tint", Color) = (0.72,0.86,0.9,1)
        _ReflectionStrength ("Reflection Strength", Range(0,1)) = 0.55
        _DistortionPixels ("Horizontal Distortion Pixels", Range(0,3)) = 1
        _DistortionSpeed ("Distortion Speed", Range(0,8)) = 2
        _EdgeFadePixels ("Edge Fade Pixels", Range(0,2)) = 1
    }

    SubShader
    {
        Tags
        {
            "Queue" = "Transparent"
            "RenderType" = "Transparent"
            "RenderPipeline" = "UniversalPipeline"
        }

        Cull Off
        ZWrite Off
        Blend SrcAlpha OneMinusSrcAlpha

        Pass
        {
            Tags { "LightMode" = "Universal2D" }

            HLSLPROGRAM
            #pragma target 2.0
            #pragma vertex Vert
            #pragma fragment Frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            TEXTURE2D(_WaterMaskTex);
            SAMPLER(sampler_WaterMaskTex);
            TEXTURE2D(_WaterReflectionTexture);
            SAMPLER(sampler_WaterReflectionTexture);

            float4 _WaterMaskTex_TexelSize;
            float4 _WaterReflectionTexture_TexelSize;
            float4x4 _WaterReflectionViewProjection;

            CBUFFER_START(UnityPerMaterial)
                half4 _Color;
                half4 _ReflectionColor;
                half _ReflectionStrength;
                half _DistortionPixels;
                half _DistortionSpeed;
                half _EdgeFadePixels;
            CBUFFER_END

            struct Attributes
            {
                float3 positionOS : POSITION;
                half4 color : COLOR;
                half2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                half4 color : COLOR;
                half2 uv : TEXCOORD0;
                float3 worldPosition : TEXCOORD1;
            };

            Varyings Vert(Attributes input)
            {
                Varyings output;
                float3 worldPosition = TransformObjectToWorld(input.positionOS);
                output.positionCS = TransformWorldToHClip(worldPosition);
                output.worldPosition = worldPosition;
                output.color = input.color * _Color;
                output.uv = input.uv;
                return output;
            }

            half SampleWaterMask(half2 uv)
            {
                return SAMPLE_TEXTURE2D(_WaterMaskTex, sampler_WaterMaskTex, uv).r;
            }

            half4 Frag(Varyings input) : SV_Target
            {
                half4 baseColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv) * input.color;
                half mask = SampleWaterMask(input.uv);

                if (_EdgeFadePixels > 0.001h)
                {
                    half2 maskStep = (half2)_WaterMaskTex_TexelSize.xy * _EdgeFadePixels;
                    half neighborMask = min(
                        min(SampleWaterMask(input.uv + half2(maskStep.x, 0)),
                            SampleWaterMask(input.uv - half2(maskStep.x, 0))),
                        min(SampleWaterMask(input.uv + half2(0, maskStep.y)),
                            SampleWaterMask(input.uv - half2(0, maskStep.y))));
                    mask *= neighborMask;
                }

                // The offset is quantized to whole reflection-RT pixels to avoid sub-pixel shimmer.
                float wave = sin((input.worldPosition.y * 7.0 + _Time.y * _DistortionSpeed) * 1.5707963);
                float pixelOffset = floor(wave + 0.5) * _DistortionPixels;
                float4 reflectionPositionCS = mul(
                    _WaterReflectionViewProjection,
                    float4(input.worldPosition, 1.0));
                float2 reflectionUV = reflectionPositionCS.xy / reflectionPositionCS.w;
                reflectionUV = reflectionUV * 0.5 + 0.5;
#if UNITY_UV_STARTS_AT_TOP
                reflectionUV.y = 1.0 - reflectionUV.y;
#endif
                reflectionUV.x += pixelOffset * _WaterReflectionTexture_TexelSize.x;

                half4 reflection = SAMPLE_TEXTURE2D(
                    _WaterReflectionTexture,
                    sampler_WaterReflectionTexture,
                    reflectionUV);
                half blend = saturate(reflection.a * mask * _ReflectionStrength * _ReflectionColor.a);
                baseColor.rgb = lerp(baseColor.rgb, reflection.rgb * _ReflectionColor.rgb, blend);
                return baseColor;
            }
            ENDHLSL
        }
    }
}
