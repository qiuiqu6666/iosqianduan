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


#import "JSQMessagesLabel.h"

@implementation JSQMessagesLabel

#pragma mark - Initialization

- (void)jsq_configureLabel
{
    [self setTranslatesAutoresizingMaskIntoConstraints:NO];
    self.textInsets = UIEdgeInsetsZero;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self jsq_configureLabel];
    }
    return self;
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    [self jsq_configureLabel];
}

#pragma mark - Setters

- (void)setTextInsets:(UIEdgeInsets)textInsets
{
    if (UIEdgeInsetsEqualToEdgeInsets(_textInsets, textInsets)) {
        return;
    }
    
    _textInsets = textInsets;
    [self setNeedsDisplay];
}

#pragma mark - Drawing

- (void)drawTextInRect:(CGRect)rect
{
    [super drawTextInRect:CGRectMake(CGRectGetMinX(rect) + self.textInsets.left,
                                     CGRectGetMinY(rect) + self.textInsets.top,
                                     CGRectGetWidth(rect) - self.textInsets.right,
                                     CGRectGetHeight(rect) - self.textInsets.bottom)];
}

@end
