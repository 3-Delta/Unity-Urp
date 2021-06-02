#ifndef CUSTOM_LIGHTING_INCLUDED
#define CUSTOM_LIGHTING_INCLUDED

float3 IncomingLight (Surface surface, Light light) {
		// 计算衰减 阴影起作用的最后一步是将衰减量纳入光线的强度中
		// light.attenuation其实是阴影
		// 这里是将阴影和传统的光源衰减进行了整合和统一
		float3 dt = dot(surface.normal, light.direction);
		// chapter3: saturate(dt) * light.color;

		// brdf中，Cos角度， 吸收率， 以及这个遮挡情况都会影响 brdf系数
		// 当下：
		return saturate(dt * light.attenuation) * light.color;
}

// 这里使用来pbr的brdf的公式计算光照
// 涉及到brdf, 入射光，表面属性
// 单个光源对于pixel的影响
float3 GetLighting (Surface surface, BRDF brdf, Light light) {
	// 输入光源 * brdf系数
	return IncomingLight(surface, light) * DirectBRDF(surface, brdf, light);
}

// 光照计算入口
float3 GetLighting (Surface surfaceWS, BRDF brdf) {
    // 获取当前surface的shadow
	ShadowData shadowData = GetShadowData(surfaceWS);
	float3 color = 0.0;
	for (int i = 0; i < GetDirectionalLightCount(); i++) {
		// 主要获取surface在light下的 遮挡情况
		Light light = GetDirectionalLight(i, surfaceWS, shadowData);
		color += GetLighting(surfaceWS, brdf, light);
	}
	return color;
}

#endif
