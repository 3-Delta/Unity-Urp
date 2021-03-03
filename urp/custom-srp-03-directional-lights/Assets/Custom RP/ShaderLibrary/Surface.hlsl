#ifndef CUSTOM_SURFACE_INCLUDED
#define CUSTOM_SURFACE_INCLUDED

struct Surface {
	float3 normal; // 法线
	
	float3 viewDirection; // 顶点指向相机方向
	
	float3 color; // 颜色
	float alpha; // 透明度
	
	float metallic; // 金属度
	float smoothness; // 光滑度
};

#endif