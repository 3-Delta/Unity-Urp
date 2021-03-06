#ifndef CUSTOM_LIT_PASS_INCLUDED
#define CUSTOM_LIT_PASS_INCLUDED

#include "../ShaderLibrary/Surface.hlsl"
#include "../ShaderLibrary/Shadows.hlsl"
#include "../ShaderLibrary/Light.hlsl"
#include "../ShaderLibrary/BRDF.hlsl"
#include "../ShaderLibrary/GI.hlsl"
#include "../ShaderLibrary/Lighting.hlsl"

struct Attributes {
	float3 positionOS : POSITION;
	float3 normalOS : NORMAL;
	float2 baseUV : TEXCOORD0;
	// https://www.xuanyusong.com/archives/4633
	// 烘焙Lightmap以后unity会自动给参与烘焙的所有mesh添加uv2的属性，例如，三角形每个顶点都会有UV2它记录着这个每个顶点对应Lightmap图中的UV值
	// 这样拥有3个顶点的三角形面就可以通过UV2在Lightmap中线性采样烘焙颜色了。
	GI_ATTRIBUTE_DATA	// float2 lightMapUV : TEXCOORD1;
	UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings {
	float4 positionCS : SV_POSITION;
	float3 positionWS : VAR_POSITION;
	float3 normalWS : VAR_NORMAL;
	float2 baseUV : VAR_BASE_UV;
	GI_VARYINGS_DATA  // float2 lightMapUV : VAR_LIGHT_MAP_UV
	UNITY_VERTEX_INPUT_INSTANCE_ID
};

Varyings LitPassVertex (Attributes input) {
	Varyings output;
	UNITY_SETUP_INSTANCE_ID(input);
	UNITY_TRANSFER_INSTANCE_ID(input, output);
	// 计算lightMapUV
	TRANSFER_GI_DATA(input, output);

	output.positionWS = TransformObjectToWorld(input.positionOS);
	output.positionCS = TransformWorldToHClip(output.positionWS);
	output.normalWS = TransformObjectToWorldNormal(input.normalOS);
	output.baseUV = TransformBaseUV(input.baseUV);
	return output;
}

float4 LitPassFragment (Varyings input) : SV_TARGET {
	UNITY_SETUP_INSTANCE_ID(input);
	float4 base = GetBase(input.baseUV);
	#if defined(_CLIPPING)
		clip(base.a - GetCutoff(input.baseUV));
	#endif
	
	Surface surface;
	surface.position = input.positionWS;
	surface.normal = normalize(input.normalWS);
	surface.viewDirection = normalize(_WorldSpaceCameraPos - input.positionWS);
	surface.depth = -TransformWorldToView(input.positionWS).z;
	surface.color = base.rgb;
	surface.alpha = base.a;
	surface.metallic = GetMetallic(input.baseUV);
	surface.smoothness = GetSmoothness(input.baseUV);
	surface.dither = InterleavedGradientNoise(input.positionCS.xy, 0);
	#if defined(_PREMULTIPLY_ALPHA)
		BRDF brdf = GetBRDF(surface, true);
	#else
		BRDF brdf = GetBRDF(surface);
	#endif

	// 添加关于gi的计算
	// ##define GI_FRAGMENT_DATA(input) input.lightMapUV 相当于 float2 lightMapUV = input.lightMapUV
	float2 lightMapUV = GI_FRAGMENT_DATA(input);
	GI gi = GetGI(lightMapUV, surface);
	// GetLighting会考虑到内部光源格式，如果都是bake类型的光源，则不会进行实质的光源计算
	float3 color = GetLighting(surface, brdf, gi);

	// 计算自发光
	color += GetEmission(input.baseUV);
	return float4(color, surface.alpha);
}

#endif