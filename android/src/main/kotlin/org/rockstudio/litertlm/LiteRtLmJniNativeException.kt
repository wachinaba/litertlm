package org.rockstudio.litertlm

class LiteRtLmJniNativeException(
    val code: Int,
    val operation: Int,
) : RuntimeException()