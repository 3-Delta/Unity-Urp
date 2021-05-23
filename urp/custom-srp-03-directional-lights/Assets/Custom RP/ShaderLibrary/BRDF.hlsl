#ifndef CUSTOM_BRDF_INCLUDED
#define CUSTOM_BRDF_INCLUDED

struct BRDF {
	float3 diffuse;
	float3 specular;
	float roughness;
};

// 物体反射的辐射能量占总辐射能量的百分比，称为反射率,总是 < 1
// https://zhuanlan.zhihu.com/p/335664226
// 非金属的反射率有所不同，但平均约为0.04
#define MIN_REFLECTIVITY 0.04

// 反射率是指接收光的时候，有多少比例的光被反射，比如黑色的东西反射率就是0也就是不反射都是吸收了
// 所以这里有一个最小反射率
// 越靠近金属，ret越小
float OneMinusReflectivity (float metallic) {
	float range = 1.0 - MIN_REFLECTIVITY;
	// (1.0 - MIN_REFLECTIVITY) * (1 - metallic)
	// (1 - metallic)得到一个趋向于非金属的数据，一般来说就是漫反射
	return range - metallic * range;
}

BRDF GetBRDF (Surface surface, bool applyAlphaToDiffuse = false) {
	BRDF brdf;
	// 1 - 金属度 = 漫反射度
	float oneMinusReflectivity = OneMinusReflectivity(surface.metallic);

	// 处理surface漫反射
	brdf.diffuse = surface.color * oneMinusReflectivity;
	if (applyAlphaToDiffuse) {
		brdf.diffuse *= surface.alpha;
	}
	
	brdf.specular = lerp(MIN_REFLECTIVITY, surface.color, surface.metallic);

	// ？？？
	float perceptualRoughness =
		PerceptualSmoothnessToPerceptualRoughness(surface.smoothness);
	brdf.roughness = PerceptualRoughnessToRoughness(perceptualRoughness);
	return brdf;
}

// 高光强度
float SpecularStrength (Surface surface, BRDF brdf, Light light) {
	float3 h = SafeNormalize(light.direction + surface.viewDirection);
	float nh2 = Square(saturate(dot(surface.normal, h)));
	float lh2 = Square(saturate(dot(light.direction, h)));
	float r2 = Square(brdf.roughness);
	float d2 = Square(nh2 * (r2 - 1.0) + 1.00001);
	float normalization = brdf.roughness * 4.0 + 2.0;
	return r2 / (d2 * max(0.1, lh2) * normalization);
}

// 处理surface, brdf, 以及光源的关系
float3 DirectBRDF (Surface surface, BRDF brdf, Light light) {
	float strength = SpecularStrength(surface, brdf, light);
	return strength * brdf.specular + brdf.diffuse;
}

// diffuse: Sc * Lc * sature(n dot l);

#endif