import '../native/runtime.dart';

/// Experimental flags for LiteRT-LM.
///
/// These flags guard APIs that are not yet considered mature and may change or
/// be removed without notice.
final class ExperimentalFlags {
  const ExperimentalFlags._();

  /// Whether benchmark collection is enabled.
  ///
  /// This flag is read when a new [Engine] is created. Changing this value does
  /// not affect existing [Engine] or [Conversation] instances.
  static bool get enableBenchmark =>
      LiteRtLmNativeRuntime.instance.enableBenchmark;

  static set enableBenchmark(bool value) {
    LiteRtLmNativeRuntime.instance.enableBenchmark = value;
  }

  /// Whether speculative decoding is enabled.
  ///
  /// If null, uses the model default. If true, enables speculative decoding; an
  /// error is thrown if the model does not support it. If false, disables
  /// speculative decoding.
  ///
  /// This flag is read when a new [Engine] is created. Changing this value does
  /// not affect existing [Engine] or [Conversation] instances.
  static bool? get enableSpeculativeDecoding =>
      LiteRtLmNativeRuntime.instance.enableSpeculativeDecoding;

  static set enableSpeculativeDecoding(bool? value) {
    LiteRtLmNativeRuntime.instance.enableSpeculativeDecoding = value;
  }

  /// Whether conversation constrained decoding is enabled.
  ///
  /// This is primarily used for function calling.
  ///
  /// This flag is read when a new [Conversation] is created. Changing this
  /// value does not affect existing [Conversation] instances.
  static bool get enableConversationConstrainedDecoding =>
      LiteRtLmNativeRuntime.instance.enableConversationConstrainedDecoding;

  static set enableConversationConstrainedDecoding(bool value) {
    LiteRtLmNativeRuntime.instance.enableConversationConstrainedDecoding =
        value;
  }
}
