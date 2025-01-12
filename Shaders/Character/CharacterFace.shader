Shader "Honkai Star Rail/Character/Face"
{
    Properties
    {
        [KeywordEnum(Game, MMD)] _Model("Model Type", Float) = 0
        _ModelScale("Model Scale", Float) = 1

        [HeaderFoldout(Shader Options)]
        [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlendAlpha("Src Blend (A)", Float) = 0   // 默认 Zero
        [Enum(UnityEngine.Rendering.BlendMode)] _DstBlendAlpha("Dst Blend (A)", Float) = 0   // 默认 Zero
        [Space(5)]
        [Toggle] _AlphaTest("Alpha Test", Float) = 0
        [If(_ALPHATEST_ON)] [Indent] _AlphaTestThreshold("Threshold", Range(0, 1)) = 0.5

        [HeaderFoldout(Maps)]
        [SingleLineTextureNoScaleOffset(_Color)] _MainTex("Albedo", 2D) = "white" {}
        [HideInInspector] _Color("Color", Color) = (1, 1, 1, 1)
        [SingleLineTextureNoScaleOffset] _FaceMap("Face Map", 2D) = "white" {}
        [SingleLineTextureNoScaleOffset] _ExpressionMap("Expression Map", 2D) = "white" {}
        [TextureScaleOffset] _Maps_ST("Maps Scale Offset", Vector) = (1, 1, 0, 0)
        [Header(Overrides)] [Space(5)]
        [If(_MODEL_GAME)] [Toggle] _FaceMapUV2("Face Map Use UV2", Float) = 0

        [HeaderFoldout(Diffuse)]
        _ShadowColor("Shadow Color", Color) = (0.5, 0.5, 0.5, 1)

        [HeaderFoldout(Emission, Use Albedo.a as emission map)]
        _EmissionColor("Color", Color) = (1, 1, 1, 1)
        _EmissionThreshold("Threshold", Range(0, 1)) = 0.1
        _EmissionIntensity("Intensity", Float) = 0.3

        [HeaderFoldout(Bloom)]
        _BloomIntensity0("Intensity", Range(0, 2)) = 0.5

        [HeaderFoldout(Outline)]
        [KeywordEnum(Tangent, Normal)] _OutlineNormal("Normal Source", Float) = 0
        _OutlineWidth("Width", Range(0, 4)) = 1
        _OutlineZOffset("Z Offset", Float) = 0
        _OutlineColor0("Color", Color) = (0, 0, 0, 1)

        [HeaderFoldout(Nose Line)]
        _NoseLineColor("Color", Color) = (1, 1, 1, 1)
        _NoseLinePower("Power", Range(0, 8)) = 1

        [HeaderFoldout(Eye Hair Blend)]
        _MaxEyeHairDistance("Max Eye Hair Distance", Float) = 0.1

        [HeaderFoldout(Dither)]
        _DitherAlpha("Alpha", Range(0, 1)) = 1
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Opaque"
            "UniversalMaterialType" = "Lit"
            "Queue" = "Geometry" // 最先渲染
        }

        Pass
        {
            Name "FaceOpaque+Z"

            Tags
            {
                "LightMode" = "HSRForward1"
            }

            // 脸的 Stencil
            Stencil
            {
                Ref 2
                WriteMask 2
                Comp Always
                Pass Replace
                Fail Keep
            }

            Cull Back
            ZWrite On

            Blend 0 One Zero, [_SrcBlendAlpha] [_DstBlendAlpha]
            Blend 1 One Zero

            ColorMask RGBA 0
            ColorMask R 1

            HLSLPROGRAM

            #pragma vertex FaceVertex
            #pragma fragment FaceOpaqueAndZFragment

            #pragma shader_feature_local _MODEL_GAME _MODEL_MMD
            #pragma shader_feature_local_fragment _ _ALPHATEST_ON
            #pragma shader_feature_local_fragment _ _FACEMAPUV2_ON

            #include "CharacterFaceCore.hlsl"

            ENDHLSL
        }

        Pass
        {
            Name "WriteEyeStencil"

            Tags
            {
                "LightMode" = "HSRForward2"
            }

            // 眼睛的 Stencil，需要在其他部分渲染之前写入
            Stencil
            {
                Ref 1
                WriteMask 1
                Comp Always
                Pass Replace
                Fail Keep
                ZFail Keep
            }

            Cull Back
            ZWrite Off
            ZTest LEqual // 眼白是在脸后面的，并且比眼睛要大，需要 ZTest 来剔除，然后再写 Stencil，这样才能准确抠出眼睛

            ColorMask 0 0
            ColorMask 0 1

            HLSLPROGRAM

            #pragma vertex FaceVertex
            #pragma fragment FaceWriteEyeStencilFragment

            #pragma shader_feature_local _MODEL_GAME _MODEL_MMD
            #pragma shader_feature_local_fragment _ _ALPHATEST_ON

            #include "CharacterFaceCore.hlsl"

            ENDHLSL
        }

        Pass
        {
            Name "FaceOutline"

            Tags
            {
                "LightMode" = "HSROutline"
            }

            Cull Front
            ZTest LEqual
            ZWrite On

            Blend 0 One Zero, [_SrcBlendAlpha] [_DstBlendAlpha]
            Blend 1 Zero Zero

            ColorMask RGBA 0
            ColorMask 0 1

            HLSLPROGRAM

            #pragma vertex FaceOutlineVertex
            #pragma fragment FaceOutlineFragment

            #pragma shader_feature_local _MODEL_GAME _MODEL_MMD
            #pragma shader_feature_local_fragment _ _ALPHATEST_ON

            #pragma shader_feature_local_vertex _OUTLINENORMAL_TANGENT _OUTLINENORMAL_NORMAL

            #include "CharacterFaceCore.hlsl"

            ENDHLSL
        }

        Pass
        {
            Name "FaceShadow"

            Tags
            {
                "LightMode" = "ShadowCaster"
            }

            Cull Back
            ZWrite On
            ZTest LEqual

            ColorMask 0 0
            ColorMask 0 1

            HLSLPROGRAM

            #pragma target 2.0

            #pragma vertex FaceShadowVertex
            #pragma fragment FaceShadowFragment

            #pragma shader_feature_local _MODEL_GAME _MODEL_MMD
            #pragma shader_feature_local_fragment _ _ALPHATEST_ON

            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            #include "CharacterFaceCore.hlsl"

            ENDHLSL
        }

        Pass
        {
            Name "FaceDepthOnly"

            Tags
            {
                "LightMode" = "DepthOnly"
            }

            Cull Back
            ZWrite On
            ColorMask 0

            HLSLPROGRAM

            #pragma vertex FaceDepthOnlyVertex
            #pragma fragment FaceDepthOnlyFragment

            #pragma shader_feature_local _MODEL_GAME _MODEL_MMD
            #pragma shader_feature_local_fragment _ _ALPHATEST_ON

            #include "CharacterFaceCore.hlsl"

            ENDHLSL
        }
    }

    CustomEditor "StaloSRPShaderGUI"
    Fallback Off
}
