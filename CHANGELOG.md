## 0.0.8

* Improved WASM compatibility.

## 0.0.7

* Added `MessageCallback.onMessageDone` for message boundaries.
* Updated `Conversation.sendMessageStream` to emit an empty message at native message-generation boundaries.
* Added `SessionConfig.maxOutputTokens` and `SessionConfig.applyPromptTemplateInSession` for supported platforms.
* Added `ExperimentalFlags.filterChannelContentFromKvCache` and `ExperimentalFlags.visualTokenBudget`.

## 0.0.6

* Added `ExperimentalFlags` with `enableBenchmark`, `enableSpeculativeDecoding`, `enableConversationConstrainedDecoding`.

## 0.0.5

* Added callback-style conversation streaming.

## 0.0.4

* Added `maxNumImages` for `EngineConfig`.
* Added `Channel` for supported platforms.
* Added `Session`, `SessionConfig`, and advanced session control.
* Added model capabilities check.
* Added benchmark support.
* Improved `Backend` control.

## 0.0.3

* Improved `ConversationConfig`, `Tool` with Swift/Java matching contract.
* Improved tool call support.
* Added document for public contract.

## 0.0.2

* Initial release with experimental support for all platforms.
