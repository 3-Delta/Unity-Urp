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
	float3 position;  // ws
	float depth; // 线性z， depth存在的意义就是：maxShadowDistance和最后一级的cullSphere存在冲突问题，sphere超过了max，导致在max之外sphere之内的frag的阴影
	// 计算存在问题

	// dither其实是为了解决在混合两个cascade的时候，需要采样两次shadowmap的情况，所以这里只采样一次，然后在一次的基础上，给个offset当做下一个cascade的结果
	float dither;
};

#endif