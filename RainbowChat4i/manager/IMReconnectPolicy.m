#import "IMReconnectPolicy.h"

@interface IMReconnectPolicy ()
@property (nonatomic, assign, readwrite) NSUInteger retryCount;
/// 下一次允许重连的时间戳
@property (nonatomic, assign) NSTimeInterval nextRetryTimestamp;
/// 当前计算出的重试间隔（含抖动）
@property (nonatomic, assign) NSTimeInterval cachedInterval;
@end

@implementation IMReconnectPolicy

static IMReconnectPolicy *_instance = nil;

+ (instancetype)sharedInstance
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[IMReconnectPolicy alloc] init];
    });
    return _instance;
}

- (instancetype)init
{
    if (self = [super init]) {
        _baseInterval = 2.0;
        _maxInterval  = 30.0;
        _jitterRatio  = 0.25;
        _retryCount   = 0;
        _nextRetryTimestamp = 0;
        _cachedInterval = 0;
    }
    return self;
}

#pragma mark - 核心接口

- (void)recordFailedAttempt
{
    self.retryCount += 1;
    
    // 计算当前退避间隔: min(base * 2^retryCount, max)
    NSTimeInterval interval = self.baseInterval * pow(2.0, (double)(self.retryCount - 1));
    interval = MIN(interval, self.maxInterval);
    
    // 添加随机抖动 (±jitterRatio)
    double jitter = interval * self.jitterRatio;
    // arc4random_uniform 返回 [0, N)，将其映射到 [-jitter, +jitter]
    double randomJitter = ((double)arc4random_uniform(10000) / 10000.0) * 2.0 * jitter - jitter;
    interval += randomJitter;
    
    // 确保间隔不小于基础间隔
    interval = MAX(interval, self.baseInterval);
    
    self.cachedInterval = interval;
    self.nextRetryTimestamp = [[NSDate date] timeIntervalSince1970] + interval;
    
    NSLog(@"【IMReconnectPolicy】重连失败第 %lu 次，下次重连间隔: %.1f 秒 (含抖动), 下次重连时间: %.0f",
          (unsigned long)self.retryCount, interval, self.nextRetryTimestamp);
}

- (void)reset
{
    if (self.retryCount > 0) {
        NSLog(@"【IMReconnectPolicy】✅ 连接成功，重置退避策略 (之前已重试 %lu 次)", (unsigned long)self.retryCount);
    }
    self.retryCount = 0;
    self.nextRetryTimestamp = 0;
    self.cachedInterval = 0;
}

- (BOOL)shouldReconnectNow
{
    // 从未失败过，或者已重置，可以立即重连
    if (self.retryCount == 0) {
        return YES;
    }
    
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    return now >= self.nextRetryTimestamp;
}

- (NSTimeInterval)currentRetryInterval
{
    if (self.retryCount == 0) return 0;
    return self.cachedInterval;
}

- (NSTimeInterval)remainingWaitTime
{
    if (self.retryCount == 0) return 0;
    
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    NSTimeInterval remaining = self.nextRetryTimestamp - now;
    return MAX(remaining, 0);
}

@end
