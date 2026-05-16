/**
 * IM 服务器多 IP 轮询管理器。
 *
 * 功能：
 *  1. 维护一组候选 IM 服务器地址（IP + Port）；
 *  2. 根据连接成功/失败记录进行智能排序，优先返回最近连接成功的地址；
 *  3. 连接失败时自动切换到下一个候选地址（Round-Robin）；
 *  4. 健康状态持久化到 NSUserDefaults，App 重启后仍可延续。
 *
 * 使用方式：
 *  - App 启动时调用 [IMServerAddressManager sharedInstance] 初始化；
 *  - 连接 IM 前调用 currentServer 获取当前最优服务器地址；
 *  - 连接成功后调用 markCurrentServerSuccess；
 *  - 连接失败后调用 markCurrentServerFailedAndSwitchNext 切换到下一个候选地址。
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 单个服务器地址信息
@interface IMServerAddress : NSObject
@property (nonatomic, copy)   NSString *ip;
@property (nonatomic, assign) int       port;
@property (nonatomic, assign) NSInteger failCount;      ///< 连续失败次数
@property (nonatomic, assign) NSTimeInterval lastSuccessTime; ///< 上次连接成功的时间戳
+ (instancetype)addressWithIp:(NSString *)ip port:(int)port;
@end


@interface IMServerAddressManager : NSObject

+ (instancetype)sharedInstance;

/// 使用给定的 IP 列表和端口初始化候选服务器。
/// 通常在 App 启动时调用一次。
/// @param ipList IP 地址数组
/// @param defaultPort 默认端口（所有 IP 共享同一端口）
- (void)setupWithIPList:(NSArray<NSString *> *)ipList defaultPort:(int)defaultPort;

/// 获取当前应该连接的服务器地址（基于健康优先 + 轮询）
- (IMServerAddress *)currentServer;

/// 标记当前服务器连接成功
- (void)markCurrentServerSuccess;

/// 标记当前服务器连接失败，并自动切换到下一个候选地址
/// @return 切换后的新服务器地址
- (IMServerAddress *)markCurrentServerFailedAndSwitchNext;

/// 重置所有服务器的失败计数（例如网络环境整体发生变化时）
- (void)resetAllFailCounts;

/// 当前候选服务器总数
- (NSUInteger)serverCount;

/// 当前选中的服务器索引
@property (nonatomic, assign, readonly) NSUInteger currentIndex;

@end

NS_ASSUME_NONNULL_END
