import 'dart:convert';
import 'dart:typed_data';

/// Input data for the lower-level LiteRT-LM session API.
sealed class InputData {
  /// Creates input data.
  const InputData();

  /// Text input.
  factory InputData.text(String text) = TextInputData;

  /// Image input bytes. Supported formats depend on the model, commonly PNG
  /// and JPEG.
  factory InputData.imageBytes(Uint8List bytes) = ImageInputData;

  /// Audio input bytes. Supported formats depend on the model, commonly WAV.
  factory InputData.audioBytes(Uint8List bytes) = AudioInputData;

  /// Converts this input data to JSON-compatible values.
  Map<String, Object?> toJson();
}

/// Text input data.
class TextInputData extends InputData {
  /// Creates text input data.
  const TextInputData(this.text);

  /// The text value.
  final String text;

  @override
  Map<String, Object?> toJson() => {'type': 'text', 'text': text};
}

/// Image input data.
class ImageInputData extends InputData {
  /// Creates image input data.
  const ImageInputData(this.bytes);

  /// The image bytes.
  final Uint8List bytes;

  @override
  Map<String, Object?> toJson() => {
    'type': 'image',
    'blob': base64Encode(bytes),
  };
}

/// Audio input data.
class AudioInputData extends InputData {
  /// Creates audio input data.
  const AudioInputData(this.bytes);

  /// The audio bytes.
  final Uint8List bytes;

  @override
  Map<String, Object?> toJson() => {
    'type': 'audio',
    'blob': base64Encode(bytes),
  };
}
