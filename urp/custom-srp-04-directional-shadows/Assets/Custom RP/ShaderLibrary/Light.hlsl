#ifndef CUSTOM_LIGHT_INCLUDED
#define CUSTOM_LIGHT_INCLUDED

#define MAX_DIRECTIONAL_LIGHT_COUNT 4

CBUFFER_START(_CustomLight)
	int _DirectionalLightCount;
	float4 _DirectionalLightColors[MAX_DIRECTIONAL_LIGHT_COUNT];
	float4 _DirectionalLightDirections[MAX_DIRECTIONAL_LIGHT_COUNT];

	// 新增光源阴影数据
	float4 _DirectionalLightShadowData[MAX_DIRECTIONAL_LIGHT_COUNT];
CBUFFER_END

struct Light {
	float3 color;	  // 光源颜色
	float3 direction;		// 光源方向，原理光源

	// 新增
	float attenuation;		// 光源衰减,其实是处理阴影，也就是frag的收到阴影的影响
};

int GetDirectionalLightCount () {
	return _DirectionalLightCount;
}

// 获取光源相关的阴影数据
DirectionalShadowData GetDirectionalShadowData (int lightIndex, ShadowData shadowData) {
	DirectionalShadowData data;
	data.strength = _DirectionalLightShadowData[lightIndex].x * shadowData.strength;
	// 通过cameraview的cullSphere计算得到的cascadeIndex,主要是为了这里从atlas中查找到底使用哪一个tile
	// 以及使用哪一个vp矩阵
	data.tileIndex = _DirectionalLightShadowData[lightIndex].y + shadowData.cascadeIndex;
	data.normalBias = _DirectionalLightShadowData[lightIndex].z;
	return data;
}

Light GetDirectionalLight (int index, Surface surfaceWS, ShadowData shadowData) {
	Light light;
	light.color = _DirectionalLightColors[index].rgb;
	light.direction = _DirectionalLightDirections[index].xyz;
	
	// 计算阴影
	DirectionalShadowData dirShadowData = GetDirectionalShadowData(index, shadowData);
	// frag的受到阴影的影响
	// 其实就是这个frag是否在阴影中，也就是是否被其他obj遮挡
	light.attenuation = GetDirectionalShadowAttenuation(dirShadowData, shadowData, surfaceWS);
	return light;
}

#endif
