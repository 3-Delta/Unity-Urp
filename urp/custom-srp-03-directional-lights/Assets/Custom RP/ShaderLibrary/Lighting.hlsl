#ifndef CUSTOM_LIGHTING_INCLUDED
#define CUSTOM_LIGHTING_INCLUDED

// 漫反射计算
float3 IncomingLight (Surface surface, Light light) {
	// saturate作用：限制value在【0， 1】之间
	return saturate(dot(surface.normal, light.direction)) * light.color;
}

// 这里使用来pbr的brdf的公式计算光照
// 涉及到brdf, 入射光，表面属性
// 单个光源对于pixel的影响
float3 GetLighting (Surface surface, BRDF brdf, Light light) {
	// 先考虑light和surface的关系
	float3 il = IncomingLight(surface, light);

	// 接着计算surface和brdf的关系
	// 输入光源 * brdf系数
	float3 diffuseAndSpecular = DirectBRDF(surface, brdf, light);
	return il * diffuseAndSpecular;
}

// 光照计算入口
// 多个光源同时影响一个pixel
float3 GetLighting (Surface surface, BRDF brdf) {
	float3 color = 0.0;
	for (int i = 0; i < GetDirectionalLightCount(); i++) {
		Light light = GetDirectionalLight(i);
		color += GetLighting(surface, brdf, light);
	}
	return color;
}

#endif