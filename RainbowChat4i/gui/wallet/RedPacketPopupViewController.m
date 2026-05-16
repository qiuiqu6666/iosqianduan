#import "RedPacketPopupViewController.h"
#import "HttpRestHelper.h"
#import "IMClientManager.h"
#import "FriendsListProvider.h"
#import "FileDownloadHelper.h"
#import "UserEntity.h"
#import "WalletRedPacketDetailViewController.h"
#import <QuartzCore/QuartzCore.h>

#define HexColor(hex) [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0 green:((hex >> 8) & 0xFF) / 255.0 blue:(hex & 0xFF) / 255.0 alpha:1.0]
#define WXGoldLight HexColor(0xF5E6C8)
#define RedPacketPopupBgColor HexColor(0xBD362B)  // 弹窗卡片背景色
#define RedPacketGoldText HexColor(0xF0D199)    // 弹窗内文字颜色

@interface RedPacketPopupViewController ()
@property (nonatomic, strong) UIView *dimView;
@property (nonatomic, strong) UIView *cardView;
@property (nonatomic, strong) UIImageView *cardBgImageView;  // 卡片背景（SVG #BD362B 圆角 12）
@property (nonatomic, strong) UIImageView *senderAvatarView;
@property (nonatomic, strong) UILabel *senderLabel;
@property (nonatomic, strong) UILabel *messageLabel;
@property (nonatomic, strong) UIButton *detailButton;
@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, strong) NSDictionary *detailData;
@end

@implementation RedPacketPopupViewController

- (instancetype)initWithPacketId:(NSString *)packetId {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _packetId = [packetId copy];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];
    self.modalPresentationStyle = UIModalPresentationOverFullScreen;
    self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;

    _dimView = [[UIView alloc] initWithFrame:self.view.bounds];
    _dimView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
    _dimView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:_dimView];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onClose)];
    [_dimView addGestureRecognizer:tap];

    // 与 SVG 尺寸比例一致（viewBox 260×360），按比例放大弹窗
    static const CGFloat kSVGWidth = 260;
    static const CGFloat kSVGHeight = 360;
    static const CGFloat kCardScale = 1.25;   // 弹窗按比例放大
    static const CGFloat kHeightScale = 1.0; // 弹窗拉长一点
    CGFloat maxW = (CGFloat)(kSVGWidth * kCardScale);
    CGFloat cardW = MIN(self.view.bounds.size.width - 32, maxW);
    CGFloat cardH = cardW * (kSVGHeight / kSVGWidth) * kHeightScale;
    _cardView = [[UIView alloc] initWithFrame:CGRectMake((self.view.bounds.size.width - cardW) / 2, (self.view.bounds.size.height - cardH) / 2 - 20, cardW, cardH)];
    _cardView.backgroundColor = [UIColor clearColor];
    _cardView.clipsToBounds = YES;
    _cardView.layer.cornerRadius = 18;
    _cardView.layer.masksToBounds = YES;
    _cardView.userInteractionEnabled = YES;
    UITapGestureRecognizer *cardTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onCardTapped)];
    [_cardView addGestureRecognizer:cardTap];
    [self.view addSubview:_cardView];

    // 使用 SVG 作为卡片背景图（Assets 中 red_packet_popup_bg.imageset）
    _cardBgImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, cardW, cardH)];
    _cardBgImageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _cardBgImageView.contentMode = UIViewContentModeScaleToFill;
    _cardBgImageView.clipsToBounds = YES;
    _cardBgImageView.layer.cornerRadius = 18;
    _cardBgImageView.backgroundColor = RedPacketPopupBgColor;  // 图片未加载时的兜底色
    [self updatePopupBackgroundWithStatus:-1];  // 初始用已领/默认背景，loadDetail 后再按 status 切换
    [_cardView addSubview:_cardBgImageView];

    // 发红包者：左上角小图标 + 文案（设计图约 20×20 图标、较小字号、左对齐）
    _senderAvatarView = [[UIImageView alloc] initWithFrame:CGRectZero];
    _senderAvatarView.backgroundColor = [WXGoldLight colorWithAlphaComponent:0.3];
    _senderAvatarView.layer.cornerRadius = 15;
    _senderAvatarView.clipsToBounds = YES;
    _senderAvatarView.contentMode = UIViewContentModeScaleAspectFill;
    _senderAvatarView.image = [UIImage imageNamed:@"default_avatar_60"];
    [_cardView addSubview:_senderAvatarView];

    _senderLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _senderLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    _senderLabel.textColor = RedPacketGoldText;
    _senderLabel.textAlignment = NSTextAlignmentCenter;  // 文字从中间往两边显示
    _senderLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    _senderLabel.text = @"红包";
    [_cardView addSubview:_senderLabel];

    // 状态文案：居中、明显更大更粗（设计图“手慢了,红包派完了”）
    _messageLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _messageLabel.font = [UIFont systemFontOfSize:22 weight:UIFontWeightMedium];
    _messageLabel.textColor = RedPacketGoldText;
    _messageLabel.textAlignment = NSTextAlignmentCenter;
    _messageLabel.numberOfLines = 2;
    _messageLabel.text = @"手慢了,红包派完了";
    [_cardView addSubview:_messageLabel];

    _detailButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_detailButton setTitle:@"查看领取详情 >" forState:UIControlStateNormal];
    [_detailButton setTitleColor:RedPacketGoldText forState:UIControlStateNormal];
    _detailButton.titleLabel.font = [UIFont systemFontOfSize:14];
    [_detailButton addTarget:self action:@selector(onViewDetail) forControlEvents:UIControlEventTouchUpInside];
    [_cardView addSubview:_detailButton];

    // 按设计图 260×360 比例布局，再按 card 实际尺寸缩放
    [self layoutCardContentWithCardWidth:cardW cardHeight:cardH];

    CGFloat closeSize = 44;
    _closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _closeButton.frame = CGRectMake((self.view.bounds.size.width - closeSize) / 2, CGRectGetMaxY(_cardView.frame) + 24, closeSize, closeSize);
    _closeButton.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.9];
    _closeButton.layer.cornerRadius = closeSize / 2;
    _closeButton.layer.borderColor = [HexColor(0xFFB366) CGColor];
    _closeButton.layer.borderWidth = 1;
    [_closeButton setTitle:@"✕" forState:UIControlStateNormal];
    [_closeButton setTitleColor:HexColor(0x666666) forState:UIControlStateNormal];
    _closeButton.titleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightMedium];
    [_closeButton addTarget:self action:@selector(onClose) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_closeButton];

    // 保证背景图在所有卡片子视图最底层
    [_cardView sendSubviewToBack:_cardBgImageView];

    [self loadDetail];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (!_cardBgImageView.image) {
        int status = _detailData[@"status"] ? [_detailData[@"status"] intValue] : -1;
        [self updatePopupBackgroundWithStatus:status];
    }
    [_cardView sendSubviewToBack:_cardBgImageView];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat cardW = _cardView.bounds.size.width;
    CGFloat cardH = _cardView.bounds.size.height;
    _cardBgImageView.frame = CGRectMake(0, 0, cardW, cardH);
    [self layoutCardContentWithCardWidth:cardW cardHeight:cardH];
    _closeButton.frame = CGRectMake((self.view.bounds.size.width - 44) / 2, CGRectGetMaxY(_cardView.frame) + 24, 44, 44);
}

// 设计图 260×360：发送者在「手慢了…」上方；所有文字从中间往两边显示
- (void)layoutCardContentWithCardWidth:(CGFloat)cardW cardHeight:(CGFloat)cardH {
    static const CGFloat kRefW = 260.0;
    static const CGFloat kRefH = 360.0;
    CGFloat sx = cardW / kRefW;
    CGFloat sy = cardH / kRefH;

    CGFloat leftPad = 16 * sx;
    CGFloat avatarSize = 30 * (CGFloat)fmin(sx, sy);  // 用户头像稍大
    CGFloat gap = 8 * sx;
    CGFloat senderRowH = (CGFloat)fmax(22 * sy, avatarSize);  // 行高不小于头像

    // 「手慢了，红包派完了」大致在卡片中部偏上
    CGFloat msgH = 40 * sy;
    CGFloat msgY = (CGFloat)(120 * sy);
    _messageLabel.frame = CGRectMake(leftPad, msgY, cardW - leftPad * 2, msgH);

    // 发送者：头像在名称前面，整块（头像+名称）居中，名称宽度随文字变化
    CGFloat topPad = msgY - senderRowH - (CGFloat)(14 * sy);
    CGFloat maxLabelW = cardW - leftPad * 2 - avatarSize - gap;
    UIFont *senderFont = _senderLabel.font ?: [UIFont systemFontOfSize:14];
    CGSize textSize = [_senderLabel.text sizeWithAttributes:@{ NSFontAttributeName: senderFont }];
    CGFloat senderLabelW = (CGFloat)fmin((double)maxLabelW, (double)ceil(textSize.width) + 4);
    CGFloat senderContentW = avatarSize + gap + senderLabelW;
    CGFloat senderStartX = (cardW - senderContentW) / 2;
    _senderAvatarView.frame = CGRectMake(senderStartX, topPad, avatarSize, avatarSize);
    _senderAvatarView.layer.cornerRadius = avatarSize * 0.5f;
    _senderLabel.frame = CGRectMake(senderStartX + avatarSize + gap, topPad, senderLabelW, senderRowH);

    CGFloat bottomPad = 12 * sy;
    CGFloat btnH = 44 * sy;
    _detailButton.frame = CGRectMake(0, cardH - bottomPad - btnH, cardW, btnH);
    _detailButton.hidden = (_detailData && [_detailData[@"status"] intValue] == 0);  // 可领取/未领取不显示
}

- (void)onCardTapped {
    if (_detailData && [_detailData[@"status"] intValue] == 0) {
        [self onViewDetail];
    }
}

- (void)updatePopupBackgroundWithStatus:(int)status {
    NSString *imageName = (status == 0) ? @"red_packet_popup_bg_can_claim" : @"red_packet_popup_bg";
    UIImage *bgImage = [UIImage imageNamed:imageName inBundle:[NSBundle mainBundle] compatibleWithTraitCollection:nil];
    if (bgImage) {
        _cardBgImageView.image = [bgImage imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    }
}

- (void)loadDetail {
    if (_packetId.length == 0) return;
    __weak typeof(self) wself = self;
    [[HttpRestHelper sharedInstance] submitWalletGetRedPacketDetail:_packetId complete:^(BOOL sucess, NSDictionary *data) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (sucess && data) {
                wself.detailData = data;
                NSString *senderUid = data[@"sender_uid"] ? [data[@"sender_uid"] description] : @"";
                NSString *localUid = [[IMClientManager sharedInstance] localUserInfo].user_uid ?: @"";
                NSString *senderName = @"用户";
                if ([senderUid isEqualToString:localUid]) {
                    UserEntity *me = [[IMClientManager sharedInstance] localUserInfo];
                    senderName = (me.nickname.length > 0 ? me.nickname : @"我");
                } else if (senderUid.length > 0) {
                    FriendsListProvider *flp = [[IMClientManager sharedInstance] getFriendsListProvider];
                    if (flp) {
                        id friend = [flp getFriendInfoByUid2:senderUid];
                        if (friend && [friend respondsToSelector:@selector(getNickNameWithRemark)]) {
                            NSString *nick = [friend getNickNameWithRemark];
                            if (nick.length > 0) senderName = nick;
                        }
                    }
                }
                wself.senderLabel.text = [NSString stringWithFormat:@"%@发出的红包", senderName];
                [wself.view setNeedsLayout];  // 名称更新后重新布局，头像跟到名称前
                int status = data[@"status"] ? [data[@"status"] intValue] : -1;
                if (status == 0) {
                    NSString *title = data[@"message"];
                    wself.messageLabel.text = (title.length > 0 ? title : @"恭喜发财，大吉大利");
                } else {
                    wself.messageLabel.text = @"手慢了,红包派完了";
                }
                [wself updatePopupBackgroundWithStatus:status];  // 可领取(status==0)用带「發」的可领取背景
                wself.detailButton.hidden = (status == 0);  // 可领取/未领取不显示「查看领取详情」
                if (senderUid.length > 0) {
                    [FileDownloadHelper loadUserAvatarWithUID:senderUid logTag:@"RedPacketPopup" complete:^(BOOL ok, UIImage *img) {
                        if (img) wself.senderAvatarView.image = img;
                    } donotLoadFromDisk:NO];
                }
            }
        });
    } hudParentView:self.view];
}

- (void)onViewDetail {
    if (self.onDismissBlock) {
        self.onDismissBlock(YES);
    } else {
        if (self.onOpenBlock) self.onOpenBlock(self.packetId);
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)onClose {
    if (self.onDismissBlock) {
        self.onDismissBlock(NO);
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

@end
