//telegram @wz662
//
//  rbSystemInfoCollectionViewCell.h
//  RainbowChat4i
//
//  Created by JackJiang on 2018/5/28.
//  Copyright © 2018年 JackJiang. All rights reserved.
//

/**
 * 聊天界面中的"系统通知"表格单元实现类。
 *
 * 【以此通知的cell实现为例，如果要为JSQ聊天界面新增一种新的消息类型（文本类型），代码只需以下4步】：
 *  * 第一步：就像所有的UITableView或UICollectionView的cell实现类一样，实现cell（真如本类的代码一样）；
 *  * 第二步：在JSQMessagesCollectionView.m类（即表格封装实现类）中，调用registerNib:，注册本cell；
 *  * 第三步：在JSQMessagesBubblesSizeCalculator类的messageBubbleSizeForMessageData:方法中，实此cell的气泡区大小计算代码（不然cell的大小怎么决定呢？）；
 *  * 第四步：在JSQMessagesViewController类的collectionView:cellForItemAtIndexPath: 方法中（就像普通的UITableView或UICollectionView一样），实现cell的值设定。
 *  * 补充说明：以上数据、组件大小等都计算好后，最终决定cell中各ui显示大小等，是通过表格自动调用cell里的applyLayoutAttributes:方法来实现的（而applyLayoutAttributes:方法中需要用到的各组件大小属性，是在JSQMessagesCollectionViewFlowLayout的jsq_configureMessageCellLayoutAttributes:方法中计算好的哦），这是UI显示的最后一步了！！
 */

#import <UIKit/UIKit.h>
#import "JSQMessagesLabel.h"
#import "JSQMessagesCellTextView.h"

#define rbSystemInfoCollectionViewCell_textView_textContainerInset_TOP    2
#define rbSystemInfoCollectionViewCell_textView_textContainerInset_LEFT   12
#define rbSystemInfoCollectionViewCell_textView_textContainerInset_BOTTOM 2
#define rbSystemInfoCollectionViewCell_textView_textContainerInset_RIGHT  12


@interface rbSystemInfoCollectionViewCell : UICollectionViewCell

/** 日期时间显示组件. */
@property (weak, nonatomic) IBOutlet JSQMessagesLabel *cellTopLabel;
/** 日期时间显示组件的高度约束（当不需要显地此组件时，本值设为0即可） */
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *cellTopLabelHeightConstraint;

/** 通知内容文本显示组件（支持多行） */
@property (weak, nonatomic) IBOutlet JSQMessagesCellTextView *textView;

/** 文本区的背景图（默认是一个圆角图片) */
@property (weak, nonatomic) IBOutlet UIImageView *messageBubbleImageView;

/** 整个文本显示区父容器（文本区和背景图都是在xib中设置是相对于本父容器自适应的），本容易的大小变化将决定了文本区和背景图的大小 */
@property (weak, nonatomic) IBOutlet UIView *messageBubbleContainerView;
/** 整个文本显示区父容器的宽度约束（此宽度就是cell中整个消息区的最终显示宽度，它直接决定了文本区和背景图的显示宽度哦）*/
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *messageBubbleContainerViewConstraint;

/**
 *  Returns the `UINib` object initialized for the cell.
 *
 *  @return The initialized `UINib` object or `nil` if there were errors during
 *  initialization or the nib file could not be located.
 */
+ (UINib *)nib;

/**
 *  Returns the default string used to identify a reusable cell for text message items.
 *
 *  @return The string used to identify a reusable cell.
 */
+ (NSString *)cellReuseIdentifier;


/**
 获取文本区的固定字体大小。

 @return 字体大小
 */
+ (UIFont *)getRbSystemInfoCollectionViewCell_textViewFont;

@end
