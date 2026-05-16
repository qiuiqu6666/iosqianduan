//telegram @wz662
//
//  FriendsReqProvider.m
//  RainbowChat4i
//
//  Created by Jack Jiang on 2022/8/18.
//  Copyright © 2022 JackJiang. All rights reserved.
//

#import "FriendsReqProvider.h"


///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - 私有API
///////////////////////////////////////////////////////////////////////////////////////////

@interface FriendsReqProvider ()

/**
 * 未读的加好友请求总数.
 * <p>
 * 说明：这是一个支持多线程原子读的变量。
 */
@property (atomic, assign) int unreadCount;

/* 观察者数组对象 */
@property (nonatomic, retain) Observers *unreadChangedObservers;

@end


///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - 本类的代码实现
///////////////////////////////////////////////////////////////////////////////////////////

@implementation FriendsReqProvider

- (id)init{
    if(self = [super init]){
        // 默认属性初始化
        self.unreadCount = 0;
        self.unreadChangedObservers = [[Observers alloc] init];
    }
    return self;
}

// 当前未读好友请求总数
- (int)getUnreadCount {
    int cnt = self.unreadCount;
    return cnt < 0 ? 0 : cnt;
}

// 设置好友请求数为请值
- (void)setUnreadCount:(int)newValue needNotify:(BOOL)notify {
    self.unreadCount = newValue;
    if (notify) {
        [self.unreadChangedObservers notifyAll:-1 whithExtra:@(newValue)];
    }
}

// 清除未读好友请求总数（就是设置为0）
- (void)clearUnreadCount:(BOOL)notify {
    [self setUnreadCount:0 needNotify:notify];
}

// 累加未读好友请求数
- (int)addUnreadCount:(int)delta needNotify:(BOOL)notify {
    int updatedValue = self.unreadCount +delta;
    self.unreadCount = updatedValue;
    if (notify) {
        [self.unreadChangedObservers notifyAll:-1 whithExtra:@(updatedValue)];
    }
    return updatedValue;
}

// 未读好友请求数+1
- (int)incrementUnreadCount:(BOOL)notify {
        self.unreadCount = self.unreadCount + 1;
        if (notify) {
            [self.unreadChangedObservers notifyAll:-1 whithExtra:@(self.unreadCount)];
        }
        return self.unreadCount;
    }

// 添加好友请求未读数变动观察者
- (void)addUnreadChangedObserver:(ObserverCompletion)o {
    [self.unreadChangedObservers add:o];
}

// 移除好友请求未读数变动观察者
- (void)removeUnreadChangedObserver:(ObserverCompletion)o {
    [self.unreadChangedObservers remove:o];
}

@end
