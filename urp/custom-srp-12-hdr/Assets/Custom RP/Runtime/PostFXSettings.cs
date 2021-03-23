using UnityEngine;

[CreateAssetMenu(menuName = "Rendering/Custom Post FX Settings")]
public class PostFXSettings : ScriptableObject {

	[SerializeField]
	Shader shader = default;

	#region BloomSettings

	[System.Serializable]
	public struct BloomSettings {

		[Range(0f, 16f)]
		public int maxIterations;

		[Min(1f)]
		public int downscaleLimit;	 // 下采样最小rt纹理限制

		public bool bicubicUpsampling;	// 是否使用三线性采样得到模糊

		[Min(0f)]
		public float threshold;

		[Range(0f, 1f)]
		public float thresholdKnee;

		[Min(0f)]
		public float intensity;

		public bool fadeFireflies;	// 消除hdr导致的萤火虫，需要fade配合blur

		public enum Mode { Additive, Scattering }

		public Mode mode;

		[Range(0.05f, 0.95f)]
		public float scatter;
	}

	[SerializeField]
	BloomSettings bloom = new BloomSettings {
		scatter = 0.7f
	};

	public BloomSettings Bloom => bloom;
	#endregion

	#region  ToneMappingSettings

	[System.Serializable]
	public struct ToneMappingSettings {

		public enum Mode { None = -1, ACES, Neutral, Reinhard }

		public Mode mode;
	}

	[SerializeField]
	ToneMappingSettings toneMapping = default;

	public ToneMappingSettings ToneMapping => toneMapping;

	#endregion

	[System.NonSerialized]
	Material material;

	public Material Material {
		get {
			if (material == null && shader != null) {
				material = new Material(shader);
				material.hideFlags = HideFlags.HideAndDontSave;
			}
			return material;
		}
	}
}