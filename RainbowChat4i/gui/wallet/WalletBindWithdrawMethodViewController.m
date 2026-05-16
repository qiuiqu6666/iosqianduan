#import "WalletBindWithdrawMethodViewController.h"
#import "HttpRestHelper.h"
#import "BasicTool.h"
#import "Default.h"
#import "Masonry.h"
#import "RBImagePickerWrapper.h"
#import "SendImageHelper.h"
#import "FileUploadHelper.h"
#import "IMClientManager.h"
#import "FileTool.h"
#import "ToolKits.h"
#import "MBProgressHUD.h"
#import "UIImageView+WebCache.h"

static const CGFloat kBindPadding = 16.f;
static const CGFloat kBindCardInner = 16.f;
static const CGFloat kBindRowHeight = 52.f;
static const CGFloat kBindLabelHeight = 20.f;
static const CGFloat kBindLabelFieldGap = 8.f;
static const CGFloat kBindSeparatorHeight = 0.5f;
static const CGFloat kBindSpacing = 20.f;
static const CGFloat kBindBeforeSubmitSpacing = 28.f;  // 收款码/表单与提交按钮之间的间距
static const CGFloat kBindBottomInset = 24.f;         // 提交按钮下方留白
static const CGFloat kBindSubmitHeight = 50.f;
static const CGFloat kBindQrAreaHeight = 140.f;
static const CGFloat kBindQrImageSize = 120.f;
static const NSInteger kBindGreen = 0x07C160;
static const NSInteger kBindBlue = 0x007AFF;       // 主按钮蓝（参考支付方式页）
static const NSInteger kBindBorderGray = 0xE5E5E5;
static const CGFloat kBindTypeSegmentGap = 8.f;
static const CGFloat kBindFieldCorner = 10.f;

@interface WalletBindWithdrawMethodViewController () <UIScrollViewDelegate, UITextFieldDelegate, RBImagePickerCompleteDelegate>
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIView *typeCard;
@property (nonatomic, strong) NSArray<UIButton *> *segmentButtons;
@property (nonatomic, strong) UIView *qrCodeCard;
@property (nonatomic, strong) UITextField *accountNameField;
@property (nonatomic, strong) UITextField *accountNumberField;
@property (nonatomic, strong) UITextField *qrCodeUrlField;
@property (nonatomic, strong) UIImageView *qrCodeImageView;
@property (nonatomic, strong) UIButton *qrCodeChangeButton;
@property (nonatomic, strong) UITextField *bankNameField;
@property (nonatomic, strong) UILabel *qrCodeHintLabel;
@property (nonatomic, strong) UILabel *bankNameHintLabel;
@property (nonatomic, strong) UIButton *uploadQrButton;
@property (nonatomic, strong) UIButton *submitButton;
@property (nonatomic, assign) NSInteger selectedMethodType;
@property (nonatomic, assign) BOOL uiBuilt;
@property (nonatomic, strong) RBImagePickerWrapper *imagePickerWrapper;
@end

@implementation WalletBindWithdrawMethodViewController

#pragma mark - Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];

    if (_methodToEdit && [_methodToEdit isKindOfClass:[NSDictionary class]]) {
        self.navigationItem.title = @"编辑提款方式";
        NSNumber *mt = _methodToEdit[@"method_type"];
        _selectedMethodType = mt ? [mt integerValue] : 0;
    } else {
        self.navigationItem.title = @"添加付款方式";
        _selectedMethodType = 1; /* 默认微信，可选支付宝/银行卡 */
    }

    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"取消" style:UIBarButtonItemStylePlain target:self action:@selector(onCancel)];

    [self buildUI];

    [_accountNameField addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    [_accountNumberField addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    [_bankNameField addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];

    if (_methodToEdit && [_methodToEdit isKindOfClass:[NSDictionary class]]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self fillFormWithMethod:self.methodToEdit];
        });
    }

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
    tap.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:tap];
}

#pragma mark - UI Build

- (void)buildUI
{
    if (_uiBuilt) return;
    _uiBuilt = YES;

    _scrollView = [[UIScrollView alloc] init];
    _scrollView.delegate = self;
    _scrollView.backgroundColor = [UIColor whiteColor];
    _scrollView.showsVerticalScrollIndicator = NO;
    _scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    [self.view addSubview:_scrollView];
    [_scrollView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];

    _contentView = [[UIView alloc] init];
    [_scrollView addSubview:_contentView];

    _titleLabel = [[UILabel alloc] init];
    _titleLabel.font = [UIFont systemFontOfSize:22 weight:UIFontWeightBold];
    _titleLabel.textColor = HexColor(0x000000);
    _titleLabel.text = (_methodToEdit && [_methodToEdit isKindOfClass:[NSDictionary class]]) ? @"编辑提款方式" : @"添加付款方式";
    [_contentView addSubview:_titleLabel];

    _subtitleLabel = [[UILabel alloc] init];
    _subtitleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightRegular];
    _subtitleLabel.textColor = HexColor(0x8E8E93);
    _subtitleLabel.text = @"请填写与平台实名一致的信息";
    [_contentView addSubview:_subtitleLabel];

    _typeCard = [[UIView alloc] init];
    _typeCard.backgroundColor = [UIColor clearColor];
    [_contentView addSubview:_typeCard];
    NSArray *segmentTitles = @[@"微信", @"支付宝", @"银行卡"];
    NSArray *segmentImageNames = @[@"bind_wechat", @"bind_alipay", @"bind_bankcard"];
    NSMutableArray *btns = [NSMutableArray arrayWithCapacity:3];
    for (NSInteger i = 0; i < 3; i++) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        [btn setTitle:segmentTitles[i] forState:UIControlStateNormal];
        [btn setTitleColor:HexColor(0x6B7280) forState:UIControlStateNormal];
        [btn setTitleColor:HexColor(kBindBlue) forState:UIControlStateSelected];
        btn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
        btn.tag = 1 + i;
        UIImage *icon = [UIImage imageNamed:segmentImageNames[i]];
        if (icon) {
            icon = [icon imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
            [btn setImage:icon forState:UIControlStateNormal];
            [btn setImage:icon forState:UIControlStateSelected];
            btn.imageView.contentMode = UIViewContentModeScaleAspectFit;
            btn.imageEdgeInsets = UIEdgeInsetsMake(0, 0, 0, 6);
            btn.titleEdgeInsets = UIEdgeInsetsMake(0, 6, 0, 0);
        }
        [btn addTarget:self action:@selector(onSegmentTapped:) forControlEvents:UIControlEventTouchUpInside];
        [_typeCard addSubview:btn];
        [btns addObject:btn];
    }
    _segmentButtons = [btns copy];

    UILabel *nameLabel = [self createLabelWithText:@"姓名"];
    nameLabel.tag = 1001;
    [_contentView addSubview:nameLabel];

    _accountNameField = [self createTextFieldWithPlaceholder:@"真实姓名"];
    _accountNameField.tag = 1002;
    _accountNameField.autocapitalizationType = UITextAutocapitalizationTypeWords;
    [_contentView addSubview:_accountNameField];

    UIView *separator1 = [self createSeparator];
    separator1.tag = 1003;
    [_contentView addSubview:separator1];

    UILabel *numberLabel = [self createLabelWithText:@"账号"];
    numberLabel.tag = 1004;
    [_contentView addSubview:numberLabel];

    _accountNumberField = [self createTextFieldWithPlaceholder:@"微信号/手机号"];
    _accountNumberField.tag = 1005;
    _accountNumberField.autocorrectionType = UITextAutocorrectionTypeNo;
    _accountNumberField.spellCheckingType = UITextSpellCheckingTypeNo;
    [_contentView addSubview:_accountNumberField];

    UIView *separator2 = [self createSeparator];
    separator2.tag = 1006;
    [_contentView addSubview:separator2];

    _bankNameHintLabel = [self createLabelWithText:@"开户行"];
    _bankNameHintLabel.tag = 1010;
    [_contentView addSubview:_bankNameHintLabel];

    _bankNameField = [self createTextFieldWithPlaceholder:@"如：中国工商银行北京分行"];
    _bankNameField.tag = 1011;
    _bankNameField.autocorrectionType = UITextAutocorrectionTypeNo;
    [_contentView addSubview:_bankNameField];

    _qrCodeCard = [self bind_addCardView];
    [_contentView addSubview:_qrCodeCard];

    _qrCodeHintLabel = [self createLabelWithText:@"收款码"];
    _qrCodeHintLabel.textColor = HexColor(0x000000);
    _qrCodeHintLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightRegular];
    _qrCodeHintLabel.tag = 1007;
    [_qrCodeCard addSubview:_qrCodeHintLabel];

    _qrCodeUrlField = [self createTextFieldWithPlaceholder:@"选填或上传后自动填充"];
    _qrCodeUrlField.keyboardType = UIKeyboardTypeURL;
    _qrCodeUrlField.autocorrectionType = UITextAutocorrectionTypeNo;
    _qrCodeUrlField.tag = 1008;
    _qrCodeUrlField.hidden = YES;
    [_qrCodeCard addSubview:_qrCodeUrlField];

    _qrCodeImageView = [[UIImageView alloc] init];
    _qrCodeImageView.contentMode = UIViewContentModeScaleAspectFit;
    _qrCodeImageView.backgroundColor = HexColor(0xF5F5F5);
    _qrCodeImageView.layer.cornerRadius = 6;
    _qrCodeImageView.clipsToBounds = YES;
    _qrCodeImageView.hidden = YES;
    [_qrCodeCard addSubview:_qrCodeImageView];

    _qrCodeChangeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [_qrCodeChangeButton setTitle:@"更换" forState:UIControlStateNormal];
    [_qrCodeChangeButton setTitleColor:HexColor(kBindBlue) forState:UIControlStateNormal];
    _qrCodeChangeButton.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightRegular];
    [_qrCodeChangeButton addTarget:self action:@selector(onUploadQrTapped) forControlEvents:UIControlEventTouchUpInside];
    _qrCodeChangeButton.hidden = YES;
    [_qrCodeCard addSubview:_qrCodeChangeButton];

    _uploadQrButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [_uploadQrButton setTitle:@"上传二维码图片" forState:UIControlStateNormal];
    [_uploadQrButton setTitleColor:HexColor(kBindBlue) forState:UIControlStateNormal];
    _uploadQrButton.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightRegular];
    _uploadQrButton.tag = 1008 + 100;
    [_uploadQrButton addTarget:self action:@selector(onUploadQrTapped) forControlEvents:UIControlEventTouchUpInside];
    [_qrCodeCard addSubview:_uploadQrButton];

    _submitButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [_submitButton setTitle:(_methodToEdit && [_methodToEdit isKindOfClass:[NSDictionary class]]) ? @"完成" : @"添加" forState:UIControlStateNormal];
    [_submitButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _submitButton.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    _submitButton.backgroundColor = HexColor(kBindBlue);
    _submitButton.layer.cornerRadius = 12.f;
    _submitButton.clipsToBounds = YES;
    _submitButton.enabled = NO;
    _submitButton.alpha = 0.5;
    [_submitButton addTarget:self action:@selector(onSubmit) forControlEvents:UIControlEventTouchUpInside];
    [_contentView addSubview:_submitButton];

    [self updateSegmentAppearance];
    [self updateFormVisibility];
}

#pragma mark - Form

- (void)updateSegmentAppearance
{
    for (UIButton *btn in _segmentButtons) {
        btn.selected = (_selectedMethodType == (NSInteger)btn.tag);
    }
    if (_accountNumberField) {
        if (_selectedMethodType == 1) {
            _accountNumberField.placeholder = @"微信号/手机号";
            _accountNumberField.keyboardType = UIKeyboardTypeDefault;
        } else if (_selectedMethodType == 2) {
            _accountNumberField.placeholder = @"支付宝账号/手机号";
            _accountNumberField.keyboardType = UIKeyboardTypeDefault;
        } else {
            _accountNumberField.placeholder = @"银行卡号，16-19位数字";
            _accountNumberField.keyboardType = UIKeyboardTypeNumberPad;
        }
    }
    [self.view setNeedsLayout];
}

#pragma mark - UI Helpers

- (UIView *)bind_addCardView
{
    UIView *card = [[UIView alloc] init];
    card.backgroundColor = [UIColor whiteColor];
    card.layer.cornerRadius = 10;
    card.layer.masksToBounds = YES;
    return card;
}

- (UILabel *)createLabelWithText:(NSString *)text
{
    UILabel *label = [[UILabel alloc] init];
    label.text = text;
    label.font = [UIFont systemFontOfSize:16 weight:UIFontWeightRegular];
    label.textColor = HexColor(0x333333);
    return label;
}

- (UITextField *)createTextFieldWithPlaceholder:(NSString *)placeholder
{
    UITextField *field = [[UITextField alloc] init];
    field.placeholder = placeholder;
    field.font = [UIFont systemFontOfSize:17 weight:UIFontWeightRegular];
    field.textColor = HexColor(0x000000);
    field.backgroundColor = [UIColor clearColor];
    field.textAlignment = NSTextAlignmentLeft;
    field.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    field.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 0)];
    field.leftViewMode = UITextFieldViewModeAlways;
    field.rightView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 0)];
    field.rightViewMode = UITextFieldViewModeAlways;
    field.clearButtonMode = UITextFieldViewModeWhileEditing;
    field.delegate = self;
    field.returnKeyType = UIReturnKeyDone;
    field.tintColor = HexColor(kBindBlue);
    field.backgroundColor = [UIColor clearColor];
    field.layer.cornerRadius = kBindFieldCorner;
    field.layer.borderWidth = 0.5f;
    field.layer.borderColor = HexColor(kBindBorderGray).CGColor;
    if (@available(iOS 13.0, *)) {
        NSMutableParagraphStyle *ps = [[NSMutableParagraphStyle alloc] init];
        ps.alignment = NSTextAlignmentLeft;
        field.attributedPlaceholder = [[NSAttributedString alloc] initWithString:placeholder attributes:@{ NSForegroundColorAttributeName: HexColor(0xADB5BD), NSParagraphStyleAttributeName: ps }];
    }
    [field addTarget:self action:@selector(textFieldDidBeginEditing:) forControlEvents:UIControlEventEditingDidBegin];
    [field addTarget:self action:@selector(textFieldDidEndEditing:) forControlEvents:UIControlEventEditingDidEnd];
    return field;
}

- (UIView *)createSeparator
{
    UIView *separator = [[UIView alloc] init];
    separator.backgroundColor = HexColor(0xC6C6C8);
    return separator;
}

#pragma mark - Layout

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    if (!_uiBuilt || !_scrollView || !_contentView || !_typeCard || !_qrCodeCard) return;
    if (self.view.bounds.size.width == 0 || self.view.bounds.size.height == 0) return;

    CGFloat safeBottom = 0;
    if (@available(iOS 11.0, *)) {
        safeBottom = self.view.safeAreaInsets.bottom;
    }
    CGFloat viewWidth = ScreenWidth;
    CGFloat formCardWidth = viewWidth - kBindPadding * 2;

    _scrollView.frame = CGRectMake(0, 0, viewWidth, self.view.bounds.size.height);
    _contentView.frame = CGRectMake(0, 0, viewWidth, 0);

    CGFloat currentY = kBindPadding;

    _titleLabel.frame = CGRectMake(kBindPadding, currentY, formCardWidth, 28);
    currentY += 28 + 6;
    _subtitleLabel.frame = CGRectMake(kBindPadding, currentY, formCardWidth, 20);
    currentY += 20 + kBindSpacing;

    CGFloat typeCardW = formCardWidth;
    CGFloat typeCardH = 48.f;
    CGFloat segW = (typeCardW - kBindTypeSegmentGap * 2) / 3.f;
    _typeCard.frame = CGRectMake(kBindPadding, currentY, typeCardW, typeCardH);
    for (NSInteger i = 0; i < _segmentButtons.count; i++) {
        UIButton *btn = _segmentButtons[i];
        btn.frame = CGRectMake(i * (segW + kBindTypeSegmentGap), 0, segW, typeCardH);
    }
    currentY += typeCardH + kBindSpacing;

    CGFloat formTop = currentY;
    CGFloat contentW = formCardWidth;
    CGFloat formX = kBindPadding;
    CGFloat rowY = 0;
    CGFloat rowSpacing = 18.f;

    UILabel *nameLabel = (UILabel *)[_contentView viewWithTag:1001];
    if (nameLabel) nameLabel.frame = CGRectMake(formX, formTop + rowY, contentW, kBindLabelHeight);
    UITextField *nameField = (UITextField *)[_contentView viewWithTag:1002];
    if (nameField) nameField.frame = CGRectMake(formX, formTop + rowY + kBindLabelHeight + kBindLabelFieldGap, contentW, kBindRowHeight);
    UIView *sep1 = (UIView *)[_contentView viewWithTag:1003];
    if (sep1) { sep1.frame = CGRectZero; sep1.hidden = YES; }
    rowY += kBindLabelHeight + kBindLabelFieldGap + kBindRowHeight + rowSpacing;

    UILabel *numberLabel = (UILabel *)[_contentView viewWithTag:1004];
    if (numberLabel) numberLabel.frame = CGRectMake(formX, formTop + rowY, contentW, kBindLabelHeight);
    UITextField *numberField = (UITextField *)[_contentView viewWithTag:1005];
    if (numberField) numberField.frame = CGRectMake(formX, formTop + rowY + kBindLabelHeight + kBindLabelFieldGap, contentW, kBindRowHeight);
    UIView *sep2 = (UIView *)[_contentView viewWithTag:1006];
    if (sep2) { sep2.frame = CGRectZero; sep2.hidden = YES; }
    rowY += kBindLabelHeight + kBindLabelFieldGap + kBindRowHeight + rowSpacing;

    if (_selectedMethodType == 1 || _selectedMethodType == 2) {
        if (_qrCodeHintLabel) _qrCodeHintLabel.hidden = NO;
        if (_qrCodeUrlField) _qrCodeUrlField.hidden = NO;
        if (_qrCodeImageView) _qrCodeImageView.hidden = (_qrCodeUrlField.text.length == 0);
        if (_qrCodeChangeButton) _qrCodeChangeButton.hidden = (_qrCodeUrlField.text.length == 0);
        if (_uploadQrButton) _uploadQrButton.hidden = (_qrCodeUrlField.text.length > 0);
        if (_bankNameHintLabel) _bankNameHintLabel.hidden = YES;
        if (_bankNameField) _bankNameField.hidden = YES;
    } else {
        if (_qrCodeHintLabel) _qrCodeHintLabel.hidden = YES;
        if (_qrCodeUrlField) _qrCodeUrlField.hidden = YES;
        if (_qrCodeImageView) _qrCodeImageView.hidden = YES;
        if (_qrCodeChangeButton) _qrCodeChangeButton.hidden = YES;
        if (_uploadQrButton) _uploadQrButton.hidden = YES;
        if (_bankNameHintLabel) {
            _bankNameHintLabel.frame = CGRectMake(formX, formTop + rowY, contentW, kBindLabelHeight);
            _bankNameHintLabel.hidden = NO;
        }
        if (_bankNameField) {
            _bankNameField.frame = CGRectMake(formX, formTop + rowY + kBindLabelHeight + kBindLabelFieldGap, contentW, kBindRowHeight);
            _bankNameField.hidden = NO;
        }
        rowY += kBindLabelHeight + kBindLabelFieldGap + kBindRowHeight;
    }

    currentY = formTop + rowY + (_selectedMethodType == 1 || _selectedMethodType == 2 ? kBindSpacing : kBindBeforeSubmitSpacing);

    if (_selectedMethodType == 1 || _selectedMethodType == 2) {
        _qrCodeCard.hidden = NO;
        CGFloat cardInner = kBindCardInner;
        CGFloat titleH = 20.f;
        CGFloat topPad = 16.f;
        _qrCodeHintLabel.frame = CGRectMake(cardInner, topPad, contentW, titleH);
        CGFloat areaTop = topPad + titleH + 12.f;
        BOOL hasQr = _qrCodeUrlField.text.length > 0;
        if (hasQr) {
            CGFloat cx = formCardWidth / 2.f;
            _qrCodeImageView.frame = CGRectMake(cx - kBindQrImageSize / 2.f, areaTop + (kBindQrAreaHeight - kBindQrImageSize) / 2.f - 20.f, kBindQrImageSize, kBindQrImageSize);
            _qrCodeChangeButton.frame = CGRectMake(cx - 44.f / 2.f, areaTop + (kBindQrAreaHeight - kBindQrImageSize) / 2.f + kBindQrImageSize, 44.f, 36.f);
        } else {
            _uploadQrButton.frame = CGRectMake(cardInner, areaTop, contentW, kBindQrAreaHeight);
        }
        _qrCodeUrlField.frame = CGRectZero;
        CGFloat qrCardH = areaTop + kBindQrAreaHeight + 16.f;
        _qrCodeCard.frame = CGRectMake(kBindPadding, currentY, formCardWidth, qrCardH);
        currentY = CGRectGetMaxY(_qrCodeCard.frame) + kBindBeforeSubmitSpacing;
    } else {
        _qrCodeCard.hidden = YES;
    }

    if (_submitButton) {
        _submitButton.frame = CGRectMake(kBindPadding, currentY, formCardWidth, kBindSubmitHeight);
        currentY = CGRectGetMaxY(_submitButton.frame) + kBindBottomInset + safeBottom;
    }

    _contentView.frame = CGRectMake(0, 0, viewWidth, currentY);
    _scrollView.contentSize = CGSizeMake(viewWidth, currentY);

    NSArray *allFields = @[ _accountNameField, _accountNumberField, _qrCodeUrlField, _bankNameField ];
    for (UITextField *f in allFields) {
        if (!f || !f.superview) continue;
        UIView *line = [f viewWithTag:9000];
        if (line) line.frame = CGRectMake(0, f.bounds.size.height - 1, f.bounds.size.width, 1);
    }
}

- (void)onSegmentTapped:(UIButton *)sender
{
    NSInteger type = (NSInteger)sender.tag;
    if (type < 1 || type > 3) return;
    _selectedMethodType = type;
    [self updateSegmentAppearance];
    [self updateFormVisibility];
}

- (void)updateFormVisibility
{
    if (!self.isViewLoaded || !self.view) return;
    
    // 使用setNeedsLayout而不是立即layoutIfNeeded，避免在viewDidLoad中调用时出现问题
    [self.view setNeedsLayout];
    
    // 延迟更新按钮状态，确保布局完成
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateSubmitButtonState];
    });
}

#pragma mark - Actions

- (void)onUploadQrTapped
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    __weak typeof(self) wself = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"拍照" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [wself presentImagePickerWithSource:YES];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"从相册选择" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [wself presentImagePickerWithSource:NO];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad && alert.popoverPresentationController) {
        alert.popoverPresentationController.sourceView = _uploadQrButton;
        alert.popoverPresentationController.sourceRect = _uploadQrButton.bounds;
    }
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)presentImagePickerWithSource:(BOOL)useCamera
{
    if (!_imagePickerWrapper) {
        _imagePickerWrapper = [[RBImagePickerWrapper alloc] initWithParent:self delegate:self crop:NO];
    }
    if (useCamera) {
        [_imagePickerWrapper takePhoto];
    } else {
        [_imagePickerWrapper takeAlbum:NO];
    }
}

- (void)processImagePickerComplete:(UIImage *)photo withTag:(NSString *)tag
{
    if (!photo) return;
    NSString *uid = [IMClientManager sharedInstance].localUserInfo.user_uid;
    if (!uid || uid.length == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [BasicTool showAlertInfo:@"请先登录" parent:self];
        });
        return;
    }
    NSString *fileName = [SendImageHelper preparedImageForUpload:photo forPhoto:NO];
    if (!fileName || fileName.length == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [BasicTool showAlertInfo:@"图片处理失败，请重试" parent:self];
        });
        return;
    }
    __weak typeof(self) wself = self;
    [SendImageHelper processImageUpload:fileName
                                forPhoto:NO
                              processing:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:wself.view animated:YES];
            hud.label.text = @"上传中...";
        });
    } processFaild:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [MBProgressHUD hideHUDForView:wself.view animated:YES];
            [BasicTool showAlertInfo:@"上传失败，请检查网络后重试" parent:wself];
        });
    } processOk:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [MBProgressHUD hideHUDForView:wself.view animated:YES];
            NSString *url = [SendImageHelper getImageDownloadURL:fileName dump:NO];
            if (url.length > 0 && wself.qrCodeUrlField) {
                wself.qrCodeUrlField.text = url;
                wself.qrCodeImageView.image = photo;
                [wself updateSubmitButtonState];
                [wself.view setNeedsLayout];
            }
        });
    }];
}

- (void)fillFormWithMethod:(NSDictionary *)method
{
    if (!method || ![method isKindOfClass:[NSDictionary class]] || !_uiBuilt) return;

    if (_accountNameField) {
        _accountNameField.text = method[@"account_name"] ?: @"";
    }
    if (_accountNumberField) {
        _accountNumberField.text = method[@"account_number"] ?: @"";
    }
    if (_qrCodeUrlField) {
        _qrCodeUrlField.text = method[@"qr_code_url"] ?: @"";
        if (_qrCodeUrlField.text.length > 0 && _qrCodeImageView) {
            NSString *urlStr = [_qrCodeUrlField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (urlStr.length > 0) {
                [_qrCodeImageView sd_setImageWithURL:[NSURL URLWithString:urlStr] placeholderImage:nil];
            }
        }
    }
    if (_bankNameField) {
        _bankNameField.text = method[@"bank_name"] ?: @"";
    }
    [self updateSegmentAppearance];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateFormVisibility];
    });
}

- (void)textFieldDidChange:(UITextField *)sender
{
    [self updateSubmitButtonState];
}

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    UIView *line = [textField viewWithTag:9000];
    if (line) line.hidden = YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    UIView *line = [textField viewWithTag:9000];
    if (line) line.hidden = YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    if (textField == _accountNumberField && _selectedMethodType == 3) {
        NSCharacterSet *digitSet = [NSCharacterSet decimalDigitCharacterSet];
        NSCharacterSet *inputSet = [NSCharacterSet characterSetWithCharactersInString:string];
        if (![digitSet isSupersetOfSet:inputSet]) return NO;
        NSString *newText = [textField.text stringByReplacingCharactersInRange:range withString:string];
        return newText.length <= 19;
    }
    return YES;
}

- (BOOL)isBankCardNumberValid:(NSString *)cardNumber
{
    if (!cardNumber || cardNumber.length == 0) return NO;
    NSCharacterSet *digitSet = [NSCharacterSet decimalDigitCharacterSet];
    NSCharacterSet *cardSet = [NSCharacterSet characterSetWithCharactersInString:cardNumber];
    if (![digitSet isSupersetOfSet:cardSet]) return NO;
    NSUInteger len = cardNumber.length;
    return len >= 16 && len <= 19;
}

- (void)updateSubmitButtonState
{
    if (!_submitButton) return;
    
    BOOL isValid = YES;
    
    // 账户姓名和账户号码必填
    if (_accountNameField && _accountNumberField) {
        NSString *accountName = [_accountNameField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSString *accountNumber = [_accountNumberField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (accountName.length == 0 || accountNumber.length == 0) {
            isValid = NO;
        }
        if (_selectedMethodType == 3) {
            if (accountNumber.length > 0 && ![self isBankCardNumberValid:accountNumber]) isValid = NO;
            if (_bankNameField) {
                NSString *bankName = [_bankNameField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                if (bankName.length == 0) isValid = NO;
            }
        }
    } else {
        isValid = NO;
    }
    
    _submitButton.enabled = isValid;
    _submitButton.alpha = isValid ? 1.0 : 0.5;
}

- (void)onSubmit
{
    if (!_submitButton || !_submitButton.enabled) return;
    
    if (!_accountNameField || !_accountNumberField) {
        [BasicTool showAlertInfo:@"表单未初始化完成" parent:self];
        return;
    }
    
    NSString *accountName = [_accountNameField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *accountNumber = [_accountNumberField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *qrCodeUrl = _qrCodeUrlField ? [_qrCodeUrlField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] : @"";
    NSString *bankName = _bankNameField ? [_bankNameField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] : @"";
    
    if (accountName.length == 0 || accountNumber.length == 0) {
        [BasicTool showAlertInfo:@"请填写账户姓名和账号" parent:self];
        return;
    }
    if (_selectedMethodType == 3) {
        if (![self isBankCardNumberValid:accountNumber]) {
            [BasicTool showAlertInfo:@"请输入16-19位银行卡号" parent:self];
            return;
        }
        if (bankName.length == 0) {
            [BasicTool showAlertInfo:@"银行卡必须填写银行名称" parent:self];
            return;
        }
    }
    
    __weak typeof(self) wself = self;
    
    // 如果是编辑模式，先删除旧的
    if (_methodToEdit && [_methodToEdit isKindOfClass:[NSDictionary class]] && _methodToEdit[@"id"]) {
        NSString *oldMethodId = [_methodToEdit[@"id"] description];
        if (oldMethodId && oldMethodId.length > 0) {
            [[HttpRestHelper sharedInstance] submitWalletDeleteWithdrawMethod:oldMethodId complete:^(BOOL deleteSucess, NSString *deleteMsg) {
                if (deleteSucess) {
                    // 删除成功，添加新的
                    [wself doBindMethod:accountName accountNumber:accountNumber qrCodeUrl:qrCodeUrl bankName:bankName];
                } else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [BasicTool showAlertInfo:deleteMsg ?: @"删除旧记录失败" parent:wself];
                    });
                }
            } hudParentView:wself.view];
            return;
        }
    }
    
    // 直接添加
    [self doBindMethod:accountName accountNumber:accountNumber qrCodeUrl:qrCodeUrl bankName:bankName];
}

#pragma mark - Network

- (void)doBindMethod:(NSString *)accountName accountNumber:(NSString *)accountNumber qrCodeUrl:(NSString *)qrCodeUrl bankName:(NSString *)bankName
{
    __weak typeof(self) wself = self;
    [[HttpRestHelper sharedInstance] submitWalletBindWithdrawMethod:(int)_selectedMethodType 
                                                         accountName:accountName 
                                                       accountNumber:accountNumber 
                                                           qrCodeUrl:qrCodeUrl.length > 0 ? qrCodeUrl : nil
                                                            bankName:bankName.length > 0 ? bankName : nil
                                                            complete:^(BOOL sucess, NSString *msg) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (sucess) {
                NSString *successMsg = wself.methodToEdit ? @"修改成功" : @"绑定成功";
                [BasicTool showAlertInfo:successMsg parent:wself];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [wself.navigationController popViewControllerAnimated:YES];
                });
            } else {
                NSString *failMsg = wself.methodToEdit ? @"修改失败" : @"绑定失败";
                [BasicTool showAlertInfo:msg ?: failMsg parent:wself];
            }
        });
    } hudParentView:self.view];
}

- (void)onCancel
{
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)dismissKeyboard
{
    [self.view endEditing:YES];
}

@end
