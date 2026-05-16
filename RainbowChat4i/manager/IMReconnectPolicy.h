/**
 * IM 重连指数退避策略管理器。
 *
 * 功能：
 *  1. 实现指数退避（Exponential Backoff）：重试间隔 2s → 4s → 8s → 16s → 30s(max)；
 *  2. 添加随机抖动（Jitter ±25%），防止大量客户端同时重连造成的"惊群效应"；
 *  3. 连接成功时自动重置退避计数；
 *  4. 提供 shouldReconnectNow 方法，判断当前是否到达重连时机。
 *
 * 使用方式：
 *  - 每次尝试重连前调用 shouldReconnectNow，返回 YES 时才执行重连；
 *  - 重连失败后调用 recordFailedAttempt；
 *  - 重连成功后调用 reset 重置退避状态。
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface IMReconnectPolicy : NSObject

+ (instancetype)sharedInstance;

/// 记录一次重连失败，自增重试计数并更新下次重连时间
- (void)recordFailedAttempt;

/// 连接成功时重置退避状态
- (void)reset;

/// 判断当前是否到达下次重连时间点
/// @return YES 表示可以立即重连，NO 表示尚需等待
- (BOOL)shouldReconnectNow;

/// 获取当前的重试间隔（秒，含抖动）
- (NSTimeInterval)currentRetryInterval;

/// 获取距离下次可重连的剩余等待秒数（如已到时间则返回 0）
- (NSTimeInterval)remainingWaitTime;

/// 当前连续失败次数
@property (nonatomic, assign, readonly) NSUInteger retryCount;

/// 基础重试间隔（秒），默认 2.0
@property (nonatomic, assign) NSTimeInterval baseInterval;

/// 最大重试间隔（秒），默认 30.0
@property (nonatomic, assign) NSTimeInterval maxInterval;

/// 抖动比例（0~1.0），默认 0.25（即 ±25%）
@property (nonatomic, assign) double jitterRatio;

@end

NS_ASSUME_NONNULL_END
