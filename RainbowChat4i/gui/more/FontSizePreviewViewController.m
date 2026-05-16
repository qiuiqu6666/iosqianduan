//telegram @wz662
#import "FontSizePreviewViewController.h"
#import "BasicTool.h"
#import "Default.h"
#import "UIViewController+RBPlainCustomNav.h"
#import "RBChromeNavigationBar.h"

static NSString * const kFontSizeKey = @"APP_FONT_SIZE";
static const NSInteger kFontSizeLevelCount = 5;  // 小、较小、标准、较大、大
static const CGFloat kPreviewBubbleMaxWidthRatio = 0.72f;
static const CGFloat kBubbleCornerRadius = 8.0f;
static const CGFloat kSliderHeight = 44.0f;
static const CGFloat kBottomPadding = 40.0f;
static const NSInteger kRBPreviewBubbleLabelTag = 173031;

@interface FontSizePreviewViewController ()
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *previewContainer;
@property (nonatomic, strong) UIView *bubbleLeft1;
@property (nonatomic, strong) UIView *bubbleLeft2;
@property (nonatomic, strong) UIView *bubbleRight;
@property (nonatomic, strong) UILabel *previewLabelLeft1;
@property (nonatomic, strong) UILabel *previewLabelLeft2;
@property (nonatomic, strong) UILabel *previewLabelRight;
@property (nonatomic, strong) NSLayoutConstraint *bubbleLeft1WidthConstraint;
@property (nonatomic, strong) NSLayoutConstraint *bubbleLeft2WidthConstraint;
@property (nonatomic, strong) NSLayoutConstraint *bubbleRightWidthConstraint;
@property (nonatomic, strong) UISlider *fontSlider;
@property (nonatomic, strong) UILabel *labelLeft;   // 小
@property (nonatomic, strong) UILabel *labelRight; // 大
@property (nonatomic, assign) NSInteger rb_lastAppliedFontIndex;
@end

@implementation FontSizePreviewViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.rb_lastAppliedFontIndex = NSNotFound;
    self.view.backgroundColor = HexColor(0xF5F5F5);
    self.navigationItem.leftBarButtonItem = nil;
    self.navigationItem.rightBarButtonItem = nil;
    self.navigationItem.title = @"";
    [self rb_installPlainCustomNavigationBarWithTitle:@"字体大小"];
    RBChromeNavigationBar *bar = [self rb_plainChromeNavigationBarIfInstalled];
    if (bar) {
        UIButton *done = [UIButton buttonWithType:UIButtonTypeCustom];
        [done setTitle:@"完成" forState:UIControlStateNormal];
        done.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
        [done setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        [done addTarget:self action:@selector(doneTapped) forControlEvents:UIControlEventTouchUpInside];
        [done sizeToFit];
        done.bounds = CGRectMake(0, 0, MAX(44.f, CGRectGetWidth(done.bounds) + 12.f), 44.f);
        [bar attachRightAccessoryView:done];
    }
    [self buildPreviewArea];
    [self buildSliderArea];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self rb_plainCustomNavHostViewWillAppear:animated];
    (void)[BasicTool getAppFontSizeMultiplier]; // 触发旧三档→五档迁移
    NSInteger idx = [[NSUserDefaults standardUserDefaults] integerForKey:kFontSizeKey];
    if (idx < 0 || idx >= kFontSizeLevelCount) idx = 2;
    _fontSlider.value = (float)idx;
    self.rb_lastAppliedFontIndex = idx;
    [self updatePreviewFonts];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    [self rb_updatePreviewBubbleSizingIfNeeded];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self rb_plainCustomNavHostViewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self rb_plainCustomNavHostViewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self rb_plainCustomNavHostViewDidDisappear:animated];
}

- (void)doneTapped {
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)buildPreviewArea {
    _scrollView = [[UIScrollView alloc] init];
    _scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    _scrollView.backgroundColor = HexColor(0xF5F5F5);
    _scrollView.showsVerticalScrollIndicator = NO;
    [self.view addSubview:_scrollView];

    _previewContainer = [[UIView alloc] init];
    _previewContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [_scrollView addSubview:_previewContainer];

    CGFloat bubbleInset = 20.0f;
    CGFloat bubbleGap = 12.0f;

    _bubbleLeft1 = [self bubbleLabelWithText:@"拖动下方的滑块，可设置聊天界面的字体大小" backgroundColor:[UIColor whiteColor] textColor:HexColor(0x333333) alignLeft:YES];
    [_previewContainer addSubview:_bubbleLeft1];

    _bubbleRight = [self bubbleLabelWithText:@"设置字体大小" backgroundColor:HexColor(0x007AFF) textColor:[UIColor whiteColor] alignLeft:NO];
    [_previewContainer addSubview:_bubbleRight];

    _bubbleLeft2 = [self bubbleLabelWithText:@"设置后会改变聊天界面中的字体大小" backgroundColor:[UIColor whiteColor] textColor:HexColor(0x333333) alignLeft:YES];
    [_previewContainer addSubview:_bubbleLeft2];

    [NSLayoutConstraint activateConstraints:@[
        [_scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [_scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_scrollView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-kSliderHeight - kBottomPadding],

        [_previewContainer.topAnchor constraintEqualToAnchor:_scrollView.topAnchor constant:16],
        [_previewContainer.leadingAnchor constraintEqualToAnchor:_scrollView.leadingAnchor],
        [_previewContainer.trailingAnchor constraintEqualToAnchor:_scrollView.trailingAnchor],
        [_previewContainer.widthAnchor constraintEqualToAnchor:_scrollView.widthAnchor],
        [_previewContainer.bottomAnchor constraintEqualToAnchor:_scrollView.bottomAnchor],

        [_bubbleLeft1.topAnchor constraintEqualToAnchor:_previewContainer.topAnchor],
        [_bubbleLeft1.leadingAnchor constraintEqualToAnchor:_previewContainer.leadingAnchor constant:bubbleInset],
        [_bubbleLeft1.widthAnchor constraintLessThanOrEqualToAnchor:_previewContainer.widthAnchor multiplier:kPreviewBubbleMaxWidthRatio],
        [_bubbleLeft1.trailingAnchor constraintLessThanOrEqualToAnchor:_previewContainer.trailingAnchor constant:-bubbleInset],

        [_bubbleRight.topAnchor constraintEqualToAnchor:_bubbleLeft1.bottomAnchor constant:bubbleGap],
        [_bubbleRight.trailingAnchor constraintEqualToAnchor:_previewContainer.trailingAnchor constant:-bubbleInset],
        [_bubbleRight.widthAnchor constraintLessThanOrEqualToAnchor:_previewContainer.widthAnchor multiplier:kPreviewBubbleMaxWidthRatio],
        [_bubbleRight.leadingAnchor constraintGreaterThanOrEqualToAnchor:_previewContainer.leadingAnchor constant:bubbleInset],

        [_bubbleLeft2.topAnchor constraintEqualToAnchor:_bubbleRight.bottomAnchor constant:bubbleGap],
        [_bubbleLeft2.leadingAnchor constraintEqualToAnchor:_previewContainer.leadingAnchor constant:bubbleInset],
        [_bubbleLeft2.widthAnchor constraintLessThanOrEqualToAnchor:_previewContainer.widthAnchor multiplier:kPreviewBubbleMaxWidthRatio],
        [_bubbleLeft2.trailingAnchor constraintLessThanOrEqualToAnchor:_previewContainer.trailingAnchor constant:-bubbleInset],
        [_bubbleLeft2.bottomAnchor constraintEqualToAnchor:_previewContainer.bottomAnchor constant:-16],
    ]];

    self.bubbleLeft1WidthConstraint = [_bubbleLeft1.widthAnchor constraintEqualToConstant:100.0f];
    self.bubbleRightWidthConstraint = [_bubbleRight.widthAnchor constraintEqualToConstant:100.0f];
    self.bubbleLeft2WidthConstraint = [_bubbleLeft2.widthAnchor constraintEqualToConstant:100.0f];
    self.bubbleLeft1WidthConstraint.active = YES;
    self.bubbleRightWidthConstraint.active = YES;
    self.bubbleLeft2WidthConstraint.active = YES;
    
    self.previewLabelLeft1 = (UILabel *)[self.bubbleLeft1 viewWithTag:kRBPreviewBubbleLabelTag];
    self.previewLabelRight = (UILabel *)[self.bubbleRight viewWithTag:kRBPreviewBubbleLabelTag];
    self.previewLabelLeft2 = (UILabel *)[self.bubbleLeft2 viewWithTag:kRBPreviewBubbleLabelTag];
}

- (UIView *)bubbleLabelWithText:(NSString *)text backgroundColor:(UIColor *)bgColor textColor:(UIColor *)textColor alignLeft:(BOOL)alignLeft {
    UIView *wrap = [[UIView alloc] init];
    wrap.translatesAutoresizingMaskIntoConstraints = NO;
    wrap.backgroundColor = bgColor;
    wrap.layer.cornerRadius = kBubbleCornerRadius;
    wrap.clipsToBounds = YES;
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = text;
    label.font = [BasicTool getSystemFontOfSize:16.0f];
    label.textColor = textColor;
    label.numberOfLines = 0;
    // 与聊天气泡一致按字符换行，避免中文+窄宽时 UILabel 少算行高导致预览裁字
    label.lineBreakMode = NSLineBreakByCharWrapping;
    label.textAlignment = alignLeft ? NSTextAlignmentLeft : NSTextAlignmentRight;
    label.tag = kRBPreviewBubbleLabelTag;
    [wrap addSubview:label];
    CGFloat padding = 12.0f;
    [NSLayoutConstraint activateConstraints:@[
        [label.topAnchor constraintEqualToAnchor:wrap.topAnchor constant:padding],
        [label.bottomAnchor constraintEqualToAnchor:wrap.bottomAnchor constant:-padding],
        [label.leadingAnchor constraintEqualToAnchor:wrap.leadingAnchor constant:padding],
        [label.trailingAnchor constraintEqualToAnchor:wrap.trailingAnchor constant:-padding],
    ]];
    return wrap;
}

- (void)buildSliderArea {
    UIView *sliderContainer = [[UIView alloc] init];
    sliderContainer.translatesAutoresizingMaskIntoConstraints = NO;
    sliderContainer.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:sliderContainer];

    _labelLeft = [[UILabel alloc] init];
    _labelLeft.translatesAutoresizingMaskIntoConstraints = NO;
    _labelLeft.text = @"小";
    _labelLeft.font = [UIFont systemFontOfSize:12];
    _labelLeft.textColor = HexColor(0x333333);
    [sliderContainer addSubview:_labelLeft];

    _labelRight = [[UILabel alloc] init];
    _labelRight.translatesAutoresizingMaskIntoConstraints = NO;
    _labelRight.text = @"大";
    _labelRight.font = [UIFont systemFontOfSize:12];
    _labelRight.textColor = HexColor(0x333333);
    [sliderContainer addSubview:_labelRight];

    _fontSlider = [[UISlider alloc] init];
    _fontSlider.translatesAutoresizingMaskIntoConstraints = NO;
    _fontSlider.minimumValue = 0.0f;
    _fontSlider.maximumValue = (float)(kFontSizeLevelCount - 1);
    _fontSlider.value = 2.0f; // 默认标准（第 3 档）
    _fontSlider.continuous = YES;
    [_fontSlider setMinimumTrackTintColor:HexColor(0x007AFF)];
    [_fontSlider setMaximumTrackTintColor:HexColor(0xE5E5EA)];
    [_fontSlider setThumbTintColor:HexColor(0x007AFF)];
    [_fontSlider addTarget:self action:@selector(fontSliderValueChanged:) forControlEvents:UIControlEventValueChanged];
    [sliderContainer addSubview:_fontSlider];

    CGFloat hor = 24.0f;
    [NSLayoutConstraint activateConstraints:@[
        [sliderContainer.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [sliderContainer.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [sliderContainer.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
        [sliderContainer.heightAnchor constraintEqualToConstant:kSliderHeight + kBottomPadding],

        [_fontSlider.leadingAnchor constraintEqualToAnchor:sliderContainer.leadingAnchor constant:hor],
        [_fontSlider.trailingAnchor constraintEqualToAnchor:sliderContainer.trailingAnchor constant:-hor],
        [_fontSlider.topAnchor constraintEqualToAnchor:sliderContainer.topAnchor constant:8],
        [_fontSlider.heightAnchor constraintEqualToConstant:30],

        [_labelLeft.leadingAnchor constraintEqualToAnchor:sliderContainer.leadingAnchor constant:hor],
        [_labelLeft.topAnchor constraintEqualToAnchor:_fontSlider.bottomAnchor constant:4],

        [_labelRight.trailingAnchor constraintEqualToAnchor:sliderContainer.trailingAnchor constant:-hor],
        [_labelRight.topAnchor constraintEqualToAnchor:_fontSlider.bottomAnchor constant:4],
    ]];
}

- (void)fontSliderValueChanged:(UISlider *)slider {
    NSInteger idx = (NSInteger)roundf(slider.value);
    idx = MAX(0, MIN(kFontSizeLevelCount - 1, idx));
    slider.value = (float)idx;
    if (self.rb_lastAppliedFontIndex == idx) {
        return;
    }
    self.rb_lastAppliedFontIndex = idx;
    [[NSUserDefaults standardUserDefaults] setInteger:idx forKey:kFontSizeKey];
    [self updatePreviewFonts];
}

- (void)rb_updatePreviewBubbleSizingIfNeeded
{
    static const CGFloat kPad = 12.0f;
    CGFloat containerW = CGRectGetWidth(self.view.bounds);
    if (containerW <= 1.0f) return;
    CGFloat maxBubbleW = floor(containerW * kPreviewBubbleMaxWidthRatio);
    CGFloat labelMaxW = MAX(1.0f, maxBubbleW - 2.0f * kPad);
    
    void (^applyOne)(UILabel *, NSLayoutConstraint *) = ^(UILabel *label, NSLayoutConstraint *widthC) {
        if (!label || !widthC) return;
        CGSize fit = [label sizeThatFits:CGSizeMake(labelMaxW, CGFLOAT_MAX)];
        CGFloat bubbleW = ceil(MIN(maxBubbleW, fit.width + 2.0f * kPad));
        if (fabs(widthC.constant - bubbleW) > 0.5f) {
            widthC.constant = bubbleW;
        }
        CGFloat prefW = MAX(1.0f, bubbleW - 2.0f * kPad);
        if (fabs(label.preferredMaxLayoutWidth - prefW) > 0.5f) {
            label.preferredMaxLayoutWidth = prefW;
        }
    };
    
    applyOne(self.previewLabelLeft1, self.bubbleLeft1WidthConstraint);
    applyOne(self.previewLabelRight, self.bubbleRightWidthConstraint);
    applyOne(self.previewLabelLeft2, self.bubbleLeft2WidthConstraint);
}

- (void)updatePreviewFonts {
    UIFont *font = [BasicTool getSystemFontOfSize:16.0f];
    self.previewLabelLeft1.font = font;
    self.previewLabelRight.font = font;
    self.previewLabelLeft2.font = font;
    [self rb_updatePreviewBubbleSizingIfNeeded];
    [UIView animateWithDuration:0.15 delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
        [self.previewContainer layoutIfNeeded];
    } completion:nil];
}

@end
