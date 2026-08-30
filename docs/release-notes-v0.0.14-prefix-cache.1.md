# v0.0.14-prefix-cache.1

First versioned release of the Android system-preface KV checkpoint fork.

## Highlights

- Prefill a fixed system message, initial messages, and tools during
  `createConversation`.
- Restore the native KV cache and per-turn processor state to the saved preface.
- Run independent requests with `sendMessageStateless`.
- Stream independent responses with `sendMessageStatelessStream`.
- Use an Android AAR built for 16 KB page-size compatibility.
- Load multi-GB models from a native filesystem path instead of bundling them
  in the APK.
- Integrate into new or existing Flutter applications without building
  LiteRT-LM from source.

## Assets

- `litertlm-prefix-cache-flutter-v0.0.14-prefix-cache.1.zip`: recommended
  integration bundle containing the matching Flutter plugin and Android AAR.
- `litertlm-android-prefix-cache-v0.16.1-prefix-cache.1.aar`: standalone runtime
  binary for existing vendor trees and verification.
- `SHA256SUMS.txt`: checksums for release assets.
- `THIRD_PARTY_NOTICES.md`: upstream and binary provenance.

## Compatibility

- Flutter 3.44 or newer
- Dart 3.12 or newer
- Java 17
- Android compile SDK 36
- Android min SDK 23
- Android `arm64-v8a` devices and `x86_64` emulators
- LiteRT-LM Android 0.16.1 base runtime

Checkpoint restore is Android-only in this release. CPU inference with Gemma 4
E2B has been validated on an arm64 Android device. GPU support remains dependent
on the selected model, device, and runtime backend.

## Installation

Read the
[Flutter integration guide](https://github.com/wachinaba/litertlm/blob/v0.0.14-prefix-cache.1/docs/flutter-integration-ja.md).

The integration ZIP is self-contained. Application developers do not need to
run the LiteRT-LM AAR GitHub Actions workflow or install Bazel.

## Runtime provenance

The included AAR is built from
[`wachinaba/LiteRT-LM@d6f1ea6`](https://github.com/wachinaba/LiteRT-LM/commit/d6f1ea65a25ab1b073d0da7d276b746832767135),
including the 16 KB alignment change. The standalone AAR SHA-256 is:

```text
CA0AA954A5281A546D5C4C88D08BDBA599DE194893F296EBA99B5749388E3AB5
```
