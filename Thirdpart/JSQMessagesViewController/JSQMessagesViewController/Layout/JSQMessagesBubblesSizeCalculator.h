//telegram @wz662
//  ----------------------------------------------------------------------
//  Copyright (C) 2018  即时通讯网(52im.net) & Jack Jiang.
//  The RainbowChat Project. All rights reserved.
//
//  > 文档地址: http://www.52im.net/thread-19-1-1.html
//  > 即时通讯技术社区：http://www.52im.net/
//  > 即时通讯技术交流群：320837163 (http://www.52im.net/topic-qqgroup.html)
//
//  "即时通讯网(52im.net) - 即时通讯开发者社区!" 推荐IM工程。
//
//  如需联系作者，请发邮件至 jack.jiang@52im.net 或 jb2011@163.com.
//  ----------------------------------------------------------------------
//
//  【版权申明】：本类原作者为JSQ作者，因原工程已停止更新，当前由JackJiang修改并用于RainbowChat等工程中，感谢原作者。


#import <Foundation/Foundation.h>

#import "JSQMessagesBubbleSizeCalculating.h"

/**
 *  An instance of `JSQMessagesBubblesSizeCalculator` is responsible for calculating
 *  message bubble sizes for an instance of `JSQMessagesCollectionViewFlowLayout`.
 */
@interface JSQMessagesBubblesSizeCalculator : NSObject <JSQMessagesBubbleSizeCalculating>

/**
 *  Initializes and returns a bubble size calculator with the given cache and minimumBubbleWidth.
 *
 *  @param cache                 A cache object used to store layout information.
 *  @param minimumBubbleWidth    The minimum width for any given message bubble.
 *  @param usesFixedWidthBubbles Specifies whether or not to use fixed-width bubbles.
 *  If `NO` (the default), then bubbles will resize when rotating to landscape.
 *
 *  @return An initialized `JSQMessagesBubblesSizeCalculator` object if successful, `nil` otherwise.
 */
- (instancetype)initWithCache:(NSCache *)cache
           minimumBubbleWidth:(NSUInteger)minimumBubbleWidth
        usesFixedWidthBubbles:(BOOL)usesFixedWidthBubbles NS_DESIGNATED_INITIALIZER;

/** 是否为多行文本（用于单行保留时间+已读右侧、多行换行到底部）；须传 indexPath 以便与气泡高度计算共用昵称区与缓存键 */
- (BOOL)isMultiLineForMessage:(id)messageData atIndexPath:(NSIndexPath *)indexPath withLayout:(JSQMessagesCollectionViewFlowLayout *)layout;

/** 最近一次 size 计算得出的多行时时间/已读是否与最后一行同行（仅读，供 FlowLayout 传给 cell） */
@property (nonatomic, assign, readonly) BOOL lastTimeFitsOnSameLine;

@end
