#include <cstdint>
#include <new>

#include "native_error.h"

#if defined(_WIN32)
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT __attribute__((visibility("default")))
#endif

struct LiteRtLmEngine;
struct LiteRtLmEngineSettings;
struct LiteRtLmConversation;
struct LiteRtLmConversationConfig;
struct LiteRtLmSession;
struct LiteRtLmSessionConfig;

namespace {

template <typename Result, typename Function, typename... Args>
Result GuardPointerCall(Function function, int32_t* status,
                        Args... args) noexcept {
  if (status == nullptr) {
    return nullptr;
  }
  *status = litertlm::kNativeCallFailure;
  if (function == nullptr) {
    return nullptr;
  }

  try {
    Result result = function(args...);
    *status = result == nullptr ? litertlm::kNativeCallFailure
                                : litertlm::kNativeCallSuccess;
    return result;
  } catch (const std::bad_alloc&) {
    *status = litertlm::kNativeCallOutOfMemory;
    return nullptr;
  } catch (...) {
    *status = litertlm::kNativeCallUnexpectedException;
    return nullptr;
  }
}

}  // namespace

extern "C" {

typedef LiteRtLmEngine* (*LiteRtLmEngineCreate)(
    const LiteRtLmEngineSettings* settings);
typedef LiteRtLmConversation* (*LiteRtLmConversationCreate)(
    LiteRtLmEngine* engine, LiteRtLmConversationConfig* config);
typedef LiteRtLmSession* (*LiteRtLmEngineCreateSession)(
    LiteRtLmEngine* engine, LiteRtLmSessionConfig* config);

FFI_PLUGIN_EXPORT LiteRtLmEngine* litertlm_engine_create_guarded(
    LiteRtLmEngineCreate create, const LiteRtLmEngineSettings* settings,
    int32_t* status) noexcept {
  return GuardPointerCall<LiteRtLmEngine*>(create, status, settings);
}

FFI_PLUGIN_EXPORT LiteRtLmConversation* litertlm_conversation_create_guarded(
    LiteRtLmConversationCreate create, LiteRtLmEngine* engine,
    LiteRtLmConversationConfig* config, int32_t* status) noexcept {
  return GuardPointerCall<LiteRtLmConversation*>(create, status, engine,
                                                 config);
}

FFI_PLUGIN_EXPORT LiteRtLmSession* litertlm_engine_create_session_guarded(
    LiteRtLmEngineCreateSession create, LiteRtLmEngine* engine,
    LiteRtLmSessionConfig* config, int32_t* status) noexcept {
  return GuardPointerCall<LiteRtLmSession*>(create, status, engine, config);
}

}  // extern "C"