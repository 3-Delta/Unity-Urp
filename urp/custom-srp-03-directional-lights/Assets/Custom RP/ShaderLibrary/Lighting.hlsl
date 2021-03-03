#ifndef CUSTOM_LIGHTING_INCLUDED
#define CUSTOM_LIGHTING_INCLUDED

// 漫反射计算
float3 IncomingLight (Surface surface, Light light) {
	// saturate作用：限制value在【0， 1】之间
	return saturate(dot(surface.normal, light.direction)) * light.color;
}

// 单个光源对于pixel的影响
float3 GetLighting (Surface surface, BRDF brdf, Light light) {
	float3 il = IncomingLight(surface, light);
	return il * DirectBRDF(surface, brdf, light);
}

// 多个光源同时影响一个pixel
float3 GetLighting (Surface surface, BRDF brdf) {
	float3 color = 0.0;
	for (int i = 0; i < GetDirectionalLightCount(); i++) {
		color += GetLighting(surface, brdf, GetDirectionalLight(i));
	}
	return color;
}

#endif