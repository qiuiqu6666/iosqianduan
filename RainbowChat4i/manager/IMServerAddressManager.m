#import "IMServerAddressManager.h"

// NSUserDefaults 持久化 key
static NSString * const kLastSuccessIPKey   = @"IM_SERVER_LAST_SUCCESS_IP";
static NSString * const kLastSuccessPortKey = @"IM_SERVER_LAST_SUCCESS_PORT";

#pragma mark - IMServerAddress

@implementation IMServerAddress

+ (instancetype)addressWithIp:(NSString *)ip port:(int)port
{
    IMServerAddress *addr = [[IMServerAddress alloc] init];
    addr.ip   = ip;
    addr.port = port;
    addr.failCount = 0;
    addr.lastSuccessTime = 0;
    return addr;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<IMServerAddress %@:%d fail=%ld lastOK=%.0f>",
            self.ip, self.port, (long)self.failCount, self.lastSuccessTime];
}

@end


#pragma mark - IMServerAddressManager

@interface IMServerAddressManager ()
@property (nonatomic, strong) NSMutableArray<IMServerAddress *> *servers;
@property (nonatomic, assign, readwrite) NSUInteger currentIndex;
@end

@implementation IMServerAddressManager

static IMServerAddressManager *_instance = nil;

+ (instancetype)sharedInstance
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[IMServerAddressManager alloc] init];
    });
    return _instance;
}

- (instancetype)init
{
    if (self = [super init]) {
        _servers = [NSMutableArray array];
        _currentIndex = 0;
    }
    return self;
}

- (void)setupWithIPList:(NSArray<NSString *> *)ipList defaultPort:(int)defaultPort
{
    [self.servers removeAllObjects];
    
    for (NSString *ip in ipList) {
        [self.servers addObject:[IMServerAddress addressWithIp:ip port:defaultPort]];
    }
    
    if (self.servers.count == 0) {
        NSLog(@"【IMServerAddressManager】⚠️ 候选 IP 列表为空！");
        return;
    }
    
    // 尝试从 NSUserDefaults 恢复上次成功的服务器
    [self restoreLastSuccessServer];
    
    NSLog(@"【IMServerAddressManager】已初始化 %lu 个候选服务器，当前选中: %@",
          (unsigned long)self.servers.count, [self currentServer]);
}

#pragma mark - 核心接口

- (IMServerAddress *)currentServer
{
    if (self.servers.count == 0) return nil;
    return self.servers[self.currentIndex];
}

- (void)markCurrentServerSuccess
{
    if (self.servers.count == 0) return;
    
    IMServerAddress *server = self.servers[self.currentIndex];
    server.failCount = 0;
    server.lastSuccessTime = [[NSDate date] timeIntervalSince1970];
    
    NSLog(@"【IMServerAddressManager】✅ 服务器连接成功: %@:%d", server.ip, server.port);
    
    // 持久化最后成功的服务器信息
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    [ud setObject:server.ip forKey:kLastSuccessIPKey];
    [ud setInteger:server.port forKey:kLastSuccessPortKey];
    [ud synchronize];
}

- (IMServerAddress *)markCurrentServerFailedAndSwitchNext
{
    if (self.servers.count == 0) return nil;
    
    IMServerAddress *failedServer = self.servers[self.currentIndex];
    failedServer.failCount += 1;
    
    NSLog(@"【IMServerAddressManager】❌ 服务器连接失败: %@:%d (连续失败 %ld 次)",
          failedServer.ip, failedServer.port, (long)failedServer.failCount);
    
    if (self.servers.count <= 1) {
        NSLog(@"【IMServerAddressManager】仅有 1 个候选服务器，无法切换。");
        return failedServer;
    }
    
    // 切换到下一个候选地址（Round-Robin）
    self.currentIndex = (self.currentIndex + 1) % self.servers.count;
    
    // 如果下一个服务器的失败次数也很高，尝试寻找一个失败次数最少的
    IMServerAddress *bestCandidate = [self findBestCandidate];
    if (bestCandidate) {
        NSUInteger bestIdx = [self.servers indexOfObject:bestCandidate];
        if (bestIdx != NSNotFound) {
            self.currentIndex = bestIdx;
        }
    }
    
    IMServerAddress *newServer = self.servers[self.currentIndex];
    NSLog(@"【IMServerAddressManager】🔄 已切换到下一个服务器: %@:%d", newServer.ip, newServer.port);
    
    return newServer;
}

- (void)resetAllFailCounts
{
    for (IMServerAddress *server in self.servers) {
        server.failCount = 0;
    }
    NSLog(@"【IMServerAddressManager】已重置所有服务器的失败计数。");
}

- (NSUInteger)serverCount
{
    return self.servers.count;
}

#pragma mark - 内部方法

/// 从候选服务器中找到"最佳"候选：优先选择失败次数最少的，相同失败次数时优先选择最近成功过的。
- (IMServerAddress *)findBestCandidate
{
    if (self.servers.count == 0) return nil;
    
    IMServerAddress *best = self.servers[0];
    for (IMServerAddress *s in self.servers) {
        // 失败次数更少的优先
        if (s.failCount < best.failCount) {
            best = s;
        }
        // 失败次数相同时，最近成功过的优先
        else if (s.failCount == best.failCount && s.lastSuccessTime > best.lastSuccessTime) {
            best = s;
        }
    }
    return best;
}

/// 从 NSUserDefaults 恢复上次成功的服务器，并将其置为 currentIndex
- (void)restoreLastSuccessServer
{
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    NSString *lastIP = [ud stringForKey:kLastSuccessIPKey];
    
    if (lastIP && lastIP.length > 0) {
        for (NSUInteger i = 0; i < self.servers.count; i++) {
            if ([self.servers[i].ip isEqualToString:lastIP]) {
                self.currentIndex = i;
                self.servers[i].lastSuccessTime = 1; // 标记为有成功记录（比 0 大即可）
                NSLog(@"【IMServerAddressManager】已恢复上次成功的服务器: %@:%d (index=%lu)",
                      lastIP, self.servers[i].port, (unsigned long)i);
                return;
            }
        }
        NSLog(@"【IMServerAddressManager】上次成功的 IP(%@) 不在当前候选列表中，使用默认第一个。", lastIP);
    }
    
    self.currentIndex = 0;
}

@end
