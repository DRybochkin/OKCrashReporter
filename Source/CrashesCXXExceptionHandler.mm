//
//  CrashesUncaughtCXXExceptionHandlerManager.mm
//  OKCrashReporter
//
//  Created by dmitry.rybochkin on 05.09.2022.
//

#import <cxxabi.h>
#import <dlfcn.h>
#import <exception>
#import <execinfo.h>
#import <libkern/OSAtomic.h>
#import <pthread.h>
#import <stdexcept>
#import <string>
#import <vector>

#import "CrashesCXXExceptionHandler.h"

// FIXME: Temporarily disable deprecated warning.
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"

typedef std::vector<CrashesUncaughtCXXExceptionHandler> CrashesUncaughtCXXExceptionHandlerList;
typedef struct {
    void *exception_object;
    uintptr_t call_stack[128];
    uint32_t num_frames;
} CrashesCXXExceptionTSInfo;

static bool _CrashesIsOurTerminateHandlerInstalled = false;
static std::terminate_handler _CrashesOriginalTerminateHandler = nullptr;
static CrashesUncaughtCXXExceptionHandlerList _CrashesUncaughtExceptionHandlerList;
static OSSpinLock _CrashesCXXExceptionHandlingLock = OS_SPINLOCK_INIT;
static pthread_key_t _CrashesCXXExceptionInfoTSDKey = 0;
static bool _ShouldUseHackExceptionHandler = false;

@implementation CrashesUncaughtCXXExceptionHandlerManager

extern "C"
{
#if !TARGET_IPHONE_SIMULATOR
    void __cxa_throw(void* thrown_exception, std::type_info* tinfo, void (*dest)(void*)) __attribute__ ((weak));
#endif

    void __cxa_throw(void* thrown_exception, std::type_info* tinfo, void (*dest)(void*))
    {
        typedef void (*cxa_throw_func)(void *, std::type_info *, void (*)(void *)) __attribute__((noreturn));
        static dispatch_once_t predicate = 0;
        static cxa_throw_func __original__cxa_throw = nullptr;
        static const void **__real_objc_ehtype_vtable = nullptr;

        dispatch_once(&predicate, ^{
            __real_objc_ehtype_vtable = reinterpret_cast<const void **>(dlsym(RTLD_DEFAULT, "objc_ehtype_vtable"));
        });

        // Actually check for Objective-C exceptions.
        if (tinfo && __real_objc_ehtype_vtable && // Guard from an ABI change
            *reinterpret_cast<void **>(tinfo) == __real_objc_ehtype_vtable + 2) {
            goto callthrough;
        }

        if (_CrashesIsOurTerminateHandlerInstalled) {
            CrashesCXXExceptionTSInfo *info = static_cast<CrashesCXXExceptionTSInfo *>(pthread_getspecific(_CrashesCXXExceptionInfoTSDKey));
            if (!info) {
                info = reinterpret_cast<CrashesCXXExceptionTSInfo *>(calloc(1, sizeof(CrashesCXXExceptionTSInfo)));
                pthread_setspecific(_CrashesCXXExceptionInfoTSDKey, info);
            }
            info->exception_object = thrown_exception;
            // XXX: All significant time in this call is spent right here.
            info->num_frames = static_cast<uint32_t>(backtrace(reinterpret_cast<void **>(&info->call_stack[0]), sizeof(info->call_stack) / sizeof(info->call_stack[0])));
        }

    callthrough:
        if(__builtin_expect(__original__cxa_throw == NULL, 0)) {
            __original__cxa_throw = (cxa_throw_func) dlsym(RTLD_NEXT, "__cxa_throw");
        }
        if (__original__cxa_throw) {
            __original__cxa_throw(thrown_exception, tinfo, dest);
        }
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wunreachable-code"
        __builtin_unreachable();
    #pragma clang diagnostic pop
    }
}

__attribute__((always_inline)) static inline void
CrashesIterateExceptionHandlers_unlocked(const CrashesUncaughtCXXExceptionInfo &info) {
    for (const auto &handler : _CrashesUncaughtExceptionHandlerList) {
        handler(&info);
    }
}

static void CrashesUncaughtCXXTerminateHandler(void) {
    CrashesUncaughtCXXExceptionInfo info = {
        .exception = nullptr,
        .exception_type_name = nullptr,
        .exception_message = nullptr,
        .exception_frames_count = 0,
        .exception_frames = nullptr,
    };
    auto p = std::current_exception();

    OSSpinLockLock(&_CrashesCXXExceptionHandlingLock);
    {
        if (p) { // explicit operator bool
            info.exception = reinterpret_cast<const void *>(&p);
            info.exception_type_name = __cxxabiv1::__cxa_current_exception_type()->name();

            CrashesCXXExceptionTSInfo *recorded_info = reinterpret_cast<CrashesCXXExceptionTSInfo *>(pthread_getspecific(_CrashesCXXExceptionInfoTSDKey));
            if (recorded_info) {
                info.exception_frames_count = recorded_info->num_frames - 1;
                info.exception_frames = &recorded_info->call_stack[1];
            } else {
                // There's no backtrace, grab this function's trace instead. Probably means the exception came from a dynamically loaded library.
                void *frames[128] = {nullptr};
                info.exception_frames_count = static_cast<uint32_t>(backtrace(&frames[0], sizeof(frames) / sizeof(frames[0])) - 1);
                info.exception_frames = reinterpret_cast<uintptr_t *>(&frames[1]);
            }
            try {
                std::rethrow_exception(p);
            } catch (const std::exception &e) {
                // C++ exception.
                info.exception_message = e.what();
                CrashesIterateExceptionHandlers_unlocked(info);
            } catch (const std::exception *e) {
                // C++ exception by pointer.
                info.exception_message = e->what();
                CrashesIterateExceptionHandlers_unlocked(info);
            } catch (const std::string &e) {
                // C++ string as exception.
                info.exception_message = e.c_str();
                CrashesIterateExceptionHandlers_unlocked(info);
            } catch (const std::string *e) {
                // C++ string pointer as exception.
                info.exception_message = e->c_str();
                CrashesIterateExceptionHandlers_unlocked(info);
            } catch (const char *e) { // Plain string as exception.
                info.exception_message = e;
                CrashesIterateExceptionHandlers_unlocked(info);
            } catch (__attribute__((unused)) id e) {
                // Objective-C exception. Pass it on to Foundation.
                OSSpinLockUnlock(&_CrashesCXXExceptionHandlingLock);
                if (_CrashesOriginalTerminateHandler != nullptr) {
                    _CrashesOriginalTerminateHandler();
                }
                return;
            } catch (...) {
                if (_ShouldUseHackExceptionHandler) {
                    CrashesIterateExceptionHandlers_unlocked(info);
                }
            }
        } else if (_ShouldUseHackExceptionHandler) {
            CrashesIterateExceptionHandlers_unlocked(info);
        }
    }
    OSSpinLockUnlock(&_CrashesCXXExceptionHandlingLock);

    // In case terminate is called reentrantly by passing it on.
    if (_CrashesOriginalTerminateHandler != nullptr) {
        _CrashesOriginalTerminateHandler();
    } else {
        abort();
    }
}

+ (void)addCXXExceptionHandler:(CrashesUncaughtCXXExceptionHandler)handler {
    static dispatch_once_t key_predicate = 0;

    // This only EVER has to be done once, since we don't delete the TSD later (there's no reason to delete it).
    dispatch_once(&key_predicate, ^{
        pthread_key_create(&_CrashesCXXExceptionInfoTSDKey, free);
    });

    OSSpinLockLock(&_CrashesCXXExceptionHandlingLock);
    {
        if (!_CrashesIsOurTerminateHandlerInstalled) {
            _CrashesOriginalTerminateHandler = std::set_terminate(CrashesUncaughtCXXTerminateHandler);
            _CrashesIsOurTerminateHandlerInstalled = true;
        }
        _CrashesUncaughtExceptionHandlerList.push_back(handler);
    }
    OSSpinLockUnlock(&_CrashesCXXExceptionHandlingLock);
}

+ (void)removeCXXExceptionHandler:(CrashesUncaughtCXXExceptionHandler)handler {
    OSSpinLockLock(&_CrashesCXXExceptionHandlingLock);
    {
        auto i = std::find(_CrashesUncaughtExceptionHandlerList.begin(), _CrashesUncaughtExceptionHandlerList.end(), handler);

        if (i != _CrashesUncaughtExceptionHandlerList.end()) {
            _CrashesUncaughtExceptionHandlerList.erase(i);
        }

        if (_CrashesIsOurTerminateHandlerInstalled) {
            if (_CrashesUncaughtExceptionHandlerList.empty()) {
                std::terminate_handler previous_handler = std::set_terminate(_CrashesOriginalTerminateHandler);
                if (previous_handler != CrashesUncaughtCXXTerminateHandler) {
                    std::set_terminate(previous_handler);
                } else {
                    _CrashesIsOurTerminateHandlerInstalled = false;
                    _CrashesOriginalTerminateHandler = nullptr;
                }
            }
        }
    }
    OSSpinLockUnlock(&_CrashesCXXExceptionHandlingLock);
}

+ (NSUInteger)countCXXExceptionHandler {
    NSUInteger count = 0;
    OSSpinLockLock(&_CrashesCXXExceptionHandlingLock);
    { count = _CrashesUncaughtExceptionHandlerList.size(); }
    OSSpinLockUnlock(&_CrashesCXXExceptionHandlingLock);
    return count;
}

+ (void)setShouldUseHackExceptionHandler:(BOOL)shouldUseHackExceptionHandler {
    _ShouldUseHackExceptionHandler = shouldUseHackExceptionHandler;
}

#pragma GCC diagnostic pop

@end
