#ifndef CUSTOM_LIT_PASS_INCLUDED
#define CUSTOM_LIT_PASS_INCLUDED

#include "../ShaderLibrary/Common.hlsl"
#include "../ShaderLibrary/Surface.hlsl"
#include "../ShaderLibrary/Light.hlsl"
#include "../ShaderLibrary/BRDF.hlsl"
#include "../ShaderLibrary/Lighting.hlsl"

TEXTURE2D(_BaseMap);
SAMPLER(sampler_BaseMap);

// UnityInstancing.hlsl中定义，本质上是定义了一个arr数组
// 因为数个数组，而且长度已经固定，那么第二章中的动态修改materialpropertyblock的形式就不起作用了，因为数组长度已经固定，而且在初始化shaderbuffer的时候，就已经申请内存了。
UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
	// define本质上是: type var
	UNITY_DEFINE_INSTANCED_PROP(float4, _BaseMap_ST)
	UNITY_DEFINE_INSTANCED_PROP(float4, _BaseColor)
	UNITY_DEFINE_INSTANCED_PROP(float, _Cutoff)
	UNITY_DEFINE_INSTANCED_PROP(float, _Metallic)
	UNITY_DEFINE_INSTANCED_PROP(float, _Smoothness)
UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)

// Renderpipeline怎么传递数据过来给GPU呢？
/* 
 * 相当于
	cbuffer UnityInstancing_UnityPerMaterial
	{
		struct
		{
			float4 _BaseMap_ST;
			float4 _BaseColor;
			float _Cutoff;
			float _Metallic;
			float _Smoothness;
		}UnityPerMaterialArray[MAX_SIZE];
	}
 */

struct Attributes {
	float3 positionOS : POSITION;
	float3 normalOS : NORMAL;
	float2 baseUV : TEXCOORD0;
	// UNITY_VERTEX_INPUT_INSTANCE_ID 相当于 uint instanceID
	UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings {
	float4 positionCS : SV_POSITION;
	float3 positionWS : VAR_POSITION;
	float3 normalWS : VAR_NORMAL;
	float2 baseUV : VAR_BASE_UV;
	UNITY_VERTEX_INPUT_INSTANCE_ID
};

Varyings LitPassVertex (Attributes input) {
	Varyings output;
	// 相当于设置全局的unity_instanceID = input.instanceID + unity_BaseInstanceID[这是一个常数]
	UNITY_SETUP_INSTANCE_ID(input);
	// 相当于 output.instanceID = input.instanceID
	UNITY_TRANSFER_INSTANCE_ID(input, output);
	output.positionWS = TransformObjectToWorld(input.positionOS);
	output.positionCS = TransformWorldToHClip(output.positionWS);
	output.normalWS = TransformObjectToWorldNormal(input.normalOS);

	// static uint unity_instanceID是一个global的静态变量
	// UNITY_ACCESS_INSTANCED_PROP相当于：UnityPerMaterialArray[unity_instanceID]._BaseMap_ST
	float4 baseST = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _BaseMap_ST);
	output.baseUV = input.baseUV * baseST.xy + baseST.zw;
	return output;
}

// UNITY_GET_INSTANCE_ID(input) 相当于 input.instanceID

float4 LitPassFragment (Varyings input) : SV_TARGET {
	UNITY_SETUP_INSTANCE_ID(input);
	float4 baseMap = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.baseUV);
	float4 baseColor = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _BaseColor);
	float4 base = baseMap * baseColor;
	#if defined(_CLIPPING)
		clip(base.a - UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Cutoff));
	#endif

	Surface surface;
	// 世界坐标法线
	surface.normal = normalize(input.normalWS);
	// 世界坐标 pixel指向相机的方向
	surface.viewDirection = normalize(_WorldSpaceCameraPos - input.positionWS);
	surface.color = base.rgb;
	surface.alpha = base.a;
	surface.metallic = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Metallic);
	surface.smoothness =
		UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Smoothness);
	
	#if defined(_PREMULTIPLY_ALPHA)
		BRDF brdf = GetBRDF(surface, true);
	#else
		BRDF brdf = GetBRDF(surface);
	#endif
	float3 color = GetLighting(surface, brdf);
	return float4(color, surface.alpha);
}

#endif