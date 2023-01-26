//
//  CrashesHandler.mm
//  OKCrashReporter
//
//  Created by dmitry.rybochkin on 05.09.2022.
//

#import <UIKit/UIKit.h>
#import <string>

#import "CrashesHandler.h"
#import "CrashesCXXExceptionWrapperException.h"

typedef void (*CrashesPostCrashSignalCallback)(void * _Nullable context);
typedef struct CrashesCallbacks {
    void * _Nullable context;
    CrashesPostCrashSignalCallback _Nullable handleSignal;
} CrashesCallbacks;
static CrashesCallbacks crashesCallbacks = {.context = nullptr, .handleSignal = nullptr};
static void plcr_post_crash_callback(__unused siginfo_t *info, __unused ucontext_t *uap, void *context) {
    if (crashesCallbacks.handleSignal != nullptr) {
        crashesCallbacks.handleSignal(context);
    }
}
static PLCrashReporterCallbacks plCrashCallbacks = {.version = 0, .context = nullptr, .handleSignal = plcr_post_crash_callback};
__attribute__((noreturn)) static void uncaught_cxx_exception_handler(const CrashesUncaughtCXXExceptionInfo *info) {
    NSGetUncaughtExceptionHandler()([[CrashesCXXExceptionWrapperException alloc] initWithCXXExceptionInfo:info]);
    abort();
}

@interface CrashesHandler ()

@property(nonatomic) NSUncaughtExceptionHandler *exceptionHandler;

@end

@implementation CrashesHandler

- (BOOL)generateObjCTestCrash {
    NSArray *array = @[@0, @1, @2];
    NSNumber *y100 = array[10];
    return y100 == nil;
}

- (void)generateCppTestCrash {
    try {
      throw std::runtime_error("test1");
    } catch (...) {
      std::get_terminate()();
    }
}

- (NSUncaughtExceptionHandler *)configureCrashReporter:(PLCrashReporter *)plCrashReporter
                         shouldUseHackExceptionHandler:(BOOL)shouldUseHackExceptionHandler {
    NSUncaughtExceptionHandler *exceptionHandler = NSGetUncaughtExceptionHandler();
    [plCrashReporter setCrashCallbacks:&plCrashCallbacks];
    [CrashesUncaughtCXXExceptionHandlerManager setShouldUseHackExceptionHandler:shouldUseHackExceptionHandler];
    [CrashesUncaughtCXXExceptionHandlerManager addCXXExceptionHandler:uncaught_cxx_exception_handler];
    return exceptionHandler;
}

@end
