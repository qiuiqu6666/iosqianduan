//telegram @wz662
//
//  PuzzleSliderCaptchaViewController.m
//

#import "PuzzleSliderCaptchaViewController.h"
#import "PuzzleSliderView.h"
#import "Default.h"

@interface PuzzleSliderCaptchaViewController () <PuzzleSliderViewDelegate>
@property (nonatomic, strong) UIView *contentView;
/// 顶部小灰字：安全验证
@property (nonatomic, strong) UILabel *titleLabel;
/// 主提示文案：向右拖动下方滑块完成验证
@property (nonatomic, strong) UILabel *messageLabel;
@property (nonatomic, strong) PuzzleSliderView *puzzleView;
@property (nonatomic, strong) UIButton *closeButton;
@end

@implementation PuzzleSliderCaptchaViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
    [self setupUI];
}

- (void)setupUI {
    CGFloat width = 360.0f;
    // 较紧凑的弹窗高度
    CGFloat contentHeight = 250.0f;
    _contentView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, contentHeight)];
    _contentView.backgroundColor = [UIColor whiteColor];
    _contentView.layer.cornerRadius = 12.0f;
    _contentView.clipsToBounds = YES;
    _contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_contentView];

    _titleLabel = [[UILabel alloc] init];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.text = @"安全验证";
    _titleLabel.font = [UIFont systemFontOfSize:12];
    _titleLabel.textColor = HexColor(0x999999);
    _titleLabel.textAlignment = NSTextAlignmentCenter;
    [_contentView addSubview:_titleLabel];

    _messageLabel = [[UILabel alloc] init];
    _messageLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _messageLabel.text = @"向右拖动下方滑块完成验证";
    _messageLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    _messageLabel.textColor = HexColor(0x333333);
    _messageLabel.textAlignment = NSTextAlignmentCenter;
    _messageLabel.numberOfLines = 2;
    [_contentView addSubview:_messageLabel];

    _closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _closeButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_closeButton setImage:[self closeIconImage] forState:UIControlStateNormal];
    _closeButton.tintColor = HexColor(0x999999);
    [_closeButton addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
    [_contentView addSubview:_closeButton];

    _puzzleView = [[PuzzleSliderView alloc] init];
    _puzzleView.translatesAutoresizingMaskIntoConstraints = NO;
    _puzzleView.delegate = self;
    [_contentView addSubview:_puzzleView];

    [NSLayoutConstraint activateConstraints:@[
        [_contentView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_contentView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [_contentView.widthAnchor constraintEqualToConstant:width],
        [_contentView.heightAnchor constraintEqualToConstant:contentHeight],

        [_titleLabel.topAnchor constraintEqualToAnchor:_contentView.topAnchor constant:20],
        [_titleLabel.centerXAnchor constraintEqualToAnchor:_contentView.centerXAnchor],

        [_messageLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:8],
        [_messageLabel.leadingAnchor constraintEqualToAnchor:_contentView.leadingAnchor constant:20],
        [_messageLabel.trailingAnchor constraintEqualToAnchor:_contentView.trailingAnchor constant:-20],

        [_closeButton.topAnchor constraintEqualToAnchor:_contentView.topAnchor constant:12],
        [_closeButton.trailingAnchor constraintEqualToAnchor:_contentView.trailingAnchor constant:-12],
        [_closeButton.widthAnchor constraintEqualToConstant:36],
        [_closeButton.heightAnchor constraintEqualToConstant:36],

        [_puzzleView.topAnchor constraintEqualToAnchor:_messageLabel.bottomAnchor constant:6],
        [_puzzleView.leadingAnchor constraintEqualToAnchor:_contentView.leadingAnchor constant:20],
        [_puzzleView.trailingAnchor constraintEqualToAnchor:_contentView.trailingAnchor constant:-20],
        [_puzzleView.heightAnchor constraintEqualToConstant:160],
    ]];
}

- (UIImage *)closeIconImage {
    CGSize size = CGSizeMake(24, 24);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetStrokeColorWithColor(ctx, [UIColor blackColor].CGColor);
    CGContextSetLineWidth(ctx, 2.0f);
    CGContextSetLineCap(ctx, kCGLineCapRound);
    CGContextMoveToPoint(ctx, 6, 6);
    CGContextAddLineToPoint(ctx, 18, 18);
    CGContextMoveToPoint(ctx, 18, 6);
    CGContextAddLineToPoint(ctx, 6, 18);
    CGContextStrokePath(ctx);
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

- (void)closeTapped {
    if (self.onCancel) self.onCancel();
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)puzzleSliderViewDidVerifySuccess:(PuzzleSliderView *)view {
    if (self.onVerifySuccess) self.onVerifySuccess();
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)puzzleSliderViewDidVerifyFail:(PuzzleSliderView *)view {
    [view reset];
}

@end
