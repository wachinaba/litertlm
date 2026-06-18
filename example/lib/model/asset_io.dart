import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show FlutterError;
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
    if (await _mergeAssetParts(assetPath, file)) {
      return file.path;
    }

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

Future<bool> _mergeAssetParts(String assetPath, File file) async {
  final tempFile = File('${file.path}.merge');
  IOSink? sink;
  for (var index = 0; ; index += 1) {
    final bytes = await _loadAssetPart(assetPath, index);
    if (bytes == null) {
      if (index == 0) return false;
      break;
    }

    sink ??= tempFile.openWrite();
    sink.add(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    );
  }
  await sink?.close();
  await tempFile.rename(file.path);
  return true;
}

Future<ByteData?> _loadAssetPart(String assetPath, int index) async {
  try {
    return await rootBundle.load('$assetPath.$index.part');
  } on FlutterError {
    return null;
  }
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
