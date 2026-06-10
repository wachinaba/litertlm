package org.rockstudio.litertlm

import android.util.Base64
import com.google.ai.edge.litertlm.Backend
import com.google.ai.edge.litertlm.Content
import com.google.ai.edge.litertlm.Contents
import com.google.ai.edge.litertlm.Conversation
import com.google.ai.edge.litertlm.ConversationConfig
import com.google.ai.edge.litertlm.Engine
import com.google.ai.edge.litertlm.EngineConfig
import com.google.ai.edge.litertlm.ExperimentalApi
import com.google.ai.edge.litertlm.LogSeverity
import com.google.ai.edge.litertlm.LoraConfig
import com.google.ai.edge.litertlm.Message
import com.google.ai.edge.litertlm.MessageCallback
import com.google.ai.edge.litertlm.OpenApiTool
import com.google.ai.edge.litertlm.SamplerConfig
import com.google.ai.edge.litertlm.ToolCall
import com.google.ai.edge.litertlm.tool
import org.json.JSONArray
import org.json.JSONObject

object LiteRtLmJniBridge {
    @JvmStatic
    fun createEngine(
        modelPath: String,
        backend: String,
        visionBackend: String,
        audioBackend: String,
        maxNumTokens: Int,
        cacheDir: String,
    ): Engine {
        return Engine(
            EngineConfig(
                modelPath = modelPath,
                backend = parseBackend(backend),
                visionBackend = visionBackend.takeIf { it.isNotEmpty() }?.let(::parseBackend),
                audioBackend = audioBackend.takeIf { it.isNotEmpty() }?.let(::parseBackend),
                maxNumTokens = maxNumTokens.takeUnless { it == Int.MIN_VALUE },
                cacheDir = cacheDir.takeIf { it.isNotEmpty() },
            ),
        )
    }

    @JvmStatic
    fun initializeEngine(engine: Engine) {
        engine.initialize()
    }

    @JvmStatic
    fun createConversation(engine: Engine, configJson: String): Conversation {
        return engine.createConversation(parseConversationConfig(configJson))
    }

    @JvmStatic
    fun sendMessage(conversation: Conversation, messageJson: String, extraContextJson: String): String {
        val response = conversation.sendMessage(parseMessage(JSONObject(messageJson)), parseMap(extraContextJson))
        return messageToJson(response)
    }

    @JvmStatic
    fun sendMessageStream(
        conversation: Conversation,
        messageJson: String,
        extraContextJson: String,
        callback: MessageCallback,
    ) {
        conversation.sendMessageAsync(parseMessage(JSONObject(messageJson)), callback, parseMap(extraContextJson))
    }

    @JvmStatic
    fun messageToJson(message: Message): String {
        return JSONObject().apply {
            put("role", message.role.value)
            if (message.contents.contents.isNotEmpty()) {
                put("content", contentsToJson(message.contents))
            }
            if (message.toolCalls.isNotEmpty()) {
                put("tool_calls", JSONArray().apply {
                    for (toolCall in message.toolCalls) put(toolCallToJson(toolCall))
                })
            }
            if (message.channels.isNotEmpty()) {
                put("channels", JSONObject(message.channels))
            }
        }.toString()
    }

    @JvmStatic
    fun cancelConversation(conversation: Conversation) {
        conversation.cancelProcess()
    }

    @JvmStatic
    fun getTokenCount(conversation: Conversation): Int {
        return conversation.getTokenCount()
    }

    @JvmStatic
    @OptIn(ExperimentalApi::class)
    fun renderMessageToString(conversation: Conversation, messageJson: String): String {
        return conversation.renderMessageIntoString(parseMessage(JSONObject(messageJson)))
    }

    @JvmStatic
    fun deleteConversation(conversation: Conversation) {
        conversation.close()
    }

    @JvmStatic
    fun deleteEngine(engine: Engine) {
        engine.close()
    }

    @JvmStatic
    fun setMinimumLogLevel(level: Int) {
        Engine.setNativeMinLogSeverity(
            when {
                level <= 0 -> LogSeverity.VERBOSE
                level == 1 -> LogSeverity.DEBUG
                level == 2 -> LogSeverity.INFO
                level == 3 -> LogSeverity.WARNING
                level == 4 -> LogSeverity.ERROR
                level == 5 -> LogSeverity.FATAL
                else -> LogSeverity.INFINITY
            },
        )
    }

    private fun parseBackend(name: String): Backend {
        return when (name.lowercase()) {
            "gpu" -> Backend.GPU()
            "npu" -> Backend.NPU()
            else -> Backend.CPU()
        }
    }

    private fun parseConversationConfig(configJson: String): ConversationConfig {
        val json = JSONObject(configJson.ifBlank { "{}" })
        val systemMessage = json.optJSONObject("systemMessage")
        val loraPath = json.optString("loraPath").takeIf { it.isNotEmpty() }
        val audioLoraPath = json.optString("audioLoraPath").takeIf { it.isNotEmpty() }
        return ConversationConfig(
            systemInstruction = systemMessage?.let { parseMessage(it).contents },
            initialMessages = parseMessages(json.optJSONArray("initialMessages")),
            tools = parseTools(json.optJSONArray("tools")),
            extraContext = parseMap(json.optJSONObject("extraContext")),
            samplerConfig = json.optJSONObject("samplerConfig")?.let(::parseSamplerConfig),
            loraConfig = if (loraPath != null || audioLoraPath != null) {
                LoraConfig(loraPath = loraPath, audioLoraPath = audioLoraPath)
            } else {
                null
            },
            automaticToolCalling = false,
        )
    }

    private fun parseTools(json: JSONArray?): List<com.google.ai.edge.litertlm.ToolProvider> {
        if (json == null) return emptyList()
        return buildList {
            for (index in 0 until json.length()) {
                val wrapper = json.getJSONObject(index)
                val function = wrapper.optJSONObject("function") ?: wrapper
                add(tool(object : OpenApiTool {
                    override fun getToolDescriptionJsonString(): String = function.toString()

                    override fun execute(paramsJsonString: String): String =
                        JSONObject(mapOf("error" to "Dart tool execution is not automatic.")).toString()
                }))
            }
        }
    }

    private fun parseSamplerConfig(json: JSONObject): SamplerConfig {
        return SamplerConfig(
            topK = json.getInt("topK"),
            topP = json.getDouble("topP"),
            temperature = json.getDouble("temperature"),
            seed = json.optInt("seed", 0),
        )
    }

    private fun parseMessages(json: JSONArray?): List<Message> {
        if (json == null) return emptyList()
        return buildList {
            for (index in 0 until json.length()) {
                add(parseMessage(json.getJSONObject(index)))
            }
        }
    }

    private fun parseMessage(json: JSONObject): Message {
        val contents = parseContents(json.opt("content"))
        val toolCalls = parseToolCalls(json.optJSONArray("tool_calls"))
        val channels = parseStringMap(json.optJSONObject("channels"))
        return when (json.optString("role", "user")) {
            "system" -> Message.system(contents)
            "tool" -> Message.tool(contents)
            "model", "assistant" -> Message.model(contents, toolCalls, channels)
            else -> Message.user(contents)
        }
    }

    private fun parseContents(value: Any?): Contents {
        return when (value) {
            null, JSONObject.NULL -> Contents.of(emptyList())
            is String -> Contents.of(value)
            is JSONObject -> Contents.of(listOf(parseContent(value)))
            is JSONArray -> Contents.of(buildList {
                for (index in 0 until value.length()) {
                    add(parseContent(value.getJSONObject(index)))
                }
            })
            else -> Contents.of(value.toString())
        }
    }

    private fun parseContent(json: JSONObject): Content {
        return when (json.optString("type")) {
            "text" -> Content.Text(json.optString("text"))
            "image" -> if (json.has("blob")) {
                Content.ImageBytes(Base64.decode(json.getString("blob"), Base64.DEFAULT))
            } else {
                Content.ImageFile(json.optString("path"))
            }
            "audio" -> if (json.has("blob")) {
                Content.AudioBytes(Base64.decode(json.getString("blob"), Base64.DEFAULT))
            } else {
                Content.AudioFile(json.optString("path"))
            }
            "tool_response" -> Content.ToolResponse(
                name = json.optString("name"),
                response = jsonToValue(json.opt("response")),
            )
            else -> Content.Text(json.toString())
        }
    }

    private fun parseToolCalls(json: JSONArray?): List<ToolCall> {
        if (json == null) return emptyList()
        return buildList {
            for (index in 0 until json.length()) {
                val function = json.getJSONObject(index).optJSONObject("function") ?: continue
                add(ToolCall(function.optString("name"), parseMap(function.optJSONObject("arguments"))))
            }
        }
    }

    private fun parseMap(jsonString: String?): Map<String, Any> {
        if (jsonString.isNullOrBlank()) return emptyMap()
        return parseMap(JSONObject(jsonString))
    }

    private fun parseMap(json: JSONObject?): Map<String, Any> {
        if (json == null) return emptyMap()
        return buildMap {
            for (key in json.keys()) {
                val value = jsonToValue(json.get(key))
                if (value != null) put(key, value)
            }
        }
    }

    private fun parseStringMap(json: JSONObject?): Map<String, String> {
        if (json == null) return emptyMap()
        return buildMap {
            for (key in json.keys()) {
                put(key, json.optString(key))
            }
        }
    }

    private fun jsonToValue(value: Any?): Any? {
        return when (value) {
            null, JSONObject.NULL -> null
            is JSONObject -> parseMap(value)
            is JSONArray -> buildList {
                for (index in 0 until value.length()) add(jsonToValue(value.get(index)))
            }
            else -> value
        }
    }

    private fun contentsToJson(contents: Contents): JSONArray {
        return JSONArray().apply {
            for (content in contents.contents) put(contentToJson(content))
        }
    }

    private fun contentToJson(content: Content): JSONObject {
        return when (content) {
            is Content.Text -> JSONObject(mapOf("type" to "text", "text" to content.text))
            is Content.ImageBytes -> JSONObject(
                mapOf("type" to "image", "blob" to Base64.encodeToString(content.bytes, Base64.NO_WRAP)),
            )
            is Content.ImageFile -> JSONObject(mapOf("type" to "image", "path" to content.absolutePath))
            is Content.AudioBytes -> JSONObject(
                mapOf("type" to "audio", "blob" to Base64.encodeToString(content.bytes, Base64.NO_WRAP)),
            )
            is Content.AudioFile -> JSONObject(mapOf("type" to "audio", "path" to content.absolutePath))
            is Content.ToolResponse -> JSONObject().apply {
                put("type", "tool_response")
                put("name", content.name)
                put("response", toJsonValue(content.response))
            }
        }
    }

    private fun toolCallToJson(toolCall: ToolCall): JSONObject {
        return JSONObject().apply {
            put("type", "function")
            put("function", JSONObject().apply {
                put("name", toolCall.name)
                put("arguments", toJsonValue(toolCall.arguments))
            })
        }
    }

    private fun toJsonValue(value: Any?): Any? {
        return when (value) {
            null -> JSONObject.NULL
            is Map<*, *> -> JSONObject().apply {
                for ((key, item) in value) put(key.toString(), toJsonValue(item))
            }
            is Iterable<*> -> JSONArray().apply {
                for (item in value) put(toJsonValue(item))
            }
            else -> value
        }
    }
}