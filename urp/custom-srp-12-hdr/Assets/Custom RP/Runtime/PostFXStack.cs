using UnityEngine;
using UnityEngine.Rendering;

public partial class PostFXStack {

	enum Pass {
		BloomAdd,
		BloomHorizontal,
		BloomPrefilter,
		BloomPrefilterFireflies,
		BloomScatter,
		BloomScatterFinal,
		BloomVertical,
		Copy,
		ToneMappingACES,
		ToneMappingNeutral,
		ToneMappingReinhard
	}

	const string bufferName = "Post FX";

	// 纹理金字塔，其实就是下采样的次数。每次/2
	const int maxBloomPyramidLevels = 16;

	int
		bloomBucibicUpsamplingId = Shader.PropertyToID("_BloomBicubicUpsampling"),
		bloomIntensityId = Shader.PropertyToID("_BloomIntensity"),
		bloomPrefilterId = Shader.PropertyToID("_BloomPrefilter"),
		bloomThresholdId = Shader.PropertyToID("_BloomThreshold"),

		bloomResultId = Shader.PropertyToID("_BloomResult"),

		// 事实证明这些 字符串名字必须对应在shader中存在，否则效果不正确
		// 除非这个 字符串名字是rt， 注意rt这里不是普通纹理
		fxSourceId = Shader.PropertyToID("_PostFXSource"),
		fxSource2Id = Shader.PropertyToID("_PostFXSource2");

	CommandBuffer buffer = new CommandBuffer {
		name = bufferName
	};

	ScriptableRenderContext context;

	Camera camera;

	PostFXSettings settings;

	int bloomPyramidId;

	bool useHDR;

	public bool IsActive => settings != null;

	public PostFXStack () {
		bloomPyramidId = Shader.PropertyToID("_BloomPyramid0");
		for (int i = 1; i < maxBloomPyramidLevels * 2; i++) {
			// 顺序分配金字塔纹理标识符，只需要追踪第一个
			// 因为是+1的关系
			Shader.PropertyToID("_BloomPyramid" + i);
		}
	}

	public void Setup (
		ScriptableRenderContext context, Camera camera, PostFXSettings settings,
		bool useHDR
	) {
		this.useHDR = useHDR;
		this.context = context;
		this.camera = camera;
		this.settings =
			camera.cameraType <= CameraType.SceneView ? settings : null;
		ApplySceneViewState();
	}

	// sourceId是frameBufferId
	public void Render (int sourceId) {
		if (DoBloom(sourceId)) {
			// 后处理顺序，先bloom,后tonemap
			DoToneMapping(bloomResultId);
			buffer.ReleaseTemporaryRT(bloomResultId);
		}
		else {
			DoToneMapping(sourceId);
		}
		context.ExecuteCommandBuffer(buffer);
		buffer.Clear();
	}

	bool DoBloom (int sourceId) {
		PostFXSettings.BloomSettings bloom = settings.Bloom;
		int width = camera.pixelWidth / 2;
		int height = camera.pixelHeight / 2;
		
		if (
			bloom.maxIterations == 0 || bloom.intensity <= 0f ||
			height < bloom.downscaleLimit * 2 || width < bloom.downscaleLimit * 2
		) {
			return false;
		}

		buffer.BeginSample("Bloom");
		Vector4 threshold;
		threshold.x = Mathf.GammaToLinearSpace(bloom.threshold);
		threshold.y = threshold.x * bloom.thresholdKnee;
		threshold.z = 2f * threshold.y;
		threshold.w = 0.25f / (threshold.y + 0.00001f);
		threshold.y -= threshold.x;
		buffer.SetGlobalVector(bloomThresholdId, threshold);

		RenderTextureFormat format = useHDR ?
			RenderTextureFormat.DefaultHDR : RenderTextureFormat.Default;
		buffer.GetTemporaryRT(
			bloomPrefilterId, width, height, 0, FilterMode.Bilinear, format
		);

		Draw(
			sourceId, bloomPrefilterId, bloom.fadeFireflies ?
				Pass.BloomPrefilterFireflies : Pass.BloomPrefilter
		);

		width /= 2;
		height /= 2;

		int fromId = bloomPrefilterId;
		int toId = bloomPyramidId + 1;
		int i;
		// 限制下采样次数
		for (i = 0; i < bloom.maxIterations; i++) {
			// 一般是 if (height < 1 || width < 1)
			if (height < bloom.downscaleLimit || width < bloom.downscaleLimit) {
				break;
			}

			int midId = toId - 1;

			buffer.GetTemporaryRT(
				midId, width, height, 0, FilterMode.Bilinear, format
			);
			buffer.GetTemporaryRT(
				toId, width, height, 0, FilterMode.Bilinear, format
			);

			// 同一层级的下采样，分别进行水平，垂直的bloom处理
			Draw(fromId, midId, Pass.BloomHorizontal);
			Draw(midId, toId, Pass.BloomVertical);

			fromId = toId;
			toId += 2;
			width /= 2;
			height /= 2;
		}

		buffer.ReleaseTemporaryRT(bloomPrefilterId);
		buffer.SetGlobalFloat(
			bloomBucibicUpsamplingId, bloom.bicubicUpsampling ? 1f : 0f
		);

		Pass combinePass;
		Pass finalPass;
		float finalIntensity;
		if (bloom.mode == PostFXSettings.BloomSettings.Mode.Additive) {
			combinePass = finalPass = Pass.BloomAdd;
			buffer.SetGlobalFloat(bloomIntensityId, 1f);
			finalIntensity = bloom.intensity;
		}
		else {
			combinePass = Pass.BloomScatter;
			finalPass = Pass.BloomScatterFinal;
			// bloom散射强度
			buffer.SetGlobalFloat(bloomIntensityId, bloom.scatter);
			finalIntensity = Mathf.Min(bloom.intensity, 1f);
		}

		if (i > 1) {
			// 上采样，blend金字塔各层级的tex到一起，默认纹理格式是linear, clamp格式
			// 上采样的时候，不进行高斯模糊处理
			buffer.ReleaseTemporaryRT(fromId - 1);
			toId -= 5;
			for (i -= 1; i > 0; i--) {
				// copy(to的rt, fx2d对应的纹理)
				buffer.SetGlobalTexture(fxSource2Id, toId + 1);
				Draw(fromId, toId, combinePass);
				buffer.ReleaseTemporaryRT(fromId);
				buffer.ReleaseTemporaryRT(toId + 1);
				fromId = toId;
				toId -= 2;
			}
		}
		else {
			buffer.ReleaseTemporaryRT(bloomPyramidId);
		}
		buffer.SetGlobalFloat(bloomIntensityId, finalIntensity);
		buffer.SetGlobalTexture(fxSource2Id, sourceId);
		buffer.GetTemporaryRT(
			bloomResultId, camera.pixelWidth, camera.pixelHeight, 0,
			FilterMode.Bilinear, format
		);
		Draw(fromId, bloomResultId, finalPass);
		buffer.ReleaseTemporaryRT(fromId);
		buffer.EndSample("Bloom");
		return true;
	}

	void DoToneMapping(int sourceId) {
		PostFXSettings.ToneMappingSettings.Mode mode = settings.ToneMapping.mode;
		Pass pass = mode < 0 ? Pass.Copy : Pass.ToneMappingACES + (int)mode;
		
		// 最后一步肯定需要将rt copy 到framebuffer
		Draw(sourceId, BuiltinRenderTextureType.CameraTarget, pass);
	}

	void Draw (
		RenderTargetIdentifier from, RenderTargetIdentifier to, Pass pass
	) {
		// buffer.Blit(sourceId, BuiltinRenderTextureType.CameraTarget);
		// 复制到目前为止渲染的任何内容到相机的帧缓冲区
		// https://zhuanlan.zhihu.com/p/339443207

		// 将rt赋值给 fxSourceId对应的纹理
		// 类似于copy(from, fxSourceId)
		buffer.SetGlobalTexture(fxSourceId, from);
		buffer.SetRenderTarget(
			to, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store
		);

		// 默认的bilt是绘制qurd的两个三角形，为了效率，这里程序绘制一个三角形
		buffer.DrawProcedural(
			Matrix4x4.identity, settings.Material, (int)pass,
			MeshTopology.Triangles, 3
		);
	}
}