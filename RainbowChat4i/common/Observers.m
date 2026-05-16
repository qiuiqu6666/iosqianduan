//telegram @wz662
//
//  Observers.m
//  RainbowChat4i
//
//  Created by Jack Jiang on 2022/8/18.
//  Copyright © 2022 JackJiang. All rights reserved.
//

#import "Observers.h"

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - 私有API
///////////////////////////////////////////////////////////////////////////////////////////

@interface Observers ()

/* 数据改变事件的观察者数组对象 */
@property (nonatomic, retain) NSMutableArray<ObserverCompletion> *observers;

@end


///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - 本类的代码实现
///////////////////////////////////////////////////////////////////////////////////////////

@implementation Observers

//-----------------------------------------------------------------------------------
#pragma mark - 仅内部可调用的方法

- (id)init{
    if (![super init])
        return nil;

    DDLogDebug(@"【Observers中】Observers已经init了！");
    
    // 内部变量初始化
    self.observers = [NSMutableArray<ObserverCompletion> array];
    return self;
}

//-----------------------------------------------------------------------------------
#pragma mark - 外部可调用的方法

- (void)add:(ObserverCompletion)obs{
    if(obs != nil) {
        if(![self.observers containsObject:obs]) {
            [self.observers addObject:obs];
        } else {
            DDLogDebug(@"【Observers中】obs对象%@已存在于观察者列表，不需要重复加入！", obs);
        }
    }
}

- (void)remove:(ObserverCompletion)obs{
    if(obs != nil)
        [self.observers removeObject:obs];
}

- (void)clear{
    [self.observers removeAllObjects];
}

- (void)notifyAll:(NSInteger)updateTypeToObserver whithExtra:(NSObject *)datas{
    // 确保在主线程中通知观察者（所以开发者需要确保观察者中要执行的逻辑应是跟ui相关且不耗时的）
    [BasicTool runInMainThread:^{
        for (ObserverCompletion obs in self.observers){
            if(obs != nil)
                obs(@(updateTypeToObserver), datas);
        }
    }];
}

- (NSMutableArray<ObserverCompletion> *)getObservers{
    return self.observers;
}

@end
