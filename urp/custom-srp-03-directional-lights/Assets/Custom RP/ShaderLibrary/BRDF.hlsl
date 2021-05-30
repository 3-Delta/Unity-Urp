#ifndef CUSTOM_BRDF_INCLUDED
#define CUSTOM_BRDF_INCLUDED

struct BRDF {
	float3 diffuse;
	float3 specular;
	float roughness;
};

// 物体反射的辐射能量占总辐射能量的百分比，称为反射率,总是 < 1
// https://zhuanlan.zhihu.com/p/335664226
// https://zhuanlan.zhihu.com/p/372984872
// 自然界的物质根据光照特性大体可以分为金属和非金属。
/*
* 总光照 = 漫反射 + 高光反射 + 吸收， 也就涉及到 高光反射率， 漫反射率
* 
金属的光照特性是：漫反射率基本为0，所以漫反射颜色也为0（黑色），所以总光照 = 高光反射 + 吸收，那么高光反射到底占总光照的多少呢，
我们使用reflctivity（高光反射率） * 总光照来获得，reflctivity在[70 % ，100%]。
而高光颜色总是偏金属本身的颜色，例如黄金的高光颜色是金黄色，白银的高光颜色是灰色，黄铜的高光颜色是黄色。

金属：漫反射率 = 0，漫反射颜色 = 黑，高光反射率 = reflctivity，高光颜色 = 自身颜色

非金属的光照特性是：高光反射率在4 % 左右（高光颜色几乎为黑色0），而漫反射很强，漫反射颜色 = （1 - reflctivity） * albedo，其中1 - reflctivity 
等于“漫反射 + 吸收”的光照比例，再乘以diffuse后就是漫反射颜色。

非金属：漫反射率 = 1 - reflctivity，漫反射颜色 = 自身颜色，高光反射率 = 0.04，高光颜色 = 灰黑		
*/
// 非金属的反射率有所不同，但平均约为0.04
#define MIN_REFLECTIVITY 0.04

// 反射率是指接收光的时候，有多少比例的光被反射，比如黑色的东西反射率就是0也就是不反射都是吸收了
// 所以这里有一个最小反射率
// 越靠近金属，ret越小
// 这里计算的其实就是漫反射率
// https://zhuanlan.zhihu.com/p/335664226  非金属的反射率有所不同，但平均约为0.04
// 该函数将范围从0~1调整为0~0.96
float OneMinusReflectivity (float metallic) {
	float range = 1.0 - MIN_REFLECTIVITY;
	// (1.0 - MIN_REFLECTIVITY) * (1 - metallic)
	// 
	// 如果metallic == 1？也就是纯金属，那么ret = 0，所以这里计算的其实就是漫反射率
	// 如果metallic == 0？也就是纯非金属，那么ret = 0.96
	// 
	// 如果metallic == 1，也就是纯金属，那么高光反射率就是 1
	// 如果metallic == 0，也就是非金属，那么高光反射率就是MIN_REFLECTIVITY
	// 
	// 	   金属没有漫反射率，但是非金属有高光反射率
	// 
	// (1 - metallic)得到一个趋向于非金属的数据，一般来说就是漫反射
	return range - metallic * range;
}

BRDF GetBRDF (Surface surface, bool applyAlphaToDiffuse = false) {
	BRDF brdf;
	// 漫反射率
	float oneMinusReflectivity = OneMinusReflectivity(surface.metallic);

	// 处理surface漫反射
	// 原始为：surface.color * （1 - surface.metallic）
	// 现在为  surface.color * 【（1.0 - MIN_REFLECTIVITY）* (1 - metallic)】
	// 也就是原始认为：MIN_REFLECTIVITY就是0，最小高光反射率为0，但是其实最小高光反射率不为0为0.04
	brdf.diffuse = surface.color * oneMinusReflectivity;
	// 预乘只针对于漫反射，不针对高光反射
	if (applyAlphaToDiffuse) {
		brdf.diffuse *= surface.alpha;
	}
	

	// 原始为：brdf.specular = surface.color * （1 - oneMinusReflectivity）
	// 处理高光项（最简单就是 surface.color *（1 - oneMinusReflectivity）），但是因为这里有吸收的存在，考虑到能量守恒
	// 如果metallic == 1，也就是纯金属，那么高光反射率就是 1
	// 如果metallic == 0，也就是非金属，那么高光反射率就是MIN_REFLECTIVITY
	brdf.specular = lerp(MIN_REFLECTIVITY, 1 * surface.color, surface.metallic);

	// smoothness -> roughness
	float perceptualRoughness = PerceptualSmoothnessToPerceptualRoughness(surface.smoothness);
	brdf.roughness = PerceptualRoughnessToRoughness(perceptualRoughness);
	return brdf;
}

// 高光强度，有具体公式计算
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