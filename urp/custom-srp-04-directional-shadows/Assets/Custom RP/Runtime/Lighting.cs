using Unity.Collections;
using UnityEngine;
using UnityEngine.Rendering;

public class Lighting {

	const string bufferName = "Lighting";

	const int maxDirLightCount = 4;

	static int
		dirLightCountId = Shader.PropertyToID("_DirectionalLightCount"),
		dirLightColorsId = Shader.PropertyToID("_DirectionalLightColors"),
		dirLightDirectionsId = Shader.PropertyToID("_DirectionalLightDirections"),

		// 每个dir光源的shadow阴影数据收集
		dirLightShadowDataId = Shader.PropertyToID("_DirectionalLightShadowData");

	static Vector4[]
		dirLightColors = new Vector4[maxDirLightCount],
		dirLightDirections = new Vector4[maxDirLightCount],
		dirLightShadowData = new Vector4[maxDirLightCount];

	CommandBuffer buffer = new CommandBuffer {
		name = bufferName
	};

	CullingResults cullingResults;

	Shadows shadows = new Shadows();

	public void Setup (
		ScriptableRenderContext context, CullingResults cullingResults, ShadowSettings shadowSettings) {
		this.cullingResults = cullingResults;

		buffer.BeginSample(bufferName);
		shadows.Setup(context, cullingResults, shadowSettings);

		// 必须先setlight, 后面才能 shadows.Render();
		SetupLights();

		shadows.Render();

		buffer.EndSample(bufferName);
		context.ExecuteCommandBuffer(buffer);
		buffer.Clear();
	}

	public void Cleanup () {
		shadows.Cleanup();
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

		buffer.SetGlobalInt(dirLightCountId, dirLightCount);
		buffer.SetGlobalVectorArray(dirLightColorsId, dirLightColors);
		buffer.SetGlobalVectorArray(dirLightDirectionsId, dirLightDirections);
		buffer.SetGlobalVectorArray(dirLightShadowDataId, dirLightShadowData);
	}

	void SetupDirectionalLight (int index, ref VisibleLight visibleLight) {
		// finalColor是强度*乘过的
		// 颜色是linearspace下的颜色
		dirLightColors[index] = visibleLight.finalColor;
		// light的-forward
		dirLightDirections[index] = -visibleLight.localToWorldMatrix.GetColumn(2);

		// 为了shadow新增 below

		// 有可能存在光源有4个，但是shadow光源不足4个的情况，此时 dirLightShadowData[index] == vector3.zero
		// 从代码看，绝对不可能出现4个光源，但是有4个以上的shadow光源
		dirLightShadowData[index] = shadows.ReserveDirectionalShadows(visibleLight.light, index);
	}
}