//telegram @wz662
//
//  PuzzleSliderView.m
//  RainbowChat4i
//
//  旋转校正验证：拖动滑块旋转中央图片到正确角度（±tolerance°）完成验证。
//

#import "PuzzleSliderView.h"
#import "Default.h"

static const CGFloat kImageAreaHeight = 110.0f;
static const CGFloat kImageInset = 8.0f;          // 图片与容器边距
static const CGFloat kImageTopInset = 6.0f;       // 图片区顶部留白，圆图靠上
static const CGFloat kSliderTrackHeight = 44.0f;
static const CGFloat kThumbWidth = 44.0f;
static const CGFloat kInset = 20.0f;
static const CGFloat kDefaultToleranceDegrees = 15.0f;
static NSString * const kRotateCaptchaImageNames[] = {
    @"rotate_captcha_1",
    @"rotate_captcha_2",
    @"rotate_captcha_3",
    @"rotate_captcha_4",
    @"rotate_captcha_5",
    @"rotate_captcha_6",
    @"rotate_captcha_7"
};
static const NSUInteger kRotateCaptchaImageCount = sizeof(kRotateCaptchaImageNames) / sizeof(NSString *);

static NSString *RandomRotateCaptchaImageName(void) {
    if (kRotateCaptchaImageCount == 0) return nil;
    u_int32_t idx = arc4random_uniform((u_int32_t)kRotateCaptchaImageCount);
    return kRotateCaptchaImageNames[idx];
}


@interface PuzzleSliderView ()
@property (nonatomic, strong) UIView *imageContainerView;
@property (nonatomic, strong) UIImageView *rotateImageView;
@property (nonatomic, strong) UIView *sliderTrackView;
@property (nonatomic, strong) UIView *sliderThumbView;
@property (nonatomic, strong) UILabel *hintLabel;
@property (nonatomic, assign) CGFloat baseValue;     // 初始随机角度（0..1 对应 0°..360°）
@property (nonatomic, assign) CGFloat targetValue;   // 0..1 对应 0°..360°
@property (nonatomic, assign) CGFloat currentValue;  // 0..1，滑块当前值
@property (nonatomic, assign) BOOL verified;
@end

@implementation PuzzleSliderView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _tolerance = kDefaultToleranceDegrees;
        _verified = NO;
        _currentValue = 0.0f;
        [self setupUI];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = self.bounds.size.width;
    if (w < kInset * 2 + kThumbWidth * 2) return;

    _imageContainerView.frame = CGRectMake(kInset, 0, w - kInset * 2, kImageAreaHeight);
    CGFloat side = MIN(_imageContainerView.bounds.size.width, _imageContainerView.bounds.size.height) - kImageInset * 2;
    side = MAX(side, 88.0f);
    _rotateImageView.bounds = CGRectMake(0, 0, side, side);
    _rotateImageView.center = CGPointMake(_imageContainerView.bounds.size.width / 2.0f, kImageTopInset + side / 2.0f);
    _rotateImageView.layer.cornerRadius = side / 2.0f;
    [self applyRotation];

    CGFloat sliderY = kImageAreaHeight + 6.0f;
    _sliderTrackView.frame = CGRectMake(kInset, sliderY, w - kInset * 2, kSliderTrackHeight);
    _hintLabel.frame = CGRectMake(kInset + kThumbWidth + 8.0f, sliderY, w - kInset * 2 - kThumbWidth - 16.0f, kSliderTrackHeight);
    [self updateThumbPosition];
}

- (void)setupUI {
    _imageContainerView = [[UIView alloc] init];
    _imageContainerView.backgroundColor = [UIColor clearColor];
    _imageContainerView.layer.cornerRadius = 0.0f;
    _imageContainerView.clipsToBounds = NO;
    [self addSubview:_imageContainerView];

    UIImage *img = [UIImage imageNamed:RandomRotateCaptchaImageName()];
    _rotateImageView = [[UIImageView alloc] init];
    _rotateImageView.image = img;
    _rotateImageView.contentMode = UIViewContentModeScaleAspectFill;
    _rotateImageView.layer.cornerRadius = 8.0f;
    _rotateImageView.layer.masksToBounds = YES;
    _rotateImageView.layer.borderWidth = 1.0f;
    _rotateImageView.layer.borderColor = HexColor(0xE0E0E0).CGColor;
    [_imageContainerView addSubview:_rotateImageView];

    _sliderTrackView = [[UIView alloc] init];
    _sliderTrackView.backgroundColor = HexColor(0xE8E8E8);
    _sliderTrackView.layer.cornerRadius = kSliderTrackHeight / 2.0f;
    _sliderTrackView.layer.masksToBounds = YES;
    [self addSubview:_sliderTrackView];

    _sliderThumbView = [[UIView alloc] init];
    _sliderThumbView.backgroundColor = [UIColor whiteColor];
    _sliderThumbView.layer.cornerRadius = 8.0f;
    _sliderThumbView.layer.borderWidth = 1.0f;
    _sliderThumbView.layer.borderColor = HexColor(0xDDDDDD).CGColor;
    _sliderThumbView.layer.shadowColor = [UIColor blackColor].CGColor;
    _sliderThumbView.layer.shadowOffset = CGSizeMake(0, 2);
    _sliderThumbView.layer.shadowOpacity = 0.25f;
    _sliderThumbView.layer.shadowRadius = 3.0f;
    [self addSubview:_sliderThumbView];
    UIImageView *arrowView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 20, 20)];
    arrowView.contentMode = UIViewContentModeCenter;
    arrowView.image = [self arrowImage];
    arrowView.center = CGPointMake(kThumbWidth / 2.0f, kSliderTrackHeight / 2.0f);
    [_sliderThumbView addSubview:arrowView];

    _hintLabel = [[UILabel alloc] init];
    _hintLabel.text = @"拖动滑块旋转图片到正确角度";
    _hintLabel.font = [UIFont systemFontOfSize:14];
    _hintLabel.textColor = HexColor(0x999999);
    [self addSubview:_hintLabel];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(onSliderPan:)];
    [_sliderThumbView addGestureRecognizer:pan];
    _sliderThumbView.userInteractionEnabled = YES;

    [self reset];
}

- (UIImage *)arrowImage {
    CGSize size = CGSizeMake(20, 20);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetStrokeColorWithColor(ctx, HexColor(0x666666).CGColor);
    CGContextSetLineWidth(ctx, 2.0f);
    CGContextSetLineCap(ctx, kCGLineCapRound);
    CGContextMoveToPoint(ctx, 6, 10);
    CGContextAddLineToPoint(ctx, 14, 10);
    CGContextMoveToPoint(ctx, 11, 6);
    CGContextAddLineToPoint(ctx, 14, 10);
    CGContextAddLineToPoint(ctx, 11, 14);
    CGContextStrokePath(ctx);
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

- (void)reset {
    _verified = NO;
    // 目标角度固定为 0°（图片正向），baseValue 为图片初始随机角度，currentValue 为滑块值
    _targetValue = 0.0f;
    _baseValue = (CGFloat)(arc4random_uniform(100)) / 100.0f;
    _currentValue = 0.0f;
    NSString *imgName = RandomRotateCaptchaImageName();
    UIImage *img = [UIImage imageNamed:imgName];
    if (img) {
        _rotateImageView.image = img;
    }
    [self setNeedsLayout];
    [self layoutIfNeeded];
    [self updateThumbPosition];
    [self applyRotation];
}

- (void)applyRotation {
    // 实际角度 = baseValue(初始随机角度) + currentValue(滑块旋转角度)
    CGFloat value = _baseValue + _currentValue;
    value = fmodf(value, 1.0f);
    if (value < 0.0f) value += 1.0f;
    CGFloat angleRad = value * (CGFloat)(2.0 * M_PI);
    _rotateImageView.transform = CGAffineTransformMakeRotation(angleRad);
}

- (void)updateThumbPosition {
    CGFloat trackW = _sliderTrackView.bounds.size.width;
    CGFloat thumbX = _currentValue * (trackW - kThumbWidth);
    _sliderThumbView.frame = CGRectMake(_sliderTrackView.frame.origin.x + thumbX,
                                        _sliderTrackView.frame.origin.y + (kSliderTrackHeight - kThumbWidth) / 2.0f,
                                        kThumbWidth, kThumbWidth);
}

/// 将 baseValue+currentValue 映射到 0..360°，计算与 target 的最小角度差（考虑 360° 环绕）
- (CGFloat)angleDifferenceDegreesFromCurrent {
    CGFloat value = _baseValue + _currentValue;
    value = fmodf(value, 1.0f);
    if (value < 0.0f) value += 1.0f;
    CGFloat curDeg = value * 360.0f;
    CGFloat tarDeg = _targetValue * 360.0f;
    CGFloat diff = (CGFloat)fabs((double)(curDeg - tarDeg));
    if (diff > 180.0f) diff = 360.0f - diff;
    return diff;
}

- (void)onSliderPan:(UIPanGestureRecognizer *)gesture {
    if (_verified) return;
    CGFloat trackW = _sliderTrackView.bounds.size.width;
    CGFloat trackX = _sliderTrackView.frame.origin.x;
    CGFloat minThumbX = trackX;
    CGFloat maxThumbX = trackX + trackW - kThumbWidth;

    if (gesture.state == UIGestureRecognizerStateChanged) {
        CGPoint translation = [gesture translationInView:self];
        CGRect f = _sliderThumbView.frame;
        CGFloat newX = f.origin.x + translation.x;
        newX = MAX(minThumbX, MIN(maxThumbX, newX));
        _sliderThumbView.frame = CGRectMake(newX, f.origin.y, f.size.width, f.size.height);
        [gesture setTranslation:CGPointZero inView:self];
        _currentValue = (newX - minThumbX) / (trackW - kThumbWidth);
        [self applyRotation];
    } else if (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled) {
        CGFloat diffDeg = [self angleDifferenceDegreesFromCurrent];
        if (diffDeg <= _tolerance) {
            _verified = YES;
            [self.delegate puzzleSliderViewDidVerifySuccess:self];
        } else {
            _currentValue = 0.0f;
            [UIView animateWithDuration:0.2 animations:^{
                [self updateThumbPosition];
                [self applyRotation];
            }];
            [self.delegate puzzleSliderViewDidVerifyFail:self];
        }
    }
}

@end
