#ifndef CUSTOM_SHADOWS_INCLUDED
#define CUSTOM_SHADOWS_INCLUDED

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Shadow/ShadowSamplingTent.hlsl"

#if defined(_DIRECTIONAL_PCF3)
	#define DIRECTIONAL_FILTER_SAMPLES 4
	#define DIRECTIONAL_FILTER_SETUP SampleShadow_ComputeSamples_Tent_3x3
#elif defined(_DIRECTIONAL_PCF5)
	#define DIRECTIONAL_FILTER_SAMPLES 9
	#define DIRECTIONAL_FILTER_SETUP SampleShadow_ComputeSamples_Tent_5x5
#elif defined(_DIRECTIONAL_PCF7)
	#define DIRECTIONAL_FILTER_SAMPLES 16
	#define DIRECTIONAL_FILTER_SETUP SampleShadow_ComputeSamples_Tent_7x7
#endif

#define MAX_SHADOWED_DIRECTIONAL_LIGHT_COUNT 4
#define MAX_CASCADE_COUNT 4

/* 一般是：
	TEXTURE2D(_DirectionalShadowAtlas);
	SAMPLER(sampler_DirectionalShadowAtlas);
*/
// shadowmap的定义 以及 采样器 需要特殊处理
TEXTURE2D_SHADOW(_DirectionalShadowAtlas);
#define SHADOW_SAMPLER sampler_linear_clamp_compare
SAMPLER_CMP(SHADOW_SAMPLER);

// unity的cs传递过来
CBUFFER_START(_CustomShadows)
	// 级联数
	int _CascadeCount;
	float4 _CascadeCullingSpheres[MAX_CASCADE_COUNT]; // cullingSphere半径的平方
	float4 _CascadeData[MAX_CASCADE_COUNT];

	// world->shadow的矩阵
	float4x4 _DirectionalShadowMatrices[MAX_SHADOWED_DIRECTIONAL_LIGHT_COUNT * MAX_CASCADE_COUNT];
	float4 _ShadowAtlasSize; // new Vector4(atlasSize, 1f / atlasSize)
	float4 _ShadowDistanceFade;
CBUFFER_END

// shadowData是针对于相机来说的， 具体的说，应该是shadowcascade
struct ShadowData {
	int cascadeIndex;
	float cascadeBlend;
	float strength;	// shadowStrength
};

// 处理fade渐变，也就是cascade突变，或者超过最大distance的时候
float FadedShadowStrength (float distance, float scale, float fade) {
    // (1 - deafDepth/maxDistance) / fade
	return saturate((1.0 - distance * scale) * fade);
}

// 最简单的情况
ShadowData GetShadowData_ (Surface surfaceWS) {
    ShadowData data;
    int i = 0;
	// 判断当前frag在cullSphere的哪一级别的级联中
	for (i = 0; i < _CascadeCount; i++) {
		float4 sphere = _CascadeCullingSpheres[i];
		// 计算顶点和球体的中心的距离
		float distanceSqr = DistanceSquared(surfaceWS.position, sphere.xyz);
		if (distanceSqr < sphere.w) {
			break;
		}
	}

	// 最后一级的cullphere中包含但是 超过maxShadowDistance 的frag
	// 此时strength 不能直接 == 0，需要fade, 否则很突兀
	// data.strength = surfaceWS.depth < _ShadowDistance ? 1.0 : 0.0;

	// 如果直接frag超过了最后一级的cullSphere的范围，说明肯定超过了maxSHadowDistance，所以strength == 0即可。
}

// lighting中获取shadowmap应该使用哪个级联
ShadowData GetShadowData (Surface surfaceWS) {
	ShadowData data;
	data.cascadeBlend = 1.0;

	// maxdistance的渐变是正常的长度渐变
	// _ShadowDistanceFade.x == 1 / maxShadowDistance
	// _ShadowDistanceFade.y == 1 / distanceFade
	data.strength = FadedShadowStrength(surfaceWS.depth, _ShadowDistanceFade.x, _ShadowDistanceFade.y);
	int i;
	// 判断当前frag在cullSphere的哪一级别的级联中
	for (i = 0; i < _CascadeCount; i++) {
		float4 sphere = _CascadeCullingSpheres[i];
		// 计算顶点和球体的中心的距离
		float distanceSqr = DistanceSquared(surfaceWS.position, sphere.xyz);
		if (distanceSqr < sphere.w) {
		    // 在球体内
		    // 级联渐变是 平方的渐变
			float fade = FadedShadowStrength(distanceSqr, _CascadeData[i].x, _ShadowDistanceFade.z);
			// 在 最后一个cullSphere中
			if (i == _CascadeCount - 1) {
				data.strength *= fade;
			}
			else {
				data.cascadeBlend = fade;
			}
			break;
		}
		
		data.cascadeIndex = i;
	    return data;
	}
	
	if (i == _CascadeCount) {
	    // 不在任何cullSphere裁减区域之内
		// 必定在maxShadowDistance之外的视锥区域里面
		data.strength = 0.0;
	}
	#if defined(_CASCADE_BLEND_DITHER)
		else if (data.cascadeBlend < surfaceWS.dither) {
			i += 1;
		}
	#endif
	#if !defined(_CASCADE_BLEND_SOFT)
		data.cascadeBlend = 1.0;
	#endif
	
	// 通过cameraview的裁减球cullSphere,得到每个frag的使用的shadowmap的级联
	data.cascadeIndex = i;
	return data;
}

// DirectionalShadowData是针对每个DirLight来说的， 也就是将来如果有其他的SpotLight之类的，应该也会有类似的结构
struct DirectionalShadowData {
	float strength;	 // shadowStrength
	int tileIndex;
	float normalBias;
};

// positionSTS是shadowspace的位置
// 获取positionSTS对应的vertex是否被遮挡
// positionSTS其实就是shadowspace的Cube立体区域中的某个位置
float SampleDirectionalShadowAtlas (float3 positionSTS) {
	// https://blog.csdn.net/weixin_43675955/article/details/85226485
	// SAMPLE_TEXTURE2D_SHADOW 因为shadowmap没有mipmap,所以采样的就是0级，而且其实是使用xy坐标的shadowmap的depth和z比较大小
	// 返回值要么0， 要么1，也就是要么被遮挡，要么不被遮挡
	// 其实bool可以表达
	return SAMPLE_TEXTURE2D_SHADOW(_DirectionalShadowAtlas, SHADOW_SAMPLER, positionSTS);
}

// 利用pcf机制对于positionSTS周边的filterSize*filterSize的矩形进行遮挡情况的计算
// 获取filtersize区域内，每个vertex的positionSTS对应的vertex是否被遮挡
// 目的是为了阴影锯齿 或者 软阴影
float FilterDirectionalShadow (float3 positionSTS) {
	#if defined(DIRECTIONAL_FILTER_SETUP)
	    // 如果是pcf机制
		float weights[DIRECTIONAL_FILTER_SAMPLES];
		float2 positions[DIRECTIONAL_FILTER_SAMPLES];
		float4 size = _ShadowAtlasSize.yyxx;
		DIRECTIONAL_FILTER_SETUP(size, positionSTS.xy, weights, positions);
		float shadow = 0;
		// 片段完全被阴影覆盖，那么我们将得到零，而如果根本没有阴影，那么我们将得到一。之间的值表示片段被部分遮挡。
		// 也就是概率
		for (int i = 0; i < DIRECTIONAL_FILTER_SAMPLES; i++) {
			shadow += weights[i] * SampleDirectionalShadowAtlas(float3(positions[i].xy, positionSTS.z));
		}
		return shadow;
	#else
	    // 无pcf机制
		return SampleDirectionalShadowAtlas(positionSTS);
	#endif
}

// 最简单的情况
// 返回positionSTS对应的vertex是否被遮挡
float GetDirectionalShadowAttenuation_ (DirectionalShadowData directional, Surface surfaceWS) {
    float3 positionSTS = mul(_DirectionalShadowMatrices[directional.tileIndex], float4(surfaceWS.position /*+ normalBias*/, 1.0)).xyz;
	float shadow = FilterDirectionalShadow(positionSTS);
	return shadow;
}

// 某个顶点是否被遮挡， 也有可能为了软阴影做的部分遮挡的效果
// 渲染这个顶点的时候，如果法线被遮挡，则直接显示阴影的颜色，否则就是正常的brdf的计算颜色
// 有阴影，frag为1，无阴影，frag为0，部分阴影就是（0， 1），也就是lerp(1.0, shadow, directional.strength)
float GetDirectionalShadowAttenuation (DirectionalShadowData directional, ShadowData global, Surface surfaceWS) {
	#if !defined(_RECEIVE_SHADOWS)
		return 1.0;
	#endif
	if (directional.strength <= 0.0) {
		return 1.0;
	}
	// 每个级联应该使用的不是相同的pcfFilterSize
	float filterSize = _CascadeData[global.cascadeIndex].y;
	// normalBias的用法：* surfaceWS.normal，然后 + surfaceWS.position
	// normalBias原来是修改vertex的位置，朝着normal方向偏移，因为是 surfaceWS.position + normalBias，相当于让vertex靠近光源
	// 也就意味着zaishadowspace中，depth越小，越不被遮挡
	float3 normalBias = surfaceWS.normal * (directional.normalBias * filterSize);
	float3 positionSTS = mul(_DirectionalShadowMatrices[directional.tileIndex], float4(surfaceWS.position + normalBias, 1.0)).xyz;
	// shadow不是depth， 其实是个bool的是否被遮挡的flag
	float shadow = FilterDirectionalShadow(positionSTS);
	
	// 如果需要级联的混合过度
	if (global.cascadeBlend < 1.0) {
		normalBias = surfaceWS.normal * (directional.normalBias * filterSize);
		// worldspace -> shadowspace
		// 获取shadowmap中next的tile的position，得到depth
		positionSTS = mul(_DirectionalShadowMatrices[directional.tileIndex + 1], float4(surfaceWS.position + normalBias, 1.0)).xyz;

		// 然后对于相邻两个tile的depth 进行lerp
		float nextTileShadow = FilterDirectionalShadow(positionSTS);
		float preTileShadow = shadow;
		shadow = lerp(nextTileShadow, preTileShadow, global.cascadeBlend);
	}

	// strength作为factor控制遮挡因子在最大1， 最小shadow之间变化
	return lerp(1.0, shadow, directional.strength);
}

#endif
