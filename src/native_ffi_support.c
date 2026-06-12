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

FFI_PLUGIN_EXPORT void litertlm_free(void *pointer) { free(pointer); }

FFI_PLUGIN_EXPORT void litertlm_stream_callback_bridge(
    void *callback_data, const char *chunk, bool is_final,
  const char *error_msg) {
  LiteRtLmDartStreamCallback dart_callback =
      (LiteRtLmDartStreamCallback)callback_data;
  if (dart_callback == NULL) {
    return;
  }

  char *chunk_copy = NULL;
  if (chunk != NULL) {
    size_t chunk_length = strlen(chunk) + 1;
    chunk_copy = (char *)malloc(chunk_length);
    if (chunk_copy != NULL) {
      memcpy(chunk_copy, chunk, chunk_length);
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

  dart_callback(chunk_copy, is_final, error_copy);
}