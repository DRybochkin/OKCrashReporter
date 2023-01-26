//
//  CrashesUncaughtCXXExceptionHandlerManager.h
//  OKCrashReporter
//
//  Created by dmitry.rybochkin on 05.09.2022.
//

#import <Foundation/Foundation.h>

typedef struct {
    const void *__nullable exception;
    const char *__nullable exception_type_name;
    const char *__nullable exception_message;
    uint32_t exception_frames_count;
    const uintptr_t *__nonnull exception_frames;
} CrashesUncaughtCXXExceptionInfo;

typedef void (*CrashesUncaughtCXXExceptionHandler)(const CrashesUncaughtCXXExceptionInfo *__nonnull info);

@interface CrashesUncaughtCXXExceptionHandlerManager : NSObject

+ (void)addCXXExceptionHandler:(nonnull CrashesUncaughtCXXExceptionHandler)handler;
+ (void)setShouldUseHackExceptionHandler:(BOOL)shouldUseHackExceptionHandler;

@end
