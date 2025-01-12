﻿#ifndef _CHARACTER_HAIR_CORE_INCLUDED
#define _CHARACTER_HAIR_CORE_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "CharacterOutline.hlsl"
#include "CharacterCommon.hlsl"
#include "CharacterUtils.hlsl"
#include "CharacterShadow.hlsl"
#include "CharacterDepthOnly.hlsl"

TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
TEXTURE2D(_LightMap); SAMPLER(sampler_LightMap);
TEXTURE2D(_RampMapCool); SAMPLER(sampler_RampMapCool);
TEXTURE2D(_RampMapWarm); SAMPLER(sampler_RampMapWarm);

CBUFFER_START(UnityPerMaterial)
    float _ModelScale;
    float _AlphaTestThreshold;

    float4 _Color;
    float4 _BackColor;
    float4 _Maps_ST;

    float _RampCoolWarmLerpFactor;

    float4 _SpecularColor0;
    float _SpecularShininess0;
    float _SpecularIntensity0;
    float _SpecularEdgeSoftness0;

    float4 _EmissionColor;
    float _EmissionThreshold;
    float _EmissionIntensity;

    float _BloomIntensity0;

    float _RimIntensity;
    float _RimIntensityBackFace;
    float _RimThresholdMin;
    float _RimThresholdMax;
    float _RimEdgeSoftness;
    float _RimWidth0;
    float4 _RimColor0;
    float _RimDark0;

    float _OutlineWidth;
    float _OutlineZOffset;
    float4 _OutlineColor0;

    float _HairBlendAlpha;

    float _DitherAlpha;
CBUFFER_END

CharacterVaryings HairVertex(CharacterAttributes i)
{
    return CharacterVertex(i, _Maps_ST);
}

float4 BaseHairOpaqueFragment(
    inout CharacterVaryings i,
    FRONT_FACE_TYPE isFrontFace)
{
    ValidateDualFaceVaryings(i.normalWS, i.uv, isFrontFace);

    // Textures
    float4 texColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv.xy);
    float4 lightMap = SAMPLE_TEXTURE2D(_LightMap, sampler_LightMap, i.uv.xy);
    texColor *= IS_FRONT_VFACE(isFrontFace, _Color, _BackColor);

    // Colors
    float3 baseColor = texColor.rgb;
    float alpha = texColor.a;

    DoAlphaClip(alpha, _AlphaTestThreshold);
    DitherAlphaEffect(i.positionHCS, _DitherAlpha);

    // Calc
    Light light = GetMainLight();

    float3 N = normalize(i.normalWS);
    float3 V = normalize(GetWorldSpaceViewDir(i.positionWS));
    float3 L = normalize(light.direction);

    float NoL = dot(N, L);
    float NoV = dot(N, V) * (NoL > 0); // 感觉 NoV 做头发高光更好看！有随视线流动的效果

    float3 diffuse = GetDiffuse(NoL, i.color, lightMap, true, baseColor, TEXTURE2D_ARGS(_RampMapCool, sampler_RampMapCool), TEXTURE2D_ARGS(_RampMapWarm, sampler_RampMapWarm), _RampCoolWarmLerpFactor);
    float3 specular = GetSpecular(NoV, lightMap, baseColor, _SpecularColor0.rgb, _SpecularShininess0, _SpecularEdgeSoftness0, _SpecularIntensity0, 0);
    float3 rimLight = GetRimLight(i.positionHCS, i.normalWS, lightMap, _ModelScale, _RimColor0.rgb, _RimWidth0, _RimEdgeSoftness, _RimThresholdMin, _RimThresholdMax, _RimDark0, _RimIntensity, _RimIntensityBackFace, isFrontFace);
    float3 emission = GetEmission(baseColor, alpha, _EmissionThreshold, _EmissionIntensity, _EmissionColor.rgb);

    // Output
    return float4((diffuse + specular) * light.color + rimLight + emission, alpha);
}

void HairOpaqueFragment(
    CharacterVaryings i,
    FRONT_FACE_TYPE isFrontFace : FRONT_FACE_SEMANTIC,
    out float4 colorTarget      : SV_Target0,
    out float4 bloomTarget      : SV_Target1)
{
    float4 hairColor = BaseHairOpaqueFragment(i, isFrontFace);

    colorTarget = float4(hairColor.rgb, 1);
    bloomTarget = float4(_BloomIntensity0, 0, 0, 0);
}

void HairFakeTransparentFragment(
    CharacterVaryings i,
    FRONT_FACE_TYPE isFrontFace : FRONT_FACE_SEMANTIC,
    out float4 colorTarget      : SV_Target0,
    out float4 bloomTarget      : SV_Target1)
{
    float4 hairColor = BaseHairOpaqueFragment(i, isFrontFace);

    float3 up = GetCharacterHeadBoneUpWS();
    float3 forward = GetCharacterHeadBoneForwardWS();
    float3 right = GetCharacterHeadBoneRightWS();
    float3 viewDirWS = GetWorldSpaceViewDir(i.positionWS);

    // Horizontal 70 度
    float3 viewDirXZ = normalize(viewDirWS - dot(viewDirWS, up) * up);
    float cosHorizontal = max(0, dot(viewDirXZ, forward));
    float alpha1 = saturate((1 - cosHorizontal) / 0.658); // 0.658: 1 - cos70°

    // Vertical 45 度
    float3 viewDirYZ = normalize(viewDirWS - dot(viewDirWS, right) * right);
    float cosVertical = max(0, dot(viewDirYZ, forward));
    float alpha2 = saturate((1 - cosVertical) / 0.293); // 0.293: 1 - cos45°

    // Output
    colorTarget = float4(hairColor.rgb, max(max(alpha1, alpha2), _HairBlendAlpha));
    bloomTarget = float4(_BloomIntensity0, 0, 0, 0);
}

CharacterOutlineVaryings HairOutlineVertex(CharacterOutlineAttributes i)
{
    return CharacterOutlineVertex(i, _Maps_ST, _ModelScale, _OutlineWidth, _OutlineZOffset);
}

float4 HairOutlineFragment(CharacterOutlineVaryings i) : SV_Target0
{
    float4 texColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv.xy) * _Color;

    DoAlphaClip(texColor.a, _AlphaTestThreshold);
    DitherAlphaEffect(i.positionHCS, _DitherAlpha);

    return float4(_OutlineColor0.rgb, 1);
}

CharacterShadowVaryings HairShadowVertex(CharacterShadowAttributes i)
{
    return CharacterShadowVertex(i, _Maps_ST);
}

void HairShadowFragment(
    CharacterShadowVaryings i,
    FRONT_FACE_TYPE isFrontFace : FRONT_FACE_SEMANTIC)
{
    ValidateDualFaceVaryings(i.normalWS, i.uv, isFrontFace);

    float4 texColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv.xy);
    texColor *= IS_FRONT_VFACE(isFrontFace, _Color, _BackColor);

    DoAlphaClip(texColor.a, _AlphaTestThreshold);
    DitherAlphaEffect(i.positionHCS, _DitherAlpha);
}

CharacterDepthOnlyVaryings HairDepthOnlyVertex(CharacterDepthOnlyAttributes i)
{
    return CharacterDepthOnlyVertex(i, _Maps_ST);
}

float4 HairDepthOnlyFragment(
    CharacterDepthOnlyVaryings i,
    FRONT_FACE_TYPE isFrontFace : FRONT_FACE_SEMANTIC) : SV_Target
{
    ValidateDualFaceVaryings(i.normalWS, i.uv, isFrontFace);

    float4 texColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv.xy);
    texColor *= IS_FRONT_VFACE(isFrontFace, _Color, _BackColor);

    DoAlphaClip(texColor.a, _AlphaTestThreshold);
    DitherAlphaEffect(i.positionHCS, _DitherAlpha);

    return CharacterDepthOnlyFragment(i);
}

#endif
