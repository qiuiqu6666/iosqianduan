//telegram @wz662
//
//  Observers.h
//  RainbowChat4i
//
//  Created by Jack Jiang on 2022/8/18.
//  Copyright © 2022 JackJiang. All rights reserved.
//
/**
 * 一个观察者集合实现类，用于需要管理多个观察者的场景下。
 *
 * @author JackJiang
 * @since 5.0
 */

#import <Foundation/Foundation.h>
#import "CompletionDefine.h"

@interface Observers : NSObject

/**
 * 添加一个观察者。
 *
 * @param obs 被添加的观察者对象（将在主线程中通知观察者，所以开发者需要确保观察者中要执行的逻辑应是跟ui相关且不耗时的）
 */
- (void)add:(ObserverCompletion)obs;

/**
 * 移除一个观察者。
 *
 * @param obs 被移除的观察者对象
 */
- (void)remove:(ObserverCompletion)obs;

/**
 * 清空观察者列表。
 */
- (void)clear;

/**
 * 通知所有观察者。
 *
 * @param updateTypeToObserver 类型（可选字段，无用则请填-1）
 * @param datas 要通知的数据，可为空
 */
- (void)notifyAll:(NSInteger)updateTypeToObserver whithExtra:(NSObject *)datas;

/**
 * 返回观察者列表引用。
 *
 * @return 集合引用
 */
- (NSMutableArray<ObserverCompletion> *)getObservers;

@end
