//
//  CrashesCXXExceptionWrapperException.h
//  OKCrashReporter
//
//  Created by dmitry.rybochkin on 05.09.2022.
//

#import <Foundation/Foundation.h>

#import "CrashesCXXExceptionHandler.h"

@interface CrashesCXXExceptionWrapperException : NSException

- (instancetype)initWithCXXExceptionInfo:(const CrashesUncaughtCXXExceptionInfo *)info;

@end
