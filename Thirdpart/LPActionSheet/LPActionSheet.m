//telegram @wz662
/*
 作者：  刘鹏 <liupeng@zhishisoft.com>
 文件：  LPActionSheet.m
 版本：  1.0
 地址：  https://github.com/wenxiangjiang/LPActionSheet
 描述：
 */

#import "LPActionSheet.h"
#import "BasicTool.h"

// 顶部圆解半径
static const CGFloat kTopTopCorner = 16.0f;//12.0f;
// 按钮item的高度
static const CGFloat kRowHeight = 54.0f;//48.0f;
// 横线高度
static const CGFloat kRowLineHeight = 0.5f;
// 与取消按钮间的间距高度
static const CGFloat kSeparatorHeight = 6.0f;
// title提示文本的字体大小
static const CGFloat kTitleFontSize = 13.0f;
// 按钮item的字体大小
static const CGFloat kButtonTitleFontSize = 17.0f;
// 弹单弹出动画持续时长（单位：秒）
static const NSTimeInterval kAnimateDuration = 0.3f;
// other 按钮左侧图标与标题的间距
static const CGFloat kOtherButtonIconTitleSpacing = 12.0f;
// other 按钮左侧内边距
static const CGFloat kOtherButtonContentLeftPadding = 16.0f;
// other 按钮左侧图标最大边长（过大则等比缩放）
static const CGFloat kOtherButtonIconMaxSize = 28.0f;

@interface LPActionSheet ()

/** block回调 */
@property (copy, nonatomic) LPActionSheetBlock actionSheetBlock;
/** 背景图片 */
@property (strong, nonatomic) UIView *backgroundView;
/** 弹出视图 */
@property (strong, nonatomic) UIView *actionSheetView;
/** other 按钮左侧图标（可选） */
@property (strong, nonatomic) NSArray<UIImage *> *otherButtonImages;
/** other 按钮右侧图标（可选） */
@property (strong, nonatomic) NSArray<UIImage *> *otherButtonRightImages;

/**
 * 收起视图
 */
- (void)dismiss;

/**
 * 通过颜色生成图片
 */
- (UIImage *)imageWithColor:(UIColor *)color;

@end

@implementation LPActionSheet

- (instancetype)initWithFrame:(CGRect)frame
{
    return [self initWithTitle:nil cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil handler:nil];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    return [self initWithTitle:nil cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil handler:nil];
}

- (instancetype)initWithTitle:(NSString *)title cancelButtonTitle:(NSString *)cancelButtonTitle destructiveButtonTitle:(NSString *)destructiveButtonTitle otherButtonTitles:(NSArray *)otherButtonTitles handler:(LPActionSheetBlock)actionSheetBlock
{
    return [self initWithTitle:title cancelButtonTitle:cancelButtonTitle destructiveButtonTitle:destructiveButtonTitle otherButtonTitles:otherButtonTitles otherButtonImages:nil otherButtonRightImages:nil handler:actionSheetBlock];
}

- (instancetype)initWithTitle:(NSString *)title cancelButtonTitle:(NSString *)cancelButtonTitle destructiveButtonTitle:(NSString *)destructiveButtonTitle otherButtonTitles:(NSArray *)otherButtonTitles otherButtonImages:(NSArray<UIImage *> *)otherButtonImages handler:(LPActionSheetBlock)actionSheetBlock
{
    return [self initWithTitle:title cancelButtonTitle:cancelButtonTitle destructiveButtonTitle:destructiveButtonTitle otherButtonTitles:otherButtonTitles otherButtonImages:otherButtonImages otherButtonRightImages:nil handler:actionSheetBlock];
}

- (instancetype)initWithTitle:(NSString *)title cancelButtonTitle:(NSString *)cancelButtonTitle destructiveButtonTitle:(NSString *)destructiveButtonTitle otherButtonTitles:(NSArray *)otherButtonTitles otherButtonImages:(NSArray<UIImage *> *)otherButtonImages otherButtonRightImages:(NSArray<UIImage *> *)otherButtonRightImages handler:(LPActionSheetBlock)actionSheetBlock
{
    self = [super initWithFrame:CGRectZero];
    if (self)
    {
        self.frame = CGRectMake(0, 0, [[UIScreen mainScreen] bounds].size.width, [[UIScreen mainScreen] bounds].size.height);
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        
        _actionSheetBlock = actionSheetBlock;
        _otherButtonImages = otherButtonImages;
        _otherButtonRightImages = otherButtonRightImages;
        
        CGFloat actionSheetHeight = 0;
        
        _backgroundView = [[UIView alloc] initWithFrame:self.frame];
        _backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _backgroundView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.5f];// 作者设定的是0.4f
        _backgroundView.alpha = 0;
        
        [self addSubview:_backgroundView];
        
//        // 创建玻璃效果
//        UIGlassEffect *glassEffect = [UIGlassEffect effectWithStyle:UIGlassEffectStyleClear];
//        // 创建视觉效果视图
//        UIVisualEffectView *visualEffectView = [[UIVisualEffectView alloc] initWithEffect:glassEffect];
//        visualEffectView.frame = self.frame;
//        // 将按钮添加到视觉效果视图的内容视图
//        [visualEffectView.contentView addSubview:_backgroundView];
//        [self addSubview:visualEffectView];
//        _backgroundView.backgroundColor = [UIColor clearColor];
//        self.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.5f];
      
        _actionSheetView = [[UIView alloc] initWithFrame:CGRectMake(0, self.frame.size.height, self.frame.size.width, 0)];
        _actionSheetView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
        
        // 原代码
//      _actionSheetView.backgroundColor = [UIColor colorWithRed:238.0f/255.0f green:238.0f/255.0f blue:238.0f/255.0f alpha:1.0f];
        // Jack Jiang改（让颜色偏蓝、偏冷）
        _actionSheetView.backgroundColor = [UIColor colorWithRed:238.0f/255.0f green:240.0f/255.0f blue:244.0f/255.0f alpha:1.0f];
        
        [self addSubview:_actionSheetView];
        
        UIImage *normalImage = [self imageWithColor:[UIColor colorWithRed:255.0f/255.0f green:255.0f/255.0f blue:255.0f/255.0f alpha:1.0f]];
        UIImage *highlightedImage = [self imageWithColor:[UIColor colorWithRed:242.0f/255.0f green:244.0f/255.0f blue:248.0f/255.0f alpha:1.0f]];
       
        if (title && title.length > 0)
        {
            actionSheetHeight += kRowLineHeight;
            
            CGFloat titleHeight = ceil([title boundingRectWithSize:CGSizeMake(self.frame.size.width, MAXFLOAT) options:NSStringDrawingUsesLineFragmentOrigin attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:kTitleFontSize]} context:nil].size.height) + 20*2;//15*2;
            
            UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, actionSheetHeight, self.frame.size.width, titleHeight)];
            titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
            titleLabel.text = title;
            titleLabel.backgroundColor = [UIColor colorWithRed:255.0f/255.0f green:255.0f/255.0f blue:255.0f/255.0f alpha:1.0f];
            
            // 原代码
//            titleLabel.textColor = [UIColor colorWithRed:135.0f/255.0f green:135.0f/255.0f blue:135.0f/255.0f alpha:1.0f];
            // Jack Jiang改（让颜色偏蓝、偏冷）
            titleLabel.textColor = [UIColor colorWithRed:135.0f/255.0f green:137.0f/255.0f blue:141.0f/255.0f alpha:1.0f];
            
            titleLabel.textAlignment = NSTextAlignmentCenter;
            titleLabel.font = [UIFont systemFontOfSize:kTitleFontSize];
            titleLabel.numberOfLines = 0;
            [_actionSheetView addSubview:titleLabel];
            
            actionSheetHeight += titleHeight;
        }
        
        if (destructiveButtonTitle && destructiveButtonTitle.length > 0)
        {
            actionSheetHeight += kRowLineHeight;
            
            UIButton *destructiveButton = [UIButton buttonWithType:UIButtonTypeCustom];
            destructiveButton.frame = CGRectMake(0, actionSheetHeight, self.frame.size.width, kRowHeight);
            destructiveButton.autoresizingMask = UIViewAutoresizingFlexibleWidth;
            destructiveButton.tag = -1;
            destructiveButton.titleLabel.font = [UIFont systemFontOfSize:kButtonTitleFontSize];
            [destructiveButton setTitle:destructiveButtonTitle forState:UIControlStateNormal];
            [destructiveButton setTitleColor:[UIColor colorWithRed:230.0f/255.0f green:66.0f/255.0f blue:66.0f/255.0f alpha:1.0f] forState:UIControlStateNormal];
            [destructiveButton setBackgroundImage:normalImage forState:UIControlStateNormal];
            [destructiveButton setBackgroundImage:highlightedImage forState:UIControlStateHighlighted];
            [destructiveButton addTarget:self action:@selector(buttonClicked:) forControlEvents:UIControlEventTouchUpInside];
            [_actionSheetView addSubview:destructiveButton];
            
            actionSheetHeight += kRowHeight;
        }
        
        if (otherButtonTitles && [otherButtonTitles count] > 0)
        {
            for (int i = 0; i < otherButtonTitles.count; i++)
            {
                actionSheetHeight += kRowLineHeight;
                
                UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
                button.frame = CGRectMake(0, actionSheetHeight, self.frame.size.width, kRowHeight);
                button.autoresizingMask = UIViewAutoresizingFlexibleWidth;
                button.tag = i+1;
                button.titleLabel.font = [UIFont systemFontOfSize:kButtonTitleFontSize];
                [button setTitle:otherButtonTitles[i] forState:UIControlStateNormal];
                
                // 原代码
//                [button setTitleColor:[UIColor colorWithRed:64.0f/255.0f green:64.0f/255.0f blue:64.0f/255.0f alpha:1.0f] forState:UIControlStateNormal];
                // Jack Jiang改（让颜色偏蓝、偏冷）
                [button setTitleColor:[UIColor colorWithRed:64.0f/255.0f green:66.0f/255.0f blue:70.0f/255.0f alpha:1.0f] forState:UIControlStateNormal];
                
                UIImage *iconImg = nil;
                if (_otherButtonImages != nil && i < (int)_otherButtonImages.count) {
                    id imageObj = _otherButtonImages[i];
                    if ([imageObj isKindOfClass:[UIImage class]]) {
                        iconImg = (UIImage *)imageObj;
                    }
                }
                if (iconImg != nil) {
                    CGFloat w = iconImg.size.width, h = iconImg.size.height;
                    if (w > kOtherButtonIconMaxSize || h > kOtherButtonIconMaxSize) {
                        CGFloat scale = MIN(kOtherButtonIconMaxSize / w, kOtherButtonIconMaxSize / h);
                        w *= scale; h *= scale;
                        UIGraphicsBeginImageContextWithOptions(CGSizeMake(w, h), NO, 0);
                        [iconImg drawInRect:CGRectMake(0, 0, w, h)];
                        iconImg = UIGraphicsGetImageFromCurrentImageContext();
                        UIGraphicsEndImageContext();
                    }
                    [button setImage:iconImg forState:UIControlStateNormal];
                    button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
                    button.imageEdgeInsets = UIEdgeInsetsMake(0, 0, 0, kOtherButtonIconTitleSpacing);
                    button.titleEdgeInsets = UIEdgeInsetsMake(0, kOtherButtonIconTitleSpacing, 0, 0);
                }

                UIImage *rightIconImg = nil;
                if (_otherButtonRightImages != nil && i < (int)_otherButtonRightImages.count) {
                    id rightImageObj = _otherButtonRightImages[i];
                    if ([rightImageObj isKindOfClass:[UIImage class]]) {
                        rightIconImg = (UIImage *)rightImageObj;
                    }
                }
                if (rightIconImg != nil) {
                    CGFloat w = rightIconImg.size.width, h = rightIconImg.size.height;
                    if (w > kOtherButtonIconMaxSize || h > kOtherButtonIconMaxSize) {
                        CGFloat scale = MIN(kOtherButtonIconMaxSize / w, kOtherButtonIconMaxSize / h);
                        w *= scale; h *= scale;
                        UIGraphicsBeginImageContextWithOptions(CGSizeMake(w, h), NO, 0);
                        [rightIconImg drawInRect:CGRectMake(0, 0, w, h)];
                        rightIconImg = UIGraphicsGetImageFromCurrentImageContext();
                        UIGraphicsEndImageContext();
                    }
                    UIImageView *rightIconView = [[UIImageView alloc] initWithImage:rightIconImg];
                    rightIconView.frame = CGRectMake(self.frame.size.width - 16.0f - w,
                                                     (kRowHeight - h) * 0.5f,
                                                     w,
                                                     h);
                    rightIconView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
                    rightIconView.contentMode = UIViewContentModeScaleAspectFit;
                    rightIconView.userInteractionEnabled = NO;
                    [button addSubview:rightIconView];
                }
                
                [button setBackgroundImage:normalImage forState:UIControlStateNormal];
                [button setBackgroundImage:highlightedImage forState:UIControlStateHighlighted];
                [button addTarget:self action:@selector(buttonClicked:) forControlEvents:UIControlEventTouchUpInside];
                [_actionSheetView addSubview:button];
                
                actionSheetHeight += kRowHeight;
            }
        }
        
        if (cancelButtonTitle && cancelButtonTitle.length > 0)
        {
            actionSheetHeight += kSeparatorHeight;
            
            UIButton *cancelButton = [UIButton buttonWithType:UIButtonTypeCustom];
            
            //## Bug FIX [适配iPhoneX这样的流海屏手机]: by Jack Jiang 20190817
            CGFloat cancelBtnH = kRowHeight;
            if (@available(iOS 11.0, *)) {
                cancelBtnH = cancelBtnH + [UIApplication sharedApplication].keyWindow.safeAreaInsets.bottom;
                cancelButton.contentEdgeInsets = UIEdgeInsetsMake(0, 0, [UIApplication sharedApplication].keyWindow.safeAreaInsets.bottom, 0);
            }
            //## Bug FIX END
            
            cancelButton.frame = CGRectMake(0, actionSheetHeight, self.frame.size.width, cancelBtnH);//kRowHeight);
            cancelButton.autoresizingMask = UIViewAutoresizingFlexibleWidth;
            cancelButton.tag = 0;
            cancelButton.titleLabel.font = [UIFont systemFontOfSize:kButtonTitleFontSize];
            [cancelButton setTitle:cancelButtonTitle ?: @"取消" forState:UIControlStateNormal];
            
             // 原代码
//            [cancelButton setTitleColor:[UIColor colorWithRed:64.0f/255.0f green:64.0f/255.0f blue:64.0f/255.0f alpha:1.0f] forState:UIControlStateNormal];
            // Jack Jiang改（让颜色偏蓝、偏冷）
            [cancelButton setTitleColor:[UIColor colorWithRed:64.0f/255.0f green:66.0f/255.0f blue:70.0f/255.0f alpha:1.0f] forState:UIControlStateNormal];
           
            [cancelButton setBackgroundImage:normalImage forState:UIControlStateNormal];
            [cancelButton setBackgroundImage:highlightedImage forState:UIControlStateHighlighted];
            [cancelButton addTarget:self action:@selector(buttonClicked:) forControlEvents:UIControlEventTouchUpInside];
            [_actionSheetView addSubview:cancelButton];
            
            actionSheetHeight += cancelBtnH;//kRowHeight;
        }
        
        _actionSheetView.frame = CGRectMake(0, self.frame.size.height, self.frame.size.width, actionSheetHeight);
        // 顶部圆角效果设置
        [BasicTool viewRoundCorner:_actionSheetView byRoundingCorners:UIRectCornerTopLeft | UIRectCornerTopRight cornerRadii:CGSizeMake(kTopTopCorner, kTopTopCorner)];
    }
    
    return self;
}

+ (instancetype)actionSheetWithTitle:(NSString *)title cancelButtonTitle:(NSString *)cancelButtonTitle destructiveButtonTitle:(NSString *)destructiveButtonTitle otherButtonTitles:(NSArray *)otherButtonTitles handler:(LPActionSheetBlock)actionSheetBlock
{
    return [[self alloc] initWithTitle:title cancelButtonTitle:cancelButtonTitle destructiveButtonTitle:destructiveButtonTitle otherButtonTitles:otherButtonTitles handler:actionSheetBlock];
}

+ (void)showActionSheetWithTitle:(NSString *)title cancelButtonTitle:(NSString *)cancelButtonTitle destructiveButtonTitle:(NSString *)destructiveButtonTitle otherButtonTitles:(NSArray *)otherButtonTitles handler:(LPActionSheetBlock)actionSheetBlock
{
    [self showActionSheetWithTitle:title cancelButtonTitle:cancelButtonTitle destructiveButtonTitle:destructiveButtonTitle otherButtonTitles:otherButtonTitles otherButtonImages:nil handler:actionSheetBlock];
}

+ (void)showActionSheetWithTitle:(NSString *)title cancelButtonTitle:(NSString *)cancelButtonTitle destructiveButtonTitle:(NSString *)destructiveButtonTitle otherButtonTitles:(NSArray *)otherButtonTitles otherButtonImages:(NSArray<UIImage *> *)otherButtonImages handler:(LPActionSheetBlock)actionSheetBlock
{
    LPActionSheet *lpActionSheet = [[self alloc] initWithTitle:title cancelButtonTitle:cancelButtonTitle destructiveButtonTitle:destructiveButtonTitle otherButtonTitles:otherButtonTitles otherButtonImages:otherButtonImages otherButtonRightImages:nil handler:actionSheetBlock];
    [lpActionSheet show];
}

+ (void)showActionSheetWithTitle:(NSString *)title cancelButtonTitle:(NSString *)cancelButtonTitle destructiveButtonTitle:(NSString *)destructiveButtonTitle otherButtonTitles:(NSArray *)otherButtonTitles otherButtonRightImages:(NSArray<UIImage *> *)otherButtonRightImages handler:(LPActionSheetBlock)actionSheetBlock
{
    LPActionSheet *lpActionSheet = [[self alloc] initWithTitle:title cancelButtonTitle:cancelButtonTitle destructiveButtonTitle:destructiveButtonTitle otherButtonTitles:otherButtonTitles otherButtonImages:nil otherButtonRightImages:otherButtonRightImages handler:actionSheetBlock];
    [lpActionSheet show];
}

- (void)show
{
    // 在主线程中处理,否则在viewDidLoad方法中直接调用,会先加本视图,后加控制器的视图到UIWindow上,导致本视图无法显示出来,这样处理后便会优先加控制器的视图到UIWindow上
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        
        NSEnumerator *frontToBackWindows = [UIApplication.sharedApplication.windows reverseObjectEnumerator];
        for (UIWindow *window in frontToBackWindows)
        {
            BOOL windowOnMainScreen = window.screen == UIScreen.mainScreen;
            BOOL windowIsVisible = !window.hidden && window.alpha > 0;
            BOOL windowLevelNormal = window.windowLevel == UIWindowLevelNormal;
            
            if(windowOnMainScreen && windowIsVisible && windowLevelNormal)
            {
                [window addSubview:self];
                [window bringSubviewToFront:self];
                break;
            }
        }

        // 原代码：弹跳动画打开效果
//        [UIView animateWithDuration:kAnimateDuration delay:0 usingSpringWithDamping:0.7f initialSpringVelocity:0.7f options:UIViewAnimationOptionCurveEaseInOut animations:^{
//            self.backgroundView.alpha = 1.0f;
//            self.actionSheetView.frame = CGRectMake(0, self.frame.size.height-self.actionSheetView.frame.size.height, self.frame.size.width, self.actionSheetView.frame.size.height);
//        } completion:nil];
        
        // Jack Jiang改：普通从下往上动画打开效果
        [UIView animateWithDuration:kAnimateDuration animations:^{
            self.backgroundView.alpha = 1.0f;
            self.actionSheetView.frame = CGRectMake(0, self.frame.size.height-self.actionSheetView.frame.size.height, self.frame.size.width, self.actionSheetView.frame.size.height);
        } completion:nil];
        
    }];
}

- (void)dismiss
{
    [UIView animateWithDuration:kAnimateDuration delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        self.backgroundView.alpha = 0.0f;
        self.actionSheetView.frame = CGRectMake(0, self.frame.size.height, self.frame.size.width, self.actionSheetView.frame.size.height);
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
    }];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    CGPoint point = [touch locationInView:self.backgroundView];
    if (!CGRectContainsPoint(self.actionSheetView.frame, point))
    {
        if (self.actionSheetBlock)
        {
            self.actionSheetBlock(self, 0);
        }
        
        [self dismiss];
    }
}

- (void)buttonClicked:(UIButton *)button
{
    if (self.actionSheetBlock)
    {
        self.actionSheetBlock(self, button.tag);
    }
    
    [self dismiss];
}

- (UIImage *)imageWithColor:(UIColor *)color
{
    CGRect rect = CGRectMake(0.0f, 0.0f, 1.0f, 1.0f);
    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextSetFillColorWithColor(context, [color CGColor]);
    CGContextFillRect(context, rect);
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

- (void)dealloc
{
#ifdef DEBUG
    NSLog(@"LPActionSheet dealloc");
#endif
}

@end
