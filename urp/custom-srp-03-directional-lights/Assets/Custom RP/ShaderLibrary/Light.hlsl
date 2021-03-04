#ifndef CUSTOM_LIGHT_INCLUDED
#define CUSTOM_LIGHT_INCLUDED

#define MAX_DIRECTIONAL_LIGHT_COUNT 4

// _CustomLight 这个名字对于cbuffer来说，没有作用，但是如果是在gpuinstance数组中，就有用
CBUFFER_START(_CustomLight)
	int _DirectionalLightCount;
	float4 _DirectionalLightColors[MAX_DIRECTIONAL_LIGHT_COUNT];
	float4 _DirectionalLightDirections[MAX_DIRECTIONAL_LIGHT_COUNT];
CBUFFER_END

/*	 _CustomLight 这个关键字好像压根就没有任何作用，外部都是直接
 * dirLightColorsId = Shader.PropertyToID("_DirectionalLightColors")
 * 相当于：
	cbuffer _CustomLight
	{
		int _DirectionalLightCount;
		float4 _DirectionalLightColors[MAX_DIRECTIONAL_LIGHT_COUNT];
		float4 _DirectionalLightDirections[MAX_DIRECTIONAL_LIGHT_COUNT];
	}
 */

struct Light {
	float3 color; // 光源颜色
	float3 direction; // 光源方向， 指向光源，而不是从光源出发
};

int GetDirectionalLightCount () {
	return _DirectionalLightCount;
}

Light GetDirectionalLight (int index) {
	Light light;
	light.color = _DirectionalLightColors[index].rgb;
	light.direction = _DirectionalLightDirections[index].xyz;
	return light;
}

#endif