#include <stdbool.h>
#include <stdlib.h>
#include <string.h>

#if defined(_WIN32)
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT __attribute__((visibility("default")))
#endif

typedef void (*LiteRtLmDartStreamCallback)(const char *chunk, bool is_final,
                                           const char *error_msg);

typedef struct LiteRtLmStreamChunk LiteRtLmStreamChunk;
typedef const char *(*LiteRtLmStreamChunkGetString)(
    const LiteRtLmStreamChunk *chunk);
typedef bool (*LiteRtLmStreamChunkIsFinal)(const LiteRtLmStreamChunk *chunk);

typedef struct LiteRtLmStreamCallbackContext {
  LiteRtLmDartStreamCallback callback;
  LiteRtLmStreamChunkGetString get_text;
  LiteRtLmStreamChunkIsFinal is_final;
  LiteRtLmStreamChunkGetString get_error;
} LiteRtLmStreamCallbackContext;

FFI_PLUGIN_EXPORT void litertlm_free(void *pointer) { free(pointer); }

FFI_PLUGIN_EXPORT void *litertlm_stream_callback_context_create(
    LiteRtLmDartStreamCallback callback,
    LiteRtLmStreamChunkGetString get_text,
    LiteRtLmStreamChunkIsFinal is_final,
    LiteRtLmStreamChunkGetString get_error) {
  LiteRtLmStreamCallbackContext *context =
      (LiteRtLmStreamCallbackContext *)malloc(sizeof(*context));
  if (context == NULL) {
    return NULL;
  }
  context->callback = callback;
  context->get_text = get_text;
  context->is_final = is_final;
  context->get_error = get_error;
  return context;
}

FFI_PLUGIN_EXPORT void litertlm_stream_callback_context_delete(
    void *callback_data) {
  free(callback_data);
}

FFI_PLUGIN_EXPORT void litertlm_stream_callback_bridge(
    void *callback_data, const LiteRtLmStreamChunk *chunk) {
  LiteRtLmStreamCallbackContext *context =
      (LiteRtLmStreamCallbackContext *)callback_data;
  if (context == NULL || context->callback == NULL ||
      context->get_text == NULL || context->is_final == NULL ||
      context->get_error == NULL) {
    return;
  }

  const char *text = context->get_text(chunk);
  const bool is_final = context->is_final(chunk);
  const char *error_msg = context->get_error(chunk);

  char *chunk_copy = NULL;
  if (text != NULL) {
    size_t chunk_length = strlen(text) + 1;
    chunk_copy = (char *)malloc(chunk_length);
    if (chunk_copy != NULL) {
      memcpy(chunk_copy, text, chunk_length);
    }
  }

  char *error_copy = NULL;
  if (error_msg != NULL) {
    size_t error_length = strlen(error_msg) + 1;
    error_copy = (char *)malloc(error_length);
    if (error_copy != NULL) {
      memcpy(error_copy, error_msg, error_length);
    }
  }

  context->callback(chunk_copy, is_final, error_copy);
}