//telegram @wz662
// 单聊文本发送失败后的前端退避重试（类似微信）：2s/5s/10s/20s/40s 重试，超 1 分钟标记失败
#import "SendRetryManager.h"
#import "MessageHelper.h"
#import "MsgBody4Friend.h"
#import "MsgBody4Group.h"
#import "MsgBodyRoot.h"
#import "QuoteMeta.h"
#import "IMClientManager.h"
#import "MessagesProvider.h"
#import "JSQMessage.h"
#import "ClientCoreSDK.h"
#import "ErrorCode.h"
#import "GMessageHelper.h"

static const NSTimeInterval kGiveUpSeconds = 60.0;
static const NSTimeInterval kRetryDelays[] = { 2.0, 5.0, 10.0, 20.0, 40.0 };
static const int kRetryCount = (int)(sizeof(kRetryDelays) / sizeof(kRetryDelays[0]));
// 群聊/大群：更密集重试，网络恢复一瞬间就能发出
static const NSTimeInterval kGroupRetryDelays[] = { 1.0, 2.0, 4.0, 8.0, 15.0, 30.0 };
static const int kGroupRetryCount = (int)(sizeof(kGroupRetryDelays) / sizeof(kGroupRetryDelays[0]));

@interface SendRetryManager ()
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSDictionary *> *pending;
@property (nonatomic, strong) dispatch_queue_t queue; // 串行队列，统一处理 pending 与定时
@end

@implementation SendRetryManager

+ (instancetype)sharedInstance {
    static SendRetryManager *s = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [[SendRetryManager alloc] init]; });
    return s;
}

- (instancetype)init {
    if (self = [super init]) {
        _pending = [NSMutableDictionary dictionary];
        _queue = dispatch_queue_create("com.rainbow.sendretry", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)startRetryForTextFp:(NSString *)fp toId:(NSString *)toId text:(NSString *)text quoteMeta:(QuoteMeta *)quoteMeta {
    if (!fp.length || !toId.length || !text.length) return;
    NSDictionary *task = @{
        @"fp": fp,
        @"toId": toId,
        @"text": text,
        @"quoteMeta": quoteMeta ?: [NSNull null],
        @"startTime": @(CFAbsoluteTimeGetCurrent()),
    };
    __weak typeof(self) wself = self;
    dispatch_async(self.queue, ^{
        __strong typeof(wself) sself = wself;
        if (!sself) return;
        if (sself.pending[fp]) return; // 已存在则不再重复
        sself.pending[fp] = task;
        // 退避重试：2s、5s、10s、20s、40s 各一次
        for (int i = 0; i < kRetryCount; i++) {
            NSTimeInterval delay = kRetryDelays[i];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), sself.queue, ^{
                [sself doRetryForFp:fp];
            });
        }
        // 1 分钟后放弃并标记失败
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kGiveUpSeconds * NSEC_PER_SEC)), sself.queue, ^{
            [sself doGiveUpForFp:fp];
        });
    });
}

- (void)doRetryForFp:(NSString *)fp {
    NSDictionary *task = self.pending[fp];
    if (!task) return;
    if ([task[@"isGroup"] boolValue]) {
        [self doRetryForGroupFp:fp];
        return;
    }
    NSString *toId = task[@"toId"];
    NSString *text = task[@"text"];
    QuoteMeta *quoteMeta = [task[@"quoteMeta"] isKindOfClass:[QuoteMeta class]] ? task[@"quoteMeta"] : nil;
    if (!toId.length || !text.length) return;
    MsgBody4Friend *msgBody = [MsgBody4Friend constructFriendChatMsgBody:[[ClientCoreSDK sharedInstance] currentLoginUserId] t:toId m:text ty:TM_TYPE_TEXT];
    if (quoteMeta) [msgBody setQuoteMeta:quoteMeta];
    int code = [MessageHelper sendChatMessage:toId withMessage:msgBody finger:fp];
    if (code == COMMON_CODE_OK) {
        [self.pending removeObjectForKey:fp];
    }
}

- (void)doRetryForGroupFp:(NSString *)fp {
    NSDictionary *task = self.pending[fp];
    if (!task) return;
    NSString *gid = task[@"toId"];
    NSString *text = task[@"text"];
    NSArray *atUsers = [task[@"atUsers"] isKindOfClass:[NSArray class]] ? task[@"atUsers"] : nil;
    QuoteMeta *quoteMeta = [task[@"quoteMeta"] isKindOfClass:[QuoteMeta class]] ? task[@"quoteMeta"] : nil;
    int msgType = [task[@"messageType"] intValue];
    if (!gid.length || !text.length) return;
    MsgBody4Group *body = [GMessageHelper constructGroupChatMsgBodyForSend:fp msgType:msgType gid:gid msg:text at:atUsers];
    if (quoteMeta) [body setQuoteMeta:quoteMeta];
    int code = [GMessageHelper sendBBSChatMsg_A_TO_SERVER_Message:body qos:YES fp:fp];
    if (code == COMMON_CODE_OK) {
        [self.pending removeObjectForKey:fp];
    }
}

- (void)doGiveUpForFp:(NSString *)fp {
    NSDictionary *task = self.pending[fp];
    if (!task) return;
    [self.pending removeObjectForKey:fp];
    NSString *toId = task[@"toId"];
    if (!toId.length) return;
    BOOL isGroup = [task[@"isGroup"] boolValue];
    dispatch_async(dispatch_get_main_queue(), ^{
        MessagesProvider *mp = isGroup
            ? (id)[[IMClientManager sharedInstance] getGroupsMessagesProvider]
            : [[IMClientManager sharedInstance] getMessagesProvider];
        JSQMessage *msg = [mp findMessageByFingerPrint:toId fp:fp];
        if (msg) {
            msg.sendStatus = SendStatus_SEND_FAILD;
            [mp notifyAllObserver];
        }
    });
}

- (void)startGiveUpTimerOnlyForTextFp:(NSString *)fp toId:(NSString *)toId {
    if (!fp.length || !toId.length) return;
    NSDictionary *task = @{ @"fp": fp, @"toId": toId };
    __weak typeof(self) wself = self;
    dispatch_async(self.queue, ^{
        __strong typeof(wself) sself = wself;
        if (!sself) return;
        if (sself.pending[fp]) return;
        sself.pending[fp] = task;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kGiveUpSeconds * NSEC_PER_SEC)), sself.queue, ^{
            [sself doGiveUpForFp:fp];
        });
    });
}

- (void)startRetryForGroupFp:(NSString *)fp gid:(NSString *)gid text:(NSString *)text atUsers:(NSArray<NSString *> *)atUsers quoteMeta:(QuoteMeta *)quoteMeta {
    if (!fp.length || !gid.length || !text.length) return;
    NSDictionary *task = @{
        @"fp": fp,
        @"toId": gid,
        @"text": text,
        @"atUsers": atUsers ?: [NSNull null],
        @"quoteMeta": quoteMeta ?: [NSNull null],
        @"messageType": @(TM_TYPE_TEXT),
        @"isGroup": @YES,
    };
    __weak typeof(self) wself = self;
    dispatch_async(self.queue, ^{
        __strong typeof(wself) sself = wself;
        if (!sself) return;
        if (sself.pending[fp]) return;
        sself.pending[fp] = task;
        for (int i = 0; i < kGroupRetryCount; i++) {
            NSTimeInterval delay = kGroupRetryDelays[i];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), sself.queue, ^{
                [sself doRetryForGroupFp:fp];
            });
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kGiveUpSeconds * NSEC_PER_SEC)), sself.queue, ^{
            [sself doGiveUpForFp:fp];
        });
    });
}

- (void)startGiveUpTimerOnlyForGroupFp:(NSString *)fp gid:(NSString *)gid {
    if (!fp.length || !gid.length) return;
    NSDictionary *task = @{ @"fp": fp, @"toId": gid, @"isGroup": @YES };
    __weak typeof(self) wself = self;
    dispatch_async(self.queue, ^{
        __strong typeof(wself) sself = wself;
        if (!sself) return;
        if (sself.pending[fp]) return;
        sself.pending[fp] = task;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kGiveUpSeconds * NSEC_PER_SEC)), sself.queue, ^{
            [sself doGiveUpForFp:fp];
        });
    });
}

- (void)cancelRetryForFp:(NSString *)fp {
    dispatch_async(self.queue, ^{
        [self.pending removeObjectForKey:fp];
    });
}

@end
