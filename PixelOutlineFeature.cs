// Assets/Scripts/PixelOutlineFeature.cs
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.RenderGraphModule.Util;

public class PixelOutlineFeature : ScriptableRendererFeature
{
    [System.Serializable]
    public class Settings
    {
        public RenderPassEvent renderPassEvent = RenderPassEvent.AfterRenderingPostProcessing;
        public Material material;

        [Header("===== CAMERA =====")]
        [Tooltip("Kapalıysa Scene View'da efekt uygulanmaz")]
        public bool applyToSceneView = false;

        [Header("===== PIXELIZATION =====")]
        [Range(1, 32)] public int pixelSize = 4;

        [Header("===== COLOR =====")]
        [Range(2, 64)] public int colorCount = 16;
        [Range(0f, 2f)] public float saturation = 1f;
        [Range(0.5f, 2f)] public float contrast = 1f;
        [Range(0.5f, 2f)] public float brightness = 1f;

        [Header("===== DITHERING =====")]
        public bool enableDithering = true;
        [Range(0f, 1f)] public float ditherStrength = 0.5f;

        [Header("===== OUTLINE =====")]
        public bool enableOutline = true;
        [Range(0.5f, 4f)] public float outlineThickness = 1f;
        public Color outlineColor = Color.black;
        [Range(0.01f, 0.5f)] public float depthThreshold = 0.05f;
    }

    public Settings settings = new Settings();

    class PixelOutlinePass : ScriptableRenderPass
    {
        public Settings settings;
        public Material material;

        public PixelOutlinePass(Settings settings)
        {
            this.settings = settings;
            this.material = settings.material;
            renderPassEvent = settings.renderPassEvent;
        }

        public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
        {
            if (material == null) return;

            var resourceData = frameData.Get<UniversalResourceData>();
            var cameraData = frameData.Get<UniversalCameraData>();

            // SCENE VIEW KONTROLÜ
            if (!settings.applyToSceneView)
            {
                if (cameraData.cameraType == CameraType.SceneView)
                {
                    return;
                }
            }

            if (resourceData.isActiveTargetBackBuffer) return;

            TextureHandle source = resourceData.activeColorTexture;

            var desc = renderGraph.GetTextureDesc(source);
            desc.name = "_PixelOutlineTempTexture";
            desc.clearBuffer = false;
            TextureHandle tempTexture = renderGraph.CreateTexture(desc);

            material.SetFloat("_PixelSize", settings.pixelSize);
            material.SetFloat("_ColorCount", settings.colorCount);
            material.SetFloat("_Saturation", settings.saturation);
            material.SetFloat("_Contrast", settings.contrast);
            material.SetFloat("_Brightness", settings.brightness);
            material.SetFloat("_EnableDithering", settings.enableDithering ? 1f : 0f);
            material.SetFloat("_DitherStrength", settings.ditherStrength);
            material.SetFloat("_EnableOuterOutline", settings.enableOutline ? 1f : 0f);
            material.SetFloat("_OuterOutlineThickness", settings.outlineThickness);
            material.SetColor("_OuterOutlineColor", settings.outlineColor);
            material.SetFloat("_DepthThreshold", settings.depthThreshold);

            var blitParams = new RenderGraphUtils.BlitMaterialParameters(source, tempTexture, material, 0);
            renderGraph.AddBlitPass(blitParams, "PixelOutlineEffect");

            renderGraph.AddBlitPass(tempTexture, source, Vector2.one, Vector2.zero);
        }
    }

    private PixelOutlinePass pass;

    public override void Create()
    {
        pass = new PixelOutlinePass(settings);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (settings.material == null) return;

        // BURADA DA KONTROL
        if (!settings.applyToSceneView)
        {
            if (renderingData.cameraData.cameraType == CameraType.SceneView)
            {
                return;
            }
        }

        pass.settings = settings;
        pass.material = settings.material;
        renderer.EnqueuePass(pass);
    }
}