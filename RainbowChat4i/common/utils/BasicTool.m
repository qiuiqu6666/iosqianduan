//telegram @wz662
#import "BasicTool.h"
#import "UIImage+Resize.h"
#import "MBProgressHUD.h"
#import "MSSBrowseModel.h"
#import "MSSBrowseNetworkViewController.h"
#import "MSSBrowseLocalViewController.h"
#import "MoreViewController.h"
#import "AppDelegate.h"
#import "IMClientManager.h"
#import <objc/runtime.h>

// 用于存储原始字体大小的关联对象key
static char kOriginalFontSizeKey;

@implementation BasicTool

// 给按钮设置液态玻璃效果
+ (void)setClearGlassBgnConfig:(UIButton *)btn
{
    // 针对ios 26的优化：给按钮设置液态玻璃效果
    if (@available(iOS 26, *)) {
        btn.configuration = [UIButtonConfiguration clearGlassButtonConfiguration];
        [btn setNeedsUpdateConfiguration];
        
        // FIXME: 设置configuration后，设置的字体大小、加粗都不起效了，暂时无解。
        
//        NSString *s = [btn titleForState:UIControlStateNormal];
//        if(s != nil) {
//            NSLog(@"----------------------------------------------- > ！！！！！！！！！");
//            NSMutableAttributedString *attributedTitle = [[NSMutableAttributedString alloc] initWithString:s];
//            [attributedTitle addAttribute:NSFontAttributeName
////                                    value:btn.titleLabel.font
//                                    value:[UIFont boldSystemFontOfSize:10]
//                                    range:NSMakeRange(0, attributedTitle.length)];
//            btn.configuration.attributedTitle = attributedTitle;
//            
//            [btn setNeedsUpdateConfiguration];
//        }
    }
}

// 一个全局的收起软键盘的方法。
+ (void)hideSoftInputMethod
{
    // 以下代码实现隐藏键盘(iOS 6及更老的系统也都有用)
    [[UIApplication sharedApplication] sendAction:@selector(resignFirstResponder) to:nil from:nil forEvent:nil];
}

// 检查手机号是否符合中国大陆手机号码规范。
+  (BOOL)verifyChineseMainlandPhone:(NSString *)phoneNum
{
    NSString * MOBILE = @"^((1[23456789]))\\d{9}$";
    NSPredicate *regextestmobile = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", MOBILE];
    if (phoneNum.length == 11 && ([regextestmobile evaluateWithObject:phoneNum] == YES))
    {
        return YES;
    }
    else
    {
        return NO;
    }
}

/**
 * 结文本输入区进行输入长度限制。
 */
+ (void)textFieldInputLimit:(UITextField *)textField maxLen:(int)mLen {
    NSString *toBeString = textField.text;
    
    //获取高亮部分
    UITextRange *selectedRange = [textField markedTextRange];
    UITextPosition *position = [textField positionFromPosition:selectedRange.start offset:0];
    CGFloat maxLength = mLen;//8;
    
    // 没有高亮选择的字，则对已输入的文字进行字数统计和限制
    if (!position){
        if (toBeString.length > maxLength){
            NSRange rangeIndex = [toBeString rangeOfComposedCharacterSequenceAtIndex:maxLength];
            if (rangeIndex.length == 1){
                textField.text = [toBeString substringToIndex:maxLength];
            } else{
                NSRange rangeRange = [toBeString rangeOfComposedCharacterSequencesForRange:NSMakeRange(0, maxLength)];
                textField.text = [toBeString substringWithRange:rangeRange];
            }
        }
    }
}

/**
 设置边框。
 */
+ (void)setBorder:(UIView *)v width:(CGFloat)w color:(UIColor *)c radius:(CGFloat)r
{
    // 为退出登录按钮添加边框
    v.layer.borderWidth = w;
    v.layer.borderColor = c.CGColor;
    v.layer.cornerRadius = r;
    v.clipsToBounds = YES;
}

/**
 * 安全地返回本地用户UID.
 *
 * @returns local uid
 */
+ (NSString *)getLocalUserUid {
    UserEntity *localUserInfo = [IMClientManager sharedInstance].localUserInfo;
    return localUserInfo != nil ? localUserInfo.user_uid : @"";
}

/**
 * 是否"@我".
 *
 * @param at 被"@"人的uid数组
 * @return true表示被"@"，否则不是
 */
+ (BOOL)isAtMe:(NSArray *)at {
    BOOL ret = NO;
    
    @try{
        NSString *localUid =[IMClientManager sharedInstance].localUserInfo.user_uid;
        
        // "@"功能中的约定：当被at对象的uid是"0"时，表示"@所有人"
        BOOL atAll = [self matchInStringArray:at target:@"0"];
        if(!atAll) {
            ret = [self matchInStringArray:at target:localUid];
        }  else {
            ret = YES;
        }
    } @catch(NSException *e) {
        DLogWarn(@"%@", e);
    }
    
    return ret;
}

/**
 * 从字符串数组中判断是否存在指定字符串的单元。
 *
 * @param src 源数组
 * @param targetString 目标字符串
 * @return true表示存在，否则不存在
 * @since 11.0
 */
+ (BOOL)matchInStringArray:(NSArray *)src target:(NSString *)targetString {
    BOOL ret = NO;
    @try {
        if(src != nil && targetString != nil) {
            ret = [src containsObject:targetString];
        } else {
            NSString *desc = [NSString stringWithFormat:@"无效的参数（src=%@， target=%@）！",src, targetString];
            DDLogWarn(@"%@", desc);
        }
    } @catch(NSException *e) {
        DDLogWarn(@"matchInStringArray时出错了：%@", e);
    }
    return ret;
}

// 显示提示信息并提供跳转到登陆界面的能力（当前用于被踢或token失效时）
+ (void)showAlertAndGotoLogin:(NSString *)alertTitle content:(NSString *)alertContent {
    [BasicTool showAlert:alertTitle content:alertContent btnTitle:@"知道了！" parent:[APP getMainViewController] handler:^(UIAlertAction *action) {
        // 退出当前登陆状态并跳转到登际界面（以便重新登陆）
        [MoreViewController exitAndGotoLogin:NO];
    }];
}

// 高亮显示该条消息（从搜索进入聊天时定位到的那条），深灰背景+圆角，增强视觉冲击
+ (void)highlightOnceMessageItem:(UIView *)msgCell forMsg:(JSQMessage *)msg {
    if (msgCell == nil || msg == nil) return;
    UIColor *hilightBg = [UIColor colorWithRed:0.78 green:0.80 blue:0.84 alpha:1.0]; // 更深灰 #C7CCD6
    msgCell.layer.backgroundColor = hilightBg.CGColor;
    msgCell.layer.cornerRadius = 10.0f;
    msgCell.layer.masksToBounds = YES;
}

// 关键字高亮显示
+ (NSMutableAttributedString *) coloredStringForSearch:(NSString *)src keyword:(NSString *)keyword keywordColor:(UIColor *)color {
    @try{
        if(![BasicTool isStringEmpty:src] && ![BasicTool isStringEmpty:keyword]) {
            // 获取关键字的位置
            NSRange range = [[src lowercaseString] rangeOfString:[keyword lowercaseString]];
            
            // 转换成可以操作的字符串类型.
            NSMutableAttributedString *attribute = [[NSMutableAttributedString alloc] initWithString:src];
            
            // 已查到到这个关键字
            if(range.location != NSNotFound) {
                // 添加属性(粗体)
//              [attribute addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:20] range:range];
                // 关键字高亮
                [attribute addAttribute:NSForegroundColorAttributeName value:color range:range];
            }
            
            return attribute;
        } else {
            return nil;
        }
    } @catch(NSException *e) {
        DDLogWarn(@"%@", e);
        return nil;
    }
}

// 将光标移至文字末尾
+ (void)setCursorToEnd:(UITextField *)txtField {
    // 将光标移至文字末尾
    if(txtField.text != nil){
        UITextPosition *position = [txtField endOfDocument];
        txtField.selectedTextRange = [txtField textRangeFromPosition:position toPosition:position];
    }
    // 获取焦点
    [txtField becomeFirstResponder];
}

// UI组件圆角，支持分别指定4个角的圆角效果
+ (void)viewRoundCorner:(UIView *)srcView byRoundingCorners:(UIRectCorner)corners cornerRadii:(CGSize)cornerRadii
{
    if(srcView == nil)
        return;
        
    UIBezierPath *maskPath = [UIBezierPath bezierPathWithRoundedRect:srcView.bounds byRoundingCorners:corners cornerRadii:cornerRadii];
    CAShapeLayer *maskLayer = [[CAShapeLayer alloc] init];
    maskLayer.frame = srcView.bounds;
    maskLayer.path = maskPath.CGPath;
    srcView.layer.mask = maskLayer;
}

// 查找字符串中最后出现的字符所在索引
+ (int)lastIndex:(NSString *)srcStr of:(char *)lastChar {
    int index = -1;
    @try {
        if(srcStr != nil && [srcStr length] > 0) {
            NSString *lastCharStr = [NSString stringWithFormat:@"%s", lastChar];
            NSString *temp = nil;
//            int lastIndex = 0;
            // 逆序查找字符并匹配之
            for(int i = (int)[srcStr length] -1; i >= 0; i--){
                temp = [srcStr substringWithRange:NSMakeRange(i, 1)];
                // 如果找到就结束循环
                if ([temp isEqualToString:lastCharStr]){
    //              NSLog(@"第%d个字是:%@", i, temp);
                    index = i;
                    break;
                }
            }
        }
    } @catch (NSException *exception) {
        DDLogWarn(@"lastIndex:of: 时发生Exception：%@", exception);
    }

    return index;
}

// 在主线程中运行
+ (void)runInMainThread:(dispatch_block_t)block {
    if(block != nil) {
        if (![NSThread isMainThread]) {
            dispatch_async(dispatch_get_main_queue(), block);
        } else {
            block();
        }
    }
}

// 识别系统通知账号
+ (BOOL)isSystemAdmin:(NSString *)uid {
    return [@"10000" isEqualToString:uid] || [@"10001" isEqualToString:uid] || [@"400069" isEqualToString:uid] || [@"400070" isEqualToString:uid];
}

// 只读官方账号（不允许发送消息），不包括客服账号400069、官方账号10001
+ (BOOL)isReadOnlyOfficialAccount:(NSString *)uid {
    return [@"10000" isEqualToString:uid] || [@"400070" isEqualToString:uid];
}

// 聊天中不显示导航更多按钮、不显示在线时间且点击标题/更多不跳转资料页的账号（10000、400069、400070）。10001 仍显示更多并可跳转。
+ (BOOL)isOfficialAccountHideAvatarInChat:(NSString *)uid {
    return [@"10000" isEqualToString:uid] || [@"400069" isEqualToString:uid] || [@"400070" isEqualToString:uid];
}

// 会话/消息列表中显示「官方」标签的账号（10000、400069、400070）。10001 不显示官方标签。
+ (BOOL)isOfficialAccountShowFlagInConversationList:(NSString *)uid {
    return [@"10000" isEqualToString:uid] || [@"400069" isEqualToString:uid] || [@"400070" isEqualToString:uid];
}

+ (UIImage *)officialBadgeImage
{
    return [UIImage imageNamed:@"xc"];
}

+ (NSAttributedString *)attributedName:(NSString *)name
                   appendOfficialBadge:(BOOL)appendBadge
                                  font:(UIFont *)font
                             textColor:(UIColor *)textColor
                           badgeHeight:(CGFloat)badgeHeight
{
    NSString *safeName = name ?: @"";
    UIFont *safeFont = font ?: [UIFont systemFontOfSize:16.0f];
    UIColor *safeColor = textColor ?: [UIColor blackColor];
    NSDictionary *attrs = @{
        NSFontAttributeName: safeFont,
        NSForegroundColorAttributeName: safeColor
    };
    NSMutableAttributedString *result = [[NSMutableAttributedString alloc] initWithString:safeName attributes:attrs];

    if (!appendBadge) {
        return result;
    }

    UIImage *badgeImage = [self officialBadgeImage];
    if (badgeImage == nil || badgeImage.size.height <= 0.0f) {
        return result;
    }

    CGFloat safeBadgeHeight = (badgeHeight > 0.0f ? badgeHeight : safeFont.lineHeight);
    CGFloat badgeWidth = ceil(safeBadgeHeight * badgeImage.size.width / badgeImage.size.height);
    [result appendAttributedString:[[NSAttributedString alloc] initWithString:@" " attributes:attrs]];

    NSTextAttachment *attachment = [[NSTextAttachment alloc] init];
    attachment.image = badgeImage;
    CGFloat yOffset = floor((safeFont.capHeight - safeBadgeHeight) * 0.5f) - 1.0f;
    attachment.bounds = CGRectMake(0.0f, yOffset, badgeWidth, safeBadgeHeight);
    [result appendAttributedString:[NSAttributedString attributedStringWithAttachment:attachment]];

    return result;
}

// 角标数字转字符串，当数字大于99时，返回"99+"
+ (NSString *)getBadgeViewString:(int)badgeNumber {
    NSString *mBadgeText = @"";
    // 角标数字显示文本处理
    if (badgeNumber > 0 && badgeNumber <= 99) {
        mBadgeText = [NSString stringWithFormat:@"%d", badgeNumber];//String.valueOf(badgeNumber);
    } else if (badgeNumber > 99) {
        mBadgeText = @"99+";
    }
    return mBadgeText;
}

// 绘制UIView圆角.
+ (void)roundView:(UIView *)v byRoundingCorners:(UIRectCorner)corners cornerRadii:(CGSize)cornerRadii
{
    // 绘制UIView圆角（左下和右下圆角）
    UIBezierPath *maskPath = [UIBezierPath bezierPathWithRoundedRect:v.bounds
                              byRoundingCorners:corners cornerRadii:cornerRadii];
    CAShapeLayer *maskLayer = [[CAShapeLayer alloc] init];
    maskLayer.path = maskPath.CGPath;
    v.layer.mask = maskLayer;
    
//    // 绘制图片圆角（左下和右下圆角）
//    UIBezierPath *maskPath = [UIBezierPath bezierPathWithRoundedRect:self.previewImgView.bounds
//                                         byRoundingCorners:(UIRectCornerBottomLeft | UIRectCornerBottomRight)
//                                               cornerRadii:CGSizeMake(12.0, 12.0)];
//    CAShapeLayer *maskLayer = [[CAShapeLayer alloc] init];
//    maskLayer.path = maskPath.CGPath;
//    self.previewImgView.layer.mask = maskLayer;
}

+ (CGFloat)getSafeAreaInsets_top
{
//    if (@available(iOS 11.0, *))
//       return [[UIApplication sharedApplication] delegate].window.safeAreaInsets.bottom;
//    return 0;
    
    if (@available(iOS 13.0, *)) {
        NSSet *set = [UIApplication sharedApplication].connectedScenes;
        UIWindowScene *windowScene = [set anyObject];
        UIWindow *window = windowScene.windows.firstObject;
        return window.safeAreaInsets.top;
    } else if (@available(iOS 11.0, *)) {
        UIWindow *window = [UIApplication sharedApplication].windows.firstObject;
        return window.safeAreaInsets.top;
    }
    return 0;
}

+ (CGFloat)getSafeAreaInsets_bottom
{
//    if (@available(iOS 11.0, *))
//       return [[UIApplication sharedApplication] delegate].window.safeAreaInsets.bottom;
//    return 0;
    
    if (@available(iOS 13.0, *)) {
        NSSet *set = [UIApplication sharedApplication].connectedScenes;
        UIWindowScene *windowScene = [set anyObject];
        UIWindow *window = windowScene.windows.firstObject;
        return window.safeAreaInsets.bottom;
    } else if (@available(iOS 11.0, *)) {
        UIWindow *window = [UIApplication sharedApplication].windows.firstObject;
        return window.safeAreaInsets.bottom;
    }
    return 0;
}

+ (void)showAlertInfo:(id)content parent:(UIViewController *)parent
{
    [BasicTool showAlert:[BasicTool localizedStringForKey:@"general_tip" value:@""] content:content btnTitle:[BasicTool localizedStringForKey:@"general_confirm_btn" value:@""] parent:parent];
}

+ (void)showAlertWarn:(id)content parent:(UIViewController *)parent
{
    [BasicTool showAlert:[BasicTool localizedStringForKey:@"general_warn" value:@""] content:content btnTitle:[BasicTool localizedStringForKey:@"general_confirm_btn" value:@""] parent:parent];
}

+ (void)showAlertError:(id)content parent:(UIViewController *)parent
{
    [BasicTool showAlert:[BasicTool localizedStringForKey:@"general_error" value:@""] content:content btnTitle:[BasicTool localizedStringForKey:@"general_confirm_btn" value:@""] parent:parent];
}

+ (void)showAlert:(NSString *)title content:(id)content btnTitle:(NSString *)btnTitle parent:(UIViewController *)parent
{
    [BasicTool showAlert:title content:content btnTitle:btnTitle parent:parent handler:nil];
}

+ (void)showAlert:(NSString *)title content:(id)content btnTitle:(NSString *)btnTitle parent:(UIViewController *)parent handler:(void (^ __nullable)(UIAlertAction *action))handler
{
    BOOL isNSString = [content isKindOfClass: NSString.class];
    BOOL isNSAttributedString = [content isKindOfClass: NSAttributedString.class];
    
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:isNSString?content:@""
                                                            preferredStyle:UIAlertControllerStyleAlert];
    if(isNSAttributedString) {
        [alert setValue:(NSAttributedString *)content forKey:@"attributedMessage"];
    }
 
    UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:btnTitle style:UIAlertActionStyleDefault handler:handler];
    
    [alert addAction:defaultAction];
    [parent presentViewController:alert animated:YES completion:nil];
}

+ (void)areYouSureAlert:(NSString *)title content:(NSString *)content okBtnTitle:(NSString *)okBtnTitle cancelBtnTitle:(NSString *)cancelBtnTitle parent:(UIViewController *)parent okHandler:(void (^ __nullable)(UIAlertAction *action))okHandler cancelHandler:(void (^ __nullable)(UIAlertAction *action))cancelHandler
{
    [self areYouSureAlert:title content:content okBtnTitle:okBtnTitle cancelBtnTitle:cancelBtnTitle parent:parent okHandler:okHandler cancelHandler:cancelHandler cencelActionStyle:UIAlertActionStyleDefault];
}

+ (void)areYouSureAlert:(NSString *)title content:(NSString *)content okBtnTitle:(NSString *)okBtnTitle cancelBtnTitle:(NSString *)cancelBtnTitle parent:(UIViewController *)parent okHandler:(void (^ __nullable)(UIAlertAction *action))okHandler cancelHandler:(void (^ __nullable)(UIAlertAction *action))cancelHandler cencelActionStyle:(UIAlertActionStyle)cencelActionStyle
{
//    UIAlertController* alert = [UIAlertController alertControllerWithTitle:title
//                                                                   message:content
//                                                            preferredStyle:UIAlertControllerStyleAlert];
//    
//    UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:okBtnTitle style:UIAlertActionStyleDefault handler:okHandler];
//    UIAlertAction* cencelAction = [UIAlertAction actionWithTitle:cancelBtnTitle style:cencelActionStyle handler:cancelHandler];// UIAlertActionStyleDestructive
//    
//    [alert addAction:cencelAction];
//    [alert addAction:defaultAction];
//    [parent presentViewController:alert animated:YES completion:nil];
    
    [self areYouSureAlert:title content:content okBtnTitle:okBtnTitle cancelBtnTitle:cancelBtnTitle parent:parent okHandler:okHandler cancelHandler:cancelHandler okActionStyle:UIAlertActionStyleDefault cencelActionStyle:cencelActionStyle];
}

+ (void)areYouSureAlert:(NSString *)title content:(NSString *)content okBtnTitle:(NSString *)okBtnTitle cancelBtnTitle:(NSString *)cancelBtnTitle parent:(UIViewController *)parent okHandler:(void (^ __nullable)(UIAlertAction *action))okHandler cancelHandler:(void (^ __nullable)(UIAlertAction *action))cancelHandler okActionStyle:(UIAlertActionStyle)okActionStyle cencelActionStyle:(UIAlertActionStyle)cencelActionStyle
{
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:content
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:okBtnTitle style:okActionStyle handler:okHandler];
    UIAlertAction* cencelAction = [UIAlertAction actionWithTitle:cancelBtnTitle style:cencelActionStyle handler:cancelHandler];// UIAlertActionStyleDestructive
    
    [alert addAction:cencelAction];
    [alert addAction:defaultAction];
    [parent presentViewController:alert animated:YES completion:nil];
}

+ (UIImage *)imageWithColor:(UIColor *)color withSize:(CGSize)size
{
    // 描述矩形
    CGRect rect = CGRectMake(0, 0, size.width, size.height);
    // 开启位图上下文
    UIGraphicsBeginImageContext(rect.size);
    // 获取位图上下文
    CGContextRef context = UIGraphicsGetCurrentContext();
    // 使用color演示填充上下文
    CGContextSetFillColorWithColor(context, [color CGColor]);
    // 渲染上下文
    CGContextFillRect(context, rect);
    // 从上下文中获取图片
    UIImage *theImage = UIGraphicsGetImageFromCurrentImageContext();
    // 结束上下文
    UIGraphicsEndImageContext();
    
    return theImage;
}

+ (UIImage *)imageWithColor:(UIColor *)color withSize:(CGSize)size cornerRadius:(CGFloat)cornerRadius {
    UIImage *image = [self imageWithColor:color  withSize:size];
    UIImage *newImage = [BasicTool imageWithCorner:image cornerRadius:cornerRadius];
    return newImage;
}

+ (UIImage *)imageWithCorner:(UIImage *)image cornerRadius:(CGFloat)cornerRadius {
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, image.size.width, image.size.height) cornerRadius:cornerRadius];
    UIGraphicsBeginImageContext(image.size);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGRect rect = CGRectMake(0, 0, image.size.width, image.size.height);
    CGContextAddPath(ctx, path.CGPath);
    CGContextClip(ctx);
    [image drawInRect:rect];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}

+ (void)showImageWithURL:(NSString *)imgHttpUrl
{
    //** 在独立的界面中查看大图（原图）
    MSSBrowseModel *browseItem = [[MSSBrowseModel alloc]init];
    // 要加载网络图片大图地址
    browseItem.bigImageUrl = imgHttpUrl;
    MSSBrowseNetworkViewController *bvc = [[MSSBrowseNetworkViewController alloc]initWithBrowseItem:browseItem];
    [bvc showBrowseViewController];
}

+ (void)showImageWithPath:(NSString *)localImagePath
{
    //** 在独立的界面中查看大图（原图）
    MSSBrowseModel *browseItem = [[MSSBrowseModel alloc]init];
    // 要加载本地大图路径
    browseItem.bigImageLocalPath = localImagePath;
//    MSSBrowseNetworkViewController *bvc = [[MSSBrowseNetworkViewController alloc]initWithBrowseItem:browseItem];
//    [bvc showBrowseViewController];
    MSSBrowseLocalViewController *bvc2 = [[MSSBrowseLocalViewController alloc] initWithBrowseItem:browseItem];
    [bvc2 showBrowseViewController];
}

+ (void)showImage:(UIImage *)img
{
    //** 在独立的界面中查看大图（原图）
    MSSBrowseModel *browseItem = [[MSSBrowseModel alloc]init];
    browseItem.bigImage = img;
//    MSSBrowseNetworkViewController *bvc = [[MSSBrowseNetworkViewController alloc]initWithBrowseItem:browseItem];
//    [bvc showBrowseViewController];
    MSSBrowseLocalViewController *bvc2 = [[MSSBrowseLocalViewController alloc] initWithBrowseItem:browseItem];
    [bvc2 showBrowseViewController];
}

// 为一个UIView增加手指点击事件处理。
+ (void)addFingerClick:(UIView *)view action:(nullable SEL)action target:(nullable id)target
{
    if(view != nil && action != nil && target != nil)
    {
        view.userInteractionEnabled = YES;

        UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:target action:action];
        [view addGestureRecognizer:singleTap];
    }
}

+ (void)setStretchImage:(UIImageView *)viewImg capInsets:(UIEdgeInsets)eim imgName:(NSString *)imgName
{
    [BasicTool setStretchImage:viewImg capInsets:eim img:[UIImage imageNamed:imgName]];
}
+ (void)setStretchImage:(UIImageView *)viewImg capInsets:(UIEdgeInsets)eim img:(UIImage *)img
{
    // 被拉伸的原始图片
    // 四个数值对应图片中距离上、左、下、右边界的不拉伸部分的范围宽度
    img = [img resizableImageWithCapInsets:eim resizingMode:UIImageResizingModeStretch];
    // 为图片组件设置拉伸后的图片
    [viewImg setImage:img];
}

+ (void)setStretchBackgroundImage:(UIButton *)btn capInsets:(UIEdgeInsets)eim imgName:(NSString *)imgName forState:(UIControlState)state
{
    [BasicTool setStretchBackgroundImage:btn capInsets:eim img:[UIImage imageNamed:imgName] forState:state];
}
+ (void)setStretchBackgroundImage:(UIButton *)btn capInsets:(UIEdgeInsets)eim img:(UIImage *)img forState:(UIControlState)state
{
    // 被拉伸的原始图片
    // 四个数值对应图片中距离上、左、下、右边界的不拉伸部分的范围宽度
    img = [img resizableImageWithCapInsets:eim resizingMode:UIImageResizingModeStretch];
    // 设置拉伸后的图片为按钮背景
    [btn setBackgroundImage:img forState:state];//UIControlStateNormal];
}

+ (void)showUserDefintToast:(NSString *)tipContent view:(UIView *)parentView atHide:(void (^)(void))complete
{
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:parentView animated:YES];
    // Set the custom view mode to show any view.
    hud.mode = MBProgressHUDModeCustomView;
    // Set an image view with a checkmark.
    UIImage *image = [[UIImage imageNamed:@"Checkmark"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    hud.customView = [[UIImageView alloc] initWithImage:image];
    // 此值设为YES则会让底边空白变的更大
    hud.square = NO;
    // Optional label text
    hud.label.text = tipContent;
    // 允许触摸穿透，提示显示期间不阻塞用户操作
    hud.userInteractionEnabled = NO;

    //    [hud hideAnimated:YES afterDelay:3.f];
    double delayInSeconds = 2.0;//3.0;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        // 隐藏
        [hud hideAnimated:YES];
        // 执行block
        if(complete)
            complete();
    });
}

// 截断文本（以字符长度为准，如中文等双字节字符是作为len=1计算的）.
+ (NSString *)truncString:(NSString *)msg maxLen:(int)maxLen
{
    NSString *ret = msg;
    if (msg != nil)
        if ([msg length] > maxLen)
            ret = [msg substringToIndex:maxLen];
    return ret;
}

+ (NSString *)trim:(NSString *)s
{
    if(s != nil)
        return [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    return s;
}

+ (BOOL)isChineseSimple
{
    // 当前系统语言
    NSString* strLanguage = [[[NSUserDefaults standardUserDefaults] objectForKey:@"AppleLanguages"] objectAtIndex:0];
    // iOS 11是返回的结果是 zh-Hans-CN
    return strLanguage != nil && ([@"zh-Hans" isEqualToString:strLanguage] || [@"zh-Hans-CN" isEqualToString:strLanguage]);
}

+ (BOOL)isChinese
{
    NSString *localeLanguageCode = [[NSLocale currentLocale] objectForKey:NSLocaleLanguageCode];
    // 是否是中文环境（不需要区分简体、繁体这些）
    return localeLanguageCode != nil && [@"zh" isEqualToString:localeLanguageCode];
}



+ (BOOL)isStringEmpty:(NSString *)str
{
    return [str isKindOfClass:[NSNull class]] || str == nil || [str length] < 1 || [[BasicTool trim:str] isEqualToString:@""];
}

+ (int)getIntValue:(NSString *)intWithStr
{
    return [BasicTool getIntValue:intWithStr defaultVal:0];
}
+ (int)getIntValue:(NSString *)intWithStr defaultVal:(int)defaultValue
{
    return (intWithStr == nil || intWithStr.length == 0 )? defaultValue : [intWithStr intValue];
}

+ (BOOL) isFullNumber:(NSString *)str
{
    NSString *regex = @"[0-9]*";
    NSPredicate *pred = [NSPredicate predicateWithFormat:@"SELF MATCHES %@",regex];
    if ([pred evaluateWithObject:str]) {
        return YES;
    }
    return NO;
}

// 邮箱地址的判断
+ (BOOL)isValidEmail:(NSString *)email
{
    NSString *emailRegex = @"[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,4}";
    NSPredicate *emailTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", emailRegex];
    return [emailTest evaluateWithObject:email];
}

#pragma mark - 字体大小管理

+ (CGFloat)getAppFontSizeMultiplier
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSString *fontSizeKey = @"APP_FONT_SIZE"; // 0~4: 五档（小、较小、标准、较大、大）
    NSInteger fontSize = [userDefaults integerForKey:fontSizeKey];
    
    // 程序初始化默认使用标准字体（档位 2）；未设置时写入默认并标记已迁移，避免被旧逻辑误改
    NSString *migratedKey = @"APP_FONT_SIZE_MIGRATED_V2";
    if ([userDefaults objectForKey:fontSizeKey] == nil) {
        fontSize = 2;
        [userDefaults setInteger:2 forKey:fontSizeKey];
        [userDefaults setBool:YES forKey:migratedKey];
        [userDefaults synchronize];
    } else if ([userDefaults objectForKey:migratedKey] == nil && fontSize <= 2) {
        // 一次性迁移：旧三档 0,1,2 转为五档 0,2,4（仅对已有旧值的用户）
        if (fontSize == 1) fontSize = 2;
        else if (fontSize == 2) fontSize = 4;
        [userDefaults setInteger:fontSize forKey:fontSizeKey];
        [userDefaults setBool:YES forKey:migratedKey];
        [userDefaults synchronize];
    }
    
    // 五档倍数：小=0.85, 较小=0.9, 标准=1.0, 较大=1.1, 大=1.15
    CGFloat multiplier = 1.0;
    switch (fontSize) {
        case 0: multiplier = 0.85f; break;
        case 1: multiplier = 0.9f;  break;
        case 2: multiplier = 1.0f;  break;
        case 3: multiplier = 1.1f;  break;
        case 4: multiplier = 1.15f; break;
        default:
            if (fontSize > 4) multiplier = 1.15f;
            else multiplier = 1.0f;
            break;
    }
    return multiplier;
}

+ (CGFloat)getAdjustedFontSize:(CGFloat)baseFontSize
{
    CGFloat multiplier = [BasicTool getAppFontSizeMultiplier];
    return baseFontSize * multiplier;
}

+ (UIFont *)getSystemFontOfSize:(CGFloat)baseFontSize
{
    CGFloat adjustedSize = [BasicTool getAdjustedFontSize:baseFontSize];
    return [UIFont systemFontOfSize:adjustedSize];
}

+ (UIFont *)getBoldSystemFontOfSize:(CGFloat)baseFontSize
{
    CGFloat adjustedSize = [BasicTool getAdjustedFontSize:baseFontSize];
    return [UIFont boldSystemFontOfSize:adjustedSize];
}

// 刷新指定视图及其所有子视图的字体大小（根据全局字体设置）
+ (void)refreshFontsForView:(UIView *)view
{
    [self refreshFontsForView:view skippingDescendantsOfView:nil];
}

+ (void)refreshFontsForView:(UIView *)view skippingDescendantsOfView:(UIView *)skipRoot
{
    if (skipRoot != nil && (view == skipRoot || [view isDescendantOfView:skipRoot])) {
        return;
    }
    // 刷新当前视图的字体（如果是文本控件）
    if ([view isKindOfClass:[UILabel class]]) {
        UILabel *label = (UILabel *)view;
        if (label.font) {
            // 获取或保存原始字体大小
            NSNumber *originalSizeObj = objc_getAssociatedObject(label, &kOriginalFontSizeKey);
            CGFloat originalSize;
            
            if (originalSizeObj == nil) {
                // 第一次设置，保存原始字体大小
                originalSize = label.font.pointSize;
                // 如果当前字体已经被调整过（不是标准倍数），需要还原到原始大小
                CGFloat currentMultiplier = [BasicTool getAppFontSizeMultiplier];
                if (currentMultiplier != 1.0 && originalSize > 0) {
                    // 尝试还原：如果当前字体大小接近调整后的值，则还原
                    CGFloat expectedSize = originalSize * currentMultiplier;
                    if (fabs(label.font.pointSize - expectedSize) < 0.1) {
                        // 当前字体已经被调整过，需要还原
                        originalSize = label.font.pointSize / currentMultiplier;
                    }
                }
                objc_setAssociatedObject(label, &kOriginalFontSizeKey, @(originalSize), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            } else {
                originalSize = [originalSizeObj floatValue];
            }
            
            if (originalSize > 0) {
                label.font = [BasicTool getSystemFontOfSize:originalSize];
            }
        }
    } else if ([view isKindOfClass:[UIButton class]]) {
        UIButton *button = (UIButton *)view;
        if (button.titleLabel && button.titleLabel.font) {
            // 获取或保存原始字体大小
            NSNumber *originalSizeObj = objc_getAssociatedObject(button, &kOriginalFontSizeKey);
            CGFloat originalSize;
            
            if (originalSizeObj == nil) {
                // 第一次设置，保存原始字体大小
                originalSize = button.titleLabel.font.pointSize;
                // 如果当前字体已经被调整过，需要还原
                CGFloat currentMultiplier = [BasicTool getAppFontSizeMultiplier];
                if (currentMultiplier != 1.0 && originalSize > 0) {
                    CGFloat expectedSize = originalSize * currentMultiplier;
                    if (fabs(button.titleLabel.font.pointSize - expectedSize) < 0.1) {
                        originalSize = button.titleLabel.font.pointSize / currentMultiplier;
                    }
                }
                objc_setAssociatedObject(button, &kOriginalFontSizeKey, @(originalSize), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            } else {
                originalSize = [originalSizeObj floatValue];
            }
            
            if (originalSize > 0) {
                button.titleLabel.font = [BasicTool getSystemFontOfSize:originalSize];
            }
        }
    } else if ([view isKindOfClass:[UITextField class]]) {
        UITextField *textField = (UITextField *)view;
        if (textField.font) {
            NSNumber *originalSizeObj = objc_getAssociatedObject(textField, &kOriginalFontSizeKey);
            CGFloat originalSize;
            
            if (originalSizeObj == nil) {
                originalSize = textField.font.pointSize;
                CGFloat currentMultiplier = [BasicTool getAppFontSizeMultiplier];
                if (currentMultiplier != 1.0 && originalSize > 0) {
                    CGFloat expectedSize = originalSize * currentMultiplier;
                    if (fabs(textField.font.pointSize - expectedSize) < 0.1) {
                        originalSize = textField.font.pointSize / currentMultiplier;
                    }
                }
                objc_setAssociatedObject(textField, &kOriginalFontSizeKey, @(originalSize), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            } else {
                originalSize = [originalSizeObj floatValue];
            }
            
            if (originalSize > 0) {
                textField.font = [BasicTool getSystemFontOfSize:originalSize];
            }
        }
    } else if ([view isKindOfClass:[UITextView class]]) {
        UITextView *textView = (UITextView *)view;
        if (textView.font) {
            NSNumber *originalSizeObj = objc_getAssociatedObject(textView, &kOriginalFontSizeKey);
            CGFloat originalSize;
            
            if (originalSizeObj == nil) {
                originalSize = textView.font.pointSize;
                CGFloat currentMultiplier = [BasicTool getAppFontSizeMultiplier];
                if (currentMultiplier != 1.0 && originalSize > 0) {
                    CGFloat expectedSize = originalSize * currentMultiplier;
                    if (fabs(textView.font.pointSize - expectedSize) < 0.1) {
                        originalSize = textView.font.pointSize / currentMultiplier;
                    }
                }
                objc_setAssociatedObject(textView, &kOriginalFontSizeKey, @(originalSize), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            } else {
                originalSize = [originalSizeObj floatValue];
            }
            
            if (originalSize > 0) {
                textView.font = [BasicTool getSystemFontOfSize:originalSize];
            }
        }
    }
    
    // 递归处理所有子视图（可整段跳过消息列表等子树，避免与业务侧气泡字体逻辑打架）
    for (UIView *subview in view.subviews) {
        if (skipRoot != nil && (subview == skipRoot || [skipRoot isDescendantOfView:subview])) {
            continue;
        }
        [BasicTool refreshFontsForView:subview skippingDescendantsOfView:skipRoot];
    }
}

#pragma mark - 多语言管理

// 获取当前应用设置的语言代码
+ (NSString *)getAppLanguage
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSString *languageKey = @"APP_LANGUAGE";
    NSString *language = [userDefaults stringForKey:languageKey];
    return language; // 如果未设置，返回 nil 表示跟随系统
}

// 设置应用语言
+ (void)setAppLanguage:(NSString *)languageCode
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSString *languageKey = @"APP_LANGUAGE";
    
    if (languageCode && languageCode.length > 0) {
        [userDefaults setObject:languageCode forKey:languageKey];
    } else {
        [userDefaults removeObjectForKey:languageKey];
    }
    [userDefaults synchronize];
    
    // 立即应用语言设置
    [BasicTool applyAppLanguage];
}

// 初始化应用语言设置（应在应用启动时调用）
+ (void)initializeAppLanguage
{
    [BasicTool applyAppLanguage];
}

// 应用语言设置（内部方法）
+ (void)applyAppLanguage
{
    NSString *languageCode = [BasicTool getAppLanguage];
    NSArray *languages;
    
    if (languageCode && languageCode.length > 0) {
        // 使用用户设置的语言
        languages = @[languageCode];
    } else {
        // 跟随系统语言
        languages = [NSLocale preferredLanguages];
    }
    
    // 设置应用的语言偏好
    [[NSUserDefaults standardUserDefaults] setObject:languages forKey:@"AppleLanguages"];
    
    // 发送语言切换通知，让界面刷新
    [[NSNotificationCenter defaultCenter] postNotificationName:@"AppLanguageDidChangeNotification" object:nil];
}

// 获取指定语言的本地化字符串（支持运行时切换）
+ (NSString *)localizedStringForKey:(NSString *)key value:(NSString *)value
{
    NSString *languageCode = [BasicTool getAppLanguage];
    NSBundle *bundle = [NSBundle mainBundle];
    
    // 如果没有设置语言，使用系统默认的本地化方法
    if (!languageCode || languageCode.length == 0) {
        return NSLocalizedString(key, value ?: @"");
    }
    
    // 获取指定语言的 bundle 路径
    NSString *path = [bundle pathForResource:languageCode ofType:@"lproj"];
    if (path) {
        NSBundle *languageBundle = [NSBundle bundleWithPath:path];
        if (languageBundle) {
            NSString *localizedString = [languageBundle localizedStringForKey:key value:value ?: @"" table:@"Localizable"];
            // 如果返回的字符串不是 key 本身，说明找到了本地化字符串
            if (localizedString && ![localizedString isEqualToString:key] && localizedString.length > 0) {
                return localizedString;
            }
        }
    }
    
    // 如果指定语言找不到，尝试使用 Base.lproj
    NSString *basePath = [bundle pathForResource:@"Base" ofType:@"lproj"];
    if (basePath) {
        NSBundle *baseBundle = [NSBundle bundleWithPath:basePath];
        if (baseBundle) {
            NSString *localizedString = [baseBundle localizedStringForKey:key value:value ?: @"" table:@"Localizable"];
            if (localizedString && ![localizedString isEqualToString:key] && localizedString.length > 0) {
                return localizedString;
            }
        }
    }
    
    // 最后尝试使用主 bundle 的默认本地化方法（使用 Localizable.strings）
    NSString *localizedString = [bundle localizedStringForKey:key value:value ?: @"" table:@"Localizable"];
    if (localizedString && ![localizedString isEqualToString:key] && localizedString.length > 0) {
        return localizedString;
    }
    
    // 如果都找不到，返回 value 或 key
    return value ?: key;
}

//#pragma mark - dialog
//
//+(void)showDialog:(NSString*)title message:(NSString*)message {
//    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * 0)), dispatch_get_main_queue(), ^{
//        UIAlertView * dialog =[[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:NSLocalizedString(@"general_confirm", @"") otherButtonTitles:nil, nil];
//        [dialog show];
//    });
//}
//
//+(void)showDialog:(NSString*)title message:(NSString*)message btnCancel:(NSString*)cancel btnOK:(NSString*)ok withDelegate:(id<UIAlertViewDelegate>)delegate{
//    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * 0)), dispatch_get_main_queue(), ^{
//        UIAlertView * dialog =[[UIAlertView alloc] initWithTitle:title message:message delegate:delegate cancelButtonTitle:cancel otherButtonTitles:ok, nil];
//        [dialog show];
//    });
//}

//+(NSMutableAttributedString *)getAttributedText:(NSString *)content contentColor:(UIColor*)contentColor contentFontSize:(int)contentFontSize unit:(NSString*)unit
//                                      unitColor:(UIColor*)unitColor unitFontSize:(int)unitFontSize{
//
//    NSString* contentAll = [NSString stringWithFormat:@"%@%@", content, unit];
//    // iOS6 and above : Use NSAttributedStrings
//    UIFont *unitFont = [UIFont systemFontOfSize:unitFontSize];
//    UIFont *contentFont = [UIFont systemFontOfSize:contentFontSize];
//
//    // Create the attributes
//    NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys:
//                           contentFont, NSFontAttributeName,
//                           contentColor, NSForegroundColorAttributeName, nil];
//    NSDictionary *subAttrs = [NSDictionary dictionaryWithObjectsAndKeys:
//                              unitFont, NSFontAttributeName,
//                              unitColor, NSForegroundColorAttributeName, nil];
//    const NSRange range = NSMakeRange([content length], [unit length]); // range of " 2012/10/14 ". Ideally this should not be hardcoded
//
//    // Create the attributed string (text + attributes)
//    NSMutableAttributedString *attributedText =
//    [[NSMutableAttributedString alloc] initWithString:contentAll
//                                           attributes:attrs];
//    [attributedText setAttributes:subAttrs range:range];
//    return attributedText;
//}

+ (UIImage *)loadImage:(NSString *)imageFilePath
{
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:imageFilePath]) {
        NSData * data = [NSData dataWithContentsOfFile:imageFilePath];
        UIImage *image = [UIImage imageWithData:data];
        return image;
    }
    return nil;
}

+ (NSString *)imageCompressForQualityAndWidth:(UIImage *)sourceImage
                                targetQuality:(CGFloat)compressionQuality
                                  targetWidth:(CGFloat)defineWidth
                                    saveToDir:(NSString *)savedDir
                                    savedName:(NSString *)savedFileName
{
    @try {
        //** 先缩放尺寸
        UIImage *imageAfterResize = [BasicTool imageCompressForWidthScale:sourceImage targetWidth:defineWidth];
        //** 再压缩质量
        NSData *imageDataAfterCompressQuality = [BasicTool imageCompressForQuality:imageAfterResize targetQuality:compressionQuality];

        //** 再保存到文件
        // 判断文件夹是否存在，如果不存在，则创建
        if (![[NSFileManager defaultManager] fileExistsAtPath:savedDir])
        {
            DDLogDebug(@"【缩放和压缩图片】要保存的文件目录 %@ 不存在，马上创建之！", savedDir);
            [[NSFileManager defaultManager] createDirectoryAtPath:savedDir withIntermediateDirectories:YES attributes:nil error:nil];
        }
        else
        {
            DDLogDebug(@"【缩放和压缩图片】要保存的文件目录 %@ 已经存在，直接使用。", savedDir);
        }

        NSString *filePath2 = [NSString stringWithFormat:@"%@/%@", savedDir, savedFileName];//[SendImageHelper constructImageFileName:@"test005" ]];
        DDLogDebug(@"【缩放和压缩图片】压缩后的图片最终保存：%@", filePath2);
//      NSData* imageData = UIImageJPEGRepresentation(photoAfterResize, 0.75);//0.75 0.35
        [imageDataAfterCompressQuality writeToFile:filePath2 atomically:NO];

        return filePath2;
    } @catch (NSException *exception) {
        DDLogError(@"【缩放和压缩图片】过程中发生了异步，Exception: %@", exception);
        return nil;
    }
}

+ (NSData *)imageCompressForQuality:(UIImage *)sourceImage targetQuality:(CGFloat)compressionQuality
{
    return UIImageJPEGRepresentation(sourceImage, compressionQuality);//0.75 0.35
}

+ (UIImage *)imageCompressForWidthScale:(UIImage *)sourceImage targetWidth:(CGFloat)defineWidth
{
    if (sourceImage == nil) {
        return nil;
    }
    
    CGSize imageSize = sourceImage.size;
    CGFloat width = imageSize.width;
    CGFloat height = imageSize.height;
    
    // 【优化】如果原图宽度小于等于目标宽度，直接返回原图（只缩小不放大，避免小图被拉伸导致模糊）
    if (width <= defineWidth) {
        DDLogDebug(@"【图片缩放】原图宽度(%.0f)小于目标宽度(%.0f)，保持原尺寸不放大", width, defineWidth);
        return sourceImage;
    }
    
    // 等比缩放：以目标宽度为基准，计算目标高度
    CGFloat targetWidth = defineWidth;
    CGFloat targetHeight = height * (targetWidth / width); // 保持宽高比
    CGSize size = CGSizeMake(targetWidth, targetHeight);
    
    DDLogDebug(@"【图片缩放】原图尺寸: %.0f x %.0f -> 目标尺寸: %.0f x %.0f", width, height, targetWidth, targetHeight);
    
    // 使用高质量的图形上下文进行缩放
    UIGraphicsBeginImageContextWithOptions(size, NO, 1.0);
    
    CGRect drawRect = CGRectMake(0, 0, targetWidth, targetHeight);
    [sourceImage drawInRect:drawRect];
    
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    if (newImage == nil) {
        DDLogError(@"【图片缩放】缩放失败，返回原图");
        return sourceImage;
    }
    
    return newImage;
}

+ (UIBarButtonItem *)rb_leftPlainTitleBarButtonItemForMainTabWithLocalizedKey:(NSString *)key
{
    if (key.length == 0) {
        return nil;
    }
    UILabel *leftNavTitle = [[UILabel alloc] init];
    leftNavTitle.text = NSLocalizedString(key, @"");
    CGFloat titlePt = [BasicTool getAdjustedFontSize:22.f];
    leftNavTitle.font = [UIFont systemFontOfSize:titlePt weight:UIFontWeightSemibold];
    if (@available(iOS 13.0, *)) {
        leftNavTitle.textColor = [UIColor labelColor];
    } else {
        leftNavTitle.textColor = [UIColor blackColor];
    }
    leftNavTitle.backgroundColor = [UIColor clearColor];
    leftNavTitle.userInteractionEnabled = NO;
    leftNavTitle.translatesAutoresizingMaskIntoConstraints = NO;
    UIView *leftNavTitleWrap = [[UIView alloc] init];
    leftNavTitleWrap.backgroundColor = [UIColor clearColor];
    leftNavTitleWrap.userInteractionEnabled = NO;
    leftNavTitleWrap.translatesAutoresizingMaskIntoConstraints = NO;
    [leftNavTitleWrap addSubview:leftNavTitle];
    [NSLayoutConstraint activateConstraints:@[
        [leftNavTitle.leadingAnchor constraintEqualToAnchor:leftNavTitleWrap.leadingAnchor],
        [leftNavTitle.trailingAnchor constraintEqualToAnchor:leftNavTitleWrap.trailingAnchor],
        [leftNavTitle.topAnchor constraintEqualToAnchor:leftNavTitleWrap.topAnchor],
        [leftNavTitle.bottomAnchor constraintEqualToAnchor:leftNavTitleWrap.bottomAnchor],
    ]];
    UIBarButtonItem *leftNavItem = [[UIBarButtonItem alloc] initWithCustomView:leftNavTitleWrap];
    if (@available(iOS 26.0, *)) {
        @try {
            [leftNavItem setValue:@YES forKey:@"hidesSharedBackground"];
        } @catch (__unused NSException *e) { }
    }
    return leftNavItem;
}

@end
