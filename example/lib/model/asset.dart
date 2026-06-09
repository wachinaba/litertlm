import 'asset_web.dart' if (dart.library.io) 'asset_io.dart' as platform;

Future<String> resolveModelAssetPath(String assetPath) =>
    platform.resolveModelAssetPath(assetPath);