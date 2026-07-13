// URP 2D mobile pixel-art reflection proxy. Position math uses float; color/UV use half.
Shader "FantasyWord/Water Reflection Proxy 2D"
{
    Properties
    {
        [PerRendererData] _MainTex ("Sprite Texture", 2D) = "white" {}
        _Color ("Tint", Color) = (1,1,1,1)
        [HideInInspector] _WaterReflectionProxy ("Water Reflection Proxy", Float) = 1
        [HideInInspector] _WaterReflectionAnchorWS ("Water Reflection Anchor WS", Vector) = (0,0,0,0)
        [HideInInspector] _WaterReflectionVerticalScale ("Water Reflection Vertical Scale", Float) = 0.65
        [HideInInspector] _WaterReflectionSkew ("Water Reflection Skew", Float) = -0.35
        [HideInInspector] _WaterReflectionLengthScale ("Water Reflection Length Scale", Float) = 1
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

            CBUFFER_START(UnityPerMaterial)
                half4 _Color;
                float _WaterReflectionProxy;
                float4 _WaterReflectionAnchorWS;
                float _WaterReflectionVerticalScale;
                float _WaterReflectionSkew;
                float _WaterReflectionLengthScale;
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
            };

            Varyings Vert(Attributes input)
            {
                Varyings output;
                float3 worldPosition = TransformObjectToWorld(input.positionOS);
                float2 delta = worldPosition.xy - _WaterReflectionAnchorWS.xy;
                float reflectedY = -delta.y * _WaterReflectionVerticalScale * _WaterReflectionLengthScale;
                worldPosition.x = _WaterReflectionAnchorWS.x + delta.x + reflectedY * _WaterReflectionSkew;
                worldPosition.y = _WaterReflectionAnchorWS.y + reflectedY;

                output.positionCS = TransformWorldToHClip(worldPosition);
                output.color = input.color * _Color;
                output.uv = input.uv;
                return output;
            }

            half4 Frag(Varyings input) : SV_Target
            {
                return SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv) * input.color;
            }
            ENDHLSL
        }
    }
}
