//
//  PLCrashReportTracerThreadInfo.m
//  OKTracer
//
//  Created by dmitry.rybochkin on 29.11.2022.
//

#import "PLCrashReportTracerThreadInfo.h"

@implementation PLCrashReportTracerThreadInfo

- (id) initWithThreadName: (NSString *) threadName
                addresses: (NSArray<NSNumber *> *) addresses
                  symbols: (NSArray<NSString *> *) symbols {
    if ((self = [super init]) == nil)
        return nil;

    _addresses = addresses;
    _symbols = symbols;
    _threadName = [threadName stringByReplacingOccurrencesOfString:@" " withString:@"_"];

    return self;
}

@synthesize threadName = _threadName;
@synthesize addresses = _addresses;
@synthesize symbols = _symbols;

@end
