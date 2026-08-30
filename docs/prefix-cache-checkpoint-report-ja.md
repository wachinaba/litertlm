# LiteRT-LM Flutter システムプロンプト KV-cache checkpoint 実装レポート

第三者が新規 Flutter アプリへ導入する手順、既存 `litertlm` アプリからの
移行、versioned release binary の利用方法は
[Flutter アプリ統合ガイド](flutter-integration-ja.md)を参照すること。

作成日: 2026-08-29
対象ブランチ: `prefix-cache-checkpoint`

## 1. エグゼクティブサマリー

Flutter 向け `litertlm` で、固定システムプロンプトを一度だけ prefill し、その直後の KV cache へ会話を繰り返し巻き戻せるようにした。

最終的に、次の利用形を実現した。

```dart
final conversation = await engine.createConversation(
  ConversationConfig(
    systemMessage: Message.system(fixedSystemPrompt),
    prefillPrefaceOnInit: true,
  ),
);

final first = await conversation.sendMessageStateless(
  Message.user(firstInput),
);
final second = await conversation.sendMessageStateless(
  Message.user(secondInput),
);
```

`firstInput` と `secondInput` は互いの履歴を参照せず、どちらも同じ固定 preface（システムメッセージ、初期メッセージ、tool 定義、extra context）だけを前提に推論される。固定 preface の KV cache は同じ `Conversation` が保持するため、リクエストごとにシステムプロンプトを再評価する必要がない。

成果は次の範囲で検証済みである。

- LiteRT-LM C++ runtime の checkpoint 保存・復元実装
- Kotlin/JNI API の公開
- Flutter/Dart API の追加
- arm64-v8a と x86_64 の JNI ライブラリ生成
- checkpoint 対応 AAR の生成と内部構造検証
- 生成した AAR を実際に Flutter plugin へ同梱した状態での debug APK ビルド
- Flutter の静的解析・unit test・通常 Android bridge ビルド

一方、実モデルと Android 実機を用いた速度・メモリ・出力同一性の測定は、今回の GitHub Actions 検証には含まれない。ここはアプリへ組み込んだ後に別途計測すべき項目である。

## 2. リポジトリと成果物

### 2.1 Flutter plugin

- ローカルcheckout名: `litertlm-prefix-cache`
- GitHub: <https://github.com/wachinaba/litertlm>
- ブランチ: `prefix-cache-checkpoint`
- 公開基準: `v0.0.14-prefix-cache.1`

主要な変更 commit:

| Commit | 内容 |
| --- | --- |
| `fbe6e71` | Flutter/Android の system-prompt checkpoint API を追加 |
| `a209d6f` | 既存 lint warning を CI 失敗条件から除外 |
| `c2f547f` | patched AAR の classes/JNI を Flutter plugin AAR へ同梱 |
| `05b0f4e` | AGP 9 向けに生成 JNI ディレクトリを静的パスで登録 |
| `3743266` | 展開タスクと `classes.jar` 利用タスクの依存を明示 |

### 2.2 LiteRT-LM core

- ローカルcheckout名: `LiteRT-LM-prefix-cache`
- GitHub: <https://github.com/wachinaba/LiteRT-LM>
- ブランチ: `prefix-cache-checkpoint`
- 公開基準: `v0.16.1-prefix-cache.1` (`d6f1ea6`)

主要な変更 commit:

| Commit | 内容 |
| --- | --- |
| `a6d5437` | C++/Kotlin/JNI checkpoint 復元を実装 |
| `f1054a1` | GitHub Actions の Bazelisk 導入権限を修正 |
| `30b74b7` | AAR の Kotlin classes packaging を修正 |
| `8d76b4f` | `pipefail` と `grep -q` の誤判定を修正 |
| `131275b` | Bazel output symlink を探索対象に追加 |
| `6c90fc6` | AAR 用 classes-only Kotlin target を追加 |
| `6766d10` | patched AAR を使う Flutter APK 統合ビルドを追加 |
| `d6f1ea6` | Android JNI を 16 KB page size 向けに link |

### 2.3 ローカル AAR

配置先:

```text
<litertlm-prefix-cache>/android/libs/litertlm-android-prefix-cache.aar
```

検証時の情報:

| 項目 | 値 |
| --- | --- |
| サイズ | 40,821,981 bytes |
| SHA-256 | `CA0AA954A5281A546D5C4C88D08BDBA599DE194893F296EBA99B5749388E3AB5` |
| Kotlin API | `com/google/ai/edge/litertlm/Conversation.class` を収録 |
| Kotlin method | `resetToPreface` を確認 |
| ABI | `arm64-v8a`, `x86_64` |
| JNI export | `Java_com_google_ai_edge_litertlm_LiteRtLmJni_nativeConversationResetToPreface` |

この AAR は `android/libs/*.aar` により gitignore される。clone しただけでは取得できない点に注意する。

## 3. 要求と設計判断

### 3.1 要求

今回の目的は一般的な multi-turn chat ではなく、次の反復処理だった。

1. システムプロンプトは固定する。
2. システムプロンプトを一度だけ prefill する。
3. ユーザー入力 A を処理する。
4. A とその応答を完全に捨てる。
5. 同じシステムプロンプト直後の状態からユーザー入力 B を処理する。
6. 以後も同様に繰り返す。

会話履歴だけを Dart 側で消しても、native session の KV cache と parser state は残る。そのため、Flutter wrapper の変更だけでは要求を満たせず、LiteRT-LM core の session checkpoint まで遡る必要があった。

### 3.2 採用した方式

Conversation 作成時に、固定 preface の prefill 完了直後で native session checkpoint を保存する。

```text
Engine
  └─ Conversation を作成
       ├─ fixed preface を template render
       ├─ RunPrefill
       └─ SaveCheckpoint("preface_checkpoint")

各リクエスト
  ├─ WaitUntilDone
  ├─ RewindToCheckpoint("preface_checkpoint")
  ├─ history / parser / constraint / channel state を初期化
  └─ 新しい user message を推論
```

単に `RewindToCheckpoint` を呼ぶだけでは不十分である。テンプレートの増分解析や tool/channel parser の内部状態、constraint、履歴、task controller も前ターンの状態を持ちうるため、それらも checkpoint と整合する状態へ戻した。

## 4. 実装詳細

### 4.1 LiteRT-LM C++ runtime

対象:

```text
runtime/conversation/conversation.cc
runtime/conversation/conversation.h
```

`Conversation::Create` で `prefill_preface_on_init=true` かつ preface が空でない場合、preface を template render して `RunPrefill` した後、次の名前で checkpoint を保存する。

```cpp
constexpr absl::string_view kPrefaceCheckpoint = "preface_checkpoint";
```

保存が成功した場合だけ `preface_checkpoint_available_` を有効にする。backend が checkpoint を実装していない場合、Conversation 作成自体は従来互換のため継続し、明示的な復元時に `Unimplemented` を返す。

`Conversation::ResetToPreface()` は次を実行する。

1. `prefill_preface_on_init=true` と non-empty preface を検証する。
2. checkpoint 利用可能性を検証する。
3. live state を変更する前に新しい `ModelDataProcessor` を構築する。
4. `session_->WaitUntilDone()` で進行中処理の終了を待つ。
5. `session_->RewindToCheckpoint("preface_checkpoint")` を呼ぶ。
6. processor を新しいものへ交換する。
7. constraint、append 状態、message checkpoint、channel 状態をクリアする。
8. native history と task controllers をクリアする。

前処理として新しい processor を構築するのは、構築失敗後に会話を中途半端な状態へ変更しないためでもある。

### 4.2 Kotlin/JNI

Kotlin `Conversation` に次を追加した。

```kotlin
fun resetToPreface()
```

さらに `LiteRtLmJni` の external method、JNI C++ export、native `Conversation::ResetToPreface()` を接続した。

最終 AAR では両 ABI に次の export が存在することを確認した。

```text
Java_com_google_ai_edge_litertlm_LiteRtLmJni_nativeConversationResetToPreface
```

### 4.3 Flutter/Dart API

`ConversationConfig` に追加:

```dart
final bool prefillPrefaceOnInit;
```

`Conversation` に追加:

```dart
Future<void> resetToPreface();

Future<Message> sendMessageStateless(
  Message message, {
  Map<String, Object?>? extraContext,
  int? maxOutputTokens,
});
```

`sendMessageStateless` は内部で次を順に呼ぶ convenience API である。

```dart
await resetToPreface();
return sendMessage(message, ...);
```

同一 `Conversation` に対して複数の `sendMessageStateless` を並行実行してはいけない。reset と send は一つの atomic native operation ではないため、アプリ側で必ず直列化する。

Android bridge は Kotlin method を reflection で探索する。これにより stock AAR でも plugin 自体はコンパイルできるが、stock AAR で復元を呼ぶと明示的に unsupported error となる。

FFI と Web backend は今回未実装であり、`prefillPrefaceOnInit` を有効にすると `UnsupportedError` を返す。現時点の checkpoint 復元対象は Android のみである。

### 4.4 Flutter plugin への AAR 同梱

patched AAR が存在する場合、`android/build.gradle.kts` は AAR をそのまま `files(...)` 依存にはしない。代わりに build directory へ以下だけを展開する。

```text
classes.jar
jni/**
```

その後:

- `classes.jar` を local JAR dependency として登録
- `jni` を `main.jniLibs` source directory として登録
- `preBuild` を展開タスクへ依存させる
- `classes.jar` の FileCollection に `builtBy(extractPrefixCacheAar)` を設定する

これにより Flutter plugin の AAR 自体へ必要な Kotlin classes と native libraries が入り、新しいアプリ側へ追加 repository 設定を要求しない。

AAR が存在しない場合は次へフォールバックする。

```kotlin
implementation("com.google.ai.edge.litertlm:litertlm-android:0.16.1")
```

この状態では通常推論と prefill は利用できるが、checkpoint 復元は利用できない。

## 5. GitHub Actions ビルド

### 5.1 Core/AAR workflow

workflow:

```text
LiteRT-LM-prefix-cache/.github/workflows/build-prefix-cache-aar.yml
```

GitHub UI では **Build prefix-cache Android AAR** を手動実行する。

完全ビルドでは次を実行する。

1. Java 17、Android SDK/NDK、Bazelisk を導入
2. `//runtime/conversation:conversation_test` を実行
3. classes-only Kotlin JAR を生成・検証
4. arm64-v8a JNI をビルド
5. x86_64 JNI をビルド
6. stock 0.16.1 AAR をベースに patched classes/JNI を格納
7. AAR artifact を upload
8. Flutter plugin fork を checkout
9. 生成直後の AAR を plugin へ配置
10. Flutter example debug APK をビルド

CLI から完全ビルドを開始する例:

```powershell
gh workflow run build-prefix-cache-aar.yml `
  --repo wachinaba/LiteRT-LM `
  --ref prefix-cache-checkpoint
```

native code が変わっていない場合だけ、以前の成功 run の JNI を再利用できる。

```powershell
gh workflow run build-prefix-cache-aar.yml `
  --repo wachinaba/LiteRT-LM `
  --ref prefix-cache-checkpoint `
  -f reuse_aar_run_id=<successful-run-id>
```

`reuse_aar_run_id` 指定時は C++ test と JNI build をスキップし、Kotlin classes、AAR packaging、Flutter APK integration を再検証する。C++/JNI を変更したのに再利用してはならない。

監視と取得:

```powershell
gh run watch <run-id> --repo wachinaba/LiteRT-LM --exit-status

gh run download <run-id> `
  --repo wachinaba/LiteRT-LM `
  --name litertlm-android-prefix-cache `
  --dir .artifacts\litertlm-aar
```

成功した代表 run:

| Run | 内容 | 結果 |
| --- | --- | --- |
| [33174867909](https://github.com/wachinaba/LiteRT-LM/actions/runs/33174867909) | C++ test、両 ABI JNI、AAR の完全ビルド | 成功 |
| [33213093144](https://github.com/wachinaba/LiteRT-LM/actions/runs/33213093144) | classes/AAR 再生成と patched AAR 使用 Flutter APK 統合ビルド | 成功、9分36秒 |
| [33250308561](https://github.com/wachinaba/LiteRT-LM/actions/runs/33250308561) | 16 KB alignment 対応 AAR と Flutter APK 統合 build | 成功 |

完全ビルドは約1時間19分を要した。再利用モードは native build を省けるが、SDK/Flutter/Gradle の初回 download があるため約10分を見込む。

### 5.2 Flutter plugin workflow

workflow:

```text
litertlm-prefix-cache/.github/workflows/android.yml
```

実行内容:

- `flutter analyze --no-fatal-infos --no-fatal-warnings`
- `flutter test`
- example Android runner 生成
- debug APK compile

成功 run:

- <https://github.com/wachinaba/litertlm/actions/runs/33174848329>

ただし AAR は gitignore されるため、この Flutter 単独 workflow は clone 直後には stock Maven AAR を使う。patched AAR を使った統合確認は Core/AAR workflow 側の最終ステップが担当する。

## 6. 新しい Flutter アプリへ組み込む手順

### 6.1 推奨ディレクトリ構成

現状の成果物をそのまま使うなら、plugin fork をアプリの隣または配下へ clone し、path dependency にするのが確実である。

```text
my_app/
  pubspec.yaml
  lib/
  third_party/
    litertlm/                 # wachinaba/litertlm の対象ブランチ
      android/
        libs/
          litertlm-android-prefix-cache.aar
```

clone 例:

```powershell
git clone `
  --branch prefix-cache-checkpoint `
  https://github.com/wachinaba/litertlm.git `
  third_party\litertlm
```

AAR artifact を取得し、次へコピーする。

```text
my_app/third_party/litertlm/android/libs/litertlm-android-prefix-cache.aar
```

`pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  litertlm:
    path: third_party/litertlm
```

単純な `git:` dependency だけでは、gitignore された AAR が dependency checkout に入らない。その場合は stock AAR fallback となり、`resetToPreface` は実行時に失敗する。

### 6.2 必要環境

今回の plugin 構成では次を基準とする。

- current Flutter stable（検証時は Flutter 3.44 以降を想定）
- Dart 3.12 以降
- Java 17
- Android compile SDK 36
- Android min SDK 23
- 実機: arm64-v8a
- emulator: x86_64

ローカルに Flutter/Android SDK がない場合、GitHub Actions でビルドすればよい。Flutter 3.44 / Dart 3.12 より古いSDKは、このリポジトリには使用しない。

### 6.3 アプリコード

Engine は通常どおり初期化する。

```dart
final engine = Engine(
  engineConfig: const EngineConfig(
    modelPath: '/absolute/path/to/model.litertlm',
    backend: Backend.gpu(),
  ),
);

await engine.initialize();
```

固定 preface を指定して Conversation を一度だけ作る。

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

独立入力を直列に処理する。

```dart
Future<Message> runIndependent(String input) {
  return conversation.sendMessageStateless(
    Message.user(input),
    maxOutputTokens: 256,
  );
}

final resultA = await runIndependent('input A');
final resultB = await runIndependent('input B');
```

明示的に reset する場合:

```dart
await conversation.resetToPreface();
final result = await conversation.sendMessage(Message.user(input));
```

通常の multi-turn 会話をしたい場合は `sendMessage` を続けて呼び、独立処理へ戻る直前に `resetToPreface` を呼ぶこともできる。

終了時:

```dart
await conversation.dispose();
await engine.dispose();
```

Conversation を dispose すると保存 KV cache も失われる。毎回 Conversation を作り直すと固定 prefix の prefill cost が毎回発生するため、固定 prompt ごとに Conversation を長生きさせる。

### 6.4 並行リクエスト

同一 Conversation への次のような処理は禁止する。

```dart
// 禁止: reset/send が競合する。
await Future.wait([
  conversation.sendMessageStateless(Message.user('A')),
  conversation.sendMessageStateless(Message.user('B')),
]);
```

選択肢は二つある。

1. 同一 Conversation を queue/mutex で直列化する。
2. 並列数だけ Conversation を作り、それぞれが独自の checkpoint/KV cache を持つようにする。

2 は throughput を上げられるが、KV cache 分だけメモリ消費が増える。

### 6.5 新規アプリの GitHub Actions 例

plugin と AAR を CI で取得して APK を作る概念例を示す。

```yaml
name: Android APK

on:
  workflow_dispatch:
    inputs:
      aar_run_id:
        description: Successful LiteRT-LM AAR workflow run ID
        required: true
        type: string

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/checkout@v4
        with:
          repository: wachinaba/litertlm
          ref: prefix-cache-checkpoint
          path: third_party/litertlm

      - name: Download patched AAR
        env:
          GH_TOKEN: ${{ secrets.LITERTLM_ARTIFACT_TOKEN }}
        run: |
          mkdir -p /tmp/litertlm-aar third_party/litertlm/android/libs
          gh run download "${{ inputs.aar_run_id }}" \
            --repo wachinaba/LiteRT-LM \
            --name litertlm-android-prefix-cache \
            --dir /tmp/litertlm-aar
          cp /tmp/litertlm-aar/litertlm-android-prefix-cache.aar \
            third_party/litertlm/android/libs/

      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: "17"

      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true

      - run: flutter pub get
      - run: flutter test
      - run: flutter build apk --debug
```

別 repository の Actions artifact 取得では、標準 `GITHUB_TOKEN` の権限が不足することがある。必要に応じて対象 repository の Actions read 権限を持つ fine-grained token を `LITERTLM_ARTIFACT_TOKEN` として登録する。

長期運用では、毎回 artifact をコピーするより次のどちらかが望ましい。

- patched AAR を GitHub Packages 等の private Maven repository へ publish する。
- AAR をライセンスと容量を確認したうえで社内 artifact repository へ固定 version で保存する。

## 7. 検証方法

### 7.1 AAR 静的検証

AAR に必要な entry があるか確認する。

```powershell
tar -tf litertlm-android-prefix-cache.aar |
  Select-String 'classes.jar|liblitertlm_jni.so'
```

期待する entry:

```text
classes.jar
jni/arm64-v8a/liblitertlm_jni.so
jni/x86_64/liblitertlm_jni.so
```

`classes.jar` を展開し、`Conversation.class` と method 名を確認する。

```powershell
tar -xf litertlm-android-prefix-cache.aar classes.jar
tar -tf classes.jar |
  Select-String 'com/google/ai/edge/litertlm/Conversation.class'
```

JNI export は LLVM の `llvm-nm` 等で確認できる。

```powershell
llvm-nm -D --defined-only liblitertlm_jni.so |
  Select-String 'nativeConversationResetToPreface'
```

### 7.2 実機で追加すべきテスト

実モデルを使い、最低限次を確認する。

1. `createConversation` 後の `getTokenCount()` が fixed preface token 数を示す。
2. 1回目の `sendMessageStateless` 後は token 数が増える。
3. 次の `resetToPreface` 後に token 数が元へ戻る。
4. A→B と B単独の出力傾向が一致し、Aの内容がBへ漏れない。
5. Conversation 作成時の prefill 時間と、各 reset 後の first-token latency を測る。
6. 反復回数を増やして native memory が増え続けないことを確認する。
7. generation cancel/error 後にも reset で回復できることを確認する。
8. GPU backend と対象端末で checkpoint backend が実装されていることを確認する。

sampling が確率的なら完全な文字列一致を期待せず、seed/temperature を固定するか、token count と履歴漏洩の有無を主に検証する。

## 8. 遭遇した落とし穴と対処

### 8.1 公式機能は prefill までで、復元 API がない

公式 0.16.1 Android AAR は `prefillPrefaceOnInit` を持つが、Flutter から preface 直後へ戻す公開 API がない。履歴を Dart 側だけで消す方法では native KV cache を戻せない。

対処: LiteRT-LM core、Kotlin、JNI、Flutter の全レイヤーへ checkpoint restore を通した。

### 8.2 KV cache だけ戻しても会話状態は完全には戻らない

ModelDataProcessor、constraint、channel parser、history、task dependency が前ターンを保持しうる。

対処: processor を再生成し、関連 state をすべてクリアした。

### 8.3 inference 中の reset

推論と reset を同時実行すると session と履歴が競合する。

対処: native 側で `WaitUntilDone` してから rewind する。ただし Dart の `reset`→`send` 間は atomic ではないため、アプリ側の直列化も必須。

### 8.4 Bazelisk の global npm install 権限

GitHub-hosted runner で通常の `npm install -g @bazel/bazelisk` が権限エラーになった。

対処:

```bash
sudo npm install -g @bazel/bazelisk
```

### 8.5 Bazel `cquery` の先頭 JARが実クラスJARとは限らない

最初に返った JAR を機械的に採用した結果、358 bytes 程度で manifest しか持たない `classes.jar` を AAR に入れてしまった。workflow 自体は成功しても、AAR は使用不能だった。

対処:

- candidate JAR を列挙する。
- `Conversation.class` を実際に含むものだけ採用する。
- `resetToPreface` symbol も検証する。
- `kt_android_library` の公開 JARに依存せず、`litertlm-jvm-classes` という classes-only target を追加する。

成果物は「build command の成功」ではなく、中身を検査して初めて成功とみなすべきである。

### 8.6 Bazel output は symlink

`bazel-bin` 以下の探索で symlink の先を走査できず、内部成果物を見落とした。

対処:

```bash
find -L bazel-bin/... -type f -name '*.jar'
```

最終的には専用 classes-only target を採用したが、Bazel output を探索するときの一般的な注意点である。

### 8.7 `set -o pipefail` と `grep -q`

次の形式は一致していても失敗することがある。

```bash
unzip -Z1 file.jar | grep -q 'Conversation.class'
```

`grep -q` が一致直後に終了すると、上流 `unzip` が SIGPIPE になり、`pipefail` が pipeline 全体を失敗と判定するためである。

対処:

```bash
unzip -Z1 file.jar | grep 'Conversation.class' >/dev/null
```

### 8.8 Android library から local AAR を直接参照できない

次は AGP で失敗する。

```kotlin
implementation(files("libs/litertlm-android-prefix-cache.aar"))
```

Flutter plugin 自身も AAR として bundle されるため、local AAR の classes/resources を自動的に内包できず、AGP は broken AAR を防ぐ目的でエラーにする。

対処: 元 AAR から `classes.jar` と `jni/**` を展開し、local JAR と jniLibs として plugin AAR へ同梱した。

### 8.9 `flatDir` はアプリへ推移すると解決できない

plugin project 内の `flatDir` では plugin のコンパイルは通るが、アプリの runtime classpath が同じ repository を知らないため、`:litertlm-android-prefix-cache:` を解決できなかった。

対処: アプリ側 repository に依存しない自己同梱方式へ変更した。

### 8.10 AGP 9 SourceSet API は Provider directory を拒否する

generated directory の Provider を従来の `sourceSets.main.jniLibs.srcDir` に直接渡すと、generated/static を Android Studio が判別できないとして失敗した。

対処: 生成先は静的パスとして登録し、展開タスク依存を別に明示した。

### 8.11 Gradle 9 の implicit task dependency 検証

生成された `classes.jar` を app の desugar task が利用するのに、生成タスクとの依存が伝わらず失敗した。

対処:

```kotlin
files(generatedClassesJar).apply {
  builtBy(extractPrefixCacheAar)
}
```

`preBuild.dependsOn(...)` だけでは、別 project の app task が直接 file dependency を読むケースに不十分だった。

### 8.12 AAR は gitignore される

ローカルでは patched AAR が存在しても、GitHub Actions の fresh checkout では存在しない。その結果、知らないうちに stock AAR fallback をテストしていることがある。

対処: Core/AAR workflow 内で生成した AAR を Flutter plugin checkout へ明示的にコピーし、その状態で APK をビルドした。

### 8.13 artifact download の注意

`gh run download` は大きな artifact でしばらく無出力になる場合がある。また、destination に同名ファイルが存在すると展開時に失敗する。

対処: run ID ごとに空の download directory を用意し、検証後に目的位置へコピーする。

### 8.14 ABI の範囲

今回の AAR に含めた native library は `arm64-v8a` と `x86_64` である。`armeabi-v7a` は含まれない。

対処: 現行 Android 実機は arm64-v8a、CI/emulator は x86_64 を対象にする。別 ABI が必要なら workflow の Bazel config と AAR packaging を追加する。

## 9. 運用上の制約

- fixed preface を変更したい場合は Conversation を作り直す。
- checkpoint は Conversation instance ごとに所有される。
- Conversation の dispose 後に checkpoint は再利用できない。
- empty preface、`prefillPrefaceOnInit=false`、checkpoint 非対応 backend では reset できない。
- stock AAR は reset 非対応。
- Android 以外の platform は今回対象外。
- 同一 Conversation のリクエストは直列化する。
- 並列 Conversation はそれぞれ KV cache memory を消費する。
- AARの更新時は Kotlin classes と JNI の version/commit を混在させない。
- native code を変更した build で古い `reuse_aar_run_id` を使わない。

## 10. 今後の改善候補

1. patched AAR を version 付き Maven package として公開する。
2. Flutter app 向けの device integration test を Firebase Test Lab 等で実行する。
3. reset 前後の token count と first-token latency を自動計測する。
4. `sendMessageStateless` 全体を native 側の一操作にして、並行呼び出し安全性を強化する。
5. Conversation pool を用意し、安全な並列 stateless inference を提供する。
6. checkpoint backend capability を API で事前照会できるようにする。
7. cancellation/error 後の復元テストを増やす。
8. Web/desktop runtime に同等の checkpoint API が追加された場合、platform 実装を拡張する。
9. GitHub Actions の SDK/NDK/Flutter cache を改善し、統合runを短縮する。
10. `actions/setup-java` 等を新しい major versionへ更新し、Node 20 deprecation warning を解消する。

## 11. 完了判定

今回の要求に対する完了条件と結果は次のとおり。

| 完了条件 | 結果 |
| --- | --- |
| 固定 system prompt を初期 prefill できる | 完了 |
| preface 直後の KV checkpoint を保持できる | 完了 |
| user/model 履歴を捨てて checkpoint へ戻せる | 完了 |
| Flutter から明示 reset できる | 完了 |
| 1 call ごとに自動 reset する API がある | 完了 (`sendMessageStateless`) |
| Flutter/Android SDK がないPCからビルドできる | 完了（GitHub Actions） |
| arm64-v8a/x86_64 AARを生成できる | 完了 |
| patched AAR を使う Flutter APK compile | 完了 |
| 実機モデルでの性能・長時間安定性検証 | 未実施、次工程 |

以上により、ソース実装と再現可能な CI build pipeline は完成している。実運用へ進む前の残作業は、対象モデル・対象端末での checkpoint backend 対応確認、速度測定、メモリ測定、並行性方針の決定である。
