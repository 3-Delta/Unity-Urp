#ifndef CUSTOM_SURFACE_INCLUDED
#define CUSTOM_SURFACE_INCLUDED

struct Surface {
	float3 normal;
	float3 color;
	float alpha;
	float3 viewDirection;
	float metallic;
	float smoothness;

	// 新增
	float3 position;
	float depth;
	float dither;
};

#endif