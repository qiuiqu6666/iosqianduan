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


#import <UIKit/UIKit.h>

/**
 *  `JSQMessagesLabel` is a subclass of `UILabel` that adds support for a `textInsets` property,
 *  which is similar to the `textContainerInset` property of `UITextView`.
 */
@interface JSQMessagesLabel : UILabel

/**
 *  The inset of the text layout area within the label's content area. The default value is `UIEdgeInsetsZero`.
 *
 *  @discussion This property provides text margins for the text laid out in the label.
 *  The inset values provided must be greater than or equal to `0.0f`.
 */
@property (assign, nonatomic) UIEdgeInsets textInsets;

@end
