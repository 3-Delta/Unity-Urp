using UnityEngine;

// framedebugger dc 78
// 数据统计面板：batchs:77, save:0, setpass:30
// gpuinstance off && srpbatcher off && dynamicBatch off
// 红色不透明物体 Unlit Red Opaque						rq: 2000  因为没有开启dynamicBatch, 所以一个一个绘制
// 绿色不透明物体 Unlit Green Opaque						rq: 2000  因为没有开启dynamicBatch, 所以一个一个绘制
// PerObjectMaterialProperties物体 Instancing Clip		rq: 2450  因为不同的MaterialPropertyBlock set，所以一个一个绘制
// 蓝色alphatest Unlit Blue Clip							rq: 2450  因为没有开启dynamicBatch, 所以一个一个绘制
// Graphics.DrawMeshInstanced不生效，因为	gpuinstance没有启用

// framedebugger dc 78
// 数据统计面板：batchs:77, save:0, setpass:30
// gpuinstance off && srpbatcher off && dynamicBatch on
// 红色不透明物体 Unlit Red Opaque						rq: 2000  因为mesh超过300个vertex,不能batch
// 绿色不透明物体 Unlit Green Opaque						rq: 2000  因为mesh超过300个vertex,不能batch
// PerObjectMaterialProperties物体 Instancing Clip		rq: 2450  因为不同的MaterialPropertyBlock set，所以一个一个绘制
// 蓝色alphatest Unlit Blue Clip							rq: 2450  因为mesh超过300个vertex,不能batch
// Graphics.DrawMeshInstanced不生效，因为	gpuinstance没有启用

// 将mesh从sphere球形修改为cube,为了减少vertex300限制发现
// 数据统计面板：batchs:30, save:47, setpass:31
// 减少dc, 不减少setpasscall也就是sc

// framedebugger dc 58
// 数据统计面板：batchs:57, save:1043, setpass:7
// gpuinstance on && srpbatcher off && dynamicBatch off
// 红色不透明物体 Unlit Red Opaque						rq: 2000  因为mesh超过300个vertex,不能batch
// 绿色不透明物体 Unlit Green Opaque						rq: 2000  因为mesh超过300个vertex,不能batch
// PerObjectMaterialProperties物体 Instancing Clip		rq: 2450  因为不同的MaterialPropertyBlock set，所以一个一个绘制
// 蓝色alphatest Unlit Blue Clip							rq: 2450  因为mesh超过300个vertex,不能batch
// Graphics.DrawMeshInstanced生效
// instance 减少dc【因为存在dynamic的成分】, 如果配合materialblock的时候，还能减少sc. 
[DisallowMultipleComponent]
public class PerObjectMaterialProperties : MonoBehaviour {

	static int baseColorId = Shader.PropertyToID("_BaseColor");
	static int cutoffId = Shader.PropertyToID("_Cutoff");

	static MaterialPropertyBlock block;

	[SerializeField]
	Color baseColor = Color.white;

	[SerializeField, Range(0f, 1f)]
	float alphaCutoff = 0.5f;

	void Awake () {
		OnValidate();
	}

	void OnValidate () {
		if (block == null) {
			block = new MaterialPropertyBlock();
		}
		block.SetColor(baseColorId, baseColor);
		block.SetFloat(cutoffId, alphaCutoff);
		GetComponent<Renderer>().SetPropertyBlock(block);
	}
}