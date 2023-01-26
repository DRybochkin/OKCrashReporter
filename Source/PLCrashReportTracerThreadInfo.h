//
//  PLCrashReportTracerThreadInfo.h
//  OKTracer
//
//  Created by dmitry.rybochkin on 29.11.2022.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PLCrashReportTracerThreadInfo : NSObject {
@private
    NSString *_threadName;
    __strong NSArray<NSNumber *> *_addresses;
    __strong NSArray<NSString *> *_symbols;
}

- (id) initWithThreadName: (NSString *) threadName
                addresses: (NSArray<NSNumber *> *) addresses
                  symbols: (NSArray<NSString *> *) symbols;

@property(nonatomic, readonly) NSString *threadName;
@property(nonatomic, readonly, strong) NSArray<NSNumber *> *addresses;
@property(nonatomic, readonly, strong) NSArray<NSString *> *symbols;

@end

NS_ASSUME_NONNULL_END
