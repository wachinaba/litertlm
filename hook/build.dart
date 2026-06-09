import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

const _codeAssetName = 'native/ffi.dart';
const _nativeFfiSupportAssetName = 'src/native_ffi_support.dart';
const _macosRpathDylib = '@rpath/libCLiteRTLM_mac.dylib';
const _iosRpathFramework = '@rpath/CLiteRTLM.framework/CLiteRTLM';
const _linuxSharedLibrary = 'liblitert-lm.so';
const _windowsSharedLibrary = 'litert-lm.dll';

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) {
      return;
    }

    final systemLibrary = switch (input.config.code.targetOS) {
      OS.iOS => _iosRpathFramework,
      OS.macOS => _macosRpathDylib,
      OS.linux => _linuxSharedLibrary,
      OS.windows => _windowsSharedLibrary,
      _ => null,
    };
    if (systemLibrary == null) {
      return;
    }

    output.assets.code.add(
      CodeAsset(
        package: input.packageName,
        name: _codeAssetName,
        linkMode: DynamicLoadingSystem(Uri.parse(systemLibrary)),
      ),
    );

    await CBuilder.library(
      name: 'native_ffi_support',
      assetName: _nativeFfiSupportAssetName,
      sources: ['src/native_ffi_support.c'],
    ).run(input: input, output: output);
  });
}
