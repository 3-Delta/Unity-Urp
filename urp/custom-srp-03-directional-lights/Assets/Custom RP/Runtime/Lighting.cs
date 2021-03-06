using System;

using Unity.Collections;
using UnityEngine;
using UnityEngine.Rendering;

public class Lighting {

	const string bufferName = "Lighting";

	const int maxDirLightCount = 4;

	static int
		dirLightCountId = Shader.PropertyToID("_DirectionalLightCount"),
		dirLightColorsId = Shader.PropertyToID("_DirectionalLightColors"),
		dirLightDirectionsId = Shader.PropertyToID("_DirectionalLightDirections");

	static Vector4[]
		dirLightColors = new Vector4[maxDirLightCount],
		dirLightDirections = new Vector4[maxDirLightCount];

	CommandBuffer buffer = new CommandBuffer {
		name = bufferName
	};

	CullingResults cullingResults;

	public void Setup (
		ScriptableRenderContext context, CullingResults cullingResults
	) {
		this.cullingResults = cullingResults;
		buffer.BeginSample(bufferName);
		SetupLights();
		buffer.EndSample(bufferName);
		context.ExecuteCommandBuffer(buffer);
		buffer.Clear();
	}

	void SetupLights () {
		NativeArray<VisibleLight> visibleLights = cullingResults.visibleLights;
		int dirLightCount = 0;
		for (int i = 0; i < visibleLights.Length; i++) {
			VisibleLight visibleLight = visibleLights[i];
			if (visibleLight.lightType == LightType.Directional) {
				SetupDirectionalLight(dirLightCount++, ref visibleLight);
				if (dirLightCount >= maxDirLightCount) {
					break;
				}
			}
		}

		// 传递 平行光光源数据
		buffer.SetGlobalInt(dirLightCountId, dirLightCount);
		buffer.SetGlobalVectorArray(dirLightColorsId, dirLightColors);
		buffer.SetGlobalVectorArray(dirLightDirectionsId, dirLightDirections);
	}

	// 设置平行光颜色/方向
	// 默认情况下Unity不会将其转换为线性空间。我们必须将GraphicsSettings.lightsUseLinearIntensity设置为true
	void SetupDirectionalLight (int index, ref VisibleLight visibleLight) {
		// RenderSettings.sun 是主光源
		// Light light = default;
		// finalColor是强度*乘过的
		// visibleLight.finalColor == light.intensity * light.color.linear;

		// 	light.color就是光源颜色， 必须乘以强度，才是最终的 颜色

		// 颜色是linearspace下的颜色
		dirLightColors[index] = visibleLight.finalColor;

		// https://zhuanlan.zhihu.com/p/163360207
		// https://www.zhihu.com/question/452040005/answer/1810783856
		// 最后一列代表的是模型中心点的世界坐标
		// localspace的光源的forward方向
		// 方向：指向光源的方向，所以是负数
		dirLightDirections[index] = -visibleLight.localToWorldMatrix.GetColumn(2);
	}
}