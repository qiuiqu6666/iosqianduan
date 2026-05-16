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

#import "JSQMessagesCellTextView.h"

@implementation JSQMessagesCellTextView

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    self.textColor = HexColor(0x000000);// 气泡内主文字黑（微信风格）
    self.editable = NO;
    self.selectable = YES;
    self.userInteractionEnabled = YES;
    self.dataDetectorTypes = UIDataDetectorTypeNone;
    self.showsHorizontalScrollIndicator = NO;
    self.showsVerticalScrollIndicator = NO;
    self.scrollEnabled = NO;
    self.backgroundColor = [UIColor clearColor];
    self.contentInset = UIEdgeInsetsZero;
    self.scrollIndicatorInsets = UIEdgeInsetsZero;
    self.contentOffset = CGPointZero;
    self.textContainerInset = UIEdgeInsetsZero;
    self.textContainer.lineFragmentPadding = 0;
    self.linkTextAttributes = @{ NSForegroundColorAttributeName : [UIColor whiteColor],
                                 NSUnderlineStyleAttributeName : @(NSUnderlineStyleSingle | NSUnderlinePatternSolid) };
    

    // 只自动识别超链接和邮箱，不识别手机号码和IP地址
    self.dataDetectorTypes = UIDataDetectorTypeLink;
    
    // 设置字体大小，请到 JSQMessagesCollectionViewFlowLayout.m中设l置，此处不是最终设置，不会生效！
//    self.font = [UIFont systemFontOfSize:11.0f];
    
    // 禁止自身的长按事件（就是不想让那个默认的复制、粘贴啥的菜单弹出来，从而影响聊天界面统一的长按事件！）
//    for (UIGestureRecognizer *recognizer in self.gestureRecognizers) {
//      if ([recognizer isKindOfClass:[UILongPressGestureRecognizer class]]){
//        recognizer.enabled = NO;
//      }
//    }
    
    // 禁止选中和编辑能力，从而永久禁止系统默认的长按弹出菜单，防止跟聊天界面里统一的消息气泡长按弹出菜单冲突
    // 通过验证：不将以下属性设为NO，通过重写下方的两个父类方法以及上面的recognizer.enabled代码，很难禁止
    //         ，就像癌症一样，从别的界面回来这个菜单又能出现，而且短时禁止后，长按直到抬手才能感知，这冲突太
    //         难受了，以下两个属于为NO就能一蒙山永逸的禁掉，舒服！
//    self.selectable = NO;// 此行设为NO可完全禁止双击默认弹出的系统菜单，但也同时识别超链接的能力也无效了
//    self.editable = NO;

    //** 240919：为了让self.dataDetectorTypes的设置生效，支持超链接等自动识别，又注释了上述两行。禁止双击默认弹出的系统菜单方法将通过本类末的两个重写方法去实现了。
}

- (void)setSelectedRange:(NSRange)selectedRange
{
    //  attempt to prevent selecting text
    [super setSelectedRange:NSMakeRange(NSNotFound, 0)];
}

- (NSRange)selectedRange
{
    //  attempt to prevent selecting text
    return NSMakeRange(NSNotFound, NSNotFound);
}

//// 阻止双击手势
//// 20211115日：自v4.3起，聊天界面中将启用统一的长按弹出菜单，这个仅针对文本消息组件的长按没有意义，立即取消！
//- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
//{
////    //  ignore double-tap to prevent copy/define/etc. menu from showing
////    if ([gestureRecognizer isKindOfClass:[UITapGestureRecognizer class]]) {
////        UITapGestureRecognizer *tap = (UITapGestureRecognizer *)gestureRecognizer;
////        // 双击
////        if (tap.numberOfTapsRequired == 2) {
////            return NO;
////        }
////    }
////
////    return YES;
//    return NO;
//}

//// 是否允许接收手指的触摸点
//// 20211115日：自v4.3起，聊天界面中将启用统一的长按弹出菜单，这个仅针对文本消息组件的长按没有意义，立即取消！
//- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
//{
////    //  ignore double-tap to prevent copy/define/etc. menu from showing
////    if ([gestureRecognizer isKindOfClass:[UITapGestureRecognizer class]]) {
////        UITapGestureRecognizer *tap = (UITapGestureRecognizer *)gestureRecognizer;
////        // 双击
////        if (tap.numberOfTapsRequired == 2) {
////            return NO;
////        }
////    }
////
////    return YES;
//
//    return NO;
//}


#pragma mark - 重写以下两个方法，实现禁用UITextView默认的双击弹出的系统菜单，这些系统菜单项不好用、不实用、也不可控！
// 参考资料：https://blog.csdn.net/weixin_36162680/article/details/140876123
-(void)buildMenuWithBuilder:(id<UIMenuBuilder>)builder{
    if (@available(iOS 17.0, *)) {
        //隐藏自动填充
        [builder removeMenuForIdentifier:UIMenuAutoFill];
    }
    [super buildMenuWithBuilder:builder];
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
//    if ([UIMenuController sharedMenuController]) {
//        [UIMenuController sharedMenuController].menuVisible = NO;
//    }
//  return YES;
    return NO;
}
@end
