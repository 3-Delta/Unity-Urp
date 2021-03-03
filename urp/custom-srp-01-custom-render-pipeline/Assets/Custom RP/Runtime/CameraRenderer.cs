using UnityEngine;
using UnityEngine.Rendering;

public partial class CameraRenderer {

	const string bufferName = "Render Camera";

	// https://www.pianshen.com/article/7860291589/
	// Shader中不写 LightMode 时默认ShaderTagId值为“SRPDefaultUnlit”
	// https://www.xuanyusong.com/archives/4759
	// URP以后并不是所有Pass都会执行，因为它预制了两个Pass所以，优先执行”UniversalForward”在执行”SrpDefaultUnlit”的Pass
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

		// https://catlikecoding.com/unity/tutorials/custom-srp/custom-render-pipeline/
		// 解决UGUI在gameview显示，不在sceneView显示的问题，不管Canvas在那种渲染模式
		// 只是在渲染模式为Overlay的时候，framedebugger中会将UI的渲染独立出来，而不是在renderpipeline中一起渲染
		// 渲染模式为camera的时候，framebebugger会将UI合并到renderpipeline中一起渲染。
		// 不被渲染的情况下，我们在editor下依然可以进行编辑操作，也就是recttransform.sizeDelta改变之后，边框gizmos会变化
		PrepareForSceneWindow();

        if (!Cull()) {
			// 找了一个不渲染任何物件的相机，solidercolor, 发现也会通过cull,只是该相机的draw操作就只是draw gl
            return;
        }

        // 为什么有的是context.xxx, 而有的是buffer.xxx, 是因为pipeline中，固定的集中操作可以直接contex.xxx
        // 而另外一些操作需要借助cmdbuffer执行，cmdbuffer相当于一个打手
        // contex.submit之后contex才能真正生效，而contex。executebuffer之后，会将cmdbuffer的指令复制到contex中，而不是剪切
        // 最终通知gpu渲染肯定是submit。
        Setup();
        DrawVisibleGeometry();
        DrawUnsupportedShaders();

		// sceneView和gameview同时受到控制， 一旦注释这里，则选中的cube就不会再gizmos情况下显示collider的绿色框
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
		// 有时候rendertarget是rt,那么怎么控制这个	ClearRenderTarget是对于camera生效，还是对于rt生效呢？
		// 猜测应该是向上查找最近的一个rendertarget, 因为这里没有明显的设置过rendertarget，所以就当是framebuffer
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