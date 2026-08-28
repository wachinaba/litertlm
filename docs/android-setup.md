# Android development without a local SDK

The package requires Flutter 3.44 or newer (Dart 3.12 or newer), Java 17, and
Android API 36 when building locally. The existing `F:\flutter` installation is
Flutter 3.16.9 / Dart 3.2.6 and is too old for this repository.

## Recommended: use GitHub Actions

Push this repository to GitHub. The workflow in
`.github/workflows/android.yml` installs a current stable Flutter SDK, Java 17,
and the Android SDK on the runner, then runs analysis and tests. This avoids
installing an Android SDK on the development PC.

## Local setup

1. Install or extract a current Flutter stable SDK to a new directory. Do not
   overwrite `F:\flutter` until the new SDK has been verified.
2. Install Android Studio, or Android command-line tools with platform/API 36
   and build-tools 36.
3. Set `ANDROID_SDK_ROOT` to the Android SDK directory.
4. Run `flutter doctor -v`, accept Android licenses, then run:

```powershell
flutter pub get
flutter analyze
flutter test
```

The model itself is not required for unit tests. An Android device and a
`.litertlm` model are required for the integration test that measures KV-cache
token counts and first-token latency.

## Build and install the checkpoint-enabled AAR

The official Android AAR exposes `prefillPrefaceOnInit`, but does not expose a
way to restore the resulting KV-cache checkpoint. The companion source checkout
at `F:\FlutterProjects\LiteRT-LM-prefix-cache` adds that native API and includes
`.github/workflows/build-prefix-cache-aar.yml` so it can be built without a
local Flutter or Android SDK.

1. Push `F:\FlutterProjects\LiteRT-LM-prefix-cache` to a GitHub repository.
2. In its **Actions** tab, run **Build prefix-cache Android AAR** manually.
3. Download the `litertlm-android-prefix-cache` artifact.
4. Copy `litertlm-android-prefix-cache.aar` to:

   `F:\FlutterProjects\litertlm-prefix-cache\android\libs\litertlm-android-prefix-cache.aar`

The Flutter plugin detects that file during the Gradle build. If it is absent,
the plugin falls back to the stock 0.16.1 Maven AAR; normal inference and
prefill still compile, but checkpoint restore throws `UnsupportedOperationException`.

Use the runtime as follows:

```dart
final conversation = await engine.createConversation(
  ConversationConfig(
    systemMessage: Message.system(fixedSystemPrompt),
    prefillPrefaceOnInit: true,
  ),
);

final a = await conversation.sendMessageStateless(Message.user(inputA));
final b = await conversation.sendMessageStateless(Message.user(inputB));
```

Each call rewinds to the checkpoint immediately after the fixed preface, clears
the native conversation history and incremental processor state, and then
processes the new input. Calls must not overlap on the same `Conversation`.
