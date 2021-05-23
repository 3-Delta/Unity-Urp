#ifndef CUSTOM_LIGHTING_INCLUDED
#define CUSTOM_LIGHTING_INCLUDED

float3 IncomingLight (Surface surface, Light light) {
	return
		saturate(dot(surface.normal, light.direction) * light.attenuation) *
		light.color;
}

float3 GetLighting (Surface surface, BRDF brdf, Light light) {
	return IncomingLight(surface, light) * DirectBRDF(surface, brdf, light);
}

float3 GetLighting (Surface surfaceWS, BRDF brdf, GI gi) {
	ShadowData shadowData = GetShadowData(surfaceWS);
	shadowData.shadowMask = gi.shadowMask;

	// 平行光的间接光，直接光
	float3 color = IndirectBRDF(surfaceWS, brdf, gi.diffuse, gi.specular);
	for (int i = 0; i < GetDirectionalLightCount(); i++) {
		Light light = GetDirectionalLight(i, surfaceWS, shadowData);
		color += GetLighting(surfaceWS, brdf, light);
	}

	// 非平行光
	#if defined(_LIGHTS_PER_OBJECT)
	// 因为不能对于每一个片源得到哪些光源影响该片源，所以只能放大过滤范围得到这个obj受到哪些光源的影响
	// 因为每个obj最多受8个光源影响，所以这里只能限制上限8
	// unity_LightIndices最长度8，unity_LightData.y是是实际影响到该obj的光源数量，可能>8,可能<=8
		for (int j = 0; j < min(unity_LightData.y, 8); j++) {
			int lightIndex = unity_LightIndices[(uint)j / 4][(uint)j % 4];
			Light light = GetOtherLight(lightIndex, surfaceWS, shadowData);
			color += GetLighting(surfaceWS, brdf, light);
		}
	#else
	// 因为这里是对于每个片源都考虑，即使不可见的光源，或者不影响该片源的光源也计算在内
		for (int j = 0; j < GetOtherLightCount(); j++) {
			Light light = GetOtherLight(j, surfaceWS, shadowData);
			color += GetLighting(surfaceWS, brdf, light);
		}
	#endif
	return color;
}

#endif
