import 'litertlm/runtime.dart';
import 'native/runtime.dart';

export 'litertlm/config.dart'
    show
        Backend,
        ConversationConfig,
        EngineConfig,
        LoraConfig,
        SamplerConfig,
        SessionConfig;
export 'litertlm/engine.dart' show Conversation, Engine;
export 'litertlm/exceptions.dart' show LiteRtLmException;
export 'litertlm/message.dart'
    show
        AudioBytesContent,
        AudioFileContent,
        Content,
        Contents,
        ImageBytesContent,
        ImageFileContent,
        Message,
        Role,
        TextContent,
        ToolCall,
        ToolResponseContent;
export 'litertlm/runtime.dart' show LogSeverity;
export 'litertlm/tool.dart' show Tool, ToolParameter, ToolParameterType;

void setMinimumLogLevel(LogSeverity severity) {
  LiteRtLmNativeRuntime.instance.setMinimumLogLevel(severity);
}
