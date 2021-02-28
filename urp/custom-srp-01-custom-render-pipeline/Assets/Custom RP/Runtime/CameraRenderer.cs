using UnityEngine;
using UnityEngine.Rendering;

public partial class CameraRenderer {

	const string bufferName = "Render Camera";

	static ShaderTagId unlitShaderTagId = new ShaderTagId("SRPDefaultUnlit");

	CommandBuffer buffer = new CommandBuffer {
		name = bufferName
	};

	ScriptableRenderContext context;

	Camera camera;

	CullingResults cullingResults;

	public void Render (ScriptableRenderContext context, Camera camera) {
		this.context = context;
		this.camera = camera;

		PrepareBuffer();
		PrepareForSceneWindow();
		if (!Cull()) {
			return;
		}

		// 为什么有的是context.xxx, 而有的是buffer.xxx, 是因为pipeline中，固定的集中操作可以直接contex.xxx
		// 而另外一些操作需要借助cmdbuffer执行，cmdbuffer相当于一个打手
		// contex.submit之后contex才能真正生效，而contex。executebuffer之后，会将cmdbuffer的指令复制到contex中，而不是剪切
		// 最终通知gpu渲染肯定是submit。
		Setup();
		DrawVisibleGeometry();
		DrawUnsupportedShaders();
		DrawGizmos();
		Submit();
	}

	bool Cull () {
		if (camera.TryGetCullingParameters(out ScriptableCullingParameters p)) {
			// cpu进行视锥裁减，layer裁减等操作
			cullingResults = context.Cull(ref p);
			return true;
		}
		return false;
	}

	void Setup () {
		// 传递矩阵等信息给gpu
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

	void DrawVisibleGeometry () {
		var sortingSettings = new SortingSettings(camera) {
			// cpu进行对象排序
			criteria = SortingCriteria.CommonOpaque
		};
		var drawingSettings = new DrawingSettings(
			unlitShaderTagId, sortingSettings
		);
		var filteringSettings = new FilteringSettings(RenderQueueRange.opaque);

		// 渲染不透明物体
		context.DrawRenderers(
			cullingResults, ref drawingSettings, ref filteringSettings
		);

		// 渲染skybox
		context.DrawSkybox(camera);

		sortingSettings.criteria = SortingCriteria.CommonTransparent;
		drawingSettings.sortingSettings = sortingSettings;
		filteringSettings.renderQueueRange = RenderQueueRange.transparent;

		// 渲染半透明物体
		context.DrawRenderers(
			cullingResults, ref drawingSettings, ref filteringSettings
		);
	}
}