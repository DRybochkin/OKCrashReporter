//
//  CrashesHandler.h
//  OKCrashReporter
//
//  Created by dmitry.rybochkin on 05.09.2022.
//

#import "PLCrashReporter.h"

NS_SWIFT_NAME(CrashesHandler)
@interface CrashesHandler : NSObject

- (NSUncaughtExceptionHandler *)configureCrashReporter:(PLCrashReporter *)plCrashReporter
                         shouldUseHackExceptionHandler:(BOOL)shouldUseHackExceptionHandler;
- (void)generateCppTestCrash;
- (BOOL)generateObjCTestCrash;

@end
