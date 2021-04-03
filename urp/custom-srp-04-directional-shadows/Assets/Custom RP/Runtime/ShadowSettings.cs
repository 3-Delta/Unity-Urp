using UnityEngine;

[System.Serializable]
public class ShadowSettings {
	// shadow大纹理size
	public enum MapSize {
		_256 = 256,
		_512 = 512, 
		_1024 = 1024,
		_2048 = 2048,
		_4096 = 4096,
		_8192 = 8192
	}

	public enum FilterMode {
		PCF2x2,
		PCF3x3, 
		PCF5x5, 
		PCF7x7
	}

	[Min(0.001f)]
	public float maxDistance = 100f;   // 针对相机，不是光源，而且不是到相机位置的距离， 而是cameraview的depth，简单理解就是到camera的nearplane的距离

	[Range(0.001f, 1f)]
	public float distanceFade = 0.1f; // 超出最大距离的阴影渐变

	[System.Serializable]
	public struct Directional {

		public MapSize atlasSize;  // shadowmap是一张atlas

		public FilterMode filter;

		[Range(1, 4)]
		public int cascadeCount;

		[Range(0f, 1f)]
		public float cascadeRatio1, cascadeRatio2, cascadeRatio3;

		public Vector3 CascadeRatios => new Vector3(cascadeRatio1, cascadeRatio2, cascadeRatio3);

		[Range(0.001f, 1f)]
		public float cascadeFade; // 级联变化的渐变

		public enum CascadeBlendMode {
			Hard, Soft, Dither
		}

		public CascadeBlendMode cascadeBlend;
	}

	public Directional directional = new Directional {
		atlasSize = MapSize._1024,
		filter = FilterMode.PCF2x2,
		cascadeCount = 4,
		cascadeRatio1 = 0.1f,
		cascadeRatio2 = 0.25f,
		cascadeRatio3 = 0.5f,
		cascadeFade = 0.1f,
		cascadeBlend = Directional.CascadeBlendMode.Hard
	};
}
