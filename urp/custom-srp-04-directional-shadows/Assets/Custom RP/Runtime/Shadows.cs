using UnityEngine;
using UnityEngine.Rendering;

public class Shadows {

    const string bufferName = "Shadows";

    // 为了效率考虑，最大允许4个平行光光源可以产出shadow
    const int maxShadowedDirLightCount = 4;

    // 最大级联
    const int maxCascades = 4;

    static string[] directionalFilterKeywords = {
        "_DIRECTIONAL_PCF3",
        "_DIRECTIONAL_PCF5",
        "_DIRECTIONAL_PCF7",
    };

    static string[] cascadeBlendKeywords = {
        "_CASCADE_BLEND_SOFT",
        "_CASCADE_BLEND_DITHER"
    };

    static int
        // 这个shadowmap的atlas是所有shadowlight的rt,而且每个shadowlight都有自己的级联数
        dirShadowAtlasId = Shader.PropertyToID("_DirectionalShadowAtlas"),
        dirShadowMatricesId = Shader.PropertyToID("_DirectionalShadowMatrices"),

        cascadeCountId = Shader.PropertyToID("_CascadeCount"),
        cascadeCullingSpheresId = Shader.PropertyToID("_CascadeCullingSpheres"),
        cascadeDataId = Shader.PropertyToID("_CascadeData"),
        shadowAtlasSizeId = Shader.PropertyToID("_ShadowAtlasSize"),
        shadowDistanceFadeId = Shader.PropertyToID("_ShadowDistanceFade");

    static Vector4[] cascadeCullingSpheres = new Vector4[maxCascades];
    static Vector4[] cascadeData = new Vector4[maxCascades];
    static Matrix4x4[] dirShadowMatrices = new Matrix4x4[maxShadowedDirLightCount * maxCascades];

    struct ShadowedDirectionalLight {
        public int visibleLightIndex;
        public float slopeScaleBias;
        public float nearPlaneOffset;
    }

    private int shadowedDirLightCount;
    private ShadowedDirectionalLight[] shadowedDirectionalLights = new ShadowedDirectionalLight[maxShadowedDirLightCount];

    CommandBuffer buffer = new CommandBuffer {
        name = bufferName
    };

    ScriptableRenderContext context;
    CullingResults cullingResults;
    ShadowSettings settings;

    public void Setup (
        ScriptableRenderContext context, CullingResults cullingResults,
        ShadowSettings settings
    ) {
        this.context = context;
        this.cullingResults = cullingResults;
        this.settings = settings;

        // 重置
        shadowedDirLightCount = 0;
    }

    public void Cleanup () {
        // 释放shadowmap 纹理
        buffer.ReleaseTemporaryRT(dirShadowAtlasId);
        ExecuteBuffer();
    }

    // 保留shadowlight
    public Vector3 ReserveDirectionalShadows (Light light, int visibleLightIndex) {
        if (
            shadowedDirLightCount < maxShadowedDirLightCount &&
            light.shadows != LightShadows.None && light.shadowStrength > 0f &&
            // 有可能出现light只影响到了maxShadowDistance外的渲染对象
            cullingResults.GetShadowCasterBounds(visibleLightIndex, out Bounds b)
        ) {
            shadowedDirectionalLights[shadowedDirLightCount] = new ShadowedDirectionalLight {visibleLightIndex = visibleLightIndex, slopeScaleBias = light.shadowBias, nearPlaneOffset = light.shadowNearPlane };
            // 1. 阴影强度
            // 2. tileIndexStartIndex
            // 3. 阴影法线偏移
            return new Vector3(light.shadowStrength, settings.directional.cascadeCount * shadowedDirLightCount++, light.shadowNormalBias);
        }
        return Vector3.zero;
    }

    public void Render () {
        if (shadowedDirLightCount > 0) {
            RenderDirectionalShadows();
        }
        else {
            // https://catlikecoding.com/unity/tutorials/custom-srp/directional-shadows/
            // 为什么还需要申请dummy的shadowmap呢？
            // 在webgl2.0情况下，如果material不提供纹理的话，会失败
            buffer.GetTemporaryRT(dirShadowAtlasId, 1, 1, 32, FilterMode.Bilinear, RenderTextureFormat.Shadowmap);
        }
    }

    void RenderDirectionalShadows () {
        int atlasSize = (int)settings.directional.atlasSize;
        // 动态创建shadowmap的矩形纹理
        buffer.GetTemporaryRT(dirShadowAtlasId, atlasSize, atlasSize, 32, FilterMode.Bilinear, RenderTextureFormat.Shadowmap);

        // 设置shadowmap为rendertarget,这样子之后的rendertarget就不是相机了。
        buffer.SetRenderTarget(dirShadowAtlasId, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store);
        // 因为只需要depth
        buffer.ClearRenderTarget(true, false, Color.clear);

        #region 形成一个块
        buffer.BeginSample(bufferName);
        ExecuteBuffer();

        // shadowmap分块总块数
        // 因为允许的最大shadowedDirLightCount就是4，而且允许的最大cascadeCount也是4，也就是最大允许16
        // 那么最多就按照每行4个切块， 否则就是每行2个，否则就是每行1个
        // 因为是矩形要求，所以只能是2的幂次
        int tiles = shadowedDirLightCount * settings.directional.cascadeCount;

        // atlas中每行几个
        // 比如2light * 3cascade, 还是atlas中每行4个
        int countPerLine = tiles <= 1 ? 1 : tiles <= 4 ? 2 : 4;
        int tileSize = atlasSize / countPerLine;

        for (int i = 0; i < shadowedDirLightCount; i++) {
            // 每个shadowlight都渲染一次shadowmap
            //string name = "DirShadowLight:" + i.ToString();
            //buffer.BeginSample(name);

            RenderDirectionalShadows(i, countPerLine, tileSize);

            //buffer.EndSample(name);
        }

        buffer.SetGlobalInt(cascadeCountId, settings.directional.cascadeCount);
        buffer.SetGlobalVectorArray(cascadeCullingSpheresId, cascadeCullingSpheres);
        buffer.SetGlobalVectorArray(cascadeDataId, cascadeData);
        buffer.SetGlobalMatrixArray(dirShadowMatricesId, dirShadowMatrices);

        float f = 1f - settings.directional.cascadeFade;
        buffer.SetGlobalVector(shadowDistanceFadeId, new Vector4(1f / settings.maxDistance, 1f / settings.distanceFade, 1f / (1f - f * f)));
        SetKeywords(directionalFilterKeywords, (int)settings.directional.filter - 1);
        SetKeywords(cascadeBlendKeywords, (int)settings.directional.cascadeBlend - 1);
        buffer.SetGlobalVector(shadowAtlasSizeId, new Vector4(atlasSize, 1f / atlasSize));

        buffer.EndSample(bufferName);
        #endregion

        ExecuteBuffer();
    }

    void SetKeywords (string[] keywords, int enabledIndex) {
        for (int i = 0; i < keywords.Length; i++) {
            if (i == enabledIndex) {
                buffer.EnableShaderKeyword(keywords[i]);
            }
            else {
                buffer.DisableShaderKeyword(keywords[i]);
            }
        }
    }

    void RenderDirectionalShadows (int lightIndex, int countPerLine, int tileSize) {
        ShadowedDirectionalLight light = shadowedDirectionalLights[lightIndex];
        var shadowSettings = new ShadowDrawingSettings(cullingResults, light.visibleLightIndex);
        int cascadeCount = settings.directional.cascadeCount;
        int startTileIndexOfThisLight = lightIndex * cascadeCount;
        Vector3 ratios = settings.directional.CascadeRatios;
        float cullingFactor = Mathf.Max(0f, 0.8f - settings.directional.cascadeFade);

        // 每个光源的每个级联都要渲染一次shadowmap,而每个级联的vp矩阵肯定不一样
        // 2light * 3cascade，atlas中每行4个
        for (int i = 0; i < cascadeCount; i++) {
            // 计算投影的时候，需要将一个虚拟camera放置到光源位置，得到相关vp矩阵
            cullingResults.ComputeDirectionalShadowMatricesAndCullingPrimitives(
                light.visibleLightIndex, i, cascadeCount, ratios, tileSize,
                light.nearPlaneOffset, out Matrix4x4 viewMatrix, out Matrix4x4 projectionMatrix, out ShadowSplitData splitData);

            splitData.shadowCascadeBlendCullingFactor = cullingFactor;

            shadowSettings.splitData = splitData;

            // 每个光源的cull球设置都是一样的，所以后续光源不需要重复设置
            // 因为cullsphere其实是针对相机设置的，而不是光源设置的
            // cascadeCullingSpheres是从cascadeIndex == 0开始的， 所以判断某个vertex在哪个sphere中
            // 就是从cascadeIndex == 0开始，这样子就避免了 两个sphere有重叠区域，而在重叠区域的vertex到底属于哪个sphere的问题
            // 始终属于cascadeIndex小的
            if (lightIndex == 0) {
                SetCascadeData(i, splitData.cullingSphere, tileSize);
            }
            int tileIndex = startTileIndexOfThisLight + i;
            // 将shadowmap中每cascade映射到一个个矩形区间中
            var viewport = SetTileViewport(tileIndex, countPerLine, tileSize);
            // 从光源的ws->ss 转换为 光源的ws->某个tile的ss, 其实我以为设置了Viewport就可以了，其实不行
            // viewport可能是一个很大的sreen隐射到一个小区域，而设置vp矩阵则可以控制原始screen的大小
            dirShadowMatrices[tileIndex] = ConvertToAtlasMatrix(projectionMatrix * viewMatrix, viewport, countPerLine);
            // 设置每个级联的vp矩阵，需要结合上下文，这里是针对shadow的cascade, 也可以用于其他上下文环境中。
            // 比如设置相机的vp为UI相机的vp
            buffer.SetViewProjectionMatrices(viewMatrix, projectionMatrix);
            // 设置depthBias,而不是normalBias
            // 而且是每个光源都会重新设置一次，因为每一个光源light的设置不一样
            // light.slopeScaleBias其实是个斜率
            buffer.SetGlobalDepthBias(0f, light.slopeScaleBias);
            ExecuteBuffer();

            //string cascadeLevel = "Cascade:" + i.ToString();
            //buffer.BeginSample(cascadeLevel);
            // 阴影绘制核心操作,只对于shadowcasterpass的物体有效
            context.DrawShadows(ref shadowSettings);
            //buffer.EndSample(cascadeLevel);

            // 还原DepthBias
            buffer.SetGlobalDepthBias(0f, 0f);
        }
    }

    void SetCascadeData (int cascadeIndex, Vector4 cullingSphere, float tileSize) {
        float texelSize = 2f * cullingSphere.w / tileSize;
        float filterSize = texelSize * ((float)settings.directional.filter + 1f);
        // 因为不同的pcf情况下，会存在seldshadow, 所以这里需要考虑filterSize
        cullingSphere.w -= filterSize;
        // 保留球体 r半径平方
        cullingSphere.w *= cullingSphere.w;
        cascadeCullingSpheres[cascadeIndex] = cullingSphere;
        cascadeData[cascadeIndex] = new Vector4(1f / cullingSphere.w, filterSize * 1.4142136f);
    }

    // worldspace -> shadowspace
    // (Mvp->s * VP) -> shadowspace
    // 世界空间中的位置在阴影贴图中的纹理坐标, shadowmap是个atlas,所以还需要知道uv信息
    // vp矩阵将positionWS转换到ndc中， 这个矩阵将positionWS转换到size=1的CUBE区域中的某个tile块中
    // 也可以理解为转换到shadowspace
    Matrix4x4 ConvertToAtlasMatrix (Matrix4x4 m, Vector2 offset, int countPerLine) {
        if (SystemInfo.usesReversedZBuffer) {
            m.m20 = -m.m20;
            m.m21 = -m.m21;
            m.m22 = -m.m22;
            m.m23 = -m.m23;
        }
        float scale = 1f / countPerLine;
        m.m00 = (0.5f * (m.m00 + m.m30) + offset.x * m.m30) * scale;
        m.m01 = (0.5f * (m.m01 + m.m31) + offset.x * m.m31) * scale;
        m.m02 = (0.5f * (m.m02 + m.m32) + offset.x * m.m32) * scale;
        m.m03 = (0.5f * (m.m03 + m.m33) + offset.x * m.m33) * scale;
        m.m10 = (0.5f * (m.m10 + m.m30) + offset.y * m.m30) * scale;
        m.m11 = (0.5f * (m.m11 + m.m31) + offset.y * m.m31) * scale;
        m.m12 = (0.5f * (m.m12 + m.m32) + offset.y * m.m32) * scale;
        m.m13 = (0.5f * (m.m13 + m.m33) + offset.y * m.m33) * scale;
        m.m20 = 0.5f * (m.m20 + m.m30);
        m.m21 = 0.5f * (m.m21 + m.m31);
        m.m22 = 0.5f * (m.m22 + m.m32);
        m.m23 = 0.5f * (m.m23 + m.m33);
        return m;
    }

    Vector2 SetTileViewport (int index, int countPerLine, float tileSize) {
        // 二维数组的行列
        int row = index / countPerLine;
        int col = index % countPerLine;
        Vector2 offset = new Vector2(col, row);
        // 这个结果计算出来应该是旋转90的吧！！！
        // qustion??? 这个结果计算出来应该是旋转90的吧！！！
        buffer.SetViewport(new Rect(offset.x * tileSize, offset.y * tileSize, tileSize, tileSize));
        return offset;
    }

    void ExecuteBuffer () {
        context.ExecuteCommandBuffer(buffer);
        buffer.Clear();
    }
}
