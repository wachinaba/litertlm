# litertlm
Native LiteRT-LM bindings for Flutter across mobile, desktop, and web.

## Overview
This package is a lightweight bridge to the official LiteRT-LM runtimes. It uses the official, platform-optimized native distribution for each target, such as the Swift package on iOS and macOS, the Gradle package on Android, and CLI packages on desktop platforms. That keeps the native runtime close to the upstream implementation while exposing one Dart API across supported platforms.

## Platform Support
| Platform | Runtime artifact | Integration |
| --- | --- | --- |
| iOS | Official Swift package | FFI |
| Android | Official Gradle package | JNI |
| macOS | Official Swift package | FFI |
| Windows | Official CLI package | FFI |
| Linux | Official CLI package | FFI |
| Web | Official NPM package | JS interop |
