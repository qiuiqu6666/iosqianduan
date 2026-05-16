//telegram @wz662
/**
 * 一个封装了NSMutableArray可变数组的拥有观察者通知功能的数据结构。  
 * 目的是实现在数组数据变动时能通知设置的0到多个观察者。此种观察者模式
 * 用于数据模型与业务逻辑解偶之用，与iOS里的“通知”有相同的意义，但不会
 * 发生“通知”这种方式滥用而致代码逻辑失控的局面。
 *
 * @author Jack Jiang
 * @version 2.0
 */

#import <Foundation/Foundation.h>
#import "CompletionDefine.h"
#import "NSMutableArrayObservable.h"
#import "Observers.h"


// 数据更新类型定义（用于通知观察者）
typedef NS_ENUM(NSInteger, UpdateTypeToObserver){
    /** 清空 */
    UpdateTypeToObserverCLEAR  = 0,
    /** 新加入了行 */
    UpdateTypeToObserverADD    = 1,
    /** 移除了行 */
    UpdateTypeToObserverREMOVE = 2,
    /** 替换了行 */
    UpdateTypeToObserverSET    = 3,
    /** 未定义 */
    UpdateTypeToObserverUNKNOW = 4,
};


@interface NSMutableArrayObservableEx : NSObject

/**
 替换指定索引处的元素。

 @param index 要被替换的索引值
 @param cme 新的元素对象
 */
- (void)set:(NSUInteger)index withObj:(NSObject *)cme;

/**
 * 替换指定索引处的元素。
 *
 * @param index 要被替换的索引值
 * @param cme 新的元素对象
 * @param notifyObserver true表示要通知观察者，此观察者通常用于刷新UI之用，所以可以将此参数理解为更新完数据模型后是否要刷新ui
 */
- (void)set:(NSUInteger)index withObj:(NSObject *)cme needNotify:(BOOL)notifyObserver;

/**
 * 在集合末尾加入一个元素。
 *
 * @param cme 新的元素对象
 */
- (void)add:(NSObject *)cme;

/**
 * 在集合末尾加入一个元素。
 *
 * @param cme 新的元素对象
 * @param notifyObserver true表示要通知观察者，此观察者通常用于刷新UI之用，所以可以将此参数理解为更新完数据模型后是否要刷新ui
 */
- (void)add:(NSObject *)cme needNotify:(BOOL)notifyObserver;

/**
 * 在指定索引处插入一个元素。
 *
 * @param index 要插入的索引位置
 * @param cme 新的元素对象
 */
- (void)add:(NSUInteger)index withObj:(NSObject *)cme;

/**
 * 在指定索引处加入一个元素。
 *
 * @param index 要插入的索引位置
 * @param cme 新的元素对象
 * @param notifyObserver true表示要通知观察者，此观察者通常用于刷新UI之用，所以可以将此参数理解为更新完数据模型后是否要刷新ui
 */
- (void)add:(NSUInteger)index withObj:(NSObject *)cme needNotify:(BOOL)notifyObserver;

/**
 * 移动指定索引处的元素。
 *
 * @param index 要移除的索引位置
 * @param notifyObserver true表示要通知观察者，此观察者通常用于刷新UI之用，所以可以将此参数理解为更新完数据模型后是否要刷新ui
 */
- (NSObject *)remove:(NSUInteger)index needNotify:(BOOL)notifyObserver;

/**
 获取指定索引处的元素对象。

 @param index 索引位置
 @return 指定索引处理的元素对象
 */
- (NSObject *)get:(NSUInteger)index;

/**
 指定元素对象所处的索引位置值。

 @param o 对象
 @return 索引值
 */
- (NSUInteger)indexOf:(NSObject *)o;

/**
 获取对象列表。

 @return 对象列表
 */
- (NSMutableArray *)getDataList;

/**
 * 用新的集合来覆盖原dataList.
 *
 * <p>注：本方法不是用新的ArrayList<T>对象来替换原dataList对象，而是将新集后的所有元素放到被clear后的原dataList集合里，
 * 也即是说：调用完本方法后，dataList还是原来的对象，只是集合元素改变了而已，此举对将dataList引用作为ListView列表数据集
 * 的场景中有好处：浅拷贝使得数据随时是被同步的（映射到ListView列表中）。
 *
 * <p>注意：此方法将会多次通知观察者.
 *
 * @param newDatas 数据集合
 * @see #add(Object)
 */
- (void)putDataList:(NSArray *)newDatas needNotify:(BOOL)notifyObserver;

/**
 * 添加观察者。
 *
 * @param obs 数据变动将通知的观察者（将在主线程中通知观察者，所以开发者需要确保观察者中要执行的逻辑应
 *           是跟ui相关且不耗时的），通知将携带该次变动详细信息的对象参数告之观察者对象
 */
- (void)addObserver:(ObserverCompletion)obs;

/**
 * 移除指定观察者。
 *
 * @param obs 被移除的观察者
 */
- (void)removeObserver:(ObserverCompletion)obs;

/**
 * 移除全部观察者。
 */
- (void)removeAllObservers;

/**
 * 通知观察者。
 *
 * @param updateTypeToObserver 数据通知类型
 * @param extraData 通知时携带的数据
 */
- (void)notifyObservers:(UpdateTypeToObserver)updateTypeToObserver whithExtra:(NSObject *)extraData;

/**
 清除对象数组。
 */
- (void)clear:(BOOL)notifyObserver;

@end
