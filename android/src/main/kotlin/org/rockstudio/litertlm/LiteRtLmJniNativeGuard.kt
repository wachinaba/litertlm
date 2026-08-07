package org.rockstudio.litertlm

internal object LiteRtLmJniNativeGuard {
    init {
        Class.forName("com.google.ai.edge.litertlm.LiteRtLmJni")
        System.loadLibrary("litertlm_jni_guard")
    }

    @JvmStatic
    external fun install()
}