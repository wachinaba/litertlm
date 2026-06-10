import 'litertlm/runtime.dart';
import 'native/runtime.dart';

export 'litertlm/config.dart'
    show Backend, ConversationConfig, EngineConfig, SamplerConfig;
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
export 'litertlm/tool.dart' show Tool, ToolManager;

/// Sets the minimum log level for the LiteRT-LM library.
void setMinimumLogLevel(LogSeverity severity) {
  LiteRtLmNativeRuntime.instance.setMinimumLogLevel(severity);
}
