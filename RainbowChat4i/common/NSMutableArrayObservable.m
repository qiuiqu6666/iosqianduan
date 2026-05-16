//telegram @wz662
//
//  NSMutableArrayObservable.m
//  TalkM_visitor
//
//  Created by JackJiang on 17/3/24.
//  Copyright © 2017年 JackJiang. All rights reserved.
//

#import "NSMutableArrayObservable.h"


///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - 私有API
///////////////////////////////////////////////////////////////////////////////////////////

@interface NSMutableArrayObservable ()

///* 数组对象 */
//@property (nonatomic, retain) NSMutableArray *dataList;
///* 数据改变事件的观察者 */
//@property (nonatomic, copy) ObserverCompletion obsNew;// block代码块一定要用copy属性，否则报错！

@end


///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - 本类的代码实现
///////////////////////////////////////////////////////////////////////////////////////////

@implementation NSMutableArrayObservable

////-----------------------------------------------------------------------------------
//#pragma mark - 仅内部可调用的方法
//
//- (id)init
//{
//    if (![super init])
//        return nil;
//
//    NSLog(@"NSMutableArrayObservable已经init了！");
//
//    // 内部变量初始化
//    self.dataList = [NSMutableArray array];
//
//    return self;
//}
//
////-----------------------------------------------------------------------------------
//#pragma mark - 外部可调用的方法
//
//- (void)set:(NSUInteger)index withObj:(NSObject *)cme
//{
//    [self set:index withObj:cme needNotify:YES];
//}
//
//- (void)set:(NSUInteger)index withObj:(NSObject *)cme needNotify:(BOOL)notifyObserver
//{
//    [self.dataList replaceObjectAtIndex:index withObject:cme];
//
//    if(notifyObserver)
//    {
//        // 通知观察者
//        [self notifyObserverNew:UpdateTypeToObserverSET whithExtra:cme];
//    }
//}
//
//- (void)add:(NSObject *)cme
//{
//    [self add:cme needNotify:YES];
//}
//
//- (void)add:(NSObject *)cme needNotify:(BOOL)notifyObserver
//{
//    [self.dataList addObject:cme];
//    if(notifyObserver)
//    {
//        // 通知观察者
//        [self notifyObserverNew:UpdateTypeToObserverADD whithExtra:cme];
//    }
//}
//
//- (void)add:(NSUInteger)index withObj:(NSObject *)cme
//{
//    [self add:index withObj:cme needNotify:YES];
//}
//
//- (void)add:(NSUInteger)index withObj:(NSObject *)cme needNotify:(BOOL)notifyObserver
//{
//    [self.dataList insertObject:cme atIndex:index];
//
//    if(notifyObserver)
//    {
//        // 通知观察者
//        [self notifyObserverNew:UpdateTypeToObserverADD whithExtra:cme];
//    }
//}
//
//- (NSObject *)remove:(NSUInteger)index needNotify:(BOOL)notifyObserver
//{
//    if(index < [self.dataList count])
//    {
//        // theRemovedElement是该被删除地对象
//        NSObject *theRemovedElement = [self.dataList objectAtIndex:index];
//        [self.dataList removeObjectAtIndex:index];
//
//        if(notifyObserver)
//        {
//            // 通知观察者
//            [self notifyObserverNew:UpdateTypeToObserverREMOVE whithExtra:theRemovedElement];
//        }
//        return theRemovedElement;
//    }
//
//    NSLog(@"[NSMutableArrayObservable] 无效的index=%lu",(unsigned long)index);
//
//    return nil;
//}
//
//- (NSObject *)get:(NSUInteger)index
//{
//    return [self.dataList objectAtIndex:index];
//}
//
//- (NSUInteger)indexOf:(NSObject *)o
//{
//    NSUInteger index = [self.dataList indexOfObject:o];
//    return index == NSNotFound ? -1 : index;
//}
//
//- (NSMutableArray *)getDataList
//{
//    return self.dataList;
//}
//
//- (void)putDataList:(NSArray *)newDatas needNotify:(BOOL)notifyObserver
//{
//    if(newDatas == nil)
//    {
//        NSLog(@"[NSMutableArrayObservable] 参数newDatas的数组是nil!!!");
//        return;
//    }
//
//    [self.dataList removeAllObjects];
//
//    for (NSObject *t in newDatas)
//    {
//        [self add:t needNotify:notifyObserver];
//    }
//}
//
///**
// * @param obsNew 数据变动将通知的观察者，通知将携带该次变动详细信息的对象参数告之观察者对象
// */
//- (void)setObserverNew:(ObserverCompletion)obsNew
//{
//    self.obsNew = obsNew;
//}
//
///**
// * @param updateTypeToObserver 数据通知类型
// * @param extraData 通知时携带的数据
// */
//- (void)notifyObserverNew:(UpdateTypeToObserver)updateTypeToObserver whithExtra:(NSObject *)extraData
//{
//    if(self.obsNew != nil)
//        self.obsNew(@(updateTypeToObserver), extraData);
//}
//
//- (void)clear
//{
//    [self.dataList removeAllObjects];
//}



@end
