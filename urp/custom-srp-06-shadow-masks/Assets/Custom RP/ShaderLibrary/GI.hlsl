#ifndef CUSTOM_GI_INCLUDED
#define CUSTOM_GI_INCLUDED

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/EntityLighting.hlsl"

// lightmap
TEXTURE2D(unity_Lightmap);
SAMPLER(samplerunity_Lightmap);

// lppv
TEXTURE3D_FLOAT(unity_ProbeVolumeSH);
SAMPLER(samplerunity_ProbeVolumeSH);

// 新增shadowmask
TEXTURE2D(unity_ShadowMask);
SAMPLER(samplerunity_ShadowMask);

#if defined(LIGHTMAP_ON)
    #define GI_ATTRIBUTE_DATA float2 lightMapUV : TEXCOORD1;
    #define GI_VARYINGS_DATA float2 lightMapUV : VAR_LIGHT_MAP_UV;
    #define TRANSFER_GI_DATA(input, output) \
        output.lightMapUV = input.lightMapUV * \
        unity_LightmapST.xy + unity_LightmapST.zw;
    #define GI_FRAGMENT_DATA(input) input.lightMapUV
#else
    #define GI_ATTRIBUTE_DATA
    #define GI_VARYINGS_DATA
    #define TRANSFER_GI_DATA(input, output)
    #define GI_FRAGMENT_DATA(input) 0.0
#endif

struct GI {
    float3 diffuse; // 漫反射

    // 新增
    ShadowMask shadowMask;  // 阴影
};

float3 SampleLightMap (float2 lightMapUV) {
    #if defined(LIGHTMAP_ON)
        return SampleSingleLightmap(
            TEXTURE2D_ARGS(unity_Lightmap, samplerunity_Lightmap), lightMapUV,
            float4(1.0, 1.0, 0.0, 0.0),
            #if defined(UNITY_LIGHTMAP_FULL_HDR)
                false,
            #else
                true,
            #endif
            float4(LIGHTMAP_HDR_MULTIPLIER, LIGHTMAP_HDR_EXPONENT, 0.0, 0.0)
    );
    #else
        return 0.0;
    #endif
}

float3 SampleLightProbe (Surface surfaceWS) {
    #if defined(LIGHTMAP_ON)
        return 0.0;
    #else
        if (unity_ProbeVolumeParams.x) {
            return SampleProbeVolumeSH4(
                TEXTURE3D_ARGS(unity_ProbeVolumeSH, samplerunity_ProbeVolumeSH),
                surfaceWS.position, surfaceWS.normal,
                unity_ProbeVolumeWorldToObject,
                unity_ProbeVolumeParams.y, unity_ProbeVolumeParams.z,
                unity_ProbeVolumeMin.xyz, unity_ProbeVolumeSizeInv.xyz
            );
        }
        else {
            float4 coefficients[7];
            coefficients[0] = unity_SHAr;
            coefficients[1] = unity_SHAg;
            coefficients[2] = unity_SHAb;
            coefficients[3] = unity_SHBr;
            coefficients[4] = unity_SHBg;
            coefficients[5] = unity_SHBb;
            coefficients[6] = unity_SHC;
            return max(0.0, SampleSH9(coefficients, surfaceWS.normal));
        }
    #endif
}

// 动态物体的shadowmask遮挡信息
float4 SampleLightProbeOcclusion (Surface surfaceWS) {
    return unity_ProbesOcclusion;
}

// 进入这个函数，说明现在是在shadowmask模式下，此时要么从shadowmask中采样 给静态物体，
// 要么从lppv或者occlusionprobo中采样 给动态物体
float4 SampleBakedShadows (float2 lightMapUV, Surface surfaceWS) {
    #if defined(LIGHTMAP_ON)
        // 静态物体
        return SAMPLE_TEXTURE2D(
            unity_ShadowMask, samplerunity_ShadowMask, lightMapUV
        );
    #else
        // 动态物体，比如scene中的球体
        // for LPPV
        if (unity_ProbeVolumeParams.x) {
            return SampleProbeOcclusion(
                TEXTURE3D_ARGS(unity_ProbeVolumeSH, samplerunity_ProbeVolumeSH),
                surfaceWS.position, unity_ProbeVolumeWorldToObject,
                unity_ProbeVolumeParams.y, unity_ProbeVolumeParams.z,
                unity_ProbeVolumeMin.xyz, unity_ProbeVolumeSizeInv.xyz
            );
        }
        else {
            // 动态球受到的静态物体的shadow影响
            return unity_ProbesOcclusion;
        }
    #endif
}

GI GetGI (float2 lightMapUV, Surface surfaceWS) {
    GI gi;
    // lightmap
    gi.diffuse = SampleLightMap(lightMapUV) + SampleLightProbe(surfaceWS);

    // shadowmask
    gi.shadowMask.always = false;
    gi.shadowMask.distance = false;
    gi.shadowMask.shadows = 1.0;

    // 有这两个marco表示存在shadowmask
    #if defined(_SHADOW_MASK_ALWAYS)
        gi.shadowMask.always = true;
        gi.shadowMask.shadows = SampleBakedShadows(lightMapUV, surfaceWS);
    #elif defined(_SHADOW_MASK_DISTANCE)
        gi.shadowMask.distance = true;
        gi.shadowMask.shadows = SampleBakedShadows(lightMapUV, surfaceWS);
    #endif
    return gi;
}

#endif