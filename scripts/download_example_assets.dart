import 'dart:io';
import 'dart:isolate';

const _liteRtLmVersion = 'v0.13.1';
const _baseUrl =
    'https://raw.githubusercontent.com/google-ai-edge/LiteRT-LM/$_liteRtLmVersion';
const _gemma4BaseUrl =
    'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main';
const _assets = [
  (
    url: '$_baseUrl/runtime/testdata/test_lm.litertlm',
    path: 'example/assets/models/test_lm.litertlm',
  ),
  (
    url: '$_gemma4BaseUrl/gemma-4-E2B-it.litertlm',
    path: 'example/assets/models/gemma-4-E2B-it.litertlm',
  ),
  (
    url: '$_gemma4BaseUrl/gemma-4-E2B-it-web.litertlm',
    path: 'example/assets/models/gemma-4-E2B-it-web.litertlm',
  ),
  (
    url: '$_baseUrl/runtime/components/preprocessor/testdata/apple.png',
    path: 'example/assets/images/apple.png',
  ),
  (
    url: '$_baseUrl/runtime/testdata/have_a_wonderful_day.wav',
    path: 'example/assets/audio/have_a_wonderful_day.wav',
  ),
];

Future<void> main() async {
  final scriptUri =
      await Isolate.resolvePackageUri(Platform.script) ?? Platform.script;
  final client = HttpClient();
  try {
    for (final asset in _assets) {
      final url = Uri.parse(asset.url);
      final file = File.fromUri(scriptUri.resolve('../${asset.path}'));
      await file.parent.create(recursive: true);

      final request = await client.getUrl(url);
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Failed to download ${asset.url}', uri: url);
      }
      await response.pipe(file.openWrite());
    }
  } finally {
    client.close();
  }
}
