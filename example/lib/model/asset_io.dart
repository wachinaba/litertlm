import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

Future<String> resolveModelAssetPath(String assetPath) async {
  if (Platform.isAndroid) {
    final supportDirectory = await getApplicationSupportDirectory();
    final file = File('${supportDirectory.path}/${_nativePath(assetPath)}');
    if (file.existsSync() && file.lengthSync() > 0) {
      return file.path;
    }

    await file.parent.create(recursive: true);
    final bytes = await rootBundle.load(assetPath);
    await file.writeAsBytes(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      flush: true,
    );
    return file.path;
  }

  for (final file in _nativeAssetFiles(assetPath)) {
    if (file.existsSync()) {
      return file.path;
    }
  }

  return File(assetPath).absolute.path;
}

Iterable<File> _nativeAssetFiles(String assetPath) sync* {
  final executableDirectory = File(Platform.resolvedExecutable).parent;

  if (Platform.isMacOS) {
    final contents = executableDirectory.parent;
    yield File(
      '${contents.path}/Frameworks/App.framework/Resources/flutter_assets/$assetPath',
    );
  }

  if (Platform.isIOS) {
    yield File(
      '${executableDirectory.path}/Frameworks/App.framework/flutter_assets/$assetPath',
    );
  }

  if (Platform.isLinux || Platform.isWindows) {
    yield File(
      '${executableDirectory.path}/data/flutter_assets/${_nativePath(assetPath)}',
    );
  }
}

String _nativePath(String assetPath) =>
    assetPath.replaceAll('/', Platform.pathSeparator);