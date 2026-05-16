//telegram @wz662
#import "RBBadgeView.h"
//#import "NSString+NIMKit.h"

@interface RBBadgeView ()

@property (nonatomic, strong) UIColor *badgeBackgroundColor;

@property (nonatomic, strong) UIColor *badgeTextColor;

@property (nonatomic) UIFont *badgeTextFont;

@property (nonatomic) CGFloat badgeTopPadding; //数字顶部到红圈的距离

@property (nonatomic) CGFloat badgeLeftPadding; //数字左部到红圈的距离

@property (nonatomic) CGFloat whiteCircleWidth; //最外层白圈的宽度

@end

@implementation RBBadgeView


#pragma mark - Public

// 纯代码创v建时，请调用本方法
+ (instancetype)viewWithBadgeTip:(NSString *)badgeValue{
    if (!badgeValue) {
        badgeValue = @"";
    }
    
    RBBadgeView *instance = [[RBBadgeView alloc] init];
    instance.frame = [instance frameWithStr:badgeValue];
    instance.badgeValue = badgeValue;

    return instance;
}

// 从xib中使用RBBadgeView时，会自动调用本方法来完成初始化
- (void)awakeFromNib {
    [super awakeFromNib];
    
    // Initialization code
    
    if (!self.badgeValue) {
        self.badgeValue = @"";
    }
    
    [self justInit];
    
    self.frame = [self frameWithStr:self.badgeValue];
}

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];

    if (self) {
        [self justInit];
    }
    
    return self;
}

- (void)setBadgeTextFont:(UIFont *)f
{
    _badgeTextFont  = f;
}

- (void)setBadgeBackgroundColor:(UIColor *)c
{
    _badgeBackgroundColor = c;
}

- (void)setBadgeTextColor:(UIColor *)c
{
    _badgeTextColor = c;
}

- (void)setBadgeValue:(NSString *)badgeValue {
    _badgeValue = badgeValue;
    if (_badgeValue.integerValue > 9) {
        _badgeLeftPadding     = 6.f;
    }else{
        _badgeLeftPadding     = 2.f;
    }
    _badgeTopPadding      = 2.f;
    
    self.frame = [self frameWithStr:badgeValue];
    
    
    [self setNeedsDisplay];
}


#pragma mark - Private

- (void)justInit
{
    self.backgroundColor  = [UIColor clearColor];
//    _badgeBackgroundColor = [UIColor colorWithRed:247.0f/255.0f green:76.0f/255.0f blue:49.0f/255.0f alpha:1.0f];//[UIColor redColor];
    _badgeBackgroundColor = [UIColor colorWithRed:247.0f/255.0f green:76.0f/255.0f blue:49.0f/255.0f alpha:1.0f];//[UIColor redColor];
    _badgeTextColor       = [UIColor whiteColor];
    _badgeTextFont        = [UIFont systemFontOfSize:12];// [UIFont boldSystemFontOfSize:12];
    _whiteCircleWidth     = 0.0f;//2.f;
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSaveGState(context);
    if ([[self badgeValue] length]) {
        [self drawWithContent:rect context:context];
    }else{
        [self drawWithOutContent:rect context:context];
    }
    CGContextRestoreGState(context);
}

- (CGSize)badgeSizeWithStr:(NSString *)badgeValue{
    if (!badgeValue || badgeValue.length == 0) {
        return CGSizeZero;
    }
        
    CGSize size = [badgeValue sizeWithAttributes:@{NSFontAttributeName:self.badgeTextFont}];
    if (size.width < size.height) {
        size = CGSizeMake(size.height, size.height);
    }
    return size;
}

- (CGRect)frameWithStr:(NSString *)badgeValue{
    CGSize badgeSize = [self badgeSizeWithStr:badgeValue];
    CGRect badgeFrame = CGRectMake(self.frame.origin.x, self.frame.origin.y, badgeSize.width + self.badgeLeftPadding * 2 + self.whiteCircleWidth * 2, badgeSize.height + self.badgeTopPadding * 2 + self.whiteCircleWidth * 2);//8=2*2（红圈-文字）+2*2（白圈-红圈）
    return badgeFrame;
}

- (void)drawWithContent:(CGRect)rect context:(CGContextRef)context{
    CGRect bodyFrame = self.bounds;
    CGRect bkgFrame = CGRectInset(self.bounds, self.whiteCircleWidth, self.whiteCircleWidth);
    CGRect badgeSize = CGRectInset(self.bounds, self.whiteCircleWidth + self.badgeLeftPadding, self.whiteCircleWidth + self.badgeTopPadding);
    if ([self badgeBackgroundColor]) {//外白色描边
        
        if(self.whiteCircleWidth > 0){// 只有在外圈衬距大于0时才需要绘制
            CGContextSetFillColorWithColor(context, [[UIColor whiteColor] CGColor]);
            if ([self badgeValue].integerValue > 9) {
                CGFloat circleWith = bodyFrame.size.height;
                CGFloat totalWidth = bodyFrame.size.width;
                CGFloat diffWidth = totalWidth - circleWith;
                CGPoint originPoint = bodyFrame.origin;
                CGRect leftCicleFrame = CGRectMake(originPoint.x, originPoint.y, circleWith, circleWith);
                CGRect centerFrame = CGRectMake(originPoint.x +circleWith/2, originPoint.y, diffWidth, circleWith);
                CGRect rightCicleFrame = CGRectMake(originPoint.x +(totalWidth - circleWith), originPoint.y, circleWith, circleWith);
                CGContextFillEllipseInRect(context, leftCicleFrame);
                CGContextFillRect(context, centerFrame);
                CGContextFillEllipseInRect(context, rightCicleFrame);
                
            }else{
                CGContextFillEllipseInRect(context, bodyFrame);
            }
        }
        
        // badge背景色
        CGContextSetFillColorWithColor(context, [[self badgeBackgroundColor] CGColor]);
        if ([self badgeValue].integerValue > 9) {
            CGFloat circleWith = bkgFrame.size.height;
            CGFloat totalWidth = bkgFrame.size.width;
            CGFloat diffWidth = totalWidth - circleWith;
            CGPoint originPoint = bkgFrame.origin;
            CGRect leftCicleFrame = CGRectMake(originPoint.x, originPoint.y, circleWith, circleWith);
            CGRect centerFrame = CGRectMake(originPoint.x +circleWith/2, originPoint.y, diffWidth, circleWith);
            CGRect rightCicleFrame = CGRectMake(originPoint.x +(totalWidth - circleWith), originPoint.y, circleWith, circleWith);
            CGContextFillEllipseInRect(context, leftCicleFrame);
            CGContextFillRect(context, centerFrame);
            CGContextFillEllipseInRect(context, rightCicleFrame);
        }else{
            CGContextFillEllipseInRect(context, bkgFrame);
        }
    }
    
    CGContextSetFillColorWithColor(context, [[self badgeTextColor] CGColor]);
    NSMutableParagraphStyle *badgeTextStyle = [[NSMutableParagraphStyle defaultParagraphStyle] mutableCopy];
    [badgeTextStyle setLineBreakMode:NSLineBreakByWordWrapping];
    [badgeTextStyle setAlignment:NSTextAlignmentCenter];
    
    
    NSDictionary *badgeTextAttributes = @{
                                          NSFontAttributeName: [self badgeTextFont],
                                          NSForegroundColorAttributeName: [self badgeTextColor],
                                          NSParagraphStyleAttributeName: badgeTextStyle,
                                          };
    [[self badgeValue] drawInRect:CGRectMake(self.whiteCircleWidth + self.badgeLeftPadding,
                                             self.whiteCircleWidth + self.badgeTopPadding,
                                             badgeSize.size.width, badgeSize.size.height)
                   withAttributes:badgeTextAttributes];
}


- (void)drawWithOutContent:(CGRect)rect context:(CGContextRef)context{
    CGRect bodyFrame = self.bounds;
    CGContextSetFillColorWithColor(context, [[UIColor redColor] CGColor]);
    CGContextFillEllipseInRect(context, bodyFrame);
}

@end
