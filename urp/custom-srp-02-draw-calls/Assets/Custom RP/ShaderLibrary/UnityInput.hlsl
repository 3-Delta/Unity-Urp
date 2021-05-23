#ifndef CUSTOM_UNITY_INPUT_INCLUDED
#define CUSTOM_UNITY_INPUT_INCLUDED

CBUFFER_START(UnityPerDraw)
	float4x4 unity_ObjectToWorld;
	float4x4 unity_WorldToObject;
	float4 unity_LODFade;
	real4 unity_WorldTransformParams;
CBUFFER_END

// 	unity_MatrixVP为什么不能和 unity_ObjectToWorld一起定义在 UnityPerDraw呢？因为vp矩阵是对于每一帧变化的一个量，和local
// 没有关系，所以这里单独拆出来
float4x4 unity_MatrixVP;
float4x4 unity_MatrixV;
float4x4 glstate_matrix_projection;

#endif