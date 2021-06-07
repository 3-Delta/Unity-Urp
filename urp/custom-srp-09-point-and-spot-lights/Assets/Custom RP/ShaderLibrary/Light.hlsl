#ifndef CUSTOM_LIGHT_INCLUDED
#define CUSTOM_LIGHT_INCLUDED

#define MAX_DIRECTIONAL_LIGHT_COUNT 4
#define MAX_OTHER_LIGHT_COUNT 64

CBUFFER_START(_CustomLight)
	// 平行光
	int _DirectionalLightCount;
	float4 _DirectionalLightColors[MAX_DIRECTIONAL_LIGHT_COUNT];
	float4 _DirectionalLightDirections[MAX_DIRECTIONAL_LIGHT_COUNT];
	float4 _DirectionalLightShadowData[MAX_DIRECTIONAL_LIGHT_COUNT];

	// 其他光源
	int _OtherLightCount;
	float4 _OtherLightColors[MAX_OTHER_LIGHT_COUNT];
	float4 _OtherLightPositions[MAX_OTHER_LIGHT_COUNT];
	float4 _OtherLightDirections[MAX_OTHER_LIGHT_COUNT];
	float4 _OtherLightSpotAngles[MAX_OTHER_LIGHT_COUNT];
	float4 _OtherLightShadowData[MAX_OTHER_LIGHT_COUNT];
CBUFFER_END

struct Light {
	float3 color;
	float3 direction;

	float attenuation; // 处理 阴影/其他光源衰减
};

int GetDirectionalLightCount () {
	return _DirectionalLightCount;
}

DirectionalShadowData GetDirectionalShadowData (int lightIndex, ShadowData shadowData) {
	DirectionalShadowData data;
	data.strength = _DirectionalLightShadowData[lightIndex].x;
	data.tileIndex = _DirectionalLightShadowData[lightIndex].y + shadowData.cascadeIndex;
	data.normalBias = _DirectionalLightShadowData[lightIndex].z;
	data.shadowMaskChannel = _DirectionalLightShadowData[lightIndex].w;
	return data;
}

Light GetDirectionalLight (int index, Surface surfaceWS, ShadowData shadowData) {
	Light light;
	light.color = _DirectionalLightColors[index].rgb;
	light.direction = _DirectionalLightDirections[index].xyz;

	DirectionalShadowData dirShadowData = GetDirectionalShadowData(index, shadowData);

	// 将shadow的attenuation	和 点光源/聚光灯的attenuation 组合起来, 因为平行光没有衰减，所以只有shadow的衰减
	// 方便统一管理
	float shadowAttenuation = GetDirectionalShadowAttenuation(dirShadowData, shadowData, surfaceWS);
	light.attenuation = shadowAttenuation;
	return light;
}

int GetOtherLightCount () {
	return _OtherLightCount;
}

OtherShadowData GetOtherShadowData (int lightIndex) {
	OtherShadowData data;
	// _OtherLightShadowData: new Vector4(light.shadowStrength, 0f, 0f, lightBaking.occlusionMaskChannel)
	data.strength = _OtherLightShadowData[lightIndex].x;
	data.shadowMaskChannel = _OtherLightShadowData[lightIndex].w;
	return data;
}

Light GetOtherLight (int index, Surface surfaceWS, ShadowData shadowData) {
	Light light;
	light.color = _OtherLightColors[index].rgb;

	// surf到光源的距离
	float3 ray = _OtherLightPositions[index].xyz - surfaceWS.position;
	light.direction = normalize(ray);

	// 平方的反比衰减
	float distanceSqr = max(dot(ray, ray), 0.00001);
	// _OtherLightPositions[index].w是: 1/光源边界距离的平方
	// 衰减公式 https://edu.uwa4d.com/lesson-detail/282/1349/0?isPreview=0
	float rateSquare = Square(distanceSqr * _OtherLightPositions[index].w);
	float rangeAttenuation = Square(saturate(1.0 - rateSquare));

	float4 spotAngles = _OtherLightSpotAngles[index];
	float dDotd = dot(_OtherLightDirections[index].xyz, light.direction);
	float spotAttenuation = Square(saturate(dDotd * spotAngles.x + spotAngles.y));

	OtherShadowData otherShadowData = GetOtherShadowData(index);
	float shadowAttenuation = GetOtherShadowAttenuation(otherShadowData, shadowData, surfaceWS);
	// 将shadow的attenuation	和 点光源/聚光灯的attenuation 组合起来
	// 方便统一管理
	light.attenuation = shadowAttenuation * spotAttenuation * rangeAttenuation / distanceSqr;
	return light;
}

#endif
