# LiteRT-LM checkpoint chat example

This Android sample keeps one fixed system-prompt KV checkpoint in memory. The
transcript stays visible in Flutter, but every request uses
`Conversation.sendMessageStatelessStream`, so earlier user/model turns are not
sent back to the model. Response chunks are rendered as they arrive.

## Select a model from the device

Copy a compatible `.litertlm` file to a folder on the Android device, then tap
**Choose device folder (direct access)**. The app lists model files directly
inside that folder and opens the selected file from its original absolute path.
It does not copy the model into application storage or create a model cache.

The model used for local development is the official instruction-tuned Gemma 4
E2B model. Copy the downloaded file to a folder such as `Models` on the device:

```text
gemma-4-E2B-it.litertlm
https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm
```

The model is about 2.59 GB. It is excluded from Git and from the APK. The sample
uses a 2,048-token context to limit KV-cache memory, limits responses to 256
tokens, and defaults to the CPU backend for broad device compatibility.

No model is bundled in the application APK. Integration-test models, when used,
must be supplied separately. For a production app, download the model after
installation and pass its filesystem path to `EngineConfig`.

The debug manifest requests all-files access. This debug-only permission is
unsuitable for a Play Store release.

## Generate and run the Android project

From this directory, using Flutter 3.44 or newer and Java 17:

```shell
flutter create --platforms=android --project-name=litertlm_example --org=org.rockstudio .
flutter pub get
flutter run
```

An Android SDK with API 36 and either an arm64 Android device or an x86_64
emulator is required. Press **Load & prefill** once after launch, then send as
many independent prompts as needed.

The patched AAR must exist at
`../android/libs/litertlm-android-prefix-cache.aar`. Without it, ordinary
inference can fall back to the upstream AAR, but checkpoint restore is not
available.
