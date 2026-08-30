# Flutter アプリ統合ガイド

対象リリース: `v0.0.14-prefix-cache.1`

この文書は、固定システムプロンプトの KV cache を保持したまま、互いに
独立した入力を繰り返し処理する Android Flutter アプリの導入手順を示す。
新規 Flutter プロジェクトと、すでに upstream `litertlm` を利用している
プロジェクトの両方を対象とする。

## 1. 結論: 利用者に GitHub Actions は不要

アプリ開発者が必要とする成果物は次の二つである。

1. checkpoint API を含む Flutter plugin source
2. `litertlm-android-prefix-cache.aar`

GitHub Release の integration bundle には両方が含まれる。利用者は bundle
を展開して path dependency にするだけでよく、LiteRT-LM core、Bazel、NDK
を自分でビルドする必要はない。

GitHub Actions が必要になるのは、AAR をソースから再生成する場合、または
アプリ側の通常の CI build を自動化する場合だけである。

APK は完成アプリであり、別の Flutter アプリへ組み込むライブラリではない。
第三者統合に使う binary は APK ではなく AAR である。

## 2. 配布物と互換バージョン

Flutter release:

```text
v0.0.14-prefix-cache.1
```

対応 LiteRT-LM core/AAR release:

```text
v0.16.1-prefix-cache.1
```

Release assets:

```text
litertlm-prefix-cache-flutter-v0.0.14-prefix-cache.1.zip
litertlm-android-prefix-cache-v0.16.1-prefix-cache.1.aar
SHA256SUMS.txt
THIRD_PARTY_NOTICES.md
```

通常は ZIP bundle だけを使用する。AAR 単体は、検証、既存 vendor tree の
更新、binary provenance の確認用である。

ZIP を展開すると次の構造になる。

```text
litertlm/
  lib/
  android/
    libs/
      litertlm-android-prefix-cache.aar
  pubspec.yaml
  README.md
  LICENSE
  THIRD_PARTY_NOTICES.md
```

plugin source と AAR は必ず同じ release の組み合わせを使う。異なる build
を混在させると Kotlin/JNI signature の不一致による `NoSuchMethodError` が
発生しうる。

## 3. 必要環境

- Flutter 3.44 以降
- Dart 3.12 以降
- Java 17
- Android compile SDK 36
- Android min SDK 23
- Android 実機: `arm64-v8a`
- Android emulator: `x86_64`
- 対応する `.litertlm` model の実ファイル

checkpoint restore はこの release では Android 専用である。

## 4. 新規 Flutter プロジェクトへの導入

### 4.1 プロジェクト作成

```shell
flutter create my_app
cd my_app
```

### 4.2 integration bundle の展開

Release ZIP を `third_party` の下へ展開する。

```text
my_app/
  lib/
  pubspec.yaml
  third_party/
    litertlm/
      android/
        libs/
          litertlm-android-prefix-cache.aar
```

PowerShell の例:

```powershell
New-Item -ItemType Directory -Force third_party | Out-Null
Expand-Archive `
  litertlm-prefix-cache-flutter-v0.0.14-prefix-cache.1.zip `
  third_party
```

### 4.3 dependency の追加

`pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  litertlm:
    path: third_party/litertlm
```

```shell
flutter pub get
```

### 4.4 AAR の存在確認

checkpoint AAR がない場合、plugin は upstream Maven AAR 0.16.1 へ
fallback する。通常推論は build できるが checkpoint restore は実行時に
失敗する。この silent fallback を公開 build で見逃さないこと。

PowerShell:

```powershell
$aar = 'third_party/litertlm/android/libs/litertlm-android-prefix-cache.aar'
if (-not (Test-Path -LiteralPath $aar)) {
  throw "checkpoint-enabled AAR is missing: $aar"
}
```

Bash:

```bash
test -f third_party/litertlm/android/libs/litertlm-android-prefix-cache.aar
```

### 4.5 model path

`EngineConfig.modelPath` には Flutter asset key ではなく、native runtime が
読める実ファイルパスを渡す。

```dart
final engine = Engine(
  engineConfig: EngineConfig(
    modelPath: modelPath,
    backend: const Backend.cpu(),
    maxNumTokens: 2048,
  ),
);

await engine.initialize();
```

multi-GB model を APK asset として配布することは推奨しない。production
app では download 後の app storage、または app が正規にアクセスできる
device storage の path を使用する。

example の folder picker は debug 用に `MANAGE_EXTERNAL_STORAGE` を使う。
これは integration の必須要件ではなく、Play Store release へそのまま
持ち込まないこと。

## 5. 固定 preface checkpoint の利用

### 5.1 Conversation 作成時に一度だけ prefill

```dart
final conversation = await engine.createConversation(
  ConversationConfig(
    systemMessage: Message.system(fixedSystemPrompt),
    initialMessages: const [],
    tools: const [],
    prefillPrefaceOnInit: true,
  ),
);
```

`createConversation` が完了した時点で、system message、initial messages、
tool declarations を含む固定 preface が KV cache に入り、その直後の
native checkpoint が保存される。

```dart
final prefixTokenCount = await conversation.getTokenCount();
```

### 5.2 完了レスポンスを返す独立リクエスト

```dart
final response = await conversation.sendMessageStateless(
  Message.user(input),
  maxOutputTokens: 256,
);
```

各呼び出しの直前に固定 preface checkpoint へ戻る。以前の user/model
messages は次のリクエストから見えない。

### 5.3 出力ストリーミング

```dart
final text = StringBuffer();

await for (final chunk in conversation.sendMessageStatelessStream(
  Message.user(input),
  maxOutputTokens: 256,
)) {
  // onMessageDone の区切りは空 Message として通知される。
  if (chunk.isEmpty) continue;
  text.write(chunk.text);
  updateUi(text.toString());
}
```

stream subscription の cancel、または `conversation.cancel()` により active
generation を停止できる。

### 5.4 明示的な reset

```dart
await conversation.resetToPreface();
```

通常の multi-turn `sendMessage` を使った後で、固定 preface 直後へ明示的に
戻す用途にも使える。

### 5.5 dispose

```dart
await conversation.dispose();
await engine.dispose();
```

checkpoint は memory 上にあり、Conversation の dispose、process 終了、
app 再起動を越えて永続化されない。

## 6. 既存 litertlm アプリへの統合

package name と import path は upstream と同じである。

```dart
import 'package:litertlm/litertlm.dart';
```

既存の import を一括変更する必要はない。

### 6.1 dependency の置き換え

変更前:

```yaml
dependencies:
  litertlm: ^0.0.13
```

変更後:

```yaml
dependencies:
  litertlm:
    path: third_party/litertlm
```

短期検証だけなら `dependency_overrides` も利用できる。

```yaml
dependencies:
  litertlm: ^0.0.13

dependency_overrides:
  litertlm:
    path: third_party/litertlm
```

production では override ではなく正式な dependency として固定する。

### 6.2 Android dependency の重複除去

既存 app が次を直接持っている場合は削除する。

```kotlin
implementation("com.google.ai.edge.litertlm:litertlm-android:0.16.1")
```

また、app の `android/app/libs` に stock LiteRT-LM AAR がある場合も除外する。
checkpoint bundle と stock AAR を同時に package してはならない。

### 6.3 API の段階的移行

checkpoint は opt-in であり、既存の `sendMessage` と
`sendMessageStream` は従来どおり multi-turn として動作する。

独立処理にしたい Conversation だけ `prefillPrefaceOnInit: true` にし、
送信 API を次のように置き換える。

```text
sendMessage       -> sendMessageStateless
sendMessageStream -> sendMessageStatelessStream
```

multi-turn と independent request の責務が異なる場合は Conversation を
分ける。各 Conversation は独自の KV cache を持つため、並列数に応じて
memory 使用量が増える。

### 6.4 clean build

native dependency の切り替え後は一度 clean build する。

```shell
flutter clean
flutter pub get
flutter build apk --debug
```

## 7. 並行性とライフサイクル

同一 Conversation に reset と generation を並行実行してはならない。

```dart
// 禁止
await Future.wait([
  conversation.sendMessageStateless(Message.user('A')),
  conversation.sendMessageStateless(Message.user('B')),
]);
```

同一 Conversation の request は queue/mutex で直列化する。真に並列化する
場合は Conversation を複数作る。

固定 system prompt を変更する場合も、新しい Conversation を作り直す。

## 8. GitHub Actions で release binary を利用する

consumer workflow が AAR を build する必要はない。versioned integration
bundle を取得し、checksum を検証してから app を build する。

```yaml
- name: Download LiteRT-LM checkpoint integration bundle
  env:
    GH_TOKEN: ${{ github.token }}
  run: |
    mkdir -p third_party
    gh release download v0.0.14-prefix-cache.1 \
      --repo wachinaba/litertlm \
      --pattern 'litertlm-prefix-cache-flutter-*.zip' \
      --dir /tmp/litertlm-release
    unzip /tmp/litertlm-release/litertlm-prefix-cache-flutter-*.zip \
      -d third_party

- name: Require checkpoint AAR
  run: test -f third_party/litertlm/android/libs/litertlm-android-prefix-cache.aar

- run: flutter pub get
- run: flutter build apk --release --split-per-abi
```

Actions run artifact は保持期限があるため、consumer の正式 dependency に
しない。GitHub Release、Maven repository、または組織内 artifact repository
を利用する。

## 9. トラブルシューティング

### `UnsupportedOperationException` during reset

checkpoint AAR が所定位置になく、stock Maven AAR へ fallback している。

```text
third_party/litertlm/android/libs/litertlm-android-prefix-cache.aar
```

を確認する。

### `NoSuchMethodError: nativeCreateEngine`

Flutter plugin/Kotlin classes/JNI libraries の build が混在している。bundle
を同一 release の内容で入れ直し、`flutter clean` 後に再 build する。

### 以前の会話が次の入力へ影響する

`sendMessage` または `sendMessageStream` を使っている。independent request
には stateless API を使う。

### model load が長時間進まない

multi-GB model を Flutter asset から Dart heap 経由でコピーしていないか
確認する。native runtime が読める実ファイル path を渡す。

### 16 KB page-size warning

古い AAR または別の native library が APK に混入している。release bundle
付属の AARを使用し、APK Analyzer 等で packaged `.so` を確認する。

### ABI mismatch

現行 AAR の主要対象は Android 実機の `arm64-v8a` と emulator の
`x86_64` である。APK は `--split-per-abi` での配布を推奨する。

## 10. 機能と制限

実装済み:

- fixed preface の作成時 prefill
- prefill 直後の native KV checkpoint 保存
- checkpoint への明示的 restore
- independent request API
- independent streaming API
- KV token count
- generation cancel
- native history、incremental template/parser、constraint、channel state の reset
- Android arm64-v8a / x86_64 runtime
- Android 16 KB page-size alignment

制限:

- checkpoint restore は Android 専用
- checkpoint は disk 永続化されない
- 同一 Conversation の generation は直列実行が必要
- Conversation ごとに独立 KV cache memory が必要
- CPU + Gemma 4 E2B は実機確認済み
- GPU/backend capability は model と端末ごとに確認が必要

## 11. ライセンスと由来

Flutter plugin fork は MIT License、LiteRT-LM core と改変 AAR は Apache
License 2.0 で提供される。bundle 内の `LICENSE`、
`LICENSE-LiteRT-LM`、`THIRD_PARTY_NOTICES.md` を保持すること。
