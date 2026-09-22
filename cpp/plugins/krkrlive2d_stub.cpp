// Optional Live2D plugin anchor. The actual Cubism implementation is added
// when the complete Framework/Core SDK is present in cpp/plugins/cubism.
struct Live2DRenderTarget {
    unsigned int fbo;
    int width;
    int height;
};

// Keep the GLES compositor linkable when the optional Cubism SDK is absent.
// Zero means that krkrgles uses its ordinary framebuffer readback path.
Live2DRenderTarget g_live2dRenderTarget = {};

extern "C" void TVPRegisterKrkrLive2DPluginAnchor() {}
