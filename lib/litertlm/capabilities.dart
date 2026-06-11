import '../native/runtime.dart';
import 'exceptions.dart';

/// Provides information about capabilities supported by a LiteRT-LM file.
class Capabilities {
  /// Loads capability information for the LiteRT-LM model at [modelPath].
  Capabilities(this.modelPath)
    : _handle = LiteRtLmNativeRuntime.instance.createCapabilities(modelPath);

  /// The file path to the LiteRT-LM model.
  final String modelPath;

  CapabilitiesHandle? _handle;

  /// Whether these capabilities are still loaded.
  bool get isAlive => _handle != null;

  /// Whether the loaded LiteRT-LM file supports speculative decoding.
  bool hasSpeculativeDecodingSupport() {
    final handle = _handle;
    if (handle == null) {
      throw const LiteRtLmException('Capabilities is already disposed.');
    }
    return LiteRtLmNativeRuntime.instance.hasSpeculativeDecodingSupport(handle);
  }

  /// Releases loaded capability resources.
  Future<void> dispose() async {
    final handle = _handle;
    if (handle != null) {
      LiteRtLmNativeRuntime.instance.deleteCapabilities(handle);
      _handle = null;
    }
  }
}
