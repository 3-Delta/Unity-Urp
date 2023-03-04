using System;
using System.Linq;
using UnityEngine;
using UnityEngine.Rendering;
using Unity.Collections;

public class DrawCascade : MonoBehaviour {
    public ShadowSettings shadowSettings;
    
    public Camera cam;
    public Light dirLight;

    private ScriptableRenderContext context;
    private CullingResults cullingResults;

    private int countPerLine;
    private int tileSize;
    private bool hasInitContext = false;
    
    protected void OnEnable() {
        int tileCount = shadowSettings.directional.cascadeCount;
        countPerLine = tileCount <= 1 ? 1 : tileCount <= 4 ? 2 : 4;
        tileSize = (int) shadowSettings.directional.atlasSize / countPerLine;
        
        hasInitContext = false;
        RenderPipelineManager.beginCameraRendering += OnBeginCameraRender;
        RenderPipelineManager.endCameraRendering += OnEndCameraRender;
    }

    protected void OnDisable() {
        RenderPipelineManager.beginCameraRendering -= OnBeginCameraRender;
        RenderPipelineManager.endCameraRendering -= OnEndCameraRender;
        hasInitContext = false;
    }

    private void OnDrawGizmos() {
        if (shadowSettings == null || cam == null || dirLight == null || !hasInitContext) {
            return;
        }
        
        if (cam.TryGetCullingParameters(out ScriptableCullingParameters cullingParams)) {
            cullingParams.shadowDistance = Mathf.Min(shadowSettings.maxDistance, this.cam.farClipPlane);
            cullingResults = this.context.Cull(ref cullingParams);

            NativeArray<VisibleLight> visibleLights = cullingResults.visibleLights;
            int visibleLightIndex = -1;
            for (int i = 0; i < visibleLights.Length; ++i) {
                if (visibleLights[i].light == this.dirLight) {
                    visibleLightIndex = i;
                    break;
                }
            }

            if (visibleLightIndex == -1) {
                return;
            }
            
            int cascadeCount = shadowSettings.directional.cascadeCount;
            for (int i = 0; i < cascadeCount; ++i) {
                cullingResults.ComputeDirectionalShadowMatricesAndCullingPrimitives(visibleLightIndex, i, cascadeCount, 
                    this.shadowSettings.directional.CascadeRatios,
                    tileSize, 
                    // https://edu.uwa4d.com/lesson-detail/282/1311/0?isPreview=0
                    // 影响unity阴影平坠的shadowmap的形成
                    dirLight.shadowNearPlane,
                    // 每个级联的矩阵都不一样， 两个light的同一个级联的矩阵也不一样
                    out Matrix4x4 viewMatrix, out Matrix4x4 projMatrix, out ShadowSplitData splitData);

                var sphere = splitData.cullingSphere;
                var nearPlane = cullingParams.GetCullingPlane(i);
                Gizmos.DrawWireSphere(sphere, sphere.w);
                Gizmos.DrawFrustum(cam.transform.position, cam.fieldOfView, nearPlane.distance, cam.nearClipPlane, cam.aspect);
            }
        }
    }

    protected void OnBeginCameraRender(ScriptableRenderContext context, Camera camera) {
        this.context = context;
        hasInitContext = true;
    }
    protected void OnEndCameraRender(ScriptableRenderContext context, Camera camera) {
        this.context = context;
        hasInitContext = true;
    }
}
