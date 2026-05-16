#import "WalletReceiveCodeViewController.h"
#import "IMClientManager.h"
#import "HttpRestHelper.h"
#import "BasicTool.h"
#import "UIViewController+RBPlainCustomNav.h"
#import "RBChromeNavigationBar.h"

@interface WalletReceiveCodeViewController ()
@property (nonatomic, strong) CAGradientLayer *bgGradientLayer;
@property (nonatomic, strong) UIView *receiveCard;
@property (nonatomic, strong) UILabel *hintLabel;
@property (nonatomic, strong) UIView *qrBox;
@property (nonatomic, strong) UIImageView *qrImageView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *addressTypeLabel;
@property (nonatomic, strong) UIView *addressBox;
@property (nonatomic, strong) UILabel *addressLabel;
@property (nonatomic, strong) UIView *actionsBox;
@property (nonatomic, strong) UIView *actionsSeparator;
@property (nonatomic, strong) UIButton *addressCopyButton;
@property (nonatomic, strong) UIButton *saveImageButton;
@property (nonatomic, strong) UILabel *warningLabel;

@property (nonatomic, copy) NSString *trxAddress;
@end

@implementation WalletReceiveCodeViewController

static NSAttributedString *RBWalletStyledAddressString(NSString *addr)
{
    if (addr.length == 0) return nil;
    NSMutableAttributedString *m = [[NSMutableAttributedString alloc] initWithString:addr];
    UIColor *blue = HexColor(0x3B82F6);
    UIFont *numFont = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    NSCharacterSet *digits = [NSCharacterSet decimalDigitCharacterSet];
    NSUInteger len = addr.length;
    for (NSUInteger i = 0; i < len; ) {
        unichar c = [addr characterAtIndex:i];
        BOOL isDigit = [digits characterIsMember:c];
        NSUInteger j = i + 1;
        while (j < len) {
            unichar cc = [addr characterAtIndex:j];
            if ([digits characterIsMember:cc] != isDigit) break;
            j++;
        }
        if (isDigit) {
            [m addAttributes:@{ NSForegroundColorAttributeName: blue, NSFontAttributeName: numFont } range:NSMakeRange(i, j - i)];
        }
        i = j;
    }
    return m;
}

static NSString *RBCachedWalletTrxAddressKey(NSString *uid) {
    if (uid.length == 0) {
        return nil;
    }
    return [NSString stringWithFormat:@"rc_wallet_trx_address_v1_%@", uid];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    self.navigationItem.titleView = nil;
    self.navigationItem.leftBarButtonItem = nil;
    self.navigationItem.rightBarButtonItem = nil;
    [self rb_installPlainCustomNavigationBarWithTitle:@"收款"];
    RBChromeNavigationBar *bar = [self rb_plainChromeNavigationBarIfInstalled];
    if (bar.backdropView) {
        for (UIView *sub in [bar.backdropView.subviews copy]) {
            [sub removeFromSuperview];
        }
        bar.backdropView.backgroundColor = [UIColor clearColor];
    }

    NSString *uid = [IMClientManager sharedInstance].localUserInfo.user_uid;
    NSString *nick = [IMClientManager sharedInstance].localUserInfo.nickname ?: @"";
    NSString *key = RBCachedWalletTrxAddressKey(uid);
    NSString *addr = key.length > 0 ? [[NSUserDefaults standardUserDefaults] stringForKey:key] : nil;
    if (addr.length == 0) {
        addr = @"--";
    }
    self.trxAddress = addr;

    _bgGradientLayer = [CAGradientLayer layer];
    _bgGradientLayer.colors = @[
        (id)[UIColor colorWithRed:0.77 green:0.84 blue:0.95 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.93 green:0.96 blue:1.0 alpha:1.0].CGColor
    ];
    _bgGradientLayer.startPoint = CGPointMake(0.0, 0.0);
    _bgGradientLayer.endPoint = CGPointMake(1.0, 1.0);
    [self.view.layer insertSublayer:_bgGradientLayer atIndex:0];

    _receiveCard = [[UIView alloc] initWithFrame:CGRectZero];
    _receiveCard.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.85];
    _receiveCard.layer.cornerRadius = 18;
    _receiveCard.layer.masksToBounds = YES;
    [self.view addSubview:_receiveCard];

    _hintLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _hintLabel.text = @"扫描二维码向我付款";
    _hintLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightRegular];
    _hintLabel.textColor = [UIColor colorWithWhite:0.45 alpha:1.0];
    _hintLabel.textAlignment = NSTextAlignmentCenter;
    [_receiveCard addSubview:_hintLabel];

    _qrBox = [[UIView alloc] initWithFrame:CGRectZero];
    _qrBox.backgroundColor = [UIColor whiteColor];
    _qrBox.layer.cornerRadius = 14;
    _qrBox.layer.masksToBounds = YES;
    [_receiveCard addSubview:_qrBox];

    _qrImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
    _qrImageView.backgroundColor = [UIColor whiteColor];
    _qrImageView.layer.cornerRadius = 8;
    _qrImageView.clipsToBounds = YES;
    _qrImageView.contentMode = UIViewContentModeScaleAspectFit;
    _qrImageView.image = [self qrImageForString:addr size:220];
    [_qrBox addSubview:_qrImageView];

    _nameLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _nameLabel.text = (nick.length > 0 ? nick : @"我");
    _nameLabel.font = [UIFont systemFontOfSize:22 weight:UIFontWeightBold];
    _nameLabel.textColor = [UIColor colorWithRed:17 / 255.0 green:24 / 255.0 blue:39 / 255.0 alpha:1.0];
    _nameLabel.textAlignment = NSTextAlignmentCenter;
    _nameLabel.hidden = YES;
    [_receiveCard addSubview:_nameLabel];

    _addressTypeLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _addressTypeLabel.text = @"普通地址";
    _addressTypeLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    _addressTypeLabel.textColor = HexColor(0x3B82F6);
    _addressTypeLabel.backgroundColor = HexColor(0xDCEBFF);
    _addressTypeLabel.textAlignment = NSTextAlignmentCenter;
    _addressTypeLabel.layer.cornerRadius = 6;
    _addressTypeLabel.layer.masksToBounds = YES;
    [_receiveCard addSubview:_addressTypeLabel];

    _addressBox = [[UIView alloc] initWithFrame:CGRectZero];
    _addressBox.backgroundColor = [UIColor colorWithRed:0.88 green:0.91 blue:0.96 alpha:1.0];
    _addressBox.layer.cornerRadius = 12;
    _addressBox.layer.masksToBounds = YES;
    [_receiveCard addSubview:_addressBox];

    _addressLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _addressLabel.text = addr;
    if (@available(iOS 13.0, *)) {
        _addressLabel.font = [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightRegular];
    } else {
        _addressLabel.font = [UIFont systemFontOfSize:13];
    }
    _addressLabel.textColor = [UIColor colorWithRed:17 / 255.0 green:24 / 255.0 blue:39 / 255.0 alpha:1.0];
    _addressLabel.numberOfLines = 0;
    _addressLabel.lineBreakMode = NSLineBreakByCharWrapping;
    NSAttributedString *styledAddr = RBWalletStyledAddressString(addr);
    if (styledAddr) _addressLabel.attributedText = styledAddr;
    [_addressBox addSubview:_addressLabel];

    _actionsBox = [[UIView alloc] initWithFrame:CGRectZero];
    _actionsBox.backgroundColor = [UIColor whiteColor];
    _actionsBox.layer.cornerRadius = 12;
    _actionsBox.layer.masksToBounds = YES;
    [_receiveCard addSubview:_actionsBox];

    _addressCopyButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_addressCopyButton setTitle:@"复制地址" forState:UIControlStateNormal];
    [_addressCopyButton setTitleColor:[UIColor colorWithRed:17 / 255.0 green:24 / 255.0 blue:39 / 255.0 alpha:1.0] forState:UIControlStateNormal];
    _addressCopyButton.backgroundColor = [UIColor clearColor];
    _addressCopyButton.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    _addressCopyButton.tintColor = HexColor(0x3B82F6);
    _addressCopyButton.contentEdgeInsets = UIEdgeInsetsMake(0, 8, 0, 8);
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *cfg2 = [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightSemibold];
        UIImage *img2 = [UIImage systemImageNamed:@"doc.on.doc.fill" withConfiguration:cfg2];
        [_addressCopyButton setImage:img2 forState:UIControlStateNormal];
        _addressCopyButton.imageEdgeInsets = UIEdgeInsetsMake(0, -4, 0, 0);
        _addressCopyButton.titleEdgeInsets = UIEdgeInsetsMake(0, 4, 0, 0);
    }
    [_addressCopyButton addTarget:self action:@selector(onCopyAddress) forControlEvents:UIControlEventTouchUpInside];
    [_actionsBox addSubview:_addressCopyButton];

    _saveImageButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_saveImageButton setTitle:@"保存图片" forState:UIControlStateNormal];
    [_saveImageButton setTitleColor:[UIColor colorWithRed:17 / 255.0 green:24 / 255.0 blue:39 / 255.0 alpha:1.0] forState:UIControlStateNormal];
    _saveImageButton.backgroundColor = [UIColor clearColor];
    _saveImageButton.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    _saveImageButton.tintColor = HexColor(0x3B82F6);
    _saveImageButton.contentEdgeInsets = UIEdgeInsetsMake(0, 8, 0, 8);
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *cfg3 = [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightSemibold];
        UIImage *img3 = [UIImage systemImageNamed:@"square.and.arrow.down.on.square.fill" withConfiguration:cfg3];
        [_saveImageButton setImage:img3 forState:UIControlStateNormal];
        _saveImageButton.imageEdgeInsets = UIEdgeInsetsMake(0, -4, 0, 0);
        _saveImageButton.titleEdgeInsets = UIEdgeInsetsMake(0, 4, 0, 0);
    }
    [_saveImageButton addTarget:self action:@selector(onSaveImage) forControlEvents:UIControlEventTouchUpInside];
    [_actionsBox addSubview:_saveImageButton];

    _actionsSeparator = [[UIView alloc] initWithFrame:CGRectZero];
    _actionsSeparator.backgroundColor = [UIColor colorWithWhite:0.88 alpha:1.0];
    [_actionsBox addSubview:_actionsSeparator];

    _warningLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _warningLabel.numberOfLines = 0;
    _warningLabel.textAlignment = NSTextAlignmentCenter;
    _warningLabel.font = [UIFont systemFontOfSize:12];
    _warningLabel.textColor = [UIColor colorWithRed:107 / 255.0 green:114 / 255.0 blue:128 / 255.0 alpha:1.0];
    _warningLabel.text = @"仅可向此账户转入波场系通证（如 TRX 或 TRC10/20/721 通证），转入其他通证将无法找回。";
    [self.view addSubview:_warningLabel];
    
    __weak typeof(self) wself = self;
    [[HttpRestHelper sharedInstance] submitTrxWalletDepositAddressWithComplete:^(BOOL sucess, NSDictionary *data) {
        dispatch_async(dispatch_get_main_queue(), ^{
            WalletReceiveCodeViewController *s = wself;
            if (!s) return;
            if (!(sucess && [data isKindOfClass:[NSDictionary class]])) return;
            NSString *addr2 = [data[@"trx_address"] description];
            if (addr2.length == 0) addr2 = [data[@"trxAddress"] description];
            if (addr2.length == 0) return;
            s.trxAddress = addr2;
            NSAttributedString *styledAddr2 = RBWalletStyledAddressString(addr2);
            if (styledAddr2) {
                s.addressLabel.attributedText = styledAddr2;
            } else {
                s.addressLabel.text = addr2;
            }
            s.qrImageView.image = [s qrImageForString:addr2 size:220];
            NSString *key2 = RBCachedWalletTrxAddressKey(uid);
            if (key2.length > 0) {
                NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
                [ud setObject:addr2 forKey:key2];
                [ud synchronize];
            }
        });
    } hudParentView:nil];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self rb_plainCustomNavHostViewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self rb_plainCustomNavHostViewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self rb_plainCustomNavHostViewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [self rb_plainCustomNavHostViewDidDisappear:animated];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height;
    CGFloat top = 0;
    if (@available(iOS 11.0, *)) {
        top = self.view.safeAreaInsets.top;
    }
    if (self.bgGradientLayer) {
        self.bgGradientLayer.frame = CGRectMake(0, 0, w, h);
    }

    CGFloat cardW = MIN(w - 32, 360);
    CGFloat cardX = (w - cardW) * 0.5;
    CGFloat y = top + 18;

    CGFloat qrOuter = MIN(280, cardW - 48);
    CGFloat qrPad = 10;
    CGFloat qrInner = qrOuter - qrPad * 2;

    CGFloat hintH = 22;
    CGFloat nameH = 0;
    CGFloat addrMinH = 52;
    CGFloat actionsH = 56;

    CGFloat hintY = 18;
    CGFloat qrBoxY = hintY + hintH + 16;
    CGFloat nameY = qrBoxY + qrOuter + 14;
    CGFloat pillY = qrBoxY + qrOuter + 16;
    CGFloat addrBoxYBase = pillY + 22 + 14;

    self.receiveCard.frame = CGRectMake(cardX, y, cardW, 0);
    self.hintLabel.frame = CGRectMake(18, hintY, cardW - 36, hintH);
    self.qrBox.frame = CGRectMake((cardW - qrOuter) * 0.5, qrBoxY, qrOuter, qrOuter);
    self.qrImageView.frame = CGRectMake(qrPad, qrPad, qrInner, qrInner);

    self.nameLabel.frame = CGRectMake(18, nameY, cardW - 36, nameH);

    CGSize pillSz = [self.addressTypeLabel.text sizeWithAttributes:@{NSFontAttributeName:self.addressTypeLabel.font}];
    CGFloat pillW = ceil(pillSz.width) + 14;
    CGFloat pillH = 22;
    CGFloat badgeW = MIN(pillW, cardW - 36);
    self.addressTypeLabel.frame = CGRectMake((cardW - badgeW) * 0.5, pillY, badgeW, pillH);

    CGFloat addrBoxW = cardW - 36;
    CGFloat addrLabelW = addrBoxW - 28;
    CGSize addrFit = [self.addressLabel sizeThatFits:CGSizeMake(addrLabelW, CGFLOAT_MAX)];
    CGFloat addrH = MAX(addrMinH, ceil(addrFit.height) + 20);
    self.addressBox.frame = CGRectMake(18, addrBoxYBase, addrBoxW, addrH);
    self.addressLabel.frame = CGRectMake(14, (addrH - ceil(addrFit.height)) * 0.5, addrLabelW, ceil(addrFit.height));

    CGFloat actionsY = CGRectGetMaxY(self.addressBox.frame) + 14;
    self.actionsBox.frame = CGRectMake(18, actionsY, cardW - 36, actionsH);
    CGFloat halfW = CGRectGetWidth(self.actionsBox.bounds) * 0.5;
    self.addressCopyButton.frame = CGRectMake(0, 0, halfW, actionsH);
    self.saveImageButton.frame = CGRectMake(halfW, 0, halfW, actionsH);
    self.actionsSeparator.frame = CGRectMake(halfW - 0.5, 10, 1, actionsH - 20);

    CGFloat receiveH = CGRectGetMaxY(self.actionsBox.frame) + 18;
    self.receiveCard.frame = CGRectMake(cardX, y, cardW, receiveH);

    self.warningLabel.frame = CGRectMake(16, CGRectGetMaxY(self.receiveCard.frame) + 16, w - 32, 60);
}

- (void)onCopyAddress
{
    NSString *addr = self.trxAddress;
    if (addr.length == 0 || [addr isEqualToString:@"--"]) {
        [BasicTool showUserDefintToast:@"地址为空" view:self.view atHide:nil];
        return;
    }
    [UIPasteboard generalPasteboard].string = addr;
    [BasicTool showUserDefintToast:@"地址已复制" view:self.view atHide:nil];
}

- (UIImage *)rb_snapshotReceiveCardImage
{
    CGSize sz = self.receiveCard.bounds.size;
    if (sz.width < 1 || sz.height < 1) {
        return nil;
    }
    BOOL h1 = self.actionsBox.hidden;
    self.actionsBox.hidden = YES;
    UIGraphicsBeginImageContextWithOptions(sz, NO, [UIScreen mainScreen].scale);
    [self.receiveCard.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    self.actionsBox.hidden = h1;
    return image;
}

- (void)onSaveImage
{
    UIImage *img = [self rb_snapshotReceiveCardImage];
    if (!img) {
        [BasicTool showUserDefintToast:@"保存失败" view:self.view atHide:nil];
        return;
    }
    UIImageWriteToSavedPhotosAlbum(img, self, @selector(image:didFinishSavingWithError:contextInfo:), nil);
}

- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo
{
    NSString *text = error ? @"保存失败" : @"保存成功";
    [BasicTool showUserDefintToast:text view:self.view atHide:nil];
}

- (UIImage *)qrImageForString:(NSString *)text size:(CGFloat)size
{
    if (text.length == 0) {
        return nil;
    }

    NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding];
    CIFilter *filter = [CIFilter filterWithName:@"CIQRCodeGenerator"];
    [filter setDefaults];
    [filter setValue:data forKey:@"inputMessage"];
    [filter setValue:@"M" forKey:@"inputCorrectionLevel"];
    CIImage *outputImage = filter.outputImage;
    if (!outputImage) {
        return nil;
    }

    CGRect extent = CGRectIntegral(outputImage.extent);
    CGFloat scale = MIN(size / CGRectGetWidth(extent), size / CGRectGetHeight(extent));
    size_t width = (size_t)(CGRectGetWidth(extent) * scale);
    size_t height = (size_t)(CGRectGetHeight(extent) * scale);

    CGColorSpaceRef cs = CGColorSpaceCreateDeviceGray();
    CGContextRef bitmapRef = CGBitmapContextCreate(nil, width, height, 8, 0, cs, (CGBitmapInfo)kCGImageAlphaNone);
    CIContext *context = [CIContext contextWithOptions:nil];
    CGImageRef bitmapImage = [context createCGImage:outputImage fromRect:extent];
    CGContextSetInterpolationQuality(bitmapRef, kCGInterpolationNone);
    CGContextScaleCTM(bitmapRef, scale, scale);
    CGContextDrawImage(bitmapRef, extent, bitmapImage);
    CGImageRef scaledImage = CGBitmapContextCreateImage(bitmapRef);

    UIImage *result = [UIImage imageWithCGImage:scaledImage];
    CGImageRelease(scaledImage);
    CGImageRelease(bitmapImage);
    CGContextRelease(bitmapRef);
    CGColorSpaceRelease(cs);
    return result;
}

@end
