#ifndef LITERTLM_NATIVE_ERROR_H_
#define LITERTLM_NATIVE_ERROR_H_

#include <cstdint>

namespace litertlm {

enum NativeErrorCode : int32_t {
  kNativeCallSuccess = 0,
  kNativeCallFailure = 1,
  kNativeCallOutOfMemory = 2,
  kNativeCallUnexpectedException = 3,
};

enum NativeOperation : int32_t {
  kEngineInitialization = 0,
  kConversationCreation = 1,
  kSessionCreation = 2,
};

}  // namespace litertlm

#endif  // LITERTLM_NATIVE_ERROR_H_