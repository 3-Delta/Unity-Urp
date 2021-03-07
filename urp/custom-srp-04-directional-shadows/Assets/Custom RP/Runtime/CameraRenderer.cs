using UnityEngine;
using UnityEngine.Rendering;

public partial class CameraRenderer {

	const string bufferName = "Render Camera";

	static ShaderTagId
		unlitShaderTagId = new ShaderTagId("SRPDefaultUnlit"),
		litShaderTagId = new ShaderTagId("CustomLit");

	CommandBuffer buffer = new CommandBuffer {
		name = bufferName
	};

	ScriptableRenderContext context;

	Camera camera;

	CullingResults cullingResults;

	Lighting lighting = new Lighting();

	public void Render (
		ScriptableRenderContext context, Camera camera,
		bool useDynamicBatching, bool useGPUInstancing,
		ShadowSettings shadowSettings
	) {
		this.context = context;
		this.camera = camera;

		PrepareBuffer();
		PrepareForSceneWindow();
		if (!Cull(shadowSettings.maxDistance)) {
			return;
		}
		
		buffer.BeginSample(SampleName);
		ExecuteBuffer();
		// 先渲染阴影
		lighting.Setup(context, cullingResults, shadowSettings);
		// 再设置相机参数，否则出问题
		Setup();
		buffer.EndSample(SampleName);

		DrawVisibleGeometry(useDynamicBatching, useGPUInstancing);
		DrawUnsupportedShaders();
		DrawGizmos();
		lighting.Cleanup();
		Submit();
	}

	bool Cull (float maxShadowDistance) {
		if (camera.TryGetCullingParameters(out ScriptableCullingParameters p)) {
			// 裁减参数中设置关于shadowdistance
			// maxShadowDistance是针对相机的参数，而不是针对光源的参数
			p.shadowDistance = Mathf.Min(maxShadowDistance, camera.farClipPlane);
			cullingResults = context.Cull(ref p);
			return true;
		}
		return false;
	}

	void Setup () {
		context.SetupCameraProperties(camera);
		CameraClearFlags flags = camera.clearFlags;
		buffer.ClearRenderTarget(
			flags <= CameraClearFlags.Depth,
			flags == CameraClearFlags.Color,
			flags == CameraClearFlags.Color ?
				camera.backgroundColor.linear : Color.clear
		);
		buffer.BeginSample(SampleName);
		ExecuteBuffer();
	}

	void Submit () {
		buffer.EndSample(SampleName);
		ExecuteBuffer();
		context.Submit();
	}

	void ExecuteBuffer () {
		context.ExecuteCommandBuffer(buffer);
		buffer.Clear();
	}

	void DrawVisibleGeometry (bool useDynamicBatching, bool useGPUInstancing) {
		var sortingSettings = new SortingSettings(camera) {
			criteria = SortingCriteria.CommonOpaque
		};
		var drawingSettings = new DrawingSettings(
			unlitShaderTagId, sortingSettings
		) {
			enableDynamicBatching = useDynamicBatching,
			enableInstancing = useGPUInstancing
		};
		drawingSettings.SetShaderPassName(1, litShaderTagId);

		var filteringSettings = new FilteringSettings(RenderQueueRange.opaque);

		context.DrawRenderers(
			cullingResults, ref drawingSettings, ref filteringSettings
		);

		context.DrawSkybox(camera);

		sortingSettings.criteria = SortingCriteria.CommonTransparent;
		drawingSettings.sortingSettings = sortingSettings;
		filteringSettings.renderQueueRange = RenderQueueRange.transparent;

		context.DrawRenderers(
			cullingResults, ref drawingSettings, ref filteringSettings
		);
	}
}