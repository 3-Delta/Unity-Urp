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

	// 为什么存在逐对象光源呢？
	// 如果不考虑的话，那么每个frag都需要计算一下每个光源对于这个frag的影响，但是这其实没必要，因为有些光源可见但是完全没有影响到
	// 某些obj, 所以我们可以大胆的将不影响obj的光源剔除， 也就是默认某个frag收到GetOtherLightCount() + GetDirectionalLightCount()个光源
	// 影响，但是过滤之后， 只有GetDirectionalLightCount()	 + 少数一些OtherLight的影响
	// 影响某个obj的可见非平行光在unity_LightIndices中定义， 也就是UnityInput.hlsl中的UnityPerDraw中
	
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
