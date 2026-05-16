//telegram @wz662
//
//  NSMutableArrayObservable.h
//  TalkM_visitor
//
//  Created by JackJiang on 17/3/24.
//  Copyright © 2017年 JackJiang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CompletionDefine.h"

//// 数据更新类型定义（用于通知观察者）
//typedef NS_ENUM(NSInteger, UpdateTypeToObserver){
//    /** 新加入了行 */
//    UpdateTypeToObserverADD    = 0,
//    /** 移除了行 */
//    UpdateTypeToObserverREMOVE = 1,
//    /** 替换了行 */
//    UpdateTypeToObserverSET    = 2,
//    /** 未定义 */
//    UpdateTypeToObserverUNKNOW = 3,
//};


@interface NSMutableArrayObservable : NSObject


///**
// 替换指定索引处的元素。
//
// @param index 要被替换的索引值
// @param cme 新的元素对象
// */
//- (void)set:(NSUInteger)index withObj:(NSObject *)cme;
//
///**
// * 替换指定索引处的元素。
// *
// * @param index 要被替换的索引值
// * @param cme 新的元素对象
// * @param notifyObserver true表示要通知观察者，此观察者通常用于刷新UI之用，所以可以将此参数理解为更新完数据模型后是否要刷新ui
// */
//- (void)set:(NSUInteger)index withObj:(NSObject *)cme needNotify:(BOOL)notifyObserver;
//
///**
// * 在集合末尾加入一个元素。
// *
// * @param cme 新的元素对象
// */
//- (void)add:(NSObject *)cme;
//
///**
// * 在集合末尾加入一个元素。
// *
// * @param cme 新的元素对象
// * @param notifyObserver true表示要通知观察者，此观察者通常用于刷新UI之用，所以可以将此参数理解为更新完数据模型后是否要刷新ui
// */
//- (void)add:(NSObject *)cme needNotify:(BOOL)notifyObserver;
//
///**
// * 在指定索引处插入一个元素。
// *
// * @param index 要插入的索引位置
// * @param cme 新的元素对象
// */
//- (void)add:(NSUInteger)index withObj:(NSObject *)cme;
//
///**
// * 在指定索引处加入一个元素。
// *
// * @param index 要插入的索引位置
// * @param cme 新的元素对象
// * @param notifyObserver true表示要通知观察者，此观察者通常用于刷新UI之用，所以可以将此参数理解为更新完数据模型后是否要刷新ui
// */
//- (void)add:(NSUInteger)index withObj:(NSObject *)cme needNotify:(BOOL)notifyObserver;
//
///**
// * 移动指定索引处的元素。
// *
// * @param index 要移除的索引位置
// * @param notifyObserver true表示要通知观察者，此观察者通常用于刷新UI之用，所以可以将此参数理解为更新完数据模型后是否要刷新ui
// */
//- (NSObject *)remove:(NSUInteger)index needNotify:(BOOL)notifyObserver;
//
//
///**
// 获取指定索引处的元素对象。
//
// @param index 索引位置
// @return 指定索引处理的元素对象
// */
//- (NSObject *)get:(NSUInteger)index;
//
//
///**
// 指定元素对象所处的索引位置值。
//
// @param o 对象
// @return 索引值
// */
//- (NSUInteger)indexOf:(NSObject *)o;
//
//
///**
// 获取对象列表。
//
// @return 对象列表
// */
//- (NSMutableArray *)getDataList;
//
///**
// * 用新的集合来覆盖原dataList.
// *
// * <p>注：本方法不是用新的ArrayList<T>对象来替换原dataList
// * 对象，而是将新集后的所有元素放到被clear后的原dataList集合里，
// * 也即是说：调用完本方法后，dataList还是原来的对象，只是集合元素改变了而
// * 已，此举对将dataList引用作为ListView列表数据集的场景中有好处：浅拷贝使得数据随时
// * 是被同步的（映射到ListView列表中）。
// *
// * <p>注意：此方法将会多次通知观察者.
// *
// * @param newDatas
// * @see #add(Object)
// */
//- (void)putDataList:(NSArray *)newDatas needNotify:(BOOL)notifyObserver;
//
///**
// * @param obsNew 数据变动将通知的观察者，通知将携带该次变动详细信息的对象参数告之观察者对象
// */
//- (void)setObserverNew:(ObserverCompletion)obsNew;
//
///**
// * 通知观察者。
// *
// * @param updateTypeToObserver 数据通知类型
// * @param extraData 通知时携带的数据
// */
//- (void)notifyObserverNew:(UpdateTypeToObserver)updateTypeToObserver whithExtra:(NSObject *)extraData;
//
///**
// 清除对象数组。
// */
//- (void)clear;

@end
